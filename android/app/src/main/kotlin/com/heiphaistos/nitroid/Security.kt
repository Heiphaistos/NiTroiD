package com.heiphaistos.nitroid

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import java.io.File
import java.security.KeyStore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit

object Security {
    private fun check(id: String, title: String, status: String, detail: String, action: String? = null) =
        mapOf("id" to id, "title" to title, "status" to status, "detail" to detail, "action" to action)

    fun selinux(): String {
        Sys.read("/sys/fs/selinux/enforce", 8)?.let { return if (it == "1") "Enforcing" else "PERMISSIF" }
        val boot = Sys.prop("ro.boot.selinux")
        if (boot.isNotBlank()) return if (boot == "permissive") "PERMISSIF" else boot
        // Lecture refusée : c'est justement le comportement d'un SELinux actif.
        return "Enforcing (lecture protégée)"
    }

    private val suPaths = listOf(
        "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su", "/system/sd/xbin/su",
        "/data/local/xbin/su", "/data/local/bin/su", "/data/local/su", "/vendor/bin/su", "/system/bin/.ext/su",
        "/data/adb/magisk", "/data/adb/ksu", "/data/adb/ap",
    )

    private val rootApps = mapOf(
        "com.topjohnwu.magisk" to "Magisk", "io.github.vvb2060.magisk" to "Magisk Alpha", "me.weishu.kernelsu" to "KernelSU",
        "me.bmax.apatch" to "APatch", "eu.chainfire.supersu" to "SuperSU", "com.koushikdutta.superuser" to "Superuser",
        "com.kingroot.kinguser" to "KingRoot", "com.noshufou.android.su" to "Superuser (ancien)",
        "de.robv.android.xposed.installer" to "Xposed", "org.lsposed.manager" to "LSPosed",
    )

    fun rootIndicators(ctx: Context): List<String> {
        val found = ArrayList<String>()
        suPaths.filter { File(it).exists() }.forEach { found.add("binaire $it") }
        for ((pkg, name) in rootApps) {
            try {
                ctx.packageManager.getPackageInfo(pkg, 0)
                found.add("app $name")
            } catch (_: PackageManager.NameNotFoundException) {
            }
        }
        if (Build.TAGS?.contains("test-keys") == true) found.add("build signé test-keys")
        if (Sys.prop("ro.debuggable") == "1") found.add("ro.debuggable=1")
        if (Sys.prop("ro.secure") == "0") found.add("ro.secure=0")
        System.getenv("PATH")?.split(':')?.forEach { dir -> if (File(dir, "su").exists() && "binaire $dir/su" !in found) found.add("su dans $dir") }
        return found
    }

    fun checks(ctx: Context): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val cr = ctx.contentResolver
        val pm = ctx.packageManager

        val root = rootIndicators(ctx)
        out += if (root.isEmpty()) check("root", "Root / jailbreak", "ok", "Aucune trace de root (su, Magisk, KernelSU…)")
        else check("root", "Appareil rooté", "warn", "Indices : ${root.joinToString(", ")}. Le root affaiblit l’isolation des applications.")

        val vbs = Sys.prop("ro.boot.verifiedbootstate")
        val locked = Sys.prop("ro.boot.flash.locked")
        out += when {
            vbs == "green" || locked == "1" -> check("boot", "Démarrage vérifié", "ok", "Bootloader verrouillé, système intègre${if (vbs.isNotBlank()) " ($vbs)" else ""}")
            vbs == "orange" || locked == "0" -> check("boot", "Bootloader déverrouillé", "bad", "N’importe qui avec un accès physique peut modifier le système (état $vbs).")
            vbs == "yellow" -> check("boot", "Démarrage vérifié", "warn", "Système signé par une clé personnalisée (yellow).")
            else -> check("boot", "Démarrage vérifié", "info", "État non communiqué par le constructeur.")
        }

        val patch = Build.VERSION.SECURITY_PATCH
        try {
            val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(patch)
            val days = TimeUnit.MILLISECONDS.toDays(Date().time - (date?.time ?: 0))
            out += when {
                days > 365 -> check("patch", "Correctifs de sécurité", "bad", "Dernier correctif : $patch (il y a $days jours). L’appareil n’est plus maintenu.", "android.settings.DEVICE_INFO_SETTINGS")
                days > 120 -> check("patch", "Correctifs de sécurité", "warn", "Dernier correctif : $patch (il y a $days jours). Cherchez une mise à jour.", "android.settings.DEVICE_INFO_SETTINGS")
                else -> check("patch", "Correctifs de sécurité", "ok", "À jour : $patch")
            }
        } catch (_: Throwable) {
            out += check("patch", "Correctifs de sécurité", "info", "Niveau : $patch")
        }

        val km = ctx.getSystemService(KeyguardManager::class.java)
        out += if (km.isDeviceSecure) check("lock", "Verrouillage de l’écran", "ok", "Code, schéma ou mot de passe configuré")
        else check("lock", "Verrouillage de l’écran", "bad", "Aucun code : n’importe qui peut accéder à vos données.", "android.app.action.SET_NEW_PASSWORD")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val bm = ctx.getSystemService(BiometricManager::class.java)
                val strong = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS
                out += check("bio", "Biométrie forte", if (strong) "ok" else "info", if (strong) "Empreinte/visage de classe 3 enregistré" else "Aucune biométrie forte enregistrée")
            } catch (_: Throwable) {
            }
        }

        val dpm = ctx.getSystemService(DevicePolicyManager::class.java)
        out += when (dpm.storageEncryptionStatus) {
            DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE, DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_PER_USER ->
                check("crypto", "Chiffrement du stockage", "ok", "Données chiffrées")
            DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_DEFAULT_KEY ->
                check("crypto", "Chiffrement du stockage", "warn", "Chiffré avec la clé par défaut : définissez un code de verrouillage.")
            else -> check("crypto", "Chiffrement du stockage", "bad", "Stockage non chiffré.", "android.settings.SECURITY_SETTINGS")
        }

        val selinux = selinux()
        out += check("selinux", "SELinux", if (selinux.startsWith("PERMISSIF")) "bad" else "ok", selinux)

        val dev = Settings.Global.getInt(cr, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
        val adb = Settings.Global.getInt(cr, Settings.Global.ADB_ENABLED, 0) == 1
        out += when {
            adb -> check("adb", "Débogage USB activé", "warn", "Un ordinateur autorisé peut contrôler le téléphone. Désactivez-le après usage.", "android.settings.APPLICATION_DEVELOPMENT_SETTINGS")
            dev -> check("adb", "Options développeur", "info", "Activées, débogage USB coupé.", "android.settings.APPLICATION_DEVELOPMENT_SETTINGS")
            else -> check("adb", "Options développeur", "ok", "Désactivées")
        }

        val am = ctx.getSystemService(AccessibilityManager::class.java)
        val services = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        val thirdParty = services.filter { (it.resolveInfo.serviceInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0 }
        out += when {
            thirdParty.isNotEmpty() -> check("a11y", "Services d’accessibilité", "warn",
                "${thirdParty.joinToString(", ") { it.resolveInfo.loadLabel(pm) }} : ces apps peuvent lire l’écran et agir à votre place.",
                "android.settings.ACCESSIBILITY_SETTINGS")
            services.isNotEmpty() -> check("a11y", "Services d’accessibilité", "ok", "Uniquement des services système")
            else -> check("a11y", "Services d’accessibilité", "ok", "Aucun service actif")
        }

        val admins = dpm.activeAdmins.orEmpty().filter {
            try {
                (pm.getApplicationInfo(it.packageName, 0).flags and ApplicationInfo.FLAG_SYSTEM) == 0
            } catch (_: Throwable) {
                true
            }
        }
        out += if (admins.isEmpty()) check("admin", "Administrateurs de l’appareil", "ok", "Aucune app tierce administratrice")
        else check("admin", "Administrateurs de l’appareil", "warn",
            "${admins.joinToString(", ") { Apps.label(pm, it.packageName) }} peuvent verrouiller/effacer l’appareil et bloquer leur désinstallation.")

        val listeners = Apps.notificationListeners(ctx).filter { !Apps.isSystem(pm, it) }
        if (listeners.isNotEmpty()) {
            out += check("notif", "Lecture des notifications", "info",
                "${listeners.joinToString(", ") { Apps.label(pm, it) }} lisent toutes vos notifications (messages, codes 2FA).",
                "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
        }

        try {
            val ks = KeyStore.getInstance("AndroidCAStore").apply { load(null) }
            val user = ks.aliases().toList().count { it.startsWith("user:") }
            out += if (user == 0) check("ca", "Certificats racine", "ok", "Aucun certificat utilisateur installé")
            else check("ca", "Certificats racine utilisateur", "warn",
                "$user certificat(s) ajouté(s) : permet d’intercepter le trafic chiffré (entreprise, antivirus… ou espion).", "android.settings.SECURITY_SETTINGS")
        } catch (_: Throwable) {
        }

        val cm = ctx.getSystemService(ConnectivityManager::class.java)
        val vpn = cm.allNetworks.any { cm.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true }
        val proxy = cm.defaultProxy
        out += when {
            proxy != null -> check("proxy", "Proxy réseau", "warn", "Trafic redirigé via ${proxy.host}:${proxy.port}. Vérifiez que vous l’avez configuré.", "android.settings.WIFI_SETTINGS")
            vpn -> check("proxy", "VPN actif", "info", "Votre trafic passe par un VPN.", "android.settings.VPN_SETTINGS")
            else -> check("proxy", "VPN / proxy", "ok", "Connexion directe")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val installers = Apps.installCapable(ctx).filter { !Apps.isSystem(pm, it) }
            if (installers.isNotEmpty()) {
                out += check("unknown", "Sources inconnues", "warn",
                    "Peuvent installer des APK : ${installers.joinToString(", ") { Apps.label(pm, it) }}.",
                    "android.settings.MANAGE_UNKNOWN_APP_SOURCES")
            } else {
                out += check("unknown", "Sources inconnues", "ok", "Aucune app tierce autorisée à installer des APK")
            }
        }

        if (Build.FINGERPRINT.contains("generic") || Build.HARDWARE.contains("ranchu") || Build.HARDWARE.contains("goldfish")) {
            out += check("emu", "Émulateur", "info", "NiTroiD tourne dans un émulateur : certaines mesures sont simulées.")
        }
        return out
    }
}
