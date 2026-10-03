package com.heiphaistos.nitroid

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())
    private val keys = KeyEventStream()

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
                "playTone" -> result.success(Audio.playTone(
                    (call.argument<Double>("freq")) ?: 1000.0,
                    call.argument("ms") ?: 1000,
                    call.argument("channel") ?: "both",
                    call.argument("sweep") ?: false,
                ))
                "stopTone" -> {
                    Audio.stop()
                    result.success(true)
                }
                "appInfo" -> result.success(Actions.appInfo(this))
                "installApk" -> result.success(Actions.installApk(this, call.argument("path") ?: ""))
                "openUrl" -> result.success(Actions.openUrl(this, call.argument("url") ?: ""))
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
        EventChannel(messenger, "nitroid/logcat").setStreamHandler(LogcatStream())
        EventChannel(messenger, "nitroid/mic").setStreamHandler(MicStream())
        EventChannel(messenger, "nitroid/keys").setStreamHandler(keys)
    }

    // Boutons physiques (volume, caméra…) : transmis à Dart pour le test des boutons.
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keys.emit(keyCode, true)) return true
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (keys.emit(keyCode, false)) return true
        return super.onKeyUp(keyCode, event)
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
            "rootAvailable" -> Root.available(args["force"] as? Boolean ?: false)
            "grantSelf" -> Dev.grantSelf(ctx)
            "getSettings" -> Dev.getSettings(ctx, (args["keys"] as? List<*>)?.map { it.toString() } ?: emptyList())
            "putSetting" -> Dev.putSetting(ctx, args["ns"] as? String ?: "secure", args["key"] as? String ?: "", args["value"] as? String ?: "")
            "appAction" -> Dev.appAction(ctx, args["action"] as? String ?: "", args["pkg"] as? String ?: "")
            "thermalDetail" -> Thermal.detail(ctx)
            "adbStatus" -> Adb.status(ctx) + mapOf("mode" to Priv.mode(ctx))
            "adbSearch" -> Adb.startSearch(ctx)
            "adbStopSearch" -> Adb.stopSearch(ctx)
            "adbPair" -> Adb.pair(ctx, (args["port"] as? Number)?.toInt() ?: -1, args["code"] as? String ?: "")
            "adbConnect" -> Adb.connect(ctx)
            "adbDisconnect" -> Adb.disconnect()
            "privShell" -> Priv.run(ctx, args["command"] as? String ?: "", 60).let {
                mapOf("ok" to it.ok, "out" to it.out, "mode" to Priv.mode(ctx))
            }
            else -> throw NotImplementedError(method)
        }
    }

    private fun requestRuntimePermission(name: String): Boolean {
        val perms = when (name) {
            "location" -> arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
            "notifications" -> if (android.os.Build.VERSION.SDK_INT >= 33) arrayOf(Manifest.permission.POST_NOTIFICATIONS) else return true
            "mic" -> arrayOf(Manifest.permission.RECORD_AUDIO)
            "camera" -> arrayOf(Manifest.permission.CAMERA)
            else -> return false
        }
        if (perms.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) return true
        requestPermissions(perms, 4242)
        return false
    }

    override fun onDestroy() {
        Audio.stop()
        worker.shutdown()
        super.onDestroy()
    }
}

/** Transmet à Dart les appuis sur les boutons physiques (test des boutons). */
class KeyEventStream : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    private val names = mapOf(
        KeyEvent.KEYCODE_VOLUME_UP to "volume_up",
        KeyEvent.KEYCODE_VOLUME_DOWN to "volume_down",
        KeyEvent.KEYCODE_CAMERA to "camera",
        KeyEvent.KEYCODE_HEADSETHOOK to "headset",
        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE to "media",
    )

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /** Renvoie true si le bouton est capté (et donc consommé pendant le test). */
    fun emit(keyCode: Int, down: Boolean): Boolean {
        val name = names[keyCode] ?: return false
        val s = sink ?: return false
        main.post { s.success(mapOf("key" to name, "down" to down)) }
        return true
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

/** Diffuse le journal systeme en direct (logcat). Complet avec la permission READ_LOGS. */
class LogcatStream : EventChannel.StreamHandler {
    private var process: Process? = null
    private var thread: Thread? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val filter = (arguments as? Map<*, *>)?.get("filter") as? String
        val main = Handler(Looper.getMainLooper())
        thread = Thread {
            try {
                val cmd = arrayListOf("logcat", "-v", "threadtime")
                if (!filter.isNullOrBlank() && filter.matches(Regex("^[A-Za-z0-9_*:. -]{1,64}$"))) {
                    cmd.add(filter)
                }
                val proc = ProcessBuilder(cmd).redirectErrorStream(true).start().also { process = it }
                proc.inputStream.bufferedReader().use { r ->
                    while (!Thread.currentThread().isInterrupted) {
                        val line = r.readLine() ?: break
                        main.post { events.success(line) }
                    }
                }
            } catch (e: Throwable) {
                main.post { events.error("logcat", e.message, null) }
            }
        }.also { it.start() }
    }

    override fun onCancel(arguments: Any?) {
        thread?.interrupt()
        process?.destroy()
        process = null
    }
}
