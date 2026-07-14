package com.fanyitong.app

import android.content.ClipboardManager
import android.content.Context
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.inputmethod.ExtractedTextRequest
import android.view.inputmethod.InputConnection
import android.widget.Button
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.LinkedHashMap
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

class FanyiTongInputMethodService : InputMethodService() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val requestEpoch = AtomicInteger(0)
    private val translationCache = object : LinkedHashMap<String, String>(20, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, String>?): Boolean {
            return size > 20
        }
    }

    private var statusView: TextView? = null
    private var previewView: TextView? = null
    private var directionButton: Button? = null

    @Volatile
    private var destroyed = false
    private var zhToVi = true
    private var lastTranslated = ""

    override fun onCreateInputView(): View {
        destroyed = false
        val view = layoutInflater.inflate(R.layout.ime_translation_view, null)
        statusView = view.findViewById(R.id.statusText)
        previewView = view.findViewById(R.id.previewText)
        directionButton = view.findViewById(R.id.directionButton)

        view.findViewById<Button>(R.id.translateSelectionButton).setOnClickListener {
            translateSelection()
        }
        view.findViewById<Button>(R.id.translateClipboardButton).setOnClickListener {
            translateClipboard()
        }
        view.findViewById<Button>(R.id.insertLastButton).setOnClickListener {
            insertLastResult()
        }
        view.findViewById<Button>(R.id.clearButton).setOnClickListener {
            requestEpoch.incrementAndGet()
            lastTranslated = ""
            previewView?.text = getString(R.string.ime_empty_preview)
            setStatus("Cache cleared.")
        }
        directionButton?.setOnClickListener {
            requestEpoch.incrementAndGet()
            zhToVi = !zhToVi
            updateDirectionButton()
            setStatus(if (zhToVi) "Direction set to ZH -> VI." else "Direction set to VI -> ZH.")
        }

        updateDirectionButton()
        setStatus("Select text or use clipboard translate.")
        previewView?.text = getString(R.string.ime_empty_preview)
        return view
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        requestEpoch.incrementAndGet()
        super.onFinishInputView(finishingInput)
    }

    override fun onDestroy() {
        destroyed = true
        requestEpoch.incrementAndGet()
        mainHandler.removeCallbacksAndMessages(null)
        statusView = null
        previewView = null
        directionButton = null
        synchronized(translationCache) {
            translationCache.clear()
        }
        super.onDestroy()
    }

    private fun translateSelection() {
        val connection = currentInputConnection ?: run {
            setStatus("No active input field.")
            return
        }

        val sourceText = try {
            val selectedText = connection.getSelectedText(0)?.toString().orEmpty()
            if (selectedText.isNotBlank()) {
                selectedText
            } else {
                connection.getExtractedText(ExtractedTextRequest(), 0)?.text?.toString().orEmpty()
            }
        } catch (_: Exception) {
            ""
        }

        if (sourceText.isBlank()) {
            setStatus("Select Chinese or Vietnamese text first.")
            return
        }

        translateAndInsert(sourceText.trim(), connection)
    }

    private fun translateClipboard() {
        val text = try {
            val manager = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
            val clip = manager?.primaryClip
            clip
                ?.takeIf { it.itemCount > 0 }
                ?.getItemAt(0)
                ?.coerceToText(this)
                ?.toString()
                .orEmpty()
        } catch (_: Exception) {
            ""
        }

        if (text.isBlank()) {
            setStatus("Clipboard is empty or unavailable.")
            return
        }

        val connection = currentInputConnection
        if (connection == null) {
            setStatus("No active input field.")
            return
        }
        translateAndInsert(text.trim(), connection)
    }

    private fun insertLastResult() {
        if (lastTranslated.isBlank()) {
            setStatus("No translated text to insert yet.")
            return
        }

        try {
            val connection = currentInputConnection ?: run {
                setStatus("No active input field.")
                return
            }
            connection.commitText(lastTranslated, 1)
            setStatus("Inserted the last translation.")
        } catch (_: Exception) {
            setStatus("The current input field rejected the text.")
        }
    }

    private fun translateAndInsert(rawText: String, targetConnection: InputConnection) {
        if (destroyed) return
        val text = rawText.take(MAX_SOURCE_LENGTH)
        val directionZhToVi = zhToVi
        val cacheKey = cacheKey(text, directionZhToVi)
        val cached = getCachedTranslation(cacheKey)
        if (cached != null) {
            publishTranslation(cached, targetConnection, fromCache = true)
            return
        }

        val epoch = requestEpoch.incrementAndGet()
        setStatus("Translating...")
        previewView?.text = text

        thread(name = "FanyiTong-IME-Translate", isDaemon = true) {
            val translated = try {
                requestTranslation(text, directionZhToVi)
            } catch (_: Exception) {
                null
            }

            mainHandler.post {
                if (destroyed || epoch != requestEpoch.get()) return@post
                if (translated == null) {
                    setStatus("Translation failed. Try again in a moment.")
                    return@post
                }
                storeCachedTranslation(cacheKey, translated)
                publishTranslation(translated, targetConnection, fromCache = false)
            }
        }
    }

    private fun publishTranslation(
        translated: String,
        targetConnection: InputConnection,
        fromCache: Boolean,
    ) {
        if (destroyed) return
        lastTranslated = translated
        previewView?.text = translated

        val activeConnection = currentInputConnection
        if (activeConnection == null || activeConnection !== targetConnection) {
            setStatus("Translation ready. Tap Insert after returning to the original field.")
            return
        }

        try {
            activeConnection.commitText(translated, 1)
            setStatus(
                if (fromCache) {
                    "Inserted cached translation."
                } else {
                    "Inserted translation. Review it before sending."
                },
            )
        } catch (_: Exception) {
            setStatus("Translation ready, but the input field rejected it. Tap Insert to retry.")
        }
    }

    private fun requestTranslation(text: String, directionZhToVi: Boolean): String {
        val langPair = if (directionZhToVi) "zh-CN|vi" else "vi|zh-CN"
        val encoded = URLEncoder.encode(text.take(MAX_NETWORK_TEXT_LENGTH), "UTF-8")
        val url = URL("https://api.mymemory.translated.net/get?q=$encoded&langpair=$langPair")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = NETWORK_TIMEOUT_MS
            readTimeout = NETWORK_TIMEOUT_MS
            useCaches = false
            setRequestProperty("Accept", "application/json")
            setRequestProperty("User-Agent", "FanyiTong-IME/1.0")
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

    private fun cacheKey(text: String, directionZhToVi: Boolean): String {
        return "${if (directionZhToVi) "zh->vi" else "vi->zh"}|${text.trim()}"
    }

    private fun getCachedTranslation(key: String): String? {
        synchronized(translationCache) {
            return translationCache[key]
        }
    }

    private fun storeCachedTranslation(key: String, value: String) {
        synchronized(translationCache) {
            translationCache[key] = value
        }
    }

    private fun updateDirectionButton() {
        directionButton?.text = if (zhToVi) "ZH -> VI" else "VI -> ZH"
    }

    private fun setStatus(message: String) {
        if (!destroyed) statusView?.text = message
    }

    private companion object {
        const val NETWORK_TIMEOUT_MS = 7_000
        const val MAX_SOURCE_LENGTH = 1_500
        const val MAX_NETWORK_TEXT_LENGTH = 600
    }
}
