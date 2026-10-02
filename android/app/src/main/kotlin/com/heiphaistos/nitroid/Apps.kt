package com.heiphaistos.nitroid

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.pm.PermissionInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.provider.Telephony
import android.view.accessibility.AccessibilityManager
import java.io.ByteArrayOutputStream
import java.security.MessageDigest

object Apps {
    fun label(pm: PackageManager, pkg: String): String = try {
        pm.getApplicationInfo(pkg, 0).loadLabel(pm).toString()
    } catch (_: Throwable) {
        pkg
    }

    fun isSystem(pm: PackageManager, pkg: String): Boolean = try {
        (pm.getApplicationInfo(pkg, 0).flags and ApplicationInfo.FLAG_SYSTEM) != 0
    } catch (_: Throwable) {
        false
    }

    fun notificationListeners(ctx: Context): Set<String> = try {
        val flat = Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners") ?: ""
        flat.split(':').mapNotNull { ComponentName.unflattenFromString(it)?.packageName }.toSet()
    } catch (_: Throwable) {
        emptySet()
    }

    private fun opAllowed(ctx: Context, op: String, uid: Int, pkg: String): Boolean = try {
        val ops = ctx.getSystemService(AppOpsManager::class.java)
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ops.unsafeCheckOpNoThrow(op, uid, pkg)
        else @Suppress("DEPRECATION") ops.checkOpNoThrow(op, uid, pkg)
        mode == AppOpsManager.MODE_ALLOWED
    } catch (_: Throwable) {
        false
    }

    /** Applications autorisées à installer des APK (« sources inconnues »). */
    fun installCapable(ctx: Context): List<String> {
        val pm = ctx.packageManager
        return pm.getInstalledPackages(PackageManager.GET_PERMISSIONS).filter { p ->
            p.requestedPermissions?.contains(Manifest.permission.REQUEST_INSTALL_PACKAGES) == true &&
                p.applicationInfo?.let { opAllowed(ctx, "android:request_install_packages", it.uid, p.packageName) } == true
        }.map { it.packageName }
    }

    private val dangerousCache = HashMap<String, Boolean>()

    private fun isDangerous(pm: PackageManager, perm: String): Boolean = dangerousCache.getOrPut(perm) {
        try {
            val info = pm.getPermissionInfo(perm, 0)
            val base = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.protection
            else @Suppress("DEPRECATION") (info.protectionLevel and PermissionInfo.PROTECTION_MASK_BASE)
            base == PermissionInfo.PROTECTION_DANGEROUS
        } catch (_: Throwable) {
            false
        }
    }

    private fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02X".format(it) }

    @Suppress("DEPRECATION")
    private fun certificates(p: PackageInfo): List<ByteArray> {
        val sigs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = p.signingInfo ?: return emptyList()
            if (info.hasMultipleSigners()) info.apkContentsSigners else info.signingCertificateHistory
        } else p.signatures
        return sigs?.map { it.toByteArray() } ?: emptyList()
    }

    @Suppress("DEPRECATION")
    private fun installer(pm: PackageManager, pkg: String): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) pm.getInstallSourceInfo(pkg).installingPackageName
        else pm.getInstallerPackageName(pkg)
    } catch (_: Throwable) {
        null
    }

    fun list(ctx: Context, includeSystem: Boolean): List<Map<String, Any?>> {
        val pm = ctx.packageManager
        val launchable = pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
            .map { it.activityInfo.packageName }.toSet()
        val a11y = ctx.getSystemService(AccessibilityManager::class.java)
            .getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .map { it.resolveInfo.serviceInfo.packageName }.toSet()
        val admins = ctx.getSystemService(DevicePolicyManager::class.java).activeAdmins.orEmpty().map { it.packageName }.toSet()
        val listeners = notificationListeners(ctx)
        val vpns = pm.queryIntentServices(Intent("android.net.VpnService"), 0).map { it.serviceInfo.packageName }.toSet()
        val sms = try { Telephony.Sms.getDefaultSmsPackage(ctx) } catch (_: Throwable) { null }
        val home = pm.resolveActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName

        val flags = PackageManager.GET_PERMISSIONS or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) PackageManager.GET_SIGNING_CERTIFICATES else @Suppress("DEPRECATION") PackageManager.GET_SIGNATURES
        val sha1 = MessageDigest.getInstance("SHA-1")
        val sha256 = MessageDigest.getInstance("SHA-256")

        return pm.getInstalledPackages(0).mapNotNull { basic ->
            val pkg = basic.packageName
            val p = try { pm.getPackageInfo(pkg, flags) } catch (_: Throwable) { return@mapNotNull null }
            val ai = p.applicationInfo ?: return@mapNotNull null
            val system = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (system && !includeSystem) return@mapNotNull null

            val requested = p.requestedPermissions?.toList() ?: emptyList()
            val reqFlags = p.requestedPermissionsFlags
            val granted = requested.filterIndexed { i, perm ->
                reqFlags != null && (reqFlags[i] and PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0 && isDangerous(pm, perm)
            }
            val special = ArrayList<String>()
            if (pkg in a11y) special += "accessibility"
            if (pkg in admins) special += "deviceAdmin"
            if (pkg in listeners) special += "notificationListener"
            if (pkg in vpns) special += "vpn"
            if (pkg == sms) special += "defaultSms"
            if (pkg == home) special += "defaultLauncher"
            if (Manifest.permission.SYSTEM_ALERT_WINDOW in requested && opAllowed(ctx, "android:system_alert_window", ai.uid, pkg)) special += "overlay"
            if (Manifest.permission.REQUEST_INSTALL_PACKAGES in requested && opAllowed(ctx, "android:request_install_packages", ai.uid, pkg)) special += "installPackages"
            if ("android.permission.PACKAGE_USAGE_STATS" in requested && opAllowed(ctx, "android:get_usage_stats", ai.uid, pkg)) special += "usageAccess"

            val certs = certificates(p)
            mapOf(
                "pkg" to pkg,
                "label" to ai.loadLabel(pm).toString(),
                "version" to (p.versionName ?: ""),
                "system" to system,
                "enabled" to ai.enabled,
                "launcher" to (pkg in launchable),
                "debuggable" to ((ai.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0),
                "installer" to installer(pm, pkg),
                "targetSdk" to ai.targetSdkVersion,
                "firstInstall" to p.firstInstallTime,
                "lastUpdate" to p.lastUpdateTime,
                "granted" to granted,
                "special" to special,
                "certSha1" to certs.map { hex(sha1.digest(it)) },
                "certSha256" to certs.firstOrNull()?.let { hex(sha256.digest(it)).chunked(2).joinToString(":") },
            )
        }
    }

    fun icon(ctx: Context, pkg: String): ByteArray? = try {
        val d = ctx.packageManager.getApplicationIcon(pkg)
        val size = 96
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        d.setBounds(0, 0, size, size)
        d.draw(Canvas(bmp))
        ByteArrayOutputStream().use { out ->
            bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    } catch (_: Throwable) {
        null
    }

    fun launchers(ctx: Context): Map<String, Any?> {
        val pm = ctx.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val current = pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
        val list = pm.queryIntentActivities(intent, 0)
            .filter { it.activityInfo.packageName != "com.android.settings" }
            .map {
                mapOf(
                    "pkg" to it.activityInfo.packageName,
                    "cls" to it.activityInfo.name,
                    "label" to it.loadLabel(pm).toString(),
                )
            }
        // « android » = le système demande à chaque fois (aucun lanceur par défaut).
        return mapOf("default" to current?.takeIf { it != "android" }, "list" to list)
    }

    fun usage(ctx: Context, days: Int): List<Map<String, Any?>> {
        val usm = ctx.getSystemService(UsageStatsManager::class.java)
        val end = System.currentTimeMillis()
        val start = end - days * 24L * 3600 * 1000
        val pm = ctx.packageManager
        return usm.queryAndAggregateUsageStats(start, end).values
            .filter { it.totalTimeInForeground > 60_000 }
            .sortedByDescending { it.totalTimeInForeground }
            .take(60)
            .map { mapOf("pkg" to it.packageName, "label" to label(pm, it.packageName), "foregroundMs" to it.totalTimeInForeground) }
    }

    fun usageGranted(ctx: Context): Boolean = opAllowed(ctx, "android:get_usage_stats", Process.myUid(), ctx.packageName)
}
