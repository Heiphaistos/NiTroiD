package com.heiphaistos.nitroid

import java.io.File
import java.util.concurrent.TimeUnit

/** Construit la structure `[{title, items: [[clé, valeur]…]}]` attendue côté Dart. */
class Sections {
    val list = ArrayList<Map<String, Any>>()

    fun section(title: String, block: Items.() -> Unit) {
        val items = Items()
        try {
            items.block()
        } catch (e: Throwable) {
            items.add("Erreur de lecture", e.message ?: e.javaClass.simpleName)
        }
        if (items.rows.isNotEmpty()) list.add(mapOf("title" to title, "items" to items.rows))
    }
}

class Items {
    val rows = ArrayList<List<String>>()

    fun add(key: String, value: Any?) {
        val text = when (value) {
            null -> return
            is Boolean -> if (value) "oui" else "non"
            else -> value.toString()
        }
        if (text.isBlank()) return
        rows.add(listOf(key, text))
    }

    /** Ajoute une valeur calculée en ignorant silencieusement les API refusées. */
    fun safe(key: String, block: () -> Any?) {
        try {
            add(key, block())
        } catch (_: Throwable) {
        }
    }
}

object Sys {
    private val getter by lazy {
        try {
            Class.forName("android.os.SystemProperties").getMethod("get", String::class.java)
        } catch (_: Throwable) {
            null
        }
    }

    /** Lit une propriété système (`getprop`) ; chaîne vide si absente ou interdite. */
    fun prop(key: String): String {
        try {
            val v = getter?.invoke(null, key) as? String
            if (!v.isNullOrEmpty()) return v
        } catch (_: Throwable) {
        }
        return ""
    }

    fun read(path: String, limit: Int = 64 * 1024): String? = try {
        val f = File(path)
        f.inputStream().use { input ->
            val buf = ByteArray(limit)
            var total = 0
            while (total < limit) {
                val n = input.read(buf, total, limit - total)
                if (n <= 0) break
                total += n
            }
            String(buf, 0, total).trim()
        }
    } catch (_: Throwable) {
        null
    }

    fun readLong(path: String): Long? = read(path, 64)?.trim()?.toLongOrNull()

    /** Exécute une commande sans shell (pas d'injection possible), sortie tronquée. */
    fun exec(cmd: List<String>, timeoutSec: Long = 20, limit: Int = 2 * 1024 * 1024): String {
        return try {
            val proc = ProcessBuilder(cmd).redirectErrorStream(true).start()
            val out = StringBuilder()
            val reader = Thread {
                try {
                    proc.inputStream.bufferedReader().use { r ->
                        val buf = CharArray(8192)
                        while (true) {
                            val n = r.read(buf)
                            if (n < 0) break
                            if (out.length < limit) out.append(buf, 0, minOf(n, limit - out.length))
                        }
                    }
                } catch (_: Throwable) {
                }
            }
            reader.start()
            if (!proc.waitFor(timeoutSec, TimeUnit.SECONDS)) proc.destroy()
            reader.join(2000)
            out.toString()
        } catch (e: Throwable) {
            "Impossible d'exécuter ${cmd.first()} : ${e.message}"
        }
    }

    fun bytes(v: Long?): String {
        if (v == null || v < 0) return "—"
        val units = arrayOf("o", "Ko", "Mo", "Go", "To")
        var value = v.toDouble()
        var i = 0
        while (value >= 1024 && i < units.size - 1) {
            value /= 1024
            i++
        }
        return if (i == 0) "$v o" else String.format(java.util.Locale.FRANCE, "%.1f %s", value, units[i])
    }

    fun mhz(khz: Long?): String = if (khz == null || khz <= 0) "—" else "${khz / 1000} MHz"

    fun duration(ms: Long): String {
        val s = ms / 1000
        val d = s / 86400
        val h = (s % 86400) / 3600
        val m = (s % 3600) / 60
        return if (d > 0) "${d}j ${h}h ${m}min" else "${h}h ${m}min"
    }
}
