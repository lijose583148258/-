package com.fanyitong.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
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
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

/**
 * Reads visible Zalo accessibility text and displays a translated overlay.
 *
 * This service deliberately avoids screenshot/OCR work. Screenshot capture and
 * multiple ML Kit recognizers are expensive inside a long-lived accessibility
 * service and are unreliable on heavily customized Android builds. When Zalo
 * does not expose readable accessibility text, the service simply hides the
 * overlay and leaves manual translation available in the main app.
 */
class ZaloReadTranslateAccessibilityService : AccessibilityService() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val eventDebounceRunnable = Runnable { processLatestText() }
    private val requestEpoch = AtomicInteger(0)
    private val overlayTouchSlop = 18

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private var sourceTextView: TextView? = null
    private var translatedTextView: TextView? = null

    @Volatile
    private var destroyed = false
    private var pendingText = ""
    private var pendingAnchorX = 16
    private var pendingAnchorY = 64
    private var lastDigest = ""
    private var screenWidthPx = 0
    private var screenHeightPx = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
        destroyed = false
        try {
            serviceInfo = AccessibilityServiceInfo().apply {
                eventTypes =
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                        AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                        AccessibilityEvent.TYPE_VIEW_SCROLLED or
                        AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
                feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
                flags =
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                        AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                        AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
                notificationTimeout = 160
                packageNames = arrayOf(ZALO_PACKAGE)
            }
            windowManager = getSystemService(WINDOW_SERVICE) as? WindowManager
            val metrics = resources.displayMetrics
            screenWidthPx = metrics.widthPixels
            screenHeightPx = metrics.heightPixels
        } catch (_: Exception) {
            windowManager = null
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (destroyed || event == null) return

        try {
            val packageName = event.packageName?.toString() ?: return
            if (packageName != ZALO_PACKAGE) {
                resetPendingState()
                return
            }

            val root = rootInActiveWindow ?: run {
                scheduleNoText()
                return
            }
            val candidate = extractBestCandidate(root)
            if (candidate == null) {
                scheduleNoText()
                return
            }

            pendingText = candidate.text.trim().take(MAX_SOURCE_LENGTH)
            pendingAnchorX = candidate.bounds.left.coerceAtLeast(dp(16))
            pendingAnchorY =
                (candidate.bounds.bottom + dp(18)).coerceIn(
                    dp(16),
                    (screenHeightPx - dp(140)).coerceAtLeast(dp(16)),
                )
            mainHandler.removeCallbacks(eventDebounceRunnable)
            mainHandler.postDelayed(eventDebounceRunnable, EVENT_DEBOUNCE_MS)
        } catch (_: Exception) {
            scheduleNoText()
        }
    }

    override fun onInterrupt() {
        resetPendingState()
    }

    override fun onDestroy() {
        destroyed = true
        requestEpoch.incrementAndGet()
        mainHandler.removeCallbacksAndMessages(null)
        hideOverlay()
        overlayView = null
        overlayParams = null
        sourceTextView = null
        translatedTextView = null
        windowManager = null
        super.onDestroy()
    }

    private fun scheduleNoText() {
        pendingText = ""
        mainHandler.removeCallbacks(eventDebounceRunnable)
        mainHandler.postDelayed(eventDebounceRunnable, EVENT_DEBOUNCE_MS)
    }

    private fun resetPendingState() {
        requestEpoch.incrementAndGet()
        mainHandler.removeCallbacks(eventDebounceRunnable)
        pendingText = ""
        pendingAnchorX = dp(16)
        pendingAnchorY = dp(64)
        lastDigest = ""
        hideOverlay()
    }

    private fun processLatestText() {
        if (destroyed) return
        val latestText = pendingText.trim()
        if (latestText.isBlank()) {
            requestEpoch.incrementAndGet()
            lastDigest = ""
            hideOverlay()
            return
        }

        val digest = latestText.take(MAX_DIGEST_LENGTH)
        if (digest == lastDigest) return
        lastDigest = digest

        showOverlay(
            source = latestText,
            translated = "Translating...",
            anchorX = pendingAnchorX,
            anchorY = pendingAnchorY,
        )
        translateAsync(latestText, pendingAnchorX, pendingAnchorY)
    }

    private fun translateAsync(text: String, anchorX: Int, anchorY: Int) {
        val epoch = requestEpoch.incrementAndGet()
        thread(name = "FanyiTong-Zalo-Translate", isDaemon = true) {
            val result = try {
                requestTranslation(text)
            } catch (_: Exception) {
                null
            }

            mainHandler.post {
                if (destroyed || epoch != requestEpoch.get()) return@post
                showOverlay(
                    source = text,
                    translated = result
                        ?: "Translation failed. Open the app for manual retry.",
                    anchorX = anchorX,
                    anchorY = anchorY,
                )
            }
        }
    }

    private fun requestTranslation(text: String): String {
        val direction = if (containsChinese(text)) "zh-CN|vi" else "vi|zh-CN"
        val encoded = URLEncoder.encode(text.take(MAX_NETWORK_TEXT_LENGTH), "UTF-8")
        val url = URL("https://api.mymemory.translated.net/get?q=$encoded&langpair=$direction")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = NETWORK_TIMEOUT_MS
            readTimeout = NETWORK_TIMEOUT_MS
            useCaches = false
            setRequestProperty("Accept", "application/json")
            setRequestProperty("User-Agent", "FanyiTong-ZaloReader/1.0")
        }

        return try {
            val responseCode = connection.responseCode
            if (responseCode !in 200..299) {
                throw IllegalStateException("Translation HTTP $responseCode")
            }
            val body = connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            val translated = JSONObject(body)
                .optJSONObject("responseData")
                ?.optString("translatedText")
                .orEmpty()
                .trim()
            if (translated.isBlank()) {
                throw IllegalStateException("Translation returned no text")
            }
            translated
        } finally {
            connection.disconnect()
        }
    }

    private fun containsChinese(text: String): Boolean {
        return text.any { it in '\u4e00'..'\u9fff' }
    }

    private fun extractBestCandidate(root: AccessibilityNodeInfo): ChatCandidate? {
        val candidates = mutableListOf<ChatCandidate>()
        val visited = intArrayOf(0)
        collectCandidates(root, candidates, visited, depth = 0)
        return candidates.lastOrNull { isLikelyChatText(it.text) }
    }

    private fun collectCandidates(
        node: AccessibilityNodeInfo,
        candidates: MutableList<ChatCandidate>,
        visited: IntArray,
        depth: Int,
    ) {
        if (destroyed || depth > MAX_NODE_DEPTH || visited[0] >= MAX_VISITED_NODES) return
        visited[0]++

        try {
            if (node.isVisibleToUser) {
                val bounds = Rect().also { node.getBoundsInScreen(it) }
                val rawCandidates = arrayOf(
                    node.text?.toString(),
                    node.contentDescription?.toString(),
                )
                for (raw in rawCandidates) {
                    val text = raw?.trim().orEmpty()
                    if (isLikelyChatText(text) && candidates.none { it.text == text }) {
                        candidates.add(ChatCandidate(text.take(MAX_SOURCE_LENGTH), Rect(bounds)))
                    }
                }
            }

            for (index in 0 until node.childCount) {
                if (visited[0] >= MAX_VISITED_NODES) break
                val child = try {
                    node.getChild(index)
                } catch (_: Exception) {
                    null
                }
                if (child != null) {
                    collectCandidates(child, candidates, visited, depth + 1)
                }
            }
        } catch (_: Exception) {
            // A node may disappear while Zalo is updating its hierarchy.
        }
    }

    private fun isLikelyChatText(text: String): Boolean {
        if (text.length !in 2..MAX_SOURCE_LENGTH) return false
        if (text.all { it.isDigit() || it.isWhitespace() }) return false
        return text.count { it.isLetterOrDigit() } >= 2
    }

    private fun ensureOverlay(): Boolean {
        if (destroyed || windowManager == null) return false
        if (overlayView != null) return true

        return try {
            val dragHandle = TextView(this).apply {
                text = "Zalo live translate"
                setTextColor(Color.parseColor("#EAFBF6"))
                textSize = 11f
            }
            val closeButton = TextView(this).apply {
                text = "×"
                contentDescription = "Close translation overlay"
                setTextColor(Color.parseColor("#EAFBF6"))
                textSize = 16f
                setPadding(12, 2, 12, 2)
                setOnClickListener {
                    requestEpoch.incrementAndGet()
                    hideOverlay()
                }
            }
            val sourceView = TextView(this).apply {
                setTextColor(Color.WHITE)
                textSize = 13f
                maxLines = 4
                maxWidth = ((screenWidthPx.takeIf { it > 0 } ?: resources.displayMetrics.widthPixels) * 0.78f).toInt()
            }
            val translatedView = TextView(this).apply {
                setTextColor(Color.parseColor("#8ED2C6"))
                textSize = 16f
                maxLines = 6
                setPadding(0, 10, 0, 0)
                maxWidth = ((screenWidthPx.takeIf { it > 0 } ?: resources.displayMetrics.widthPixels) * 0.78f).toInt()
            }
            sourceTextView = sourceView
            translatedTextView = translatedView

            val headerRow = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(
                    dragHandle,
                    LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
                )
                addView(closeButton)
            }
            val contentCard = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(20, 18, 20, 18)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#1E3A35"))
                    cornerRadius = 24f
                    setStroke(2, Color.parseColor("#8ED2C6"))
                }
                addView(headerRow)
                addView(sourceView)
                addView(translatedView)
                setOnTouchListener(DragTouchListener())
            }
            overlayView = FrameLayout(this).apply {
                setPadding(16, 16, 16, 16)
                addView(
                    contentCard,
                    FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                    ),
                )
            }
            true
        } catch (_: Exception) {
            overlayView = null
            sourceTextView = null
            translatedTextView = null
            false
        }
    }

    private fun showOverlay(source: String, translated: String, anchorX: Int, anchorY: Int) {
        if (!ensureOverlay()) return
        val overlay = overlayView ?: return
        val wm = windowManager ?: return

        try {
            sourceTextView?.text = source
            translatedTextView?.text = translated
            val width = screenWidthPx.takeIf { it > 0 } ?: resources.displayMetrics.widthPixels
            val params = overlayParams ?: WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.START
            }.also { overlayParams = it }

            params.x = anchorX.coerceIn(dp(16), (width - dp(280)).coerceAtLeast(dp(16)))
            params.y = anchorY.coerceAtLeast(dp(16))
            if (overlay.parent == null) {
                wm.addView(overlay, params)
            } else {
                wm.updateViewLayout(overlay, params)
            }
        } catch (_: Exception) {
            try {
                if (overlay.parent != null) wm.removeViewImmediate(overlay)
            } catch (_: Exception) {
                // Ignore OEM window manager teardown races.
            }
            overlayParams = null
        }
    }

    private fun hideOverlay() {
        val overlay = overlayView ?: return
        val wm = windowManager ?: return
        try {
            if (overlay.parent != null) {
                wm.removeViewImmediate(overlay)
            }
        } catch (_: Exception) {
            // The accessibility window can disappear between the parent check and removal.
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private inner class DragTouchListener : View.OnTouchListener {
        private var startX = 0
        private var startY = 0
        private var touchX = 0f
        private var touchY = 0f
        private var dragging = false

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            val params = overlayParams ?: return false
            return try {
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        startX = params.x
                        startY = params.y
                        touchX = event.rawX
                        touchY = event.rawY
                        dragging = false
                        true
                    }

                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - touchX).toInt()
                        val dy = (event.rawY - touchY).toInt()
                        if (!dragging &&
                            (kotlin.math.abs(dx) > overlayTouchSlop ||
                                kotlin.math.abs(dy) > overlayTouchSlop)
                        ) {
                            dragging = true
                        }
                        if (dragging) {
                            params.x = startX + dx
                            params.y = startY + dy
                            overlayView?.let { windowManager?.updateViewLayout(it, params) }
                        }
                        true
                    }

                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> true
                    else -> false
                }
            } catch (_: Exception) {
                false
            }
        }
    }

    private data class ChatCandidate(
        val text: String,
        val bounds: Rect,
    )

    private companion object {
        const val ZALO_PACKAGE = "com.zing.zalo"
        const val EVENT_DEBOUNCE_MS = 260L
        const val NETWORK_TIMEOUT_MS = 7_000
        const val MAX_SOURCE_LENGTH = 1_500
        const val MAX_NETWORK_TEXT_LENGTH = 600
        const val MAX_DIGEST_LENGTH = 240
        const val MAX_NODE_DEPTH = 40
        const val MAX_VISITED_NODES = 500
    }
}
