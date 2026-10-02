package com.heiphaistos.nitroid

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import io.github.muntashirakon.adb.AbsAdbConnectionManager
import io.github.muntashirakon.adb.AdbPairingRequiredException
import io.github.muntashirakon.adb.android.AdbMdns
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import org.lsposed.hiddenapibypass.HiddenApiBypass
import java.io.File
import java.math.BigInteger
import java.net.InetAddress
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.cert.Certificate
import java.security.cert.CertificateFactory
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Date
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/**
 * ADB sans PC : NiTroiD s'appaire au « Débogage sans fil » du téléphone (Android 11+),
 * puis ouvre un shell ADB local (utilisateur `shell`), comme Shizuku ou LADB.
 * La clé d'appairage reste dans le stockage privé de l'app.
 */
object Adb {
    private const val CHANNEL = "nitroid_adb"
    const val NOTIF_ID = 4711
    const val KEY_CODE = "pairing_code"
    const val ACTION_CODE = "com.heiphaistos.nitroid.ADB_PAIRING_CODE"

    private val worker = Executors.newSingleThreadExecutor()
    private val timer = Executors.newSingleThreadScheduledExecutor()
    private val pairingPort = AtomicInteger(-1)
    private val pairingHost = AtomicReference<InetAddress?>(null)
    @Volatile private var mdns: AdbMdns? = null
    @Volatile private var manager: Manager? = null

    val supported: Boolean get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R

    private class Manager(ctx: Context) : AbsAdbConnectionManager() {
        private val key: PrivateKey
        private val cert: Certificate

        init {
            setApi(Build.VERSION.SDK_INT)
            val dir = File(ctx.filesDir, "adb").apply { mkdirs() }
            val keyFile = File(dir, "private.key")
            val certFile = File(dir, "cert.der")
            if (keyFile.exists() && certFile.exists()) {
                key = KeyFactory.getInstance("RSA").generatePrivate(PKCS8EncodedKeySpec(keyFile.readBytes()))
                cert = certFile.inputStream().use { CertificateFactory.getInstance("X.509").generateCertificate(it) }
            } else {
                val pair = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
                val name = X500Name("CN=NiTroiD")
                val now = System.currentTimeMillis()
                val holder = JcaX509v3CertificateBuilder(
                    name, BigInteger.valueOf(now), Date(now - 86_400_000L), Date(now + 30L * 365 * 86_400_000L), name, pair.public,
                ).build(JcaContentSignerBuilder("SHA256withRSA").build(pair.private))
                key = pair.private
                cert = JcaX509CertificateConverter().getCertificate(holder)
                keyFile.writeBytes(key.encoded)
                certFile.writeBytes(cert.encoded)
            }
        }

        override fun getPrivateKey(): PrivateKey = key
        override fun getCertificate(): Certificate = cert
        override fun getDeviceName(): String = "NiTroiD"
    }

    @Synchronized
    private fun manager(ctx: Context): Manager {
        manager?.let { return it }
        // L'appairage TLS passe par des API Conscrypt masquées d'Android.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) HiddenApiBypass.addHiddenApiExemptions("L")
        return Manager(ctx.applicationContext).also { manager = it }
    }

    private fun pairedFile(ctx: Context) = File(ctx.filesDir, "adb/paired")

    fun paired(ctx: Context) = pairedFile(ctx).exists()

    fun connected(): Boolean = manager?.isConnected == true

    fun status(ctx: Context): Map<String, Any> = mapOf(
        "supported" to supported,
        "paired" to pairedFile(ctx).exists(),
        "connected" to connected(),
        "wirelessOn" to (Settings.Global.getInt(ctx.contentResolver, "adb_wifi_enabled", 0) == 1),
        "searching" to (mdns != null),
        "pairingPort" to pairingPort.get(),
    )

    /** Appaire avec le code à 6 chiffres. Port inconnu (-1) : celui trouvé par la recherche mDNS. */
    fun pair(ctx: Context, port: Int, code: String): String? {
        if (!supported) return "Le débogage sans fil demande Android 11 ou plus."
        if (!Regex("^\\d{6}$").matches(code)) return "Le code d’association fait 6 chiffres."
        val p = if (port in 1..65535) port else pairingPort.get()
        if (p <= 0) return "Port d’association introuvable : ouvre « Associer l’appareil avec un code » dans Débogage sans fil."
        return try {
            val host = pairingHost.get()?.hostAddress ?: "127.0.0.1"
            if (!manager(ctx).pair(host, p, code)) return "Association refusée (code expiré ?)"
            pairedFile(ctx).writeText(System.currentTimeMillis().toString())
            stopSearch(ctx.applicationContext)
            null
        } catch (e: Throwable) {
            "Échec de l’association : ${e.message ?: e.javaClass.simpleName}"
        }
    }

    /** Connexion au démon ADB du téléphone. Rallume le débogage sans fil si NiTroiD en a le droit. */
    fun connect(ctx: Context): String? {
        if (!supported) return "Le débogage sans fil demande Android 11 ou plus."
        if (connected()) return null
        val cr = ctx.contentResolver
        if (Settings.Global.getInt(cr, "adb_wifi_enabled", 0) != 1) {
            try {
                Settings.Global.putInt(cr, "adb_wifi_enabled", 1)
                Thread.sleep(1500)
            } catch (_: Throwable) {
                return "Active « Débogage sans fil » dans les options pour les développeurs (Wi-Fi requis)."
            }
        }
        return try {
            if (manager(ctx).connectTls(ctx, 10_000)) null else "Démon ADB introuvable : le Wi-Fi est-il connecté ?"
        } catch (e: AdbPairingRequiredException) {
            pairedFile(ctx).delete()
            "Association requise (ou révoquée) : refais l’association avec un code."
        } catch (e: Throwable) {
            "Connexion ADB impossible : ${e.message ?: e.javaClass.simpleName}"
        }
    }

    fun disconnect() {
        try {
            manager?.disconnect()
        } catch (_: Throwable) {
            // Déjà fermée : rien à faire.
        }
    }

    /** Lance une commande dans le shell ADB (utilisateur shell). */
    fun run(ctx: Context, command: String, timeoutSec: Long = 30): Root.Result {
        if (!connected()) connect(ctx)?.let { return Root.Result(false, it, -1) }
        return try {
            val stream = manager(ctx).openStream("shell:$command")
            val out = StringBuilder()
            val reader = Thread {
                try {
                    stream.openInputStream().bufferedReader().use { r ->
                        val buf = CharArray(8192)
                        while (true) {
                            val n = r.read(buf)
                            if (n < 0) break
                            synchronized(out) { if (out.length < 2 * 1024 * 1024) out.append(buf, 0, n) }
                        }
                    }
                } catch (_: Throwable) {
                    // Flux coupé (fermeture ou délai) : on garde ce qui a été lu.
                }
            }
            reader.start()
            reader.join(timeoutSec * 1000)
            val finished = !reader.isAlive
            stream.close()
            val text = synchronized(out) { out.toString().trim() }
            if (finished) Root.Result(true, text, 0) else Root.Result(false, "$text\n(délai dépassé)", -1)
        } catch (e: Throwable) {
            Root.Result(false, "Shell ADB : ${e.message ?: e.javaClass.simpleName}", -1)
        }
    }

    // --- Recherche du port d'association + saisie du code depuis la notification ---
    // L'écran « Associer avec un code » se ferme si on quitte les Paramètres : la
    // notification permet de taper le code sans le quitter.

    fun startSearch(ctx: Context): Boolean {
        if (!supported) return false
        val app = ctx.applicationContext
        stopSearch(app)
        pairingPort.set(-1)
        // Service de premier plan : sans lui, Android gèle NiTroiD dès qu'on passe
        // dans les Paramètres et la découverte du port n'aboutit jamais.
        app.startForegroundService(Intent(app, AdbPairingService::class.java))
        val m = AdbMdns(app, AdbMdns.SERVICE_TYPE_TLS_PAIRING) { host, port ->
            if (port > 0 && port != pairingPort.getAndSet(port)) {
                pairingHost.set(host)
                post(app, build(app, "Code d’association prêt", "Touche « Saisir le code » et tape les 6 chiffres affichés.", true))
            }
        }
        mdns = m
        m.start()
        // Pas de recherche infinie : 5 minutes suffisent pour aller dans les Paramètres.
        timer.schedule({ if (mdns === m) stopSearch(app) }, 5, TimeUnit.MINUTES)
        return true
    }

    fun stopSearch(ctx: Context) {
        mdns?.stop()
        mdns = null
        ctx.stopService(Intent(ctx, AdbPairingService::class.java))
    }

    fun build(ctx: Context, title: String, text: String, withInput: Boolean): android.app.Notification {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        nm?.createNotificationChannel(NotificationChannel(CHANNEL, "ADB sans fil", NotificationManager.IMPORTANCE_HIGH))
        val b = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setAutoCancel(!withInput)
        if (withInput) {
            val input = RemoteInput.Builder(KEY_CODE).setLabel("Code à 6 chiffres").build()
            val pi = PendingIntent.getBroadcast(
                ctx, 1, Intent(ctx, AdbCodeReceiver::class.java).setAction(ACTION_CODE),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            b.addAction(NotificationCompat.Action.Builder(0, "Saisir le code", pi).addRemoteInput(input).build())
        }
        return b.build()
    }

    private fun post(ctx: Context, n: android.app.Notification) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ctx.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        ctx.getSystemService(NotificationManager::class.java)?.notify(NOTIF_ID, n)
    }

    fun onCodeFromNotification(ctx: Context, code: String, done: () -> Unit) {
        worker.execute {
            val err = pair(ctx, -1, code.trim()) ?: connect(ctx)
            if (err == null) post(ctx, build(ctx, "ADB sans fil prêt", "NiTroiD dispose maintenant des droits ADB. Reviens dans l’app.", false))
            else post(ctx, build(ctx, "Association échouée", err, pairingPort.get() > 0))
            done()
        }
    }
}

/** Garde NiTroiD actif pendant l'association (recherche mDNS + saisie du code). */
class AdbPairingService : android.app.Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val n = Adb.build(this, "Recherche du code d’association…", "Ouvre « Associer l’appareil avec un code » dans Débogage sans fil.", false)
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(Adb.NOTIF_ID, n, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(Adb.NOTIF_ID, n)
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): android.os.IBinder? = null
}

class AdbCodeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Adb.ACTION_CODE) return
        val code = RemoteInput.getResultsFromIntent(intent)?.getCharSequence(Adb.KEY_CODE)?.toString() ?: return
        val pending = goAsync()
        Adb.onCodeFromNotification(context.applicationContext, code) { pending.finish() }
    }
}

/** Droits élevés : root s'il est là, sinon le shell ADB sans fil. */
object Priv {
    // Connexion ADB tentée seulement si déjà appairé : jamais 10 s d'attente pour rien.
    fun available(ctx: Context): Boolean =
        Root.available() || Adb.connected() || (Adb.supported && Adb.paired(ctx) && Adb.connect(ctx) == null)

    fun mode(ctx: Context): String = when {
        Root.available() -> "root"
        Adb.connected() || (Adb.supported && Adb.paired(ctx) && Adb.connect(ctx) == null) -> "adb"
        else -> "none"
    }

    fun run(ctx: Context, command: String, timeoutSec: Long = 30): Root.Result =
        if (Root.available()) Root.exec(command, timeoutSec)
        else if (Adb.supported) Adb.run(ctx, command, timeoutSec)
        else Root.Result(false, "Ni root ni ADB sans fil disponibles.", -1)
}
