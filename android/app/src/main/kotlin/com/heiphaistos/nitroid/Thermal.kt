package com.heiphaistos.nitroid

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager

/**
 * Températures détaillées : capteurs du HAL thermique (CPU, GPU, coque, port USB,
 * modem…) avec leurs seuils de bridage, lus dans `dumpsys thermalservice`
 * (permission DUMP, ou shell root/ADB), plus les zones /sys/class/thermal
 * que l'app ne peut pas lire seule mais que le shell peut lire.
 */
object Thermal {
    // android.os.Temperature.TYPE_*
    private val types = mapOf(
        0 to "CPU", 1 to "GPU", 2 to "Batterie", 3 to "Coque (peau)", 4 to "Port USB",
        5 to "Amplificateur radio", 6 to "Tension batterie (BCL)", 7 to "Courant batterie (BCL)",
        8 to "Niveau batterie (BCL)", 9 to "NPU (IA)", 10 to "TPU", 11 to "Écran", 12 to "Modem",
        13 to "SoC", 14 to "Wi-Fi", 15 to "Caméra", 16 to "Flash", 17 to "Haut-parleur",
        18 to "Ambiante", 19 to "Connecteur",
    )

    private val tempRe = Regex("""Temperature\{mValue=([-\d.]+|NaN), mType=(-?\d+), mName=([^,]+), mStatus=(\d+)""")
    private val thresholdRe = Regex("""TemperatureThreshold\{mType=(-?\d+), mName=([^,]+), mHotThrottlingThresholds=\[([^\]]*)]""")

    private fun hasDump(ctx: Context) = ctx.checkSelfPermission(Manifest.permission.DUMP) == PackageManager.PERMISSION_GRANTED

    /** Shell élevé déjà disponible, sans tenter de connexion lente. */
    private fun privReady() = Root.available() || Adb.connected()

    private fun dumpsys(ctx: Context): String? = when {
        hasDump(ctx) -> Sys.exec(listOf("dumpsys", "thermalservice"), 10).takeIf { it.contains("Temperature{") }
        privReady() -> Priv.run(ctx, "dumpsys thermalservice", 10).out.takeIf { it.contains("Temperature{") }
        else -> null
    }

    fun detail(ctx: Context): Map<String, Any?> {
        val text = dumpsys(ctx)
        val sensors = ArrayList<Map<String, Any?>>()
        if (text != null) {
            // Seuils « chaud » par capteur : index = niveau de bridage (3 = SEVERE).
            val thresholds = HashMap<String, List<Double?>>()
            thresholdRe.findAll(text).forEach { m ->
                thresholds[m.groupValues[2]] = m.groupValues[3].split(',').map { it.trim().toDoubleOrNull()?.takeIf { v -> !v.isNaN() } }
            }
            // Seule la section « HAL » reflète les capteurs ; les caches en double sont ignorés.
            val seen = HashSet<String>()
            val hal = text.substringAfter("Current temperatures from HAL:", text)
            tempRe.findAll(hal).forEach { m ->
                val name = m.groupValues[3].trim()
                val value = m.groupValues[1].toDoubleOrNull()?.takeIf { !it.isNaN() } ?: return@forEach
                if (!seen.add(name)) return@forEach
                val type = m.groupValues[2].toInt()
                val t = thresholds[name]
                sensors.add(
                    mapOf(
                        "name" to name,
                        "kind" to (types[type] ?: "Autre"),
                        "type" to type,
                        "temp" to value,
                        "status" to m.groupValues[4].toInt(),
                        "severe" to t?.getOrNull(3),
                        "critical" to t?.getOrNull(4),
                    ),
                )
            }
        }
        val zones = if (sensors.isEmpty() && privReady()) shellZones(ctx) else emptyList()
        val pm = ctx.getSystemService(PowerManager::class.java)
        val forecast = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pm.getThermalHeadroom(10).takeIf { !it.isNaN() }?.toDouble()
        } else null
        return mapOf(
            "source" to when {
                sensors.isNotEmpty() -> "hal"
                zones.isNotEmpty() -> "shell"
                else -> "none"
            },
            "sensors" to sensors,
            "zones" to zones,
            "dump" to hasDump(ctx),
            // Marge prévue dans 10 s : 1.0 = seuil de bridage sévère atteint.
            "headroom10s" to forecast,
        )
    }

    /** Zones /sys/class/thermal lues par le shell (root ou ADB) quand SELinux bloque l'app. */
    private fun shellZones(ctx: Context): List<Map<String, Any>> {
        val r = Priv.run(ctx, "for z in /sys/class/thermal/thermal_zone*; do echo \"\$(cat \$z/type 2>/dev/null)|\$(cat \$z/temp 2>/dev/null)\"; done", 10)
        if (!r.ok) return emptyList()
        return r.out.lineSequence().mapNotNull { line ->
            val name = line.substringBefore('|').trim()
            val raw = line.substringAfter('|').trim().toLongOrNull() ?: return@mapNotNull null
            if (name.isEmpty()) null else mapOf("name" to name, "temp" to raw)
        }.toList()
    }
}
