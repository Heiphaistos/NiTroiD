package com.heiphaistos.nitroid

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import io.flutter.plugin.common.EventChannel
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/** Génération de sons pour tester les haut-parleurs (canaux gauche/droite, balayage). */
object Audio {
    private const val RATE = 44100

    @Volatile
    private var track: AudioTrack? = null

    fun stop() {
        try {
            track?.pause()
            track?.flush()
            track?.release()
        } catch (_: Throwable) {
        }
        track = null
    }

    /**
     * Joue un son. [channel] : "left", "right" ou "both".
     * [sweep] true = balayage 200 Hz → 12 kHz (utile pour entendre un haut-parleur fatigué).
     */
    fun playTone(freq: Double, ms: Int, channel: String, sweep: Boolean): Boolean {
        stop()
        return try {
            val frames = RATE * ms / 1000
            val samples = ShortArray(frames * 2)
            val left = channel != "right"
            val right = channel != "left"
            for (i in 0 until frames) {
                val t = i.toDouble() / RATE
                val f = if (sweep) 200.0 * Math.pow(60.0, i.toDouble() / frames) else freq
                // Enveloppe pour éviter les clics au début/fin.
                val env = min(1.0, min(i, frames - i) / (RATE * 0.01))
                val v = (sin(2 * PI * f * t) * env * 0.6 * Short.MAX_VALUE).toInt().toShort()
                samples[i * 2] = if (left) v else 0
                samples[i * 2 + 1] = if (right) v else 0
            }
            val buffSize = max(samples.size * 2, AudioTrack.getMinBufferSize(RATE, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT))
            val t = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(RATE)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .build()
                )
                .setBufferSizeInBytes(buffSize)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
            track = t
            t.write(samples, 0, samples.size)
            t.play()
            true
        } catch (_: Throwable) {
            false
        }
    }
}

/** Niveau du micro en direct (0..1) pour le test du microphone. Nécessite RECORD_AUDIO. */
class MicStream : EventChannel.StreamHandler {
    private var recording = false
    private var thread: Thread? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val rate = 44100
        val minBuf = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minBuf <= 0) {
            events.error("mic", "Micro indisponible", null)
            return
        }
        recording = true
        thread = Thread {
            var record: AudioRecord? = null
            try {
                @Suppress("MissingPermission")
                record = AudioRecord(MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minBuf * 2)
                if (record.state != AudioRecord.STATE_INITIALIZED) {
                    events.error("mic", "Autorise le micro", null)
                    return@Thread
                }
                val buf = ShortArray(minBuf)
                record.startRecording()
                while (recording) {
                    val n = record.read(buf, 0, buf.size)
                    if (n <= 0) continue
                    var sum = 0.0
                    var peak = 0
                    for (i in 0 until n) {
                        val s = buf[i].toInt()
                        sum += (s * s).toDouble()
                        if (kotlin.math.abs(s) > peak) peak = kotlin.math.abs(s)
                    }
                    val rms = sqrt(sum / n) / Short.MAX_VALUE
                    val pk = peak.toDouble() / Short.MAX_VALUE
                    events.success(listOf(rms, pk))
                }
            } catch (e: Throwable) {
                events.error("mic", e.message, null)
            } finally {
                try {
                    record?.stop()
                    record?.release()
                } catch (_: Throwable) {
                }
            }
        }.also { it.start() }
    }

    override fun onCancel(arguments: Any?) {
        recording = false
        thread?.interrupt()
    }
}
