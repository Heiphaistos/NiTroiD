package com.heiphaistos.nitroid

import android.content.Context
import android.provider.Settings
import java.io.DataOutputStream
import java.util.concurrent.TimeUnit

/** Exécution de commandes avec les droits superutilisateur (su). */
object Root {
    @Volatile
    private var cached: Boolean? = null

    data class Result(val ok: Boolean, val out: String, val code: Int)

    /** Lance une commande via `su -c`. La première fois, Magisk/KernelSU affiche une demande. */
    fun exec(command: String, timeoutSec: Long = 30): Result {
        return try {
            val proc = ProcessBuilder("su").redirectErrorStream(true).start()
            DataOutputStream(proc.outputStream).use { os ->
                os.writeBytes(command + "\n")
                os.writeBytes("exit\n")
                os.flush()
            }
            val out = StringBuilder()
            val reader = Thread {
                try {
                    proc.inputStream.bufferedReader().use { r ->
                        val buf = CharArray(8192)
                        while (true) {
                            val n = r.read(buf)
                            if (n < 0) break
                            if (out.length < 2 * 1024 * 1024) out.append(buf, 0, n)
                        }
                    }
                } catch (_: Throwable) {
                }
            }
            reader.start()
            val finished = proc.waitFor(timeoutSec, TimeUnit.SECONDS)
            if (!finished) {
                proc.destroy()
                return Result(false, "Délai dépassé (commande toujours en cours)", -1)
            }
            reader.join(2000)
            Result(proc.exitValue() == 0, out.toString().trim(), proc.exitValue())
        } catch (e: Throwable) {
            Result(false, "Pas d'accès root : ${e.message}", -1)
        }
    }

    fun available(force: Boolean = false): Boolean {
        cached?.let { if (!force) return it }
        val r = exec("id", 8)
        val ok = r.ok && r.out.contains("uid=0")
        cached = ok
        return ok
    }
}

object Dev {
    // Permissions « développeur » accordables par ADB… ou directement par root.
    private val devPermissions = listOf(
        "android.permission.WRITE_SECURE_SETTINGS",
        "android.permission.READ_LOGS",
        "android.permission.DUMP",
        "android.permission.PACKAGE_USAGE_STATS",
    )

    /** Accorde à NiTroiD les permissions avancées via root. Renvoie le détail par permission. */
    fun grantSelf(ctx: Context): Map<String, Any> {
        if (!Root.available()) return mapOf("root" to false, "results" to emptyList<Any>())
        val pkg = ctx.packageName
        val results = ArrayList<Map<String, Any>>()
        for (perm in devPermissions) {
            val r = Root.exec("pm grant $pkg $perm", 10)
            results.add(mapOf("perm" to perm.substringAfterLast('.'), "ok" to r.ok, "detail" to r.out.take(200)))
        }
        // AppOps pour les accès qui ne passent pas par pm grant.
        for ((op, label) in listOf("GET_USAGE_STATS" to "usage", "WRITE_SETTINGS" to "writeSettings")) {
            val r = Root.exec("appops set $pkg $op allow", 8)
            results.add(mapOf("perm" to label, "ok" to r.ok, "detail" to r.out.take(200)))
        }
        return mapOf("root" to true, "results" to results)
    }

    private fun readSetting(ctx: Context, ns: String, key: String): String? = try {
        when (ns) {
            "global" -> Settings.Global.getString(ctx.contentResolver, key)
            "secure" -> Settings.Secure.getString(ctx.contentResolver, key)
            else -> Settings.System.getString(ctx.contentResolver, key)
        }
    } catch (_: Throwable) {
        null
    }

    /** Lit un lot de réglages « ns/key » (format "global:key"). */
    fun getSettings(ctx: Context, keys: List<String>): Map<String, String?> {
        val out = HashMap<String, String?>()
        for (full in keys) {
            val ns = full.substringBefore(':')
            val key = full.substringAfter(':')
            out[full] = readSetting(ctx, ns, key) ?: Root.run {
                if (available()) exec("settings get $ns $key", 6).out.takeIf { it.isNotBlank() && it != "null" } else null
            }
        }
        return out
    }

    private val nsAllowed = setOf("global", "secure", "system")
    private val keyPattern = Regex("^[A-Za-z0-9_.]{1,64}$")
    private val valuePattern = Regex("^[A-Za-z0-9_.,:/@+-]{0,128}$")

    /** Écrit un réglage : WRITE_SECURE_SETTINGS si disponible, sinon root. Renvoie null si OK. */
    fun putSetting(ctx: Context, ns: String, key: String, value: String): String? {
        // Valeurs bornées : aucune métacaractère shell ne peut atteindre root.
        if (ns !in nsAllowed || !keyPattern.matches(key) || !valuePattern.matches(value)) return "Paramètre invalide"
        // 1) Tenter via le ContentResolver (si la permission est détenue).
        try {
            val cr = ctx.contentResolver
            val asInt = value.toIntOrNull()
            when (ns) {
                "global" -> if (asInt != null) Settings.Global.putInt(cr, key, asInt) else Settings.Global.putString(cr, key, value)
                "secure" -> if (asInt != null) Settings.Secure.putInt(cr, key, asInt) else Settings.Secure.putString(cr, key, value)
                else -> if (asInt != null) Settings.System.putInt(cr, key, asInt) else Settings.System.putString(cr, key, value)
            }
            return null
        } catch (_: Throwable) {
            // 2) Repli root.
            if (Root.available()) {
                val r = Root.exec("settings put $ns $key $value", 8)
                return if (r.ok) null else "Échec root : ${r.out.take(200)}"
            }
            return "Permission requise : accorde WRITE_SECURE_SETTINGS (ADB ou root)."
        }
    }

    /** Actions avancées sur une application (root requis). */
    fun appAction(ctx: Context, action: String, pkg: String): String {
        if (pkg.isBlank() || !Regex("^[A-Za-z0-9._]+$").matches(pkg)) return "Paquet invalide"
        if (!Root.available()) return "Cette action nécessite le root."
        val cmd = when (action) {
            "forceStop" -> "am force-stop $pkg"
            "clearData" -> "pm clear $pkg"
            "clearCache" -> "pm trim-caches 999999999999 && echo caches-trimmed"
            "disable" -> "pm disable-user --user 0 $pkg"
            "enable" -> "pm enable $pkg"
            "uninstallSystem" -> "pm uninstall -k --user 0 $pkg"
            else -> return "Action inconnue"
        }
        val r = Root.exec(cmd, 20)
        return if (r.ok) "ok" else "Échec : ${r.out.take(300)}"
    }
}
