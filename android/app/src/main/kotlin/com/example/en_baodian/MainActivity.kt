package com.example.en_baodian

import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import android.util.Log

class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val CHANNEL = "com.en_baodian/tts"
    private val TAG = "EnBaodianTTS"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val lang = call.argument<String>("lang") ?: "en"
                        speak(text, lang) { result.success(true) }
                    }
                    "init" -> {
                        initTts()
                        result.success(true)
                    }
                    "stop" -> {
                        tts?.stop()
                        result.success(true)
                    }
                    "playAudio" -> {
                        val path = call.argument<String>("path") ?: ""
                        playAudio(path) { result.success(true) }
                    }
                    "startForeground" -> {
                        val intent = Intent(this, AudioService::class.java)
                        startForegroundService(intent)
                        result.success(true)
                    }
                    "stopForeground" -> {
                        val intent = Intent(this, AudioService::class.java)
                        intent.action = "STOP"
                        startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        initTts()
    }

    private fun initTts() {
        if (ttsReady) return
        tts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                ttsReady = true
                Log.i(TAG, "TTS initialized OK")
            } else {
                Log.e(TAG, "TTS init failed: status=$status")
            }
        }
    }

    private var ttsRetryCount = 0

    private fun speak(text: String, lang: String, onDone: () -> Unit) {
        if (tts == null) { onDone(); return }
        // Wait for TTS to be ready (first call may be before init completes)
        if (!ttsReady) {
            if (ttsRetryCount++ > 15) {  // ~3 seconds max
                Log.e(TAG, "TTS never became ready, giving up")
                ttsRetryCount = 0
                onDone()
                return
            }
            android.os.Handler(mainLooper).postDelayed({
                speak(text, lang, onDone)
            }, 200)
            return
        }
        ttsRetryCount = 0
        // Try explicit locale first, then fallback
        val locale = if (lang == "zh")
            Locale.SIMPLIFIED_CHINESE  // zh-CN
        else
            Locale.US
        var result = tts!!.setLanguage(locale)
        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
            result = tts!!.setLanguage(Locale.getDefault())
        }
        Log.i(TAG, "speak lang=$lang result=$result locale=${tts!!.language}")

        tts!!.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onDone(utteranceId: String?) {
                Log.d(TAG, "TTS done: $text")
                tts!!.setOnUtteranceProgressListener(null)
                onDone()
            }
            override fun onStart(utteranceId: String?) {}
            override fun onError(utteranceId: String?) {
                Log.e(TAG, "TTS error: $text")
                tts!!.setOnUtteranceProgressListener(null)
                onDone()
            }
        })

        val speakResult = tts!!.speak(text, TextToSpeech.QUEUE_FLUSH, null, "tts_${text.hashCode()}")
        if (speakResult == TextToSpeech.ERROR) {
            Log.e(TAG, "TTS speak failed: $text")
            tts!!.setOnUtteranceProgressListener(null)
            onDone()
        }
    }

    private var mediaPlayer: MediaPlayer? = null

    private fun playAudio(path: String, onDone: () -> Unit) {
        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build())
                setDataSource(path)
                setOnCompletionListener {
                    release()
                    mediaPlayer = null
                    onDone()
                }
                setOnErrorListener { _, _, _ ->
                    release()
                    mediaPlayer = null
                    onDone()
                    true
                }
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "MediaPlayer error: $e")
            mediaPlayer?.release()
            mediaPlayer = null
            onDone()
        }
    }

    override fun onDestroy() {
        mediaPlayer?.release()
        mediaPlayer = null
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}
