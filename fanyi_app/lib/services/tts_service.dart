import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 语音朗读服务（Text-to-Speech）
///
/// 技术说明：
///   flutter_tts 底层调用 Android 的 TextToSpeech API，
///   这是 Android 框架自带的功能，完全不依赖 Google Play 服务。
///
/// 中国手机兼容性：
///   • 华为/荣耀：使用 HiSilicon 自带 TTS 引擎
///   • 小米：使用小米/讯飞 TTS 引擎
///   • OPPO/vivo：使用自带 TTS 引擎
///   • 以上均支持中文朗读。越南语 TTS 需要设备安装了越南语语音包，
///     如果不支持会自动降级为静音（不会崩溃）。
class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static bool _viSupported = false; // 是否支持越南语朗读

  /// 初始化（懒加载，第一次调用时才执行）
  static Future<void> _init() async {
    if (_initialized) return;

    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.65); // 稍慢，方便学习者听清楚
    await _tts.setPitch(1.0);

    // 检测设备是否支持越南语 TTS
    try {
      final langs = await _tts.getLanguages;
      if (langs is List) {
        _viSupported = langs.any((l) =>
            l.toString().toLowerCase().startsWith('vi'));
      }
    } catch (_) {
      _viSupported = false;
    }

    _initialized = true;
    debugPrint('TTS 初始化完成，越南语支持: $_viSupported');
  }

  /// 朗读越南语文本
  /// 返回 true 表示成功，false 表示设备不支持越南语 TTS
  static Future<bool> speakVietnamese(String text) async {
    await _init();
    if (!_viSupported) return false;

    await _tts.setLanguage('vi-VN');
    final result = await _tts.speak(text);
    return result == 1;
  }

  /// 朗读中文文本（基本所有中国手机都支持）
  static Future<void> speakChinese(String text) async {
    await _init();
    await _tts.setLanguage('zh-CN');
    await _tts.speak(text);
  }

  /// 根据方向自动选择语言朗读
  /// [isVietnamese] = true 时朗读越南语，否则朗读中文
  static Future<bool> speak(String text, {required bool isVietnamese}) async {
    if (isVietnamese) {
      return speakVietnamese(text);
    } else {
      await speakChinese(text);
      return true;
    }
  }

  /// 停止当前朗读
  static Future<void> stop() async {
    await _tts.stop();
  }

  /// 是否支持越南语朗读
  static Future<bool> get isViSupported async {
    await _init();
    return _viSupported;
  }
}
