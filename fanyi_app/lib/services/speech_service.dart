import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// 语音识别服务（Speech-to-Text）
///
/// 技术说明：
///   speech_to_text 插件底层调用 Android 的 SpeechRecognizer API。
///   各品牌手机的语音引擎：
///     华为/荣耀 → 华为自研语音引擎（支持普通话，越南语支持有限）
///     小米       → 小米/百度语音（支持普通话）
///     OPPO/vivo  → 各自的语音引擎（支持普通话）
///
///   因此：中文语音识别在中国手机上效果好；
///         越南语语音识别依赖设备，不保证全部手机都支持。
///
/// 使用模式：PTT（Push-to-Talk，按住说话）
///   比连续监听更省电、更准确，也更符合对话翻译的使用习惯。
class SpeechService {
  static final SpeechToText _speech = SpeechToText();
  static bool _available = false;   // 设备是否支持语音识别
  static bool _initialized = false; // 是否已完成初始化

  // ─── 初始化 ───────────────────────────────────────────
  /// 初始化语音识别引擎
  /// 返回 true = 设备支持语音识别；false = 不支持（降级为纯文本输入）
  static Future<bool> initialize() async {
    if (_initialized) return _available;

    // 第一步：申请麦克风权限
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('麦克风权限被拒绝');
      _initialized = true;
      _available = false;
      return false;
    }

    // 第二步：初始化 SpeechToText 引擎
    _available = await _speech.initialize(
      onError: (e) => debugPrint('STT 错误: ${e.errorMsg}'),
      onStatus: (s) => debugPrint('STT 状态: $s'),
    );

    _initialized = true;
    debugPrint('STT 初始化完成，是否可用: $_available');
    return _available;
  }

  // ─── 开始监听 ─────────────────────────────────────────
  /// 开始语音识别
  /// [localeId] 语言代码：'zh-CN'（普通话）或 'vi-VN'（越南语）
  /// [onResult] 识别结果回调，每次识别出文字都会触发
  /// [onDone]   识别结束回调（用户停止说话或超时）
  static Future<bool> startListening({
    required String localeId,
    required Function(String text) onResult,
    VoidCallback? onDone,
  }) async {
    if (!_available) return false;
    if (_speech.isListening) await _speech.stop();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords);
        if (result.finalResult && onDone != null) {
          onDone();
        }
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 30),  // 最长监听 30 秒
      pauseFor: const Duration(seconds: 3),    // 3 秒无声音自动结束
      options: SpeechListenOptions(
        partialResults: true, // 实时返回中间结果（显示更流畅）
        cancelOnError: true,
      ),
    );

    return true;
  }

  /// 停止语音识别
  static Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// 取消语音识别（不返回最终结果）
  static Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  // ─── 状态查询 ─────────────────────────────────────────
  static bool get isListening => _speech.isListening;
  static bool get isAvailable => _available;

  /// 获取设备支持的语言列表（用于判断是否支持越南语识别）
  static Future<List<String>> getSupportedLocales() async {
    if (!_available) return [];
    final locales = await _speech.locales();
    return locales.map((l) => l.localeId).toList();
  }

  /// 检查是否支持越南语识别
  static Future<bool> isVietnameseSpeechSupported() async {
    final locales = await getSupportedLocales();
    return locales.any((l) => l.toLowerCase().startsWith('vi'));
  }
}
