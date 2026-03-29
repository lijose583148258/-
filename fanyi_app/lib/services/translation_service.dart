import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_db_service.dart';
import 'mlkit_service.dart';

/// 翻译服务 ── 三层瀑布式降级架构
///
/// 每次翻译请求按优先级逐层尝试，一层失败才落到下一层：
///
///   第一层 ── 本地 SQLite 词典（毫秒级，完全离线）
///             覆盖越南语高频词、俚语、Teencode 缩写，共 311 条
///
///   第二层 ── Google ML Kit NMT（需要 Google Play 服务）
///             神经机器翻译，质量等同谷歌翻译网页版
///             语言模型（约 30MB × 2）首次下载后完全离线使用
///             在国内无 GMS 设备上静默跳过
///
///   第三层 ── MyMemory 免费在线 API（需要网络）
///             意大利服务器，国内无需翻墙，无 API Key，每天 5000 字符免费
///
/// 每次翻译结果都标注来源（TranslationSource），界面透明展示给用户。

class TranslationService {
  // ── 方向常量 ──────────────────────────────────────────────────
  static const String zhToVi = 'zh→vi';
  static const String viToZh = 'vi→zh';

  // ── App 启动时预热 ────────────────────────────────────────────
  /// 在 main() 里调用一次，提前检测 ML Kit 可用性。
  /// 故意不 await，让初始化在后台并发进行，不影响启动速度。
  static void warmUp() {
    MlKitService.initialize();
  }

  // ── 语言自动检测 ──────────────────────────────────────────────
  /// 分析文本判断语言：
  ///   · 含 CJK 汉字（U+4E00~U+9FFF）→ 中文
  ///   · 含越南语有调符号（如 ắ、ị、ộ）→ 越南语
  ///   · 纯拉丁字母 → 默认越南语（越语用拉丁字母书写）
  static String detectLanguage(String text) {
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) return 'zh';
    if (RegExp(
      r'[àáạảãăắặẳẵấầậẩẫđèéẹẻẽêếềệểễìíịỉĩòóọỏõôốồộổỗơớờợởỡùúụủũưứừựửữỳýỵỷỹ]',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'vi';
    }
    return 'vi';
  }

  // ── 主翻译入口 ────────────────────────────────────────────────
  static Future<TranslationResult> translate(
    String text, {
    String? direction,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return TranslationResult(translated: '', source: TranslationSource.empty);
    }

    final lang = detectLanguage(trimmed);
    final dir = direction ?? (lang == 'zh' ? zhToVi : viToZh);

    // ══ 第一层：本地 SQLite 词典 ══════════════════════════════════
    // 本地词典以越南语词为主键，只在 vi→zh 方向精确查询。
    if (dir == viToZh) {
      final offline = await LocalDbService.translate(trimmed);
      if (offline.found) {
        return TranslationResult(
          original: trimmed,
          translated: offline.translated,
          normalized: offline.normalized,
          hanZi: offline.hanZi,
          explanation: offline.explanation,
          isSlang: offline.isSlang,
          direction: dir,
          source: TranslationSource.localDb,
        );
      }
    }

    // ══ 第二层：ML Kit NMT ════════════════════════════════════════
    // 只在 Google Play 服务可用时尝试。
    // isAvailable 由 MlKitService.initialize() 在后台检测并设置，
    // 如果初始化还未完成（App 刚启动），这里会是 false，安全地跳过。
    if (MlKitService.isAvailable) {
      final mlResult = dir == zhToVi
          ? await MlKitService.zhToVi(trimmed)
          : await MlKitService.viToZh(trimmed);

      if (mlResult != null && mlResult.isNotEmpty) {
        return TranslationResult(
          original: trimmed,
          translated: mlResult,
          direction: dir,
          source: TranslationSource.mlKit,
        );
      }
    }

    // ══ 第三层：MyMemory 在线 API ═════════════════════════════════
    try {
      final online = await _callMyMemory(trimmed, dir);
      return TranslationResult(
        original: trimmed,
        translated: online,
        direction: dir,
        source: TranslationSource.myMemory,
      );
    } catch (_) {
      // 三层全部失败（无 GMS、无网络、且词库未收录）
      return TranslationResult(
        original: trimmed,
        translated: trimmed,
        direction: dir,
        source: TranslationSource.noResult,
      );
    }
  }

  // ── MyMemory API 实现 ─────────────────────────────────────────
  static Future<String> _callMyMemory(String text, String direction) async {
    final langpair = direction == zhToVi ? 'zh-CN|vi' : 'vi|zh-CN';
    final uri = Uri.parse(
      'https://api.mymemory.translated.net/get'
      '?q=${Uri.encodeQueryComponent(text)}'
      '&langpair=$langpair',
    );

    final response = await http
        .get(uri, headers: {'User-Agent': 'FanyiTong/1.0'})
        .timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      final translated = data['responseData']?['translatedText'] as String?;
      if (translated != null && translated.isNotEmpty) {
        return translated;
      }
    }
    throw Exception('MyMemory 返回无效结果');
  }
}

// ── 翻译来源枚举 ──────────────────────────────────────────────
enum TranslationSource {
  localDb,   // 本地 SQLite 词典（离线）
  mlKit,     // Google ML Kit NMT（有 Google Play 服务时）
  myMemory,  // MyMemory 在线 API
  noResult,  // 三层均失败
  empty,     // 输入为空
}

// ── 翻译结果数据类 ────────────────────────────────────────────
class TranslationResult {
  final String? original;
  final String translated;
  final String? normalized;    // Teencode 规范化后的原文
  final String? hanZi;         // 汉字根（汉越词专属）
  final String? explanation;   // 俚语详解
  final bool isSlang;
  final String? direction;
  final TranslationSource source;

  TranslationResult({
    this.original,
    required this.translated,
    this.normalized,
    this.hanZi,
    this.explanation,
    this.isSlang = false,
    this.direction,
    required this.source,
  });

  /// 翻译来源的用户友好标签
  String get sourceLabel {
    switch (source) {
      case TranslationSource.localDb:
        return isSlang ? '📚 本地俚语库（离线）' : '📴 本地词典（离线）';
      case TranslationSource.mlKit:
        return '🤖 ML Kit 神经翻译（高质量）';
      case TranslationSource.myMemory:
        return '🌐 MyMemory 在线翻译';
      case TranslationSource.noResult:
        return '⚠️ 无网络且词库未收录';
      case TranslationSource.empty:
        return '';
    }
  }

  /// 来源标签的颜色
  int get sourceLabelColor {
    switch (source) {
      case TranslationSource.localDb:   return 0xFF677D6A;
      case TranslationSource.mlKit:     return 0xFF1565C0;
      case TranslationSource.myMemory:  return 0xFF0277BD;
      case TranslationSource.noResult:  return 0xFFE65100;
      case TranslationSource.empty:     return 0xFF9E9E9E;
    }
  }

  bool get hasResult =>
      source != TranslationSource.empty &&
      source != TranslationSource.noResult;

  bool get isOffline =>
      source == TranslationSource.localDb ||
      source == TranslationSource.mlKit;

  bool get isOnline =>
      source == TranslationSource.myMemory;

  bool get isMlKit => source == TranslationSource.mlKit;
}
