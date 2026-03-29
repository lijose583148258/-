package com.fanyitong.app

import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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

                "isImeEnabled" -> result.success(isImeEnabled())
                "isImeSelected" -> result.success(isImeSelected())
                else -> result.notImplemented()
            }
        }
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
}
