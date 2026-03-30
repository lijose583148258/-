package com.fanyitong.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.hardware.HardwareBuffer
import android.os.Build
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
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class ZaloReadTranslateAccessibilityService : AccessibilityService() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val eventDebounceRunnable = Runnable { processLatestWindowContent() }
    private val overlayTouchSlop = 18

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private lateinit var sourceTextView: TextView
    private lateinit var translatedTextView: TextView
    private lateinit var closeButton: TextView

    private var pendingText: String = ""
    private var pendingAnchorX: Int = 16
    private var pendingAnchorY: Int = 64
    private var lastDigest = ""
    private var requestEpoch = 0
    private var screenWidthPx = 0
    private var screenHeightPx = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
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
            notificationTimeout = 120
            packageNames = arrayOf("com.zing.zalo")
        }
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = resources.displayMetrics
        screenWidthPx = metrics.widthPixels
        screenHeightPx = metrics.heightPixels
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName != "com.zing.zalo") {
            hideOverlay()
            pendingText = ""
            pendingAnchorX = dp(16)
            pendingAnchorY = dp(64)
            lastDigest = ""
            return
        }

        val root = rootInActiveWindow ?: return
        val candidate = extractBestCandidate(root)
        if (candidate == null) {
            pendingText = ""
            mainHandler.removeCallbacks(eventDebounceRunnable)
            mainHandler.postDelayed(eventDebounceRunnable, 220)
            return
        }

        pendingText = candidate.text.trim()
        pendingAnchorX = candidate.bounds.left.coerceAtLeast(dp(16))
        pendingAnchorY = (candidate.bounds.bottom + dp(18)).coerceAtMost(screenHeightPx - dp(140))
        mainHandler.removeCallbacks(eventDebounceRunnable)
        mainHandler.postDelayed(eventDebounceRunnable, 220)
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        mainHandler.removeCallbacks(eventDebounceRunnable)
        hideOverlay()
        super.onDestroy()
    }

    private fun processLatestWindowContent() {
        val latestText = pendingText.trim()
        if (latestText.isNotBlank() && latestText != lastDigest) {
            lastDigest = latestText.take(240)
            showOverlay(
                source = latestText,
                translated = "Translating...",
                anchorX = pendingAnchorX,
                anchorY = pendingAnchorY,
            )
            translateAsync(latestText, pendingAnchorX, pendingAnchorY)
            return
        }

        if (latestText.isBlank()) {
            runOcrFallback()
        }
    }

    private fun runOcrFallback() {
        val root = rootInActiveWindow ?: run {
            hideOverlay()
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            captureScreenshot(displayId = DEFAULT_DISPLAY_ID, root.windowId)
        } else {
            hideOverlay()
        }
    }

    private fun captureScreenshot(displayId: Int, windowId: Int? = null) {
        hideOverlay()
        val executor = mainExecutor
        val isWindowShot = windowId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE

        if (isWindowShot) {
            takeScreenshotOfWindow(windowId!!, executor) { result ->
                handleScreenshotResult(result)
            }
        } else {
            takeScreenshot(displayId, executor) { result ->
                handleScreenshotResult(result)
            }
        }
    }

    private fun handleScreenshotResult(result: AccessibilityService.ScreenshotResult?) {
        if (result == null) {
            return
        }

        thread {
            val buffer: HardwareBuffer = result.hardwareBuffer
            try {
                val bitmap = Bitmap.wrapHardwareBuffer(buffer, result.colorSpace)
                    ?.copy(Bitmap.Config.ARGB_8888, false)
                if (bitmap == null) {
                    mainHandler.post { hideOverlay() }
                    return@thread
                }

                val recognized = recognizeText(bitmap)
                bitmap.recycle()
                if (recognized.isBlank()) {
                    mainHandler.post { hideOverlay() }
                    return@thread
                }

                val normalized = recognized.trim()
                val epoch = ++requestEpoch
                mainHandler.post {
                    lastDigest = normalized.take(240)
                    showOverlay(
                        source = normalized,
                        translated = "Translating...",
                        anchorX = dp(16),
                        anchorY = dp(96),
                    )
                    translateAsync(normalized, dp(16), dp(96), epoch)
                }
            } catch (_: Exception) {
                mainHandler.post { hideOverlay() }
            } finally {
                buffer.close()
            }
        }
    }

    private fun recognizeText(bitmap: Bitmap): String {
        val image = InputImage.fromBitmap(bitmap, 0)
        val latinRecognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val chineseRecognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
        return try {
            val latinText = runRecognizer(image, latinRecognizer)
            val chineseText = runRecognizer(image, chineseRecognizer)
            listOf(latinText, chineseText)
                .maxByOrNull { recognitionScore(it) }
                .orEmpty()
        } finally {
            latinRecognizer.close()
            chineseRecognizer.close()
        }
    }

    private fun runRecognizer(
        image: InputImage,
        recognizer: com.google.mlkit.vision.text.TextRecognizer,
    ): String {
        return try {
            Tasks.await(recognizer.process(image), 8, TimeUnit.SECONDS).text.orEmpty()
        } catch (_: Exception) {
            ""
        }
    }

    private fun recognitionScore(text: String): Int {
        return text.length + text.count { it == '\n' } * 12 + text.count { it.isLetterOrDigit() }
    }

    private fun translateAsync(text: String, anchorX: Int, anchorY: Int, epochOverride: Int? = null) {
        val epoch = epochOverride ?: ++requestEpoch
        thread {
            try {
                val translated = requestTranslation(text)
                mainHandler.post {
                    if (epoch != requestEpoch) return@post
                    showOverlay(source = text, translated = translated, anchorX = anchorX, anchorY = anchorY)
                }
            } catch (_: Exception) {
                mainHandler.post {
                    if (epoch != requestEpoch) return@post
                    showOverlay(
                        source = text,
                        translated = "Translation failed. Open the app for manual retry.",
                        anchorX = anchorX,
                        anchorY = anchorY,
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

    private fun extractBestCandidate(node: AccessibilityNodeInfo): ChatCandidate? {
        val candidates = mutableListOf<ChatCandidate>()
        collectCandidates(node, candidates)
        return candidates.lastOrNull { isLikelyChatText(it.text) }
    }

    private fun collectCandidates(node: AccessibilityNodeInfo, candidates: MutableList<ChatCandidate>) {
        if (node.isVisibleToUser) {
            val texts = listOf(
                node.text?.toString(),
                node.contentDescription?.toString(),
            )
            val bounds = Rect().also { node.getBoundsInScreen(it) }
            texts.forEach { candidate ->
                val text = candidate?.trim().orEmpty()
                if (text.isNotBlank() && text !in candidates.map { it.text }) {
                    candidates.add(ChatCandidate(text, bounds))
                }
            }
        }

        for (index in 0 until node.childCount) {
            node.getChild(index)?.let { collectCandidates(it, candidates) }
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
            maxLines = 4
            maxWidth = (screenWidthPx * 0.78f).toInt()
        }

        translatedTextView = TextView(this).apply {
            setTextColor(Color.parseColor("#8ED2C6"))
            textSize = 16f
            maxLines = 6
            setPadding(0, 10, 0, 0)
            maxWidth = (screenWidthPx * 0.78f).toInt()
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

        val contentCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 18, 20, 18)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1E3A35"))
                cornerRadius = 24f
                setStroke(2, Color.parseColor("#8ED2C6"))
            }
            addView(headerRow)
            addView(sourceTextView)
            addView(translatedTextView)
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
    }

    private fun showOverlay(source: String, translated: String, anchorX: Int, anchorY: Int) {
        ensureOverlay()
        sourceTextView.text = source
        translatedTextView.text = translated

        val overlay = overlayView ?: return
        val wm = windowManager ?: return
        val params = overlayParams ?: WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = anchorX.coerceIn(dp(16), (screenWidthPx - dp(280)).coerceAtLeast(dp(16)))
            y = anchorY
        }.also { overlayParams = it }

        params.y = anchorY.coerceAtLeast(dp(16))
        params.x = anchorX.coerceIn(dp(16), (screenWidthPx - dp(280)).coerceAtLeast(dp(16)))
        if (overlay.parent == null) {
            wm.addView(overlay, params)
        } else {
            wm.updateViewLayout(overlay, params)
        }
    }

    private fun hideOverlay() {
        val overlay = overlayView ?: return
        val wm = windowManager ?: return
        if (overlay.parent != null) {
            wm.removeView(overlay)
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
                        overlayView?.let { windowManager?.updateViewLayout(it, params) }
                        return true
                    }
                }
            }
            return false
        }
    }

    private data class ChatCandidate(
        val text: String,
        val bounds: Rect,
    )

    private companion object {
        const val DEFAULT_DISPLAY_ID = 0
    }
}
