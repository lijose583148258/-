import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static FlutterTts? _tts;
  static Future<bool>? _initializing;
  static bool _initialized = false;
  static bool _available = false;
  static bool _viSupported = false;

  static const Duration _platformTimeout = Duration(seconds: 8);
  static const Duration _speakTimeout = Duration(seconds: 15);

  static Future<bool> _init() {
    if (_initialized) return Future<bool>.value(_available);
    return _initializing ??= _initSafely();
  }

  static Future<bool> _initSafely() async {
    try {
      final tts = _tts ??= FlutterTts();
      await tts.setVolume(1.0).timeout(_platformTimeout);
      await tts.setSpeechRate(0.65).timeout(_platformTimeout);
      await tts.setPitch(1.0).timeout(_platformTimeout);

      final languages = await tts.getLanguages.timeout(_platformTimeout);
      if (languages is List) {
        _viSupported = languages.any(
          (language) => language.toString().toLowerCase().startsWith('vi'),
        );
      }
      _available = true;
      debugPrint('TTS initialized. Vietnamese supported: $_viSupported');
      return true;
    } catch (error, stack) {
      _available = false;
      _viSupported = false;
      debugPrint('TTS is unavailable: $error\n$stack');
      return false;
    } finally {
      _initialized = true;
      _initializing = null;
    }
  }

  static Future<bool> speakVietnamese(String text) async {
    try {
      if (!await _init() || !_viSupported) return false;
      final tts = _tts;
      if (tts == null) return false;
      final languageResult = await tts
          .setLanguage('vi-VN')
          .timeout(_platformTimeout);
      if (languageResult != 1) return false;
      return await tts.speak(text).timeout(_speakTimeout) == 1;
    } catch (error) {
      debugPrint('Vietnamese TTS failed: $error');
      return false;
    }
  }

  static Future<bool> speakChinese(String text) async {
    try {
      if (!await _init()) return false;
      final tts = _tts;
      if (tts == null) return false;
      final languageResult = await tts
          .setLanguage('zh-CN')
          .timeout(_platformTimeout);
      if (languageResult != 1) return false;
      return await tts.speak(text).timeout(_speakTimeout) == 1;
    } catch (error) {
      debugPrint('Chinese TTS failed: $error');
      return false;
    }
  }

  static Future<bool> speak(String text, {required bool isVietnamese}) {
    return isVietnamese ? speakVietnamese(text) : speakChinese(text);
  }

  static Future<void> stop() async {
    try {
      await _tts?.stop().timeout(_platformTimeout);
    } catch (error) {
      debugPrint('TTS could not stop: $error');
    }
  }

  static Future<void> reset() async {
    await stop();
    _tts = null;
    _initialized = false;
    _initializing = null;
    _available = false;
    _viSupported = false;
  }

  static Future<bool> get isViSupported async {
    if (!await _init()) return false;
    return _viSupported;
  }
}
