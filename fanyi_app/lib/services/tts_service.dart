import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static FlutterTts? _tts;
  static Future<bool>? _initializing;
  static bool _initialized = false;
  static bool _available = false;
  static bool _viSupported = false;

  static Future<bool> _init() {
    if (_initialized) return Future<bool>.value(_available);
    return _initializing ??= _initSafely();
  }

  static Future<bool> _initSafely() async {
    try {
      final tts = _tts ??= FlutterTts();
      await tts.setVolume(1.0);
      await tts.setSpeechRate(0.65);
      await tts.setPitch(1.0);

      final languages = await tts.getLanguages;
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
      await tts.setLanguage('vi-VN');
      return await tts.speak(text) == 1;
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
      await tts.setLanguage('zh-CN');
      return await tts.speak(text) == 1;
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
      await _tts?.stop();
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
