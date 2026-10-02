package com.heiphaistos.nitroid

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.Settings

/**
 * Réglages système modifiables : WRITE_SETTINGS (accordable par l'utilisateur)
 * pour l'écran, WRITE_SECURE_SETTINGS (accordable via ADB) pour le reste.
 */
object Tweaks {
    private fun has(ctx: Context, perm: String) = ctx.checkSelfPermission(perm) == PackageManager.PERMISSION_GRANTED

    fun permissions(ctx: Context): Map<String, Boolean> = mapOf(
        "usageAccess" to Apps.usageGranted(ctx),
        "writeSettings" to Settings.System.canWrite(ctx),
        "writeSecure" to has(ctx, Manifest.permission.WRITE_SECURE_SETTINGS),
        "readLogs" to has(ctx, Manifest.permission.READ_LOGS),
        "dump" to has(ctx, Manifest.permission.DUMP),
        "location" to has(ctx, Manifest.permission.ACCESS_FINE_LOCATION),
    )

    private fun global(ctx: Context, key: String): String? = try {
        Settings.Global.getString(ctx.contentResolver, key)
    } catch (_: Throwable) {
        null
    }

    private fun system(ctx: Context, key: String): String? = try {
        Settings.System.getString(ctx.contentResolver, key)
    } catch (_: Throwable) {
        null
    }

    fun read(ctx: Context): Map<String, Any?> {
        val p = permissions(ctx)
        return mapOf(
            "writeSettings" to p["writeSettings"],
            "writeSecure" to p["writeSecure"],
            "screen_off_timeout" to system(ctx, Settings.System.SCREEN_OFF_TIMEOUT),
            "screen_brightness" to system(ctx, Settings.System.SCREEN_BRIGHTNESS),
            "screen_brightness_mode" to system(ctx, Settings.System.SCREEN_BRIGHTNESS_MODE),
            "window_animation_scale" to global(ctx, Settings.Global.WINDOW_ANIMATION_SCALE),
            "transition_animation_scale" to global(ctx, Settings.Global.TRANSITION_ANIMATION_SCALE),
            "animator_duration_scale" to global(ctx, Settings.Global.ANIMATOR_DURATION_SCALE),
            "stay_on_while_plugged_in" to global(ctx, Settings.Global.STAY_ON_WHILE_PLUGGED_IN),
            "private_dns_mode" to global(ctx, "private_dns_mode"),
            "private_dns_specifier" to global(ctx, "private_dns_specifier"),
        )
    }

    private val systemKeys = setOf(Settings.System.SCREEN_OFF_TIMEOUT, Settings.System.SCREEN_BRIGHTNESS, Settings.System.SCREEN_BRIGHTNESS_MODE)
    private val globalKeys = setOf(
        Settings.Global.WINDOW_ANIMATION_SCALE, Settings.Global.TRANSITION_ANIMATION_SCALE,
        Settings.Global.ANIMATOR_DURATION_SCALE, Settings.Global.STAY_ON_WHILE_PLUGGED_IN,
    )
    private val hostname = Regex("^[A-Za-z0-9.-]{1,253}$")

    /** Renvoie null en cas de succès, sinon un message d'erreur lisible. */
    fun write(ctx: Context, key: String, value: String): String? {
        val cr = ctx.contentResolver
        return try {
            when {
                key in systemKeys -> {
                    if (!Settings.System.canWrite(ctx)) return "Autorisez d’abord « Modifier les paramètres système »."
                    val n = value.toIntOrNull() ?: return "Valeur invalide"
                    Settings.System.putInt(cr, key, n)
                    null
                }
                key in globalKeys -> {
                    if (!has(ctx, Manifest.permission.WRITE_SECURE_SETTINGS)) return "Permission WRITE_SECURE_SETTINGS manquante (voir ADB)."
                    if (key == Settings.Global.STAY_ON_WHILE_PLUGGED_IN) Settings.Global.putInt(cr, key, value.toIntOrNull() ?: 0)
                    else Settings.Global.putFloat(cr, key, value.toFloatOrNull() ?: 1f)
                    null
                }
                key == "private_dns" -> {
                    if (!has(ctx, Manifest.permission.WRITE_SECURE_SETTINGS)) return "Permission WRITE_SECURE_SETTINGS manquante (voir ADB)."
                    when (value) {
                        "off", "opportunistic" -> Settings.Global.putString(cr, "private_dns_mode", value)
                        else -> {
                            if (!hostname.matches(value)) return "Nom d’hôte invalide"
                            Settings.Global.putString(cr, "private_dns_specifier", value)
                            Settings.Global.putString(cr, "private_dns_mode", "hostname")
                        }
                    }
                    null
                }
                else -> "Réglage inconnu : $key"
            }
        } catch (e: Throwable) {
            "Refusé par le système : ${e.message}"
        }
    }
}
