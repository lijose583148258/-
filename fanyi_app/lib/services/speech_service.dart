import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  static final SpeechToText _speech = SpeechToText();
  static bool _available = false;
  static bool _initialized = false;

  static Future<bool> initialize() async {
    if (_initialized) return _available;

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('Microphone permission was denied.');
        _initialized = true;
        _available = false;
        return false;
      }

      _available = await _speech.initialize(
        onError: (error) => debugPrint('STT error: ${error.errorMsg}'),
        onStatus: (status) => debugPrint('STT status: $status'),
      );
    } catch (error) {
      debugPrint('Speech initialization failed: $error');
      _available = false;
    }

    _initialized = true;
    return _available;
  }

  static Future<bool> startListening({
    required String localeId,
    required Function(String text) onResult,
    VoidCallback? onDone,
  }) async {
    if (!_available) return false;
    if (_speech.isListening) {
      await _speech.stop();
    }

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);
        if (result.finalResult && onDone != null) {
          onDone();
        }
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );

    return true;
  }

  static Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  static Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  static bool get isListening => _speech.isListening;
  static bool get isAvailable => _available;

  static Future<List<String>> getSupportedLocales() async {
    if (!_available) return [];
    final locales = await _speech.locales();
    return locales.map((locale) => locale.localeId).toList();
  }

  static Future<bool> isVietnameseSpeechSupported() async {
    final locales = await getSupportedLocales();
    return locales.any((locale) => locale.toLowerCase().startsWith('vi'));
  }
}
