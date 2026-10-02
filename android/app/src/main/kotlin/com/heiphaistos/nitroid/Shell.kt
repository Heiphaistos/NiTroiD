package com.heiphaistos.nitroid

import java.io.File

/** Outils en ligne de commande, exécutés sans shell et avec arguments validés. */
object Shell {
    private val host = Regex("^[A-Za-z0-9.:-]{1,253}$")
    private val service = Regex("^[a-z_.]+( --?[a-z]+)*$")

    fun tool(args: Map<*, *>): String = when (args["tool"]) {
        "ping" -> {
            val h = args["host"] as? String ?: ""
            if (!host.matches(h)) "Hôte invalide"
            else Sys.exec(listOf(if (h.contains(':')) "/system/bin/ping6" else "/system/bin/ping", "-c", "4", "-W", "2", h), 15)
        }
        "logcat" -> Sys.exec(listOf("logcat", "-d", "-v", "threadtime", "-t", "2000"), 15).ifBlank {
            "Journal vide : sans la permission READ_LOGS, Android ne montre que les messages de NiTroiD."
        }
        "dumpsys" -> {
            val svc = args["service"] as? String ?: ""
            if (!service.matches(svc)) "Service invalide" else Sys.exec(listOf("dumpsys") + svc.split(' '), 30)
        }
        else -> "Outil inconnu"
    }

    private fun allowed(path: String): Boolean {
        val canonical = try {
            File(path).canonicalPath
        } catch (_: Throwable) {
            return false
        }
        return canonical == "/proc" || canonical == "/sys" || canonical.startsWith("/proc/") || canonical.startsWith("/sys/") ||
            path.startsWith("/proc/") || path.startsWith("/sys/")
    }

    fun listDir(path: String): List<Map<String, Any>> {
        if (!allowed(path) || path.contains("..")) return emptyList()
        val files = File(path).listFiles() ?: return emptyList()
        return files.take(3000).map { f ->
            mapOf("name" to f.name, "dir" to f.isDirectory, "readable" to f.canRead())
        }
    }

    fun readFile(path: String): String? {
        if (!allowed(path) || path.contains("..")) return null
        return Sys.read(path, 128 * 1024) ?: "(lecture refusée par SELinux)"
    }
}
