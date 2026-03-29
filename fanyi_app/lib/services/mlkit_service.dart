import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class MlKitService {
  static OnDeviceTranslator? _zhToViTranslator;
  static OnDeviceTranslator? _viToZhTranslator;

  static bool _isAvailable = false;
  static bool _initialized = false;
  static bool _zhViModelReady = false;
  static bool _viZhModelReady = false;

  static bool get isAvailable => _isAvailable;
  static bool get isDownloading =>
      _isAvailable && (!_zhViModelReady || !_viZhModelReady);

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _zhToViTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.chinese,
        targetLanguage: TranslateLanguage.vietnamese,
      );
      _viToZhTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.vietnamese,
        targetLanguage: TranslateLanguage.chinese,
      );

      await _zhToViTranslator!.translateText('你好');
      _isAvailable = true;
      debugPrint('ML Kit is available on this device.');
      _downloadModels();
    } catch (error) {
      _isAvailable = false;
      debugPrint('ML Kit is unavailable. Falling back to other translators: $error');
      _zhToViTranslator?.close();
      _viToZhTranslator?.close();
      _zhToViTranslator = null;
      _viToZhTranslator = null;
    }
  }

  static Future<void> _downloadModels() async {
    final modelManager = OnDeviceTranslatorModelManager();

    try {
      final zhViDownloaded = await modelManager.isModelDownloaded(
        TranslateLanguage.vietnamese.bcpCode,
      );
      if (!zhViDownloaded) {
        await modelManager.downloadModel(
          TranslateLanguage.vietnamese.bcpCode,
          isWifiRequired: false,
        );
      }
      _zhViModelReady = true;
    } catch (error) {
      debugPrint('Vietnamese model download failed: $error');
    }

    try {
      final viZhDownloaded = await modelManager.isModelDownloaded(
        TranslateLanguage.chinese.bcpCode,
      );
      if (!viZhDownloaded) {
        await modelManager.downloadModel(
          TranslateLanguage.chinese.bcpCode,
          isWifiRequired: false,
        );
      }
      _viZhModelReady = true;
    } catch (error) {
      debugPrint('Chinese model download failed: $error');
    }
  }

  static Future<String?> zhToVi(String text) async {
    if (!_isAvailable || _zhToViTranslator == null) return null;
    try {
      return await _zhToViTranslator!.translateText(text);
    } catch (error) {
      debugPrint('ML Kit zh->vi translation failed: $error');
      return null;
    }
  }

  static Future<String?> viToZh(String text) async {
    if (!_isAvailable || _viToZhTranslator == null) return null;
    try {
      return await _viToZhTranslator!.translateText(text);
    } catch (error) {
      debugPrint('ML Kit vi->zh translation failed: $error');
      return null;
    }
  }

  static Future<MlKitStatus> getStatus() async {
    if (!_isAvailable) {
      return MlKitStatus(
        available: false,
        message: 'ML Kit is unavailable on this device.',
      );
    }

    final manager = OnDeviceTranslatorModelManager();
    final viReady = await manager.isModelDownloaded(
      TranslateLanguage.vietnamese.bcpCode,
    );
    final zhReady = await manager.isModelDownloaded(
      TranslateLanguage.chinese.bcpCode,
    );

    if (viReady && zhReady) {
      return MlKitStatus(
        available: true,
        modelsDownloaded: true,
        message: 'ML Kit offline models are ready.',
      );
    }

    return MlKitStatus(
      available: true,
      modelsDownloaded: false,
      message: 'ML Kit models are downloading in the background.',
    );
  }

  static Future<void> forceDownloadModels() async {
    if (!_isAvailable) return;
    await _downloadModels();
  }

  static void dispose() {
    _zhToViTranslator?.close();
    _viToZhTranslator?.close();
  }
}

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
