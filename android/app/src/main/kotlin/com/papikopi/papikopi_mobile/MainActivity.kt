package com.papikopi.papikopi_mobile

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "papikopi/scan_feedback"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "beep" -> {
                    toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 90)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
