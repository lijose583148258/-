import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  static SpeechToText? _speech;
  static Future<bool>? _initializing;
  static bool _available = false;
  static bool _initialized = false;

  static const Duration _permissionStatusTimeout = Duration(seconds: 3);
  static const Duration _permissionRequestTimeout = Duration(seconds: 3);
  static const Duration _platformTimeout = Duration(seconds: 3);
  static const Duration _stopTimeout = Duration(seconds: 2);

  static Future<bool> initialize({
    bool requestPermission = false,
    bool forceRetry = false,
  }) {
    if (_initializing != null) return _initializing!;
    if (_initialized && _available && !forceRetry) {
      return Future<bool>.value(_available);
    }
    if (forceRetry) {
      _initialized = false;
      _available = false;
      _speech = null;
    }
    return _initializing ??= _initializeSafely(
      requestPermission: requestPermission,
    );
  }

  static Future<bool> refreshAvailability() async {
    try {
      final status = await Permission.microphone.status.timeout(
        _permissionStatusTimeout,
        onTimeout: () => PermissionStatus.denied,
      );
      if (!status.isGranted) {
        _available = false;
        return false;
      }
      return await initialize(requestPermission: false, forceRetry: !_available);
    } catch (error) {
      debugPrint('Microphone permission status is unavailable: $error');
      _available = false;
      return false;
    }
  }

  static Future<bool> _initializeSafely({
    required bool requestPermission,
  }) async {
    try {
      final status = requestPermission
          ? await Permission.microphone.request().timeout(
              _permissionRequestTimeout,
              onTimeout: () => PermissionStatus.denied,
            )
          : await Permission.microphone.status.timeout(
              _permissionStatusTimeout,
              onTimeout: () => PermissionStatus.denied,
            );
      if (!status.isGranted) {
        debugPrint('Microphone permission was denied.');
        _available = false;
        return false;
      }

      final speech = _speech ??= SpeechToText();
      _available = await speech
          .initialize(
            onError: (error) => debugPrint('STT error: ${error.errorMsg}'),
            onStatus: (status) => debugPrint('STT status: $status'),
            options: [
              SpeechToText.androidNoBluetooth,
              SpeechToText.androidIntentLookup,
            ],
          )
          .timeout(_platformTimeout, onTimeout: () => false);
      return _available;
    } catch (error, stack) {
      _available = false;
      debugPrint('Speech recognition is unavailable: $error\n$stack');
      return false;
    } finally {
      _initialized = true;
      _initializing = null;
    }
  }

  static Future<String> resolveLocaleId(String requestedLocale) async {
    try {
      final locales = await getSupportedLocales();
      if (locales.isEmpty) return requestedLocale;
      final normalizedReq = requestedLocale.toLowerCase().replaceAll('_', '-');
      for (final loc in locales) {
        if (loc.toLowerCase().replaceAll('_', '-') == normalizedReq) {
          return loc;
        }
      }
      final prefix = normalizedReq.split('-').first;
      for (final loc in locales) {
        if (loc.toLowerCase().startsWith(prefix)) {
          return loc;
        }
      }
    } catch (_) {}
    return requestedLocale;
  }

  static Future<bool> startListening({
    required String localeId,
    required ValueChanged<String> onResult,
    VoidCallback? onDone,
    ValueChanged<String>? onError,
  }) async {
    try {
      if (!_initialized && !await initialize(requestPermission: true)) return false;
      final speech = _speech;
      if (!_available || speech == null) return false;

      if (speech.isListening) {
        await speech.stop().timeout(_stopTimeout, onTimeout: () {});
      }

      final actualLocaleId = await resolveLocaleId(localeId);

      bool doneTriggered = false;
      void triggerDone() {
        if (!doneTriggered) {
          doneTriggered = true;
          onDone?.call();
        }
      }

      speech.statusListener = (status) {
        debugPrint('STT status listener: $status');
        if (status == 'done' || status == 'notListening') {
          triggerDone();
        }
      };

      speech.errorListener = (errorNotification) {
        debugPrint('STT error listener: ${errorNotification.errorMsg}');
        onError?.call(errorNotification.errorMsg);
      };

      await speech
          .listen(
            onResult: (SpeechRecognitionResult result) {
              onResult(result.recognizedWords);
              if (result.finalResult) {
                triggerDone();
              }
            },
            listenOptions: SpeechListenOptions(
              partialResults: true,
              cancelOnError: true,
              listenMode: ListenMode.dictation,
              localeId: actualLocaleId,
              listenFor: const Duration(seconds: 30),
              pauseFor: const Duration(seconds: 4),
            ),
          )
          .timeout(_platformTimeout, onTimeout: () {});
      return true;
    } catch (error, stack) {
      debugPrint('Speech recognition could not start: $error\n$stack');
      onError?.call(error.toString());
      return false;
    }
  }

  static Future<void> stopListening() async {
    try {
      final speech = _speech;
      if (speech != null && speech.isListening) {
        await speech.stop().timeout(_stopTimeout, onTimeout: () {});
      }
    } catch (error) {
      debugPrint('Speech recognition could not stop: $error');
    }
  }

  static Future<void> cancelListening() async {
    try {
      final speech = _speech;
      if (speech != null && speech.isListening) {
        await speech.cancel().timeout(_stopTimeout, onTimeout: () {});
      }
    } catch (error) {
      debugPrint('Speech recognition could not be cancelled: $error');
    }
  }

  static bool get isListening {
    try {
      return _speech?.isListening ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool get isAvailable => _available;

  static Future<List<String>> getSupportedLocales() async {
    try {
      final speech = _speech;
      if (!_available || speech == null) return const [];
      final locales = await speech.locales().timeout(_platformTimeout, onTimeout: () => []);
      return locales.map((locale) => locale.localeId).toList();
    } catch (error) {
      debugPrint('Speech locale discovery failed: $error');
      return const [];
    }
  }

  static Future<bool> isVietnameseSpeechSupported() async {
    final locales = await getSupportedLocales();
    return locales.any((locale) => locale.toLowerCase().startsWith('vi'));
  }

  static Future<bool> isChineseSpeechSupported() async {
    final locales = await getSupportedLocales();
    return locales.any((locale) => locale.toLowerCase().startsWith('zh'));
  }
}
