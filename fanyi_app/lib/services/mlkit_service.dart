import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class MlKitService {
  static OnDeviceTranslator? _zhToViTranslator;
  static OnDeviceTranslator? _viToZhTranslator;
  static Future<void>? _initializing;
  static Future<void>? _downloading;

  static bool _isAvailable = false;
  static bool _initialized = false;
  static bool _zhViModelReady = false;
  static bool _viZhModelReady = false;

  static bool get isAvailable => _isAvailable;
  static bool get isDownloading => _downloading != null;

  /// Initializes ML Kit only after a user requests translation or model setup.
  static Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initializeSafely();
  }

  static Future<void> _initializeSafely() async {
    try {
      _zhToViTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.chinese,
        targetLanguage: TranslateLanguage.vietnamese,
      );
      _viToZhTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.vietnamese,
        targetLanguage: TranslateLanguage.chinese,
      );

      final manager = OnDeviceTranslatorModelManager();
      _zhViModelReady = await manager.isModelDownloaded(
        TranslateLanguage.vietnamese.bcpCode,
      );
      _viZhModelReady = await manager.isModelDownloaded(
        TranslateLanguage.chinese.bcpCode,
      );
      _isAvailable = true;
      debugPrint('ML Kit is available on this device.');

      if (!_zhViModelReady || !_viZhModelReady) {
        unawaited(_downloadModels());
      }
    } catch (error, stack) {
      _isAvailable = false;
      await _closeTranslators();
      debugPrint(
        'ML Kit is unavailable. Falling back to other translators: '
        '$error\n$stack',
      );
    } finally {
      _initialized = true;
      _initializing = null;
    }
  }

  static Future<void> _downloadModels() {
    return _downloading ??= _downloadModelsSafely();
  }

  static Future<void> _downloadModelsSafely() async {
    try {
      final modelManager = OnDeviceTranslatorModelManager();

      try {
        if (!await modelManager.isModelDownloaded(
          TranslateLanguage.vietnamese.bcpCode,
        )) {
          await modelManager.downloadModel(
            TranslateLanguage.vietnamese.bcpCode,
            isWifiRequired: false,
          );
        }
        _zhViModelReady = true;
      } catch (error) {
        _zhViModelReady = false;
        debugPrint('Vietnamese model download failed: $error');
      }

      try {
        if (!await modelManager.isModelDownloaded(
          TranslateLanguage.chinese.bcpCode,
        )) {
          await modelManager.downloadModel(
            TranslateLanguage.chinese.bcpCode,
            isWifiRequired: false,
          );
        }
        _viZhModelReady = true;
      } catch (error) {
        _viZhModelReady = false;
        debugPrint('Chinese model download failed: $error');
      }
    } catch (error, stack) {
      debugPrint('ML Kit model manager is unavailable: $error\n$stack');
    } finally {
      _downloading = null;
    }
  }

  static Future<String?> zhToVi(String text) async {
    final translator = _zhToViTranslator;
    if (!_isAvailable || !_zhViModelReady || translator == null) return null;
    try {
      return await translator.translateText(text);
    } catch (error) {
      debugPrint('ML Kit zh->vi translation failed: $error');
      return null;
    }
  }

  static Future<String?> viToZh(String text) async {
    final translator = _viToZhTranslator;
    if (!_isAvailable || !_viZhModelReady || translator == null) return null;
    try {
      return await translator.translateText(text);
    } catch (error) {
      debugPrint('ML Kit vi->zh translation failed: $error');
      return null;
    }
  }

  static Future<MlKitStatus> getStatus() async {
    if (!_initialized || !_isAvailable) {
      return MlKitStatus(
        available: false,
        message: _initialized
            ? 'ML Kit is unavailable on this device.'
            : 'ML Kit has not been initialized.',
      );
    }

    try {
      final manager = OnDeviceTranslatorModelManager();
      final viReady = await manager.isModelDownloaded(
        TranslateLanguage.vietnamese.bcpCode,
      );
      final zhReady = await manager.isModelDownloaded(
        TranslateLanguage.chinese.bcpCode,
      );
      _zhViModelReady = viReady;
      _viZhModelReady = zhReady;

      return MlKitStatus(
        available: true,
        modelsDownloaded: viReady && zhReady,
        message: viReady && zhReady
            ? 'ML Kit offline models are ready.'
            : 'ML Kit models are not ready yet.',
      );
    } catch (error) {
      debugPrint('ML Kit status check failed: $error');
      return MlKitStatus(
        available: false,
        message: 'ML Kit status is unavailable.',
      );
    }
  }

  static Future<void> forceDownloadModels() async {
    await initialize();
    if (!_isAvailable) return;
    await _downloadModels();
  }

  static Future<void> clearDownloadedModels() async {
    await _closeTranslators();

    _isAvailable = false;
    _initialized = false;
    _zhViModelReady = false;
    _viZhModelReady = false;

    try {
      final modelManager = OnDeviceTranslatorModelManager();
      try {
        await modelManager.deleteModel(TranslateLanguage.vietnamese.bcpCode);
      } catch (error) {
        debugPrint('Failed to delete Vietnamese model: $error');
      }
      try {
        await modelManager.deleteModel(TranslateLanguage.chinese.bcpCode);
      } catch (error) {
        debugPrint('Failed to delete Chinese model: $error');
      }
    } catch (error) {
      debugPrint('ML Kit model cache could not be cleared: $error');
    }
  }

  static Future<void> _closeTranslators() async {
    final zhToVi = _zhToViTranslator;
    final viToZh = _viToZhTranslator;
    _zhToViTranslator = null;
    _viToZhTranslator = null;

    try {
      await zhToVi?.close();
    } catch (_) {}
    try {
      await viToZh?.close();
    } catch (_) {}
  }

  static Future<void> dispose() => _closeTranslators();
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
