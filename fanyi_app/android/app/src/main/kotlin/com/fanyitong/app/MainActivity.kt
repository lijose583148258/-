package com.fanyitong.app

import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var appActionsChannel: MethodChannel? = null
    private var pendingLaunchAction: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureLaunchAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchAction(intent)
        dispatchPendingLaunchAction()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fanyitong/ime",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openInputMethodSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_INPUT_METHOD_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )
                    result.success(true)
                }

                "showInputMethodPicker" -> {
                    val manager = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
                    manager.showInputMethodPicker()
                    result.success(true)
                }

                "openAccessibilitySettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )
                    result.success(true)
                }

                "isImeEnabled" -> result.success(isImeEnabled())
                "isImeSelected" -> result.success(isImeSelected())
                else -> result.notImplemented()
            }
        }

        appActionsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fanyitong/app_actions",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumePendingAction" -> {
                        result.success(pendingLaunchAction)
                        pendingLaunchAction = null
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun captureLaunchAction(intent: Intent?) {
        val action = parseLaunchAction(intent) ?: return
        pendingLaunchAction = action
    }

    private fun parseLaunchAction(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null

        val widgetAction = intent.getStringExtra(EXTRA_LAUNCH_ACTION)
        if (!widgetAction.isNullOrBlank()) {
            return mapOf(
                "action" to widgetAction,
                "text" to intent.getStringExtra(EXTRA_LAUNCH_TEXT),
                "requestId" to System.currentTimeMillis(),
            )
        }

        if (Intent.ACTION_SEND == intent.action && intent.type == "text/plain") {
            val sharedText = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString().orEmpty()
            if (sharedText.isNotBlank()) {
                return mapOf(
                    "action" to ACTION_SHARED_TEXT,
                    "text" to sharedText,
                    "requestId" to System.currentTimeMillis(),
                )
            }
        }

        return null
    }

    private fun dispatchPendingLaunchAction() {
        val action = pendingLaunchAction ?: return
        appActionsChannel?.invokeMethod("launchAction", action)
        pendingLaunchAction = null
    }

    private fun isImeEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_INPUT_METHODS,
        ) ?: return false

        return enabled.contains("${packageName}/.FanyiTongInputMethodService")
    }

    private fun isImeSelected(): Boolean {
        val selected = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.DEFAULT_INPUT_METHOD,
        ) ?: return false

        return selected.contains("${packageName}/.FanyiTongInputMethodService")
    }

    companion object {
        const val EXTRA_LAUNCH_ACTION = "launch_action"
        const val EXTRA_LAUNCH_TEXT = "launch_text"
        const val ACTION_SHARED_TEXT = "shared_text"
    }
}
