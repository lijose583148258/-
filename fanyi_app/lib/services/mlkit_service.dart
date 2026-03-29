import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Google ML Kit 翻译服务
///
/// ─── 工作原理 ───────────────────────────────────────────────────
/// ML Kit 的翻译功能使用神经机器翻译（NMT）模型，翻译质量与谷歌翻译
/// 网页版处于同一水准。每个语言对的模型大约 30MB，用户首次使用时
/// 会在后台自动下载，下载完成后永久离线使用，不再消耗流量。
///
/// ─── 设备兼容性 ─────────────────────────────────────────────────
/// 依赖 Google Play 服务（Google Play Services），在以下情况可用：
///   ✅ 三星、索尼、摩托罗拉、OnePlus 等国际版机型（全球均可用）
///   ✅ 在中国购买但刷了 Google 系统的手机
///   ✅ 出境后使用的国际版华为/小米（如果手机本身装了 Google Play）
///   ❌ 国行华为、荣耀（2020 年后）、部分国行小米/OPPO/vivo
///      → 这些设备 _isAvailable 会是 false，调用方自动降级到 MyMemory
///
/// ─── 检测逻辑 ────────────────────────────────────────────────────
/// 我们不依赖 IP 检测地理位置，而是直接尝试初始化 ML Kit 翻译器：
///   - 成功 → Google Play 服务存在，ML Kit 可用
///   - 抛出异常 → Google Play 服务不存在，标记为不可用并静默失败
/// 这种方式比 IP 检测更准确，因为它检测的是真实能力而非地理位置。
class MlKitService {
  // 两个翻译器：一个负责中文→越南语，一个负责越南语→中文
  static OnDeviceTranslator? _zhToViTranslator;
  static OnDeviceTranslator? _viToZhTranslator;

  static bool _isAvailable = false; // Google Play 服务是否可用
  static bool _initialized = false; // 是否已经完成初始化检测
  static bool _zhViModelReady = false; // 中→越模型是否已下载
  static bool _viZhModelReady = false; // 越→中模型是否已下载

  // ─── 对外查询接口 ──────────────────────────────────────────────
  /// 是否可以使用 ML Kit（设备有 Google Play 服务且模型已就绪）
  static bool get isAvailable => _isAvailable;

  /// 是否正在下载模型（可用于显示进度提示）
  static bool get isDownloading => _isAvailable && (!_zhViModelReady || !_viZhModelReady);

  // ─── 初始化 ───────────────────────────────────────────────────
  /// 检测设备能力并尝试初始化翻译器。
  /// 这个方法设计为静默失败：无论成功还是失败都不会抛出异常。
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 创建翻译器实例（此时尚未下载模型）
      _zhToViTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.chinese,
        targetLanguage: TranslateLanguage.vietnamese,
      );
      _viToZhTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.vietnamese,
        targetLanguage: TranslateLanguage.chinese,
      );

      // 尝试翻译一个空字符串——这会触发 Google Play 服务的初始化。
      // 如果没有 Google Play 服务，这里会抛出 PlatformException，
      // 我们在 catch 里把 _isAvailable 设为 false 并静默退出。
      await _zhToViTranslator!.translateText('你好');

      // 走到这里说明 Google Play 服务正常
      _isAvailable = true;
      debugPrint('✅ ML Kit 初始化成功，Google Play 服务可用');

      // 异步下载语言模型（不阻塞 UI，后台静默完成）
      _downloadModels();
    } catch (e) {
      // 静默失败：Google Play 服务不可用（国行无 GMS 手机），
      // 调用方（TranslationService）会自动降级到 MyMemory API。
      _isAvailable = false;
      debugPrint('ℹ️ ML Kit 不可用（无 Google Play 服务），已降级到 MyMemory：$e');

      // 清理资源，避免内存泄漏
      _zhToViTranslator?.close();
      _viToZhTranslator?.close();
      _zhToViTranslator = null;
      _viToZhTranslator = null;
    }
  }

  // ─── 后台下载语言模型 ──────────────────────────────────────────
  /// 在后台静默下载中文↔越南语翻译模型（各约 30MB）。
  /// 下载完成后，翻译完全离线运行，不再需要网络。
  /// WiFi 环境下约 1-2 分钟完成；移动数据约 3-5 分钟。
  static Future<void> _downloadModels() async {
    final modelManager = OnDeviceTranslatorModelManager();

    // 下载中文→越南语模型
    try {
      final zhViDownloaded = await modelManager.isModelDownloaded(
        TranslateLanguage.vietnamese.bcpCode,
      );
      if (!zhViDownloaded) {
        debugPrint('📥 开始下载越南语翻译模型（约 30MB）...');
        await modelManager.downloadModel(
          TranslateLanguage.vietnamese.bcpCode,
          isWifiRequired: false, // 允许移动数据下载，用户可在设置里调整
        );
      }
      _zhViModelReady = true;
      debugPrint('✅ 越南语模型就绪，中↔越翻译已完全离线可用');
    } catch (e) {
      debugPrint('⚠️ 越南语模型下载失败，将使用在线翻译：$e');
    }

    // 下载中文模型（用于越南语→中文方向）
    try {
      final viZhDownloaded = await modelManager.isModelDownloaded(
        TranslateLanguage.chinese.bcpCode,
      );
      if (!viZhDownloaded) {
        debugPrint('📥 开始下载中文翻译模型（约 30MB）...');
        await modelManager.downloadModel(
          TranslateLanguage.chinese.bcpCode,
          isWifiRequired: false,
        );
      }
      _viZhModelReady = true;
    } catch (e) {
      debugPrint('⚠️ 中文模型下载失败：$e');
    }
  }

  // ─── 核心翻译方法 ──────────────────────────────────────────────
  /// 中文 → 越南语
  /// 在模型下载完成之前，ML Kit 会临时联网翻译；
  /// 模型下载完成后自动切换为完全离线翻译，用户无需任何操作。
  static Future<String?> zhToVi(String text) async {
    if (!_isAvailable || _zhToViTranslator == null) return null;
    try {
      return await _zhToViTranslator!.translateText(text);
    } catch (e) {
      debugPrint('ML Kit zh→vi 翻译失败：$e');
      return null; // 返回 null，让调用方降级到 MyMemory
    }
  }

  /// 越南语 → 中文
  static Future<String?> viToZh(String text) async {
    if (!_isAvailable || _viToZhTranslator == null) return null;
    try {
      return await _viToZhTranslator!.translateText(text);
    } catch (e) {
      debugPrint('ML Kit vi→zh 翻译失败：$e');
      return null;
    }
  }

  // ─── 模型管理 ──────────────────────────────────────────────────
  /// 查询当前模型下载状态，用于在设置页面展示给用户
  static Future<MlKitStatus> getStatus() async {
    if (!_isAvailable) {
      return MlKitStatus(
        available: false,
        message: '当前设备不支持 ML Kit（无 Google Play 服务）',
      );
    }

    final manager = OnDeviceTranslatorModelManager();
    final viReady = await manager.isModelDownloaded(TranslateLanguage.vietnamese.bcpCode);
    final zhReady = await manager.isModelDownloaded(TranslateLanguage.chinese.bcpCode);

    if (viReady && zhReady) {
      return MlKitStatus(
        available: true,
        modelsDownloaded: true,
        message: '✅ ML Kit 就绪（完全离线，质量最佳）',
      );
    } else {
      return MlKitStatus(
        available: true,
        modelsDownloaded: false,
        message: '⏳ 模型下载中（${viReady ? '✅' : '⏳'}越南语 · ${zhReady ? '✅' : '⏳'}中文）',
      );
    }
  }

  /// 手动触发模型下载（用于设置页面的"立即下载"按钮）
  static Future<void> forceDownloadModels() async {
    if (!_isAvailable) return;
    await _downloadModels();
  }

  /// 释放翻译器资源（App 关闭时调用）
  static void dispose() {
    _zhToViTranslator?.close();
    _viToZhTranslator?.close();
  }
}

/// ML Kit 状态数据类
class MlKitStatus {
  final bool available;
  final bool modelsDownloaded;
  final String message;

  MlKitStatus({
    required this.available,
    this.modelsDownloaded = false,
    required this.message,
  });
}
