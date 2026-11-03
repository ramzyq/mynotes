package com.flutter.mynotes

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth (BiometricPrompt).
class MainActivity : FlutterFragmentActivity() {
    /** Text shared into Notely that Dart has not collected yet. */
    private var pendingSharedText: String? = null
    private var shareChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (captureShare(intent)) {
            // The app is already running: tell Dart right away.
            shareChannel?.invokeMethod("sharedTextAvailable", null)
        }
    }

    /** Store text from a "Share > Notely" intent. Returns true if there was any. */
    private fun captureShare(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return false
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return false
        pendingSharedText = if (subject.isNullOrBlank() || text.contains(subject)) text else "$subject\n$text"
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lets Dart check the API level: Keystore-backed biometric storage
        // is only enforced on Android 9 (API 28) and later.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "notely/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "androidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }
        // Quick capture: Dart collects shared text once, then it is cleared.
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "notely/share").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeSharedText" -> {
                        result.success(pendingSharedText)
                        pendingSharedText = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
