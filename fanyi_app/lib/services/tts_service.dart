import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static bool _viSupported = false;

  static Future<void> _init() async {
    if (_initialized) return;

    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.65);
    await _tts.setPitch(1.0);

    try {
      final languages = await _tts.getLanguages;
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

    await _tts.setLanguage('vi-VN');
    final result = await _tts.speak(text);
    return result == 1;
  }

  static Future<void> speakChinese(String text) async {
    await _init();
    await _tts.setLanguage('zh-CN');
    await _tts.speak(text);
  }

  static Future<bool> speak(String text, {required bool isVietnamese}) async {
    if (isVietnamese) {
      return speakVietnamese(text);
    }

    await speakChinese(text);
    return true;
  }

  static Future<void> stop() async {
    await _tts.stop();
  }

  static Future<bool> get isViSupported async {
    await _init();
    return _viSupported;
  }
}
