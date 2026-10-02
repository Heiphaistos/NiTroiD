package com.heiphaistos.nitroid

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings

/** Actions qui touchent l'interface ou le matériel : thread principal. */
object Actions {
    private fun start(activity: Activity, intent: Intent): Boolean = try {
        activity.startActivity(intent)
        true
    } catch (_: Throwable) {
        false
    }

    fun openSettings(activity: Activity, action: String, pkg: String?): Boolean {
        if (action.isBlank()) return false
        val intent = Intent(action)
        if (pkg != null) {
            when (action) {
                Settings.ACTION_APP_NOTIFICATION_SETTINGS -> intent.putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
                else -> intent.data = Uri.fromParts("package", pkg, null)
            }
        }
        if (start(activity, intent)) return true
        // Certains écrans n'existent pas partout : repli sur un écran plus général.
        val fallback = when (action) {
            "android.settings.ALL_APPS_NOTIFICATION_SETTINGS" -> Settings.ACTION_APPLICATION_SETTINGS
            "android.settings.MANAGE_ALL_FILES_ACCESS_PERMISSION" -> Settings.ACTION_APPLICATION_SETTINGS
            Settings.ACTION_HOME_SETTINGS -> Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS
            "android.settings.BIOMETRIC_ENROLL" -> Settings.ACTION_SECURITY_SETTINGS
            "android.app.action.SET_NEW_PASSWORD" -> Settings.ACTION_SECURITY_SETTINGS
            else -> null
        }
        return fallback != null && start(activity, Intent(fallback))
    }

    fun openComponent(activity: Activity, pkg: String, cls: String): Boolean =
        pkg.isNotBlank() && cls.isNotBlank() && start(activity, Intent().setClassName(pkg, cls).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))

    fun uninstall(activity: Activity, pkg: String): Boolean =
        pkg.isNotBlank() && start(activity, Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")))

    fun launchApp(activity: Activity, pkg: String): Boolean {
        val intent = activity.packageManager.getLaunchIntentForPackage(pkg) ?: return false
        return start(activity, intent)
    }

    fun torch(ctx: Context, on: Boolean): Boolean = try {
        val cm = ctx.getSystemService(CameraManager::class.java)
        val id = cm.cameraIdList.firstOrNull { cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true }
        if (id == null) false else {
            cm.setTorchMode(id, on)
            true
        }
    } catch (_: Throwable) {
        false
    }

    fun vibrate(ctx: Context, ms: Long, amplitude: Int): Boolean = try {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ctx.getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            ctx.getSystemService(Vibrator::class.java)
        }
        if (!vibrator.hasVibrator()) false else {
            val amp = if (vibrator.hasAmplitudeControl()) amplitude.coerceIn(1, 255) else VibrationEffect.DEFAULT_AMPLITUDE
            vibrator.vibrate(VibrationEffect.createOneShot(ms, amp))
            true
        }
    } catch (_: Throwable) {
        false
    }

    fun tone(ms: Int): Boolean = try {
        val gen = ToneGenerator(AudioManager.STREAM_MUSIC, 90)
        gen.startTone(ToneGenerator.TONE_DTMF_1, ms)
        Handler(Looper.getMainLooper()).postDelayed({ gen.release() }, ms + 200L)
        true
    } catch (_: Throwable) {
        false
    }
}
