import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static bool _viSupported = false;
  static bool _speaking = false;

  static const Duration _ttsTimeout = Duration(seconds: 2);

  static Future<void> _init() async {
    if (_initialized) return;

    try {
      _tts.setStartHandler(() => _speaking = true);
      _tts.setCompletionHandler(() => _speaking = false);
      _tts.setErrorHandler((_) => _speaking = false);
      _tts.setCancelHandler(() => _speaking = false);

      await _tts.setVolume(1.0).timeout(_ttsTimeout, onTimeout: () => 1);
      await _tts.setSpeechRate(0.65).timeout(_ttsTimeout, onTimeout: () => 1);
      await _tts.setPitch(1.0).timeout(_ttsTimeout, onTimeout: () => 1);

      final languages = await _tts.getLanguages.timeout(
        _ttsTimeout,
        onTimeout: () => const [],
      );
      if (languages is List) {
        _viSupported = languages.any(
          (language) => language.toString().toLowerCase().startsWith('vi'),
        );
      }
    } catch (_) {
      _viSupported = false;
    }

    _initialized = true;
    debugPrint('TTS initialized. Vietnamese supported: $_viSupported');
  }

  static Future<bool> speakVietnamese(String text) async {
    await _init();
    if (!_viSupported) return false;

    _speaking = true;
    try {
      await _tts.setLanguage('vi-VN').timeout(_ttsTimeout, onTimeout: () => 1);
      final result = await _tts.speak(text).timeout(_ttsTimeout, onTimeout: () => 0);
      return result == 1;
    } catch (_) {
      return false;
    } finally {
      _speaking = false;
    }
  }

  static Future<void> speakChinese(String text) async {
    await _init();
    _speaking = true;
    try {
      await _tts.setLanguage('zh-CN').timeout(_ttsTimeout, onTimeout: () => 1);
      await _tts.speak(text).timeout(_ttsTimeout, onTimeout: () => 0);
    } catch (_) {
    } finally {
      _speaking = false;
    }
  }

  static Future<bool> speak(String text, {required bool isVietnamese}) async {
    if (isVietnamese) {
      return speakVietnamese(text);
    }

    await speakChinese(text);
    return true;
  }

  static Future<void> stop() async {
    if (!_initialized || !_speaking) return;
    _speaking = false;
    try {
      await _tts.stop().timeout(_ttsTimeout, onTimeout: () => 0);
    } catch (_) {}
  }

  static Future<bool> get isViSupported async {
    await _init();
    return _viSupported;
  }
}
