package com.heiphaistos.nitroid

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "nitroid/native").setMethodCallHandler { call, result ->
            // Les opérations UI (Intents, torche, vibreur) restent sur le thread principal,
            // les lectures système (fichiers /proc, PackageManager…) partent en arrière-plan.
            when (call.method) {
                "openSettings" -> result.success(Actions.openSettings(this, call.argument("action") ?: "", call.argument("pkg")))
                "openComponent" -> result.success(Actions.openComponent(this, call.argument("pkg") ?: "", call.argument("cls") ?: ""))
                "uninstall" -> result.success(Actions.uninstall(this, call.argument("pkg") ?: ""))
                "launchApp" -> result.success(Actions.launchApp(this, call.argument("pkg") ?: ""))
                "torch" -> result.success(Actions.torch(this, call.argument("on") ?: false))
                "vibrate" -> result.success(Actions.vibrate(this, (call.argument<Int>("ms") ?: 200).toLong(), call.argument("amplitude") ?: 255))
                "tone" -> result.success(Actions.tone(call.argument("ms") ?: 500))
                "requestPermission" -> result.success(requestRuntimePermission(call.argument("name") ?: ""))
                else -> worker.execute {
                    val value = try {
                        handleBackground(call.method, call.arguments as? Map<*, *> ?: emptyMap<String, Any>())
                    } catch (e: NotImplementedError) {
                        main.post { result.notImplemented() }
                        return@execute
                    } catch (e: Throwable) {
                        main.post { result.error("native_error", e.message ?: e.javaClass.simpleName, null) }
                        return@execute
                    }
                    main.post { result.success(value) }
                }
            }
        }

        EventChannel(messenger, "nitroid/sensors").setStreamHandler(SensorStream(this))
    }

    private fun handleBackground(method: String, args: Map<*, *>): Any? {
        val ctx = applicationContext
        return when (method) {
            "getInfo" -> Info.category(ctx, args["category"] as? String ?: "system")
            "getDashboard" -> Info.dashboard(ctx)
            "getLive" -> Info.live(ctx)
            "listSensors" -> Info.sensors(ctx)
            "securityChecks" -> Security.checks(ctx)
            "listApps" -> Apps.list(ctx, args["system"] as? Boolean ?: false)
            "appIcon" -> Apps.icon(ctx, args["pkg"] as? String ?: "")
            "launchers" -> Apps.launchers(ctx)
            "usageStats" -> Apps.usage(ctx, (args["days"] as? Number)?.toInt() ?: 1)
            "permissions" -> Tweaks.permissions(ctx)
            "getTweaks" -> Tweaks.read(ctx)
            "setTweak" -> Tweaks.write(ctx, args["key"] as? String ?: "", args["value"] as? String ?: "")
            "wifiScan" -> NetInfo.wifiScan(ctx)
            "exec" -> Shell.tool(args)
            "listDir" -> Shell.listDir(args["path"] as? String ?: "/proc")
            "readFile" -> Shell.readFile(args["path"] as? String ?: "")
            else -> throw NotImplementedError(method)
        }
    }

    private fun requestRuntimePermission(name: String): Boolean {
        val perms = when (name) {
            "location" -> arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
            else -> return false
        }
        if (perms.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) return true
        requestPermissions(perms, 4242)
        return false
    }

    override fun onDestroy() {
        worker.shutdown()
        super.onDestroy()
    }
}

/** Diffuse les mesures d'un capteur (type Android) vers Dart, ~15 Hz. */
class SensorStream(private val activity: MainActivity) : EventChannel.StreamHandler, SensorEventListener {
    private val manager = activity.getSystemService(SensorManager::class.java)
    private var sink: EventChannel.EventSink? = null
    private var lastEmit = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val type = ((arguments as? Map<*, *>)?.get("type") as? Number)?.toInt() ?: Sensor.TYPE_ACCELEROMETER
        val sm = manager
        val sensor = sm?.getDefaultSensor(type)
        if (sm == null || sensor == null) {
            events.error("no_sensor", "Capteur indisponible", null)
            return
        }
        sink = events
        sm.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        manager?.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val now = System.currentTimeMillis()
        if (now - lastEmit < 66) return
        lastEmit = now
        sink?.success(event.values.map { it.toDouble() })
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
