package com.fanyitong.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.concurrent.thread

class ZaloReadTranslateAccessibilityService : AccessibilityService() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val eventDebounceRunnable = Runnable { processLatestWindowText() }
    private val overlayTouchSlop = 18

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private lateinit var sourceTextView: TextView
    private lateinit var translatedTextView: TextView
    private lateinit var closeButton: TextView

    private var pendingText: String = ""
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
            pendingText = ""
            lastDigest = ""
            return
        }

        val root = rootInActiveWindow ?: return
        pendingText = extractLatestText(root).trim()
        if (pendingText.isBlank()) {
            hideOverlay()
            return
        }
        mainHandler.removeCallbacks(eventDebounceRunnable)
        mainHandler.postDelayed(eventDebounceRunnable, 220)
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        mainHandler.removeCallbacks(eventDebounceRunnable)
        hideOverlay()
        super.onDestroy()
    }

    private fun processLatestWindowText() {
        val latestText = pendingText.trim()
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
        return texts
            .asReversed()
            .firstOrNull { isLikelyChatText(it) }
            ?: texts.lastOrNull { it.isNotBlank() }
            ?: ""
    }

    private fun collectTexts(node: AccessibilityNodeInfo, texts: MutableList<String>) {
        if (node.isVisibleToUser) {
            val candidates = listOf(
                node.text?.toString(),
                node.contentDescription?.toString(),
            )
            candidates.forEach { candidate ->
                val text = candidate?.trim().orEmpty()
                if (text.isNotBlank() && text !in texts) {
                    texts.add(text)
                }
            }
        }

        for (index in 0 until node.childCount) {
            node.getChild(index)?.let { collectTexts(it, texts) }
        }
    }

    private fun isLikelyChatText(text: String): Boolean {
        if (text.length < 2) return false
        if (text.all { it.isDigit() }) return false
        if (text.count { it.isLetterOrDigit() } < 2) return false
        return true
    }

    private fun ensureOverlay() {
        if (overlayView != null) return

        val dragHandle = TextView(this).apply {
            text = "Zalo live translate"
            setTextColor(Color.parseColor("#EAFBF6"))
            textSize = 11f
            setPadding(0, 0, 0, 0)
        }

        closeButton = TextView(this).apply {
            text = "×"
            setTextColor(Color.parseColor("#EAFBF6"))
            textSize = 16f
            setPadding(12, 2, 12, 2)
            setOnClickListener { hideOverlay() }
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

        val headerRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(
                dragHandle,
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
            )
            addView(closeButton)
        }

        val contentColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(headerRow)
            addView(sourceTextView)
            addView(translatedTextView)
        }

        val root = FrameLayout(this).apply {
            setPadding(20, 18, 20, 18)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1E3A35"))
                cornerRadius = 24f
                setStroke(2, Color.parseColor("#8ED2C6"))
            }
            addView(contentColumn)
            setOnTouchListener(DragTouchListener())
        }
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
            overlayParams = params
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

    private inner class DragTouchListener : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            val params = overlayParams ?: return false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    return false
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (kotlin.math.abs(dx) > overlayTouchSlop || kotlin.math.abs(dy) > overlayTouchSlop) {
                        params.x = startX + dx
                        params.y = startY + dy
                        windowManager?.updateViewLayout(view, params)
                        return true
                    }
                }
            }
            return false
        }
    }
}
