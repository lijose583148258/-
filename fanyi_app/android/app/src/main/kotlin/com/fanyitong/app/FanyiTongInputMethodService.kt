package com.fanyitong.app

import android.content.ClipboardManager
import android.content.Context
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.inputmethod.ExtractedTextRequest
import android.widget.Button
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.LinkedHashMap
import kotlin.concurrent.thread

class FanyiTongInputMethodService : InputMethodService() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val translationCache = object : LinkedHashMap<String, String>(20, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, String>?): Boolean {
            return size > 20
        }
    }

    private lateinit var statusView: TextView
    private lateinit var previewView: TextView
    private lateinit var directionButton: Button

    private var zhToVi = true
    private var lastTranslated = ""

    override fun onCreateInputView(): View {
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
            lastTranslated = ""
            previewView.text = getString(R.string.ime_empty_preview)
            setStatus("Cache cleared.")
        }
        directionButton.setOnClickListener {
            zhToVi = !zhToVi
            updateDirectionButton()
            setStatus(if (zhToVi) "Direction set to ZH -> VI." else "Direction set to VI -> ZH.")
        }

        updateDirectionButton()
        setStatus("Select text or use clipboard translate.")
        previewView.text = getString(R.string.ime_empty_preview)
        return view
    }

    private fun translateSelection() {
        val connection = currentInputConnection ?: run {
            setStatus("No active input field.")
            return
        }

        val selectedText = connection.getSelectedText(0)?.toString().orEmpty()
        val sourceText = if (selectedText.isNotBlank()) {
            selectedText
        } else {
            connection.getExtractedText(ExtractedTextRequest(), 0)?.text?.toString().orEmpty()
        }

        if (sourceText.isBlank()) {
            setStatus("Select Chinese or Vietnamese text first.")
            return
        }

        translateAndInsert(sourceText.trim())
    }

    private fun translateClipboard() {
        val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = manager.primaryClip
        val text = clip
            ?.takeIf { it.itemCount > 0 }
            ?.getItemAt(0)
            ?.coerceToText(this)
            ?.toString()
            .orEmpty()

        if (text.isBlank()) {
            setStatus("Clipboard is empty.")
            return
        }

        translateAndInsert(text.trim())
    }

    private fun insertLastResult() {
        if (lastTranslated.isBlank()) {
            setStatus("No translated text to insert yet.")
            return
        }

        currentInputConnection?.commitText(lastTranslated, 1)
        setStatus("Inserted the last translation.")
    }

    private fun translateAndInsert(text: String) {
        val cacheKey = cacheKey(text)
        val cached = getCachedTranslation(cacheKey)
        if (cached != null) {
            lastTranslated = cached
            previewView.text = cached
            val connection = currentInputConnection
            if (connection == null) {
                setStatus("Translation ready, but input field is unavailable.")
                return
            }
            connection.commitText(cached, 1)
            setStatus("Inserted cached translation.")
            return
        }

        setStatus("Translating...")
        previewView.text = text

        thread {
            try {
                val translated = requestTranslation(text)
                storeCachedTranslation(cacheKey, translated)
                mainHandler.post {
                    lastTranslated = translated
                    previewView.text = translated
                    val connection = currentInputConnection
                    if (connection == null) {
                        setStatus("Translation ready, but input field is unavailable.")
                        return@post
                    }

                    connection.commitText(translated, 1)
                    setStatus("Inserted translation. Review it before sending.")
                }
            } catch (_: Exception) {
                mainHandler.post {
                    setStatus("Translation failed. Try again in a moment.")
                }
            }
        }
    }

    private fun requestTranslation(text: String): String {
        val langPair = if (zhToVi) "zh-CN|vi" else "vi|zh-CN"
        val encoded = URLEncoder.encode(text, "UTF-8")
        val url = URL("https://api.mymemory.translated.net/get?q=$encoded&langpair=$langPair")
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 7000
            readTimeout = 7000
            setRequestProperty("User-Agent", "FanyiTong-IME/1.0")
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

    private fun cacheKey(text: String): String {
        return "${if (zhToVi) "zh->vi" else "vi->zh"}|${text.trim()}"
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
        directionButton.text = if (zhToVi) "ZH -> VI" else "VI -> ZH"
    }

    private fun setStatus(message: String) {
        statusView.text = message
    }
}
