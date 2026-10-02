package com.heiphaistos.nitroid

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.Sensor
import android.hardware.SensorManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CameraMetadata
import android.hardware.display.DisplayManager
import android.media.MediaCodecList
import android.media.MediaDrm
import android.opengl.EGL14
import android.opengl.GLES20
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.os.SystemClock
import android.os.storage.StorageManager
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.Display
import java.io.File
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.roundToInt

object Info {
    fun category(ctx: Context, category: String): List<Map<String, Any>> = when (category) {
        "system" -> system(ctx)
        "cpu" -> cpu()
        "battery" -> battery(ctx)
        "memory" -> memory(ctx)
        "storage" -> storage(ctx)
        "display" -> display(ctx)
        "cameras" -> cameras(ctx)
        "network" -> NetInfo.sections(ctx)
        "features" -> features(ctx)
        "media" -> media()
        "props" -> props()
        else -> emptyList()
    }

    // ---------------------------------------------------------------- Système

    fun socName(): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val m = Build.SOC_MANUFACTURER
            val model = Build.SOC_MODEL
            if (model.isNotBlank() && model != Build.UNKNOWN) return "$m $model".trim()
        }
        val platform = Sys.prop("ro.board.platform")
        val hw = cpuInfoField("Hardware")
        return listOf(hw, platform).firstOrNull { !it.isNullOrBlank() }
    }

    private fun system(ctx: Context): List<Map<String, Any>> {
        val s = Sections()
        s.section("Appareil") {
            add("Fabricant", Build.MANUFACTURER)
            add("Marque", Build.BRAND)
            add("Modèle", Build.MODEL)
            safe("Nom de l’appareil") { Settings.Global.getString(ctx.contentResolver, Settings.Global.DEVICE_NAME) }
            add("Nom de code", Build.DEVICE)
            add("Produit", Build.PRODUCT)
            add("Carte mère", Build.BOARD)
            add("Matériel", Build.HARDWARE)
            add("SoC", socName())
            add("Premier niveau d’API", Sys.prop("ro.product.first_api_level").ifBlank { null })
        }
        s.section("Android") {
            add("Version", "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
            add("Correctif de sécurité", Build.VERSION.SECURITY_PATCH)
            add("Correctif fournisseur", Sys.prop("ro.vendor.build.security_patch"))
            add("Build", Build.DISPLAY)
            add("Incrémental", Build.VERSION.INCREMENTAL)
            add("Type / tags", "${Build.TYPE} / ${Build.TAGS}")
            add("Date de compilation", java.text.DateFormat.getDateTimeInstance().format(Build.TIME))
            add("Empreinte", Build.FINGERPRINT)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) add("Classe de performance média", Build.VERSION.MEDIA_PERFORMANCE_CLASS.takeIf { it > 0 })
            safe("Mise à jour système Google Play") {
                ctx.packageManager.getPackageInfo("com.google.android.modulemetadata", 0).versionName
            }
            add("Surcouche", listOf(
                "ro.build.version.oneui" to "One UI", "ro.miui.ui.version.name" to "MIUI/HyperOS",
                "ro.build.version.emui" to "EMUI", "ro.build.version.opporom" to "ColorOS",
                "ro.vivo.os.version" to "Funtouch/OriginOS", "ro.oxygen.version" to "OxygenOS", "ro.lineage.version" to "LineageOS",
            ).map { (key, label) -> label to Sys.prop(key) }.firstOrNull { it.second.isNotBlank() }?.let { "${it.first} ${it.second}" })
        }
        s.section("Noyau & démarrage") {
            add("Noyau", System.getProperty("os.version"))
            add("Détail du noyau", Sys.read("/proc/version"))
            add("Bootloader", Build.BOOTLOADER)
            safe("Firmware radio") { Build.getRadioVersion() }
            add("Démarrage vérifié", Sys.prop("ro.boot.verifiedbootstate").ifBlank { null })
            add("Bootloader verrouillé", when (Sys.prop("ro.boot.flash.locked")) { "1" -> "oui"; "0" -> "NON (déverrouillé)"; else -> null })
            add("État vbmeta", Sys.prop("ro.boot.vbmeta.device_state").ifBlank { null })
            add("Project Treble", Sys.prop("ro.treble.enabled").ifBlank { null })
            add("Partitions A/B", if (Sys.prop("ro.build.ab_update") == "true") "oui (slot ${Sys.prop("ro.boot.slot_suffix")})" else "non")
            add("Partitions dynamiques", Sys.prop("ro.boot.dynamic_partitions").ifBlank { null })
            add("SELinux", Security.selinux())
            add("Machine virtuelle", "${System.getProperty("java.vm.name")} ${System.getProperty("java.vm.version")}")
            add("Allumé depuis", Sys.duration(SystemClock.elapsedRealtime()))
        }
        s.section("Région") {
            add("Langue", Locale.getDefault().displayName)
            add("Fuseau horaire", TimeZone.getDefault().id)
            safe("Identifiant Android (SSAID)") { Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ANDROID_ID) }
        }
        return s.list
    }

    // --------------------------------------------------------------- Processeur

    private val armParts = mapOf(
        "0xd03" to "Cortex-A53", "0xd04" to "Cortex-A35", "0xd05" to "Cortex-A55", "0xd07" to "Cortex-A57",
        "0xd08" to "Cortex-A72", "0xd09" to "Cortex-A73", "0xd0a" to "Cortex-A75", "0xd0b" to "Cortex-A76",
        "0xd0d" to "Cortex-A77", "0xd41" to "Cortex-A78", "0xd44" to "Cortex-X1", "0xd46" to "Cortex-A510",
        "0xd47" to "Cortex-A710", "0xd48" to "Cortex-X2", "0xd4d" to "Cortex-A715", "0xd4e" to "Cortex-X3",
        "0xd80" to "Cortex-A520", "0xd81" to "Cortex-A720", "0xd82" to "Cortex-X4", "0xd85" to "Cortex-X925",
        "0xd87" to "Cortex-A725", "0x800" to "Kryo (Gold)", "0x801" to "Kryo (Silver)", "0x802" to "Kryo 385 Gold",
        "0x803" to "Kryo 385 Silver", "0x804" to "Kryo 485 Gold", "0x805" to "Kryo 485 Silver",
    )

    private fun cpuInfoField(name: String): String? =
        Sys.read("/proc/cpuinfo")?.lineSequence()?.firstOrNull { it.startsWith(name) }?.substringAfter(':')?.trim()

    fun coreCount(): Int {
        val present = Sys.read("/sys/devices/system/cpu/present", 64)
        val last = present?.substringAfterLast('-')?.trim()?.toIntOrNull()
        return if (last != null) last + 1 else Runtime.getRuntime().availableProcessors()
    }

    fun coreFreq(i: Int, kind: String): Long? = Sys.readLong("/sys/devices/system/cpu/cpu$i/cpufreq/$kind")

    private fun cpu(): List<Map<String, Any>> {
        val s = Sections()
        val cores = coreCount()
        val cpuinfo = Sys.read("/proc/cpuinfo") ?: ""
        val parts = cpuinfo.lineSequence().filter { it.startsWith("CPU part") }.map { it.substringAfter(':').trim() }.toList()
        s.section("Processeur") {
            add("SoC", socName())
            add("Cœurs", cores)
            add("Architecture", System.getProperty("os.arch"))
            add("ABI prises en charge", Build.SUPPORTED_ABIS.joinToString(", "))
            add("Plateforme", Sys.prop("ro.board.platform").ifBlank { null })
            add("Implémenteur", cpuInfoField("CPU implementer"))
            if (parts.isNotEmpty()) {
                add("Microarchitectures", parts.groupingBy { armParts[it] ?: it }.eachCount().entries.joinToString(" + ") { "${it.value}× ${it.key}" })
            }
        }
        val clusters = (0 until cores).groupBy { coreFreq(it, "cpuinfo_max_freq") ?: 0L }.toSortedMap()
        var n = 1
        for ((max, ids) in clusters) {
            val first = ids.first()
            s.section("Cluster ${n++} — cœurs ${ids.joinToString(",")}") {
                add("Cœur", parts.getOrNull(first)?.let { armParts[it] ?: it })
                add("Fréquence max", Sys.mhz(max))
                add("Fréquence min", Sys.mhz(coreFreq(first, "cpuinfo_min_freq")))
                add("Gouverneur", Sys.read("/sys/devices/system/cpu/cpu$first/cpufreq/scaling_governor", 64))
                add("Limite actuelle", Sys.mhz(coreFreq(first, "scaling_max_freq")))
                add("Paliers disponibles", Sys.read("/sys/devices/system/cpu/cpu$first/cpufreq/scaling_available_frequencies", 2048)
                    ?.split(Regex("\\s+"))?.size?.let { "$it fréquences" })
            }
        }
        s.section("Jeu d’instructions") {
            add("Extensions", cpuInfoField("Features") ?: cpuInfoField("flags"))
        }
        return s.list
    }

    // ------------------------------------------------------------------ Batterie

    private fun batteryIntent(ctx: Context): Intent? =
        ctx.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))

    /** Le courant est en µA selon la doc, mais certains constructeurs renvoient des mA. */
    fun currentMa(raw: Int): Double? {
        if (raw == Int.MIN_VALUE || raw == 0) return null
        return if (abs(raw) > 20000) raw / 1000.0 else raw.toDouble()
    }

    fun designCapacityMah(ctx: Context): Double? = try {
        val cls = Class.forName("com.android.internal.os.PowerProfile")
        val profile = cls.getConstructor(Context::class.java).newInstance(ctx)
        (cls.getMethod("getBatteryCapacity").invoke(profile) as Double).takeIf { it > 100 }
    } catch (_: Throwable) {
        null
    }

    private fun battery(ctx: Context): List<Map<String, Any>> {
        val s = Sections()
        val i = batteryIntent(ctx) ?: return s.list
        val bm = ctx.getSystemService(BatteryManager::class.java)
        val level = i.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100 / i.getIntExtra(BatteryManager.EXTRA_SCALE, 100).coerceAtLeast(1)
        val design = designCapacityMah(ctx)
        val chargeUah = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER) ?: Int.MIN_VALUE
        val chargeMah = if (chargeUah > 0) (if (chargeUah > 100000) chargeUah / 1000.0 else chargeUah.toDouble()) else null
        val estimatedFull = if (chargeMah != null && level in 10..100) chargeMah * 100 / level else null
        s.section("État") {
            add("Niveau", "$level %")
            add("Statut", when (i.getIntExtra(BatteryManager.EXTRA_STATUS, -1)) {
                BatteryManager.BATTERY_STATUS_CHARGING -> "En charge"
                BatteryManager.BATTERY_STATUS_DISCHARGING -> "Décharge"
                BatteryManager.BATTERY_STATUS_FULL -> "Pleine"
                BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "Branchée, pas en charge"
                else -> "Inconnu"
            })
            add("Alimentation", when (i.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)) {
                BatteryManager.BATTERY_PLUGGED_AC -> "Secteur"
                BatteryManager.BATTERY_PLUGGED_USB -> "USB"
                BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Sans fil"
                8 -> "Station d’accueil"
                else -> "Débranchée"
            })
            add("Santé", healthLabel(i.getIntExtra(BatteryManager.EXTRA_HEALTH, 0)))
            add("Technologie", i.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY))
            add("Température", "${i.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) / 10.0} °C")
            add("Tension", "${i.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0) / 1000.0} V")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                safe("Temps de charge restant") { bm?.computeChargeTimeRemaining()?.takeIf { it > 0 }?.let { Sys.duration(it) } }
            }
        }
        s.section("Capacité & usure") {
            add("Capacité d’origine", design?.let { "${it.roundToInt()} mAh" })
            add("Charge actuelle", chargeMah?.let { "${it.roundToInt()} mAh" })
            add("Capacité réelle estimée", estimatedFull?.let { "${it.roundToInt()} mAh" })
            if (design != null && estimatedFull != null) {
                add("Santé estimée", "${(estimatedFull / design * 100).roundToInt().coerceAtMost(100)} % (estimation, plus fiable vers 100 % de charge)")
            }
            val cycles = i.getIntExtra("android.os.extra.CYCLE_COUNT", -1)
            add("Cycles de charge", cycles.takeIf { it >= 0 } ?: Sys.readLong("/sys/class/power_supply/battery/cycle_count"))
            Sys.readLong("/sys/class/power_supply/battery/charge_full")?.let { add("charge_full (noyau)", "${it / 1000} mAh") }
            Sys.readLong("/sys/class/power_supply/battery/charge_full_design")?.let { add("charge_full_design (noyau)", "${it / 1000} mAh") }
        }
        s.section("Mesures instantanées") {
            bm?.let {
                add("Courant instantané", currentMa(it.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW))?.let { c -> "${c.roundToInt()} mA" })
                add("Courant moyen", currentMa(it.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_AVERAGE))?.let { c -> "${c.roundToInt()} mA" })
                val energy = it.getLongProperty(BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER)
                if (energy > 0 && energy != Long.MIN_VALUE) add("Énergie restante", "${energy / 1_000_000_000.0} Wh")
            }
        }
        return s.list
    }

    private fun healthLabel(h: Int) = when (h) {
        BatteryManager.BATTERY_HEALTH_GOOD -> "Bonne"
        BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Surchauffe"
        BatteryManager.BATTERY_HEALTH_DEAD -> "Morte"
        BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Surtension"
        BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Défaillance"
        BatteryManager.BATTERY_HEALTH_COLD -> "Trop froide"
        else -> "Inconnue"
    }

    // ------------------------------------------------------------------- Mémoire

    private fun meminfo(): Map<String, Long> = (Sys.read("/proc/meminfo") ?: "").lineSequence().mapNotNull { line ->
        val key = line.substringBefore(':').trim()
        val kb = line.substringAfter(':').trim().substringBefore(' ').toLongOrNull()
        if (key.isEmpty() || kb == null) null else key to kb * 1024
    }.toMap()

    private fun memory(ctx: Context): List<Map<String, Any>> {
        val s = Sections()
        val am = ctx.getSystemService(ActivityManager::class.java)
        val mi = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        s.section("Mémoire vive") {
            add("Totale", Sys.bytes(mi.totalMem))
            add("Disponible", Sys.bytes(mi.availMem))
            add("Utilisée", Sys.bytes(mi.totalMem - mi.availMem))
            add("Seuil de mémoire basse", Sys.bytes(mi.threshold))
            add("En manque de mémoire", mi.lowMemory)
            add("Appareil « faible RAM »", am.isLowRamDevice)
            add("Mémoire max par app", "${am.memoryClass} Mo (large : ${am.largeMemoryClass} Mo)")
        }
        val m = meminfo()
        s.section("Détail du noyau (/proc/meminfo)") {
            for (k in listOf("MemTotal", "MemFree", "MemAvailable", "Buffers", "Cached", "Active", "Inactive", "AnonPages", "Mapped", "Shmem", "Slab", "KernelStack", "PageTables", "VmallocUsed", "CmaTotal", "CmaFree")) {
                m[k]?.let { add(k, Sys.bytes(it)) }
            }
        }
        s.section("Swap / zRAM") {
            m["SwapTotal"]?.let { add("Swap total", Sys.bytes(it)) }
            m["SwapFree"]?.let { add("Swap libre", Sys.bytes(it)) }
            Sys.readLong("/sys/block/zram0/disksize")?.let { add("Taille zRAM", Sys.bytes(it)) }
            add("Algorithme zRAM", Sys.read("/sys/block/zram0/comp_algorithm", 256))
            add("Swappiness", Sys.read("/proc/sys/vm/swappiness", 16))
        }
        return s.list
    }

    // ------------------------------------------------------------------ Stockage

    private fun storage(ctx: Context): List<Map<String, Any>> {
        val s = Sections()
        val data = StatFs(Environment.getDataDirectory().path)
        s.section("Stockage interne") {
            add("Capacité", Sys.bytes(data.totalBytes))
            add("Libre", Sys.bytes(data.availableBytes))
            add("Utilisé", Sys.bytes(data.totalBytes - data.availableBytes))
            add("Type de puce", when {
                File("/sys/block/sda").exists() || Sys.prop("ro.boot.bootdevice").contains("ufs") -> "UFS"
                File("/sys/block/mmcblk0").exists() -> "eMMC"
                File("/sys/block/nvme0n1").exists() -> "NVMe"
                else -> null
            })
            add("Périphérique de démarrage", Sys.prop("ro.boot.bootdevice").ifBlank { null })
        }
        s.section("Chiffrement") {
            val dpm = ctx.getSystemService(DevicePolicyManager::class.java)
            add("État", when (dpm.storageEncryptionStatus) {
                DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_PER_USER -> "Actif (par fichier, FBE)"
                DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE -> "Actif"
                DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_DEFAULT_KEY -> "Actif (clé par défaut)"
                DevicePolicyManager.ENCRYPTION_STATUS_INACTIVE -> "INACTIF"
                DevicePolicyManager.ENCRYPTION_STATUS_UNSUPPORTED -> "Non pris en charge"
                else -> "Inconnu"
            })
            add("Type", Sys.prop("ro.crypto.type").ifBlank { null })
        }
        s.section("Systèmes de fichiers") {
            val mounts = Sys.read("/proc/self/mounts", 256 * 1024)?.lines() ?: emptyList()
            for (point in listOf("/", "/system", "/vendor", "/product", "/data", "/metadata", "/cache")) {
                mounts.firstOrNull { it.split(' ').getOrNull(1) == point }?.split(' ')?.let {
                    add(point, "${it.getOrNull(2)} (${if (it.getOrNull(3)?.startsWith("ro") == true) "lecture seule" else "lecture/écriture"})")
                }
            }
        }
        val sm = ctx.getSystemService(StorageManager::class.java)
        for (v in sm.storageVolumes) {
            s.section("Volume : ${v.getDescription(ctx)}") {
                add("Principal", v.isPrimary)
                add("Amovible", v.isRemovable)
                add("Émulé", v.isEmulated)
                add("État", v.state)
                add("UUID", v.uuid)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    v.directory?.let { dir ->
                        safe("Capacité") { Sys.bytes(StatFs(dir.path).totalBytes) }
                        safe("Libre") { Sys.bytes(StatFs(dir.path).availableBytes) }
                    }
                }
            }
        }
        return s.list
    }

    // --------------------------------------------------------------------- Écran

    private fun display(ctx: Context): List<Map<String, Any>> {
        val s = Sections()
        val dm = ctx.getSystemService(DisplayManager::class.java)
        for (d in dm.displays) {
            s.section(if (d.displayId == Display.DEFAULT_DISPLAY) "Écran principal" else "Écran ${d.displayId} — ${d.name}") {
                val metrics = DisplayMetrics()
                @Suppress("DEPRECATION")
                d.getRealMetrics(metrics)
                val mode = d.mode
                add("Nom", d.name)
                add("Résolution", "${mode.physicalWidth} × ${mode.physicalHeight} px")
                add("Densité", "${metrics.densityDpi} dpi (${densityBucket(metrics.densityDpi)})")
                add("Densité physique", "${metrics.xdpi.roundToInt()} × ${metrics.ydpi.roundToInt()} ppp")
                val inches = hypot(mode.physicalWidth / metrics.xdpi.toDouble(), mode.physicalHeight / metrics.ydpi.toDouble())
                add("Diagonale estimée", String.format(Locale.FRANCE, "%.2f\"", inches))
                add("Fréquence actuelle", "${d.refreshRate.roundToInt()} Hz")
                add("Modes", d.supportedModes.joinToString(", ") { "${it.physicalWidth}×${it.physicalHeight}@${it.refreshRate.roundToInt()}" })
                add("Gamut étendu", d.isWideColorGamut)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    d.hdrCapabilities?.let { hdr ->
                        val types = hdr.supportedHdrTypes.map {
                            when (it) {
                                Display.HdrCapabilities.HDR_TYPE_DOLBY_VISION -> "Dolby Vision"
                                Display.HdrCapabilities.HDR_TYPE_HDR10 -> "HDR10"
                                Display.HdrCapabilities.HDR_TYPE_HLG -> "HLG"
                                4 -> "HDR10+"
                                else -> "type $it"
                            }
                        }
                        add("HDR", if (types.isEmpty()) "non" else types.joinToString(", "))
                        if (hdr.desiredMaxLuminance > 0) add("Luminance max HDR", "${hdr.desiredMaxLuminance.roundToInt()} nits")
                    }
                }
                add("Rotation", "${d.rotation * 90}°")
            }
        }
        s.section("Réglages d’affichage") {
            safe("Luminosité") { "${Settings.System.getInt(ctx.contentResolver, Settings.System.SCREEN_BRIGHTNESS)}/255" }
            safe("Luminosité auto") { Settings.System.getInt(ctx.contentResolver, Settings.System.SCREEN_BRIGHTNESS_MODE) == 1 }
            safe("Mise en veille") { "${Settings.System.getInt(ctx.contentResolver, Settings.System.SCREEN_OFF_TIMEOUT) / 1000} s" }
            add("Échelle de police", ctx.resources.configuration.fontScale)
            add("Mode sombre", (ctx.resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) == android.content.res.Configuration.UI_MODE_NIGHT_YES)
        }
        return s.list
    }

    private fun densityBucket(dpi: Int) = when {
        dpi <= 120 -> "ldpi"
        dpi <= 160 -> "mdpi"
        dpi <= 240 -> "hdpi"
        dpi <= 320 -> "xhdpi"
        dpi <= 480 -> "xxhdpi"
        else -> "xxxhdpi"
    }

    // ------------------------------------------------------------------- Caméras

    private fun cameras(ctx: Context): List<Map<String, Any>> {
        val s = Sections()
        val cm = ctx.getSystemService(CameraManager::class.java)
        for (id in cm.cameraIdList) {
            val c = cm.getCameraCharacteristics(id)
            val facing = when (c.get(CameraCharacteristics.LENS_FACING)) {
                CameraMetadata.LENS_FACING_FRONT -> "avant"
                CameraMetadata.LENS_FACING_BACK -> "arrière"
                else -> "externe"
            }
            s.section("Caméra $id ($facing)") {
                c.get(CameraCharacteristics.SENSOR_INFO_PIXEL_ARRAY_SIZE)?.let {
                    add("Définition", String.format(Locale.FRANCE, "%.1f Mpx (%d × %d)", it.width * it.height / 1e6, it.width, it.height))
                }
                c.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)?.let {
                    add("Taille du capteur", String.format(Locale.FRANCE, "%.2f × %.2f mm", it.width, it.height))
                }
                c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)?.let { add("Focale(s)", it.joinToString(", ") { f -> "$f mm" }) }
                c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_APERTURES)?.let { add("Ouverture", it.joinToString(", ") { a -> "f/$a" }) }
                add("Flash", c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE))
                add("Stabilisation optique", c.get(CameraCharacteristics.LENS_INFO_AVAILABLE_OPTICAL_STABILIZATION)?.any { it == 1 })
                add("Zoom numérique max", c.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)?.let { "×$it" })
                add("Niveau matériel", when (c.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL)) {
                    CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY -> "LEGACY"
                    CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED -> "LIMITED"
                    CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_FULL -> "FULL"
                    CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_3 -> "LEVEL_3"
                    CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_EXTERNAL -> "EXTERNAL"
                    else -> null
                })
                val caps = c.get(CameraCharacteristics.REQUEST_AVAILABLE_CAPABILITIES)?.toList() ?: emptyList()
                add("Photo RAW", caps.contains(CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_RAW))
                add("Contrôle manuel", caps.contains(CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_MANUAL_SENSOR))
                add("Ralenti haute vitesse", caps.contains(CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_CONSTRAINED_HIGH_SPEED_VIDEO))
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && caps.contains(CameraMetadata.REQUEST_AVAILABLE_CAPABILITIES_LOGICAL_MULTI_CAMERA)) {
                    add("Caméra logique regroupant", c.physicalCameraIds.joinToString(", "))
                }
                c.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)?.maxOfOrNull { it.upper }?.let { add("Images/s max", it) }
                c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)?.getOutputSizes(ImageFormat.JPEG)?.maxByOrNull { it.width * it.height }?.let {
                    add("JPEG max", "${it.width} × ${it.height}")
                }
            }
        }
        return s.list
    }

    // ---------------------------------------------------- Fonctions matérielles

    private val featureNames = linkedMapOf(
        PackageManager.FEATURE_NFC to "NFC",
        PackageManager.FEATURE_NFC_HOST_CARD_EMULATION to "Paiement sans contact (HCE)",
        PackageManager.FEATURE_BLUETOOTH_LE to "Bluetooth Low Energy",
        "android.hardware.uwb" to "Ultra Wideband (UWB)",
        PackageManager.FEATURE_CONSUMER_IR to "Émetteur infrarouge",
        PackageManager.FEATURE_FINGERPRINT to "Lecteur d’empreintes",
        PackageManager.FEATURE_FACE to "Reconnaissance faciale",
        PackageManager.FEATURE_IRIS to "Lecteur d’iris",
        PackageManager.FEATURE_SENSOR_BAROMETER to "Baromètre",
        PackageManager.FEATURE_SENSOR_STEP_COUNTER to "Podomètre",
        PackageManager.FEATURE_SENSOR_HEART_RATE to "Cardiofréquencemètre",
        PackageManager.FEATURE_USB_HOST to "USB hôte (OTG)",
        PackageManager.FEATURE_WIFI_DIRECT to "Wi-Fi Direct",
        PackageManager.FEATURE_WIFI_AWARE to "Wi-Fi Aware",
        PackageManager.FEATURE_WIFI_RTT to "Wi-Fi RTT (localisation intérieure)",
        PackageManager.FEATURE_TELEPHONY to "Téléphonie",
        "android.hardware.telephony.euicc" to "eSIM",
        PackageManager.FEATURE_VR_MODE_HIGH_PERFORMANCE to "VR haute performance",
        PackageManager.FEATURE_STRONGBOX_KEYSTORE to "Puce de sécurité StrongBox",
        PackageManager.FEATURE_HARDWARE_KEYSTORE to "Keystore matériel",
        PackageManager.FEATURE_CAMERA_FLASH to "Flash",
        PackageManager.FEATURE_SECURE_LOCK_SCREEN to "Écran de verrouillage sécurisé",
        PackageManager.FEATURE_PICTURE_IN_PICTURE to "Image dans l’image",
        PackageManager.FEATURE_FREEFORM_WINDOW_MANAGEMENT to "Fenêtres libres",
    )

    private fun gpu(): Map<String, String> {
        val out = HashMap<String, String>()
        try {
            val dpy = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            val ver = IntArray(2)
            if (!EGL14.eglInitialize(dpy, ver, 0, ver, 1)) return out
            val attribs = intArrayOf(EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT, EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT, EGL14.EGL_NONE)
            val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
            val num = IntArray(1)
            EGL14.eglChooseConfig(dpy, attribs, 0, configs, 0, 1, num, 0)
            if (num[0] > 0) {
                val ctx = EGL14.eglCreateContext(dpy, configs[0], EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
                val surf = EGL14.eglCreatePbufferSurface(dpy, configs[0], intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0)
                if (EGL14.eglMakeCurrent(dpy, surf, surf, ctx)) {
                    out["GPU"] = GLES20.glGetString(GLES20.GL_RENDERER) ?: ""
                    out["Fabricant GPU"] = GLES20.glGetString(GLES20.GL_VENDOR) ?: ""
                    out["Pilote OpenGL ES"] = GLES20.glGetString(GLES20.GL_VERSION) ?: ""
                    out["Extensions GL"] = "${(GLES20.glGetString(GLES20.GL_EXTENSIONS) ?: "").split(' ').count { it.isNotBlank() }}"
                }
                EGL14.eglMakeCurrent(dpy, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                EGL14.eglDestroySurface(dpy, surf)
                EGL14.eglDestroyContext(dpy, ctx)
            }
            EGL14.eglTerminate(dpy)
        } catch (_: Throwable) {
        }
        return out
    }

    private fun features(ctx: Context): List<Map<String, Any>> {
        val s = Sections()
        val pm = ctx.packageManager
        val all = pm.systemAvailableFeatures
        s.section("Graphismes") {
            for ((k, v) in gpu()) add(k, v)
            val am = ctx.getSystemService(ActivityManager::class.java)
            add("OpenGL ES (déclaré)", am.deviceConfigurationInfo.glEsVersion)
            all.firstOrNull { it.name == PackageManager.FEATURE_VULKAN_HARDWARE_VERSION }?.let {
                add("Vulkan", "${it.version shr 22}.${(it.version shr 12) and 0x3ff}.${it.version and 0xfff}")
            }
            all.firstOrNull { it.name == PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL }?.let { add("Niveau Vulkan", it.version) }
        }
        s.section("Fonctions clés") {
            for ((feature, label) in featureNames) add(label, pm.hasSystemFeature(feature))
        }
        s.section("Toutes les fonctions déclarées (${all.size})") {
            all.mapNotNull { it.name }.sorted().forEach { add(it.removePrefix("android.hardware.").removePrefix("android.software."), "✓") }
        }
        return s.list
    }

    // ------------------------------------------------------------ Médias & DRM

    private val widevine = UUID(-0x121074568629b532L, -0x5c37d8232ae2de13L)
    private val clearKey = UUID(-0x1d8e62a7567a4c37L, 0x781AB030AF78D30EL)

    private fun media(): List<Map<String, Any>> {
        val s = Sections()
        s.section("Widevine (DRM Netflix, Disney+, Prime…)") {
            if (!MediaDrm.isCryptoSchemeSupported(widevine)) {
                add("Pris en charge", false)
            } else {
                val drm = MediaDrm(widevine)
                try {
                    add("Niveau de sécurité", drm.getPropertyString("securityLevel"))
                    safe("Version") { drm.getPropertyString(MediaDrm.PROPERTY_VERSION) }
                    safe("Fournisseur") { drm.getPropertyString(MediaDrm.PROPERTY_VENDOR) }
                    safe("System ID") { drm.getPropertyString("systemId") }
                    safe("HDCP") { drm.getPropertyString("hdcpLevel") }
                    safe("HDCP max") { drm.getPropertyString("maxHdcpLevel") }
                    safe("Sessions max") { drm.getPropertyString("maxNumberOfSessions") }
                } finally {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) drm.close() else @Suppress("DEPRECATION") drm.release()
                }
            }
            add("ClearKey", MediaDrm.isCryptoSchemeSupported(clearKey))
        }
        val codecs = MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos
        val formats = linkedMapOf(
            "video/avc" to "H.264 / AVC", "video/hevc" to "H.265 / HEVC", "video/x-vnd.on2.vp9" to "VP9",
            "video/av01" to "AV1", "video/dolby-vision" to "Dolby Vision", "video/x-vnd.on2.vp8" to "VP8",
            "audio/mp4a-latm" to "AAC", "audio/opus" to "Opus", "audio/flac" to "FLAC", "audio/ac3" to "Dolby Digital",
            "audio/eac3" to "Dolby Digital Plus", "audio/ac4" to "Dolby AC-4",
        )
        fun hw(info: android.media.MediaCodecInfo): Boolean =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) info.isHardwareAccelerated
            else !info.name.startsWith("OMX.google.") && !info.name.startsWith("c2.android.")
        s.section("Décodage") {
            for ((mime, label) in formats) {
                val dec = codecs.filter { !it.isEncoder && it.supportedTypes.any { t -> t.equals(mime, true) } }
                add(label, when {
                    dec.isEmpty() -> "non"
                    dec.any { hw(it) } -> "matériel"
                    else -> "logiciel"
                })
            }
        }
        s.section("Encodage") {
            for ((mime, label) in formats) {
                val enc = codecs.filter { it.isEncoder && it.supportedTypes.any { t -> t.equals(mime, true) } }
                if (enc.isNotEmpty()) add(label, if (enc.any { hw(it) }) "matériel" else "logiciel")
            }
        }
        s.section("Tous les codecs (${codecs.size})") {
            for (c in codecs) add(c.name, "${if (c.isEncoder) "enc" else "dec"} · ${c.supportedTypes.joinToString(", ")}")
        }
        return s.list
    }

    private fun props(): List<Map<String, Any>> {
        val s = Sections()
        val out = Sys.exec(listOf("getprop"))
        val re = Regex("^\\[(.+?)]: \\[(.*)]$")
        s.section("getprop") {
            out.lineSequence().mapNotNull { re.find(it.trim()) }.forEach { rows.add(listOf(it.groupValues[1], it.groupValues[2].ifEmpty { "(vide)" })) }
        }
        return s.list
    }

    // ------------------------------------------------- Tableau de bord & direct

    fun dashboard(ctx: Context): Map<String, Any?> {
        val am = ctx.getSystemService(ActivityManager::class.java)
        val mi = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        val st = StatFs(Environment.getDataDirectory().path)
        val bi = batteryIntent(ctx)
        val level = bi?.let { it.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100 / it.getIntExtra(BatteryManager.EXTRA_SCALE, 100).coerceAtLeast(1) }
        val health = bi?.getIntExtra(BatteryManager.EXTRA_HEALTH, 0)
        return mapOf(
            "manufacturer" to Build.MANUFACTURER.replaceFirstChar { it.uppercase() },
            "model" to Build.MODEL,
            "os" to "Android ${Build.VERSION.RELEASE} · API ${Build.VERSION.SDK_INT} · patch ${Build.VERSION.SECURITY_PATCH}",
            "soc" to socName(),
            "ramTotal" to mi.totalMem,
            "ramAvail" to mi.availMem,
            "storageTotal" to st.totalBytes,
            "storageFree" to st.availableBytes,
            "batteryLevel" to level,
            "charging" to (bi?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0 != 0),
            "batteryHealthOk" to (health == null || health == BatteryManager.BATTERY_HEALTH_GOOD || health == BatteryManager.BATTERY_HEALTH_UNKNOWN),
            "batteryTemp" to bi?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0)?.div(10.0),
            "uptimeMs" to SystemClock.elapsedRealtime(),
        )
    }

    private var zoneCache: List<Pair<String, String>>? = null

    private fun thermalZones(): List<Map<String, Any>> {
        val zones = zoneCache ?: run {
            val dir = File("/sys/class/thermal")
            val found = dir.listFiles { f -> f.name.startsWith("thermal_zone") }?.mapNotNull { z ->
                val type = Sys.read("${z.path}/type", 128) ?: return@mapNotNull null
                if (Sys.readLong("${z.path}/temp") == null) null else type to "${z.path}/temp"
            } ?: emptyList()
            found.also { zoneCache = it }
        }
        return zones.mapNotNull { (name, path) ->
            val t = Sys.readLong(path) ?: return@mapNotNull null
            mapOf("name" to name, "temp" to t)
        }
    }

    fun live(ctx: Context): Map<String, Any?> {
        val cores = coreCount()
        val bm = ctx.getSystemService(BatteryManager::class.java)
        val bi = batteryIntent(ctx)
        val am = ctx.getSystemService(ActivityManager::class.java)
        val mi = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        val pm = ctx.getSystemService(PowerManager::class.java)
        val status = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) when (pm.currentThermalStatus) {
            PowerManager.THERMAL_STATUS_NONE -> "Normal"
            PowerManager.THERMAL_STATUS_LIGHT -> "Chauffe légère"
            PowerManager.THERMAL_STATUS_MODERATE -> "Chauffe modérée"
            PowerManager.THERMAL_STATUS_SEVERE -> "Chauffe sévère (bridage)"
            PowerManager.THERMAL_STATUS_CRITICAL -> "Critique"
            PowerManager.THERMAL_STATUS_EMERGENCY -> "Urgence"
            PowerManager.THERMAL_STATUS_SHUTDOWN -> "Arrêt imminent"
            else -> null
        } else null
        val headroom = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            pm.getThermalHeadroom(0).takeIf { !it.isNaN() }?.let { String.format(Locale.FRANCE, "%.0f %%", (1 - it).coerceIn(0f, 1f) * 100) }
        } else null
        val level = bi?.let { it.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100 / it.getIntExtra(BatteryManager.EXTRA_SCALE, 100).coerceAtLeast(1) }
        return mapOf(
            "cpuFreqs" to (0 until cores).map { coreFreq(it, "scaling_cur_freq") ?: 0L },
            "cpuMaxFreqs" to (0 until cores).map { coreFreq(it, "cpuinfo_max_freq") ?: 0L },
            "batteryTemp" to bi?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0)?.div(10.0),
            "batteryVoltageMv" to bi?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0),
            "batteryCurrentMa" to bm?.let { currentMa(it.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)) },
            "batteryLevel" to level,
            "charging" to (bi?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0 != 0),
            "ramTotal" to mi.totalMem,
            "ramAvail" to mi.availMem,
            "thermalZones" to thermalZones(),
            "thermalStatus" to status,
            "thermalHeadroom" to headroom,
        )
    }

    // ------------------------------------------------------------------ Capteurs

    private val sensorNames = mapOf(
        Sensor.TYPE_ACCELEROMETER to ("Accéléromètre" to "m/s²"),
        Sensor.TYPE_GYROSCOPE to ("Gyroscope" to "rad/s"),
        Sensor.TYPE_MAGNETIC_FIELD to ("Magnétomètre" to "µT"),
        Sensor.TYPE_LIGHT to ("Luminosité ambiante" to "lx"),
        Sensor.TYPE_PROXIMITY to ("Proximité" to "cm"),
        Sensor.TYPE_PRESSURE to ("Baromètre" to "hPa"),
        Sensor.TYPE_GRAVITY to ("Gravité" to "m/s²"),
        Sensor.TYPE_LINEAR_ACCELERATION to ("Accélération linéaire" to "m/s²"),
        Sensor.TYPE_ROTATION_VECTOR to ("Vecteur de rotation" to ""),
        Sensor.TYPE_GAME_ROTATION_VECTOR to ("Rotation (jeu)" to ""),
        Sensor.TYPE_AMBIENT_TEMPERATURE to ("Température ambiante" to "°C"),
        Sensor.TYPE_RELATIVE_HUMIDITY to ("Humidité" to "%"),
        Sensor.TYPE_STEP_COUNTER to ("Podomètre" to "pas"),
        Sensor.TYPE_HEART_RATE to ("Fréquence cardiaque" to "bpm"),
        Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR to ("Rotation géomagnétique" to ""),
    )

    fun sensors(ctx: Context): List<Map<String, Any?>> {
        val sm = ctx.getSystemService(SensorManager::class.java) ?: return emptyList()
        val defaults = sensorNames.keys.mapNotNull { sm.getDefaultSensor(it) }.toSet()
        return sm.getSensorList(Sensor.TYPE_ALL).map { s ->
            val known = sensorNames[s.type]
            mapOf(
                "name" to s.name,
                "vendor" to s.vendor,
                "type" to s.type,
                "kind" to (known?.first ?: s.stringType.substringAfterLast('.')),
                "unit" to known?.second,
                "power" to s.power,
                "range" to s.maximumRange,
                "resolution" to s.resolution,
                "live" to (s in defaults && s.reportingMode != Sensor.REPORTING_MODE_ONE_SHOT),
            )
        }.sortedBy { if (it["live"] == true) 0 else 1 }
    }
}
