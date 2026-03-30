package com.fanyitong.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.concurrent.thread

class ZaloReadTranslateAccessibilityService : AccessibilityService() {
    private val mainHandler = Handler(Looper.getMainLooper())

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var sourceTextView: TextView? = null
    private var translatedTextView: TextView? = null

    private var lastDigest = ""
    private var requestEpoch = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes =
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags =
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 120
            packageNames = arrayOf("com.zing.zalo")
        }
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName != "com.zing.zalo") {
            hideOverlay()
            return
        }

        val root = rootInActiveWindow ?: return
        val latestText = extractLatestText(root).trim()
        if (latestText.isBlank()) {
            hideOverlay()
            return
        }

        val digest = latestText.take(240)
        if (digest == lastDigest) return
        lastDigest = digest

        showOverlay(
            source = latestText,
            translated = "Translating...",
        )
        translateAsync(latestText)
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        hideOverlay()
        super.onDestroy()
    }

    private fun translateAsync(text: String) {
        val epoch = ++requestEpoch
        thread {
            try {
                val translated = requestTranslation(text)
                mainHandler.post {
                    if (epoch != requestEpoch) return@post
                    showOverlay(source = text, translated = translated)
                }
            } catch (_: Exception) {
                mainHandler.post {
                    if (epoch != requestEpoch) return@post
                    showOverlay(
                        source = text,
                        translated = "Translation failed. Open the app for manual retry.",
                    )
                }
            }
        }
    }

    private fun requestTranslation(text: String): String {
        val direction = if (containsChinese(text)) "zh-CN|vi" else "vi|zh-CN"
        val encoded = URLEncoder.encode(text, "UTF-8")
        val url = URL("https://api.mymemory.translated.net/get?q=$encoded&langpair=$direction")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 7000
            readTimeout = 7000
            setRequestProperty("User-Agent", "FanyiTong-ZaloReader/1.0")
        }

        return connection.inputStream.bufferedReader().use { reader ->
            val body = reader.readText()
            val translated = JSONObject(body)
                .optJSONObject("responseData")
                ?.optString("translatedText")
                .orEmpty()
            if (translated.isBlank()) {
                throw IllegalStateException("Translation failed")
            }
            translated
        }
    }

    private fun containsChinese(text: String): Boolean {
        return text.any { it in '\u4e00'..'\u9fff' }
    }

    private fun extractLatestText(node: AccessibilityNodeInfo): String {
        val texts = mutableListOf<String>()
        collectTexts(node, texts)
        return texts.lastOrNull { it.isNotBlank() } ?: ""
    }

    private fun collectTexts(node: AccessibilityNodeInfo, texts: MutableList<String>) {
        if (node.isVisibleToUser) {
            val text = node.text?.toString()?.trim().orEmpty()
            if (text.isNotBlank()) {
                texts.add(text)
            }
        }

        for (index in 0 until node.childCount) {
            node.getChild(index)?.let { collectTexts(it, texts) }
        }
    }

    private fun ensureOverlay() {
        if (overlayView != null) return

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 18, 20, 18)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1E3A35"))
                cornerRadius = 24f
                setStroke(2, Color.parseColor("#8ED2C6"))
            }
        }

        val title = TextView(this).apply {
            text = "Zalo live translate"
            setTextColor(Color.parseColor("#EAFBF6"))
            textSize = 11f
            setPadding(0, 0, 0, 8)
        }

        sourceTextView = TextView(this).apply {
            setTextColor(Color.parseColor("#FFFFFF"))
            textSize = 13f
            maxLines = 3
        }

        translatedTextView = TextView(this).apply {
            setTextColor(Color.parseColor("#8ED2C6"))
            textSize = 16f
            maxLines = 4
            setPadding(0, 10, 0, 0)
        }

        root.addView(title)
        root.addView(sourceTextView)
        root.addView(translatedTextView)
        overlayView = root
    }

    private fun showOverlay(source: String, translated: String) {
        ensureOverlay()
        sourceTextView?.text = source
        translatedTextView?.text = translated

        val overlay = overlayView ?: return
        val wm = windowManager ?: return

        if (overlay.parent == null) {
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
                y = 48
            }
            wm.addView(overlay, params)
        }
    }

    private fun hideOverlay() {
        val overlay = overlayView ?: return
        val wm = windowManager ?: return
        if (overlay.parent != null) {
            wm.removeView(overlay)
        }
    }
}
