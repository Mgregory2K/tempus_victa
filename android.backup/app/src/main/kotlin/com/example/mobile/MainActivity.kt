package com.example.mobile

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognizerIntent
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "tempus.native.speech"
    private val REQUEST_CODE_SPEECH = 9001
    private var speechResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "startSpeech") {
                speechResult = result
                startSpeechRecognition()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startSpeechRecognition() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        intent.putExtra(
            RecognizerIntent.EXTRA_LANGUAGE_MODEL,
            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
        )
        intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak now")

        startActivityForResult(intent, REQUEST_CODE_SPEECH)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_SPEECH) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val results =
                    data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                speechResult?.success(results?.get(0) ?: "")
            } else {
                speechResult?.error("CANCELLED", "Speech cancelled", null)
            }
        }
    }
}