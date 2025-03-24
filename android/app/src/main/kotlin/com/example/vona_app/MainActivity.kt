package com.example.vona_app

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import kotlin.math.abs
import kotlin.math.sqrt

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.vona_app/audio"
    private var audioRecord: AudioRecord? = null
    private var visualizer: Visualizer? = null
    private var isRecording = false
    private var currentAudioLevel = 0.0
    private val handler = Handler(Looper.getMainLooper())
    private val bufferSize = 1024
    private var audioThread: Thread? = null
    private val SAMPLE_RATE = 44100 // 샘플 레이트 정의

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAudio" -> {
                    startAudio()
                    result.success(null)
                }
                "stopAudio" -> {
                    stopAudio()
                    result.success(null)
                }
                "startAudioAnalysis" -> {
                    startAudioAnalysis(result)
                }
                "stopAudioAnalysis" -> {
                    stopAudioAnalysis(result)
                }
                "getAudioLevel" -> {
                    result.success(currentAudioLevel)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startAudio() {
        val minBufferSize = AudioTrack.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        val audioTrack = AudioTrack(
            AudioManager.STREAM_MUSIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBufferSize,
            AudioTrack.MODE_STREAM
        )

        audioTrack.play()

        audioThread = Thread {
            // 오디오 처리 로직
            // 예: 원래 코드에서 Float를 Double로 변환
        }
        audioThread?.start()
    }

    private fun stopAudio() {
        audioThread?.interrupt()
        audioThread = null
    }

    private fun startAudioAnalysis(result: MethodChannel.Result) {
        try {
            val bufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_FLOAT
            )

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_FLOAT,
                bufferSize
            )

            isRecording = true
            audioRecord?.startRecording()

            // Start reading audio data in a background thread
            audioThread = Thread {
                val buffer = FloatArray(bufferSize)
                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, bufferSize, AudioRecord.READ_NON_BLOCKING) ?: 0
                    if (read > 0) {
                        // Calculate RMS value
                        var sum = 0.0f
                        for (i in 0 until read) {
                            sum += buffer[i] * buffer[i]
                        }
                        currentAudioLevel = sqrt(sum / read).toDouble()
                    }
                    Thread.sleep(100) // Update every 100ms
                }
            }.apply { start() }

            result.success(null)
        } catch (e: Exception) {
            result.error("AUDIO_ERROR", "Failed to start audio recording", e.message)
        }
    }

    private fun stopAudioAnalysis(result: MethodChannel.Result) {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        result.success(null)
    }

    override fun onDestroy() {
        stopAudioAnalysis(object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
            override fun notImplemented() {}
        })
        super.onDestroy()
    }
}
