import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppLaunchAction {
  static const String openTranslate = 'open_translate';
  static const String openConversation = 'open_conversation';
  static const String openLearn = 'open_learn';
  static const String openKeyboard = 'open_keyboard';
  static const String pasteTranslate = 'paste_translate';
  static const String voiceTranslate = 'voice_translate';
  static const String sharedText = 'shared_text';
}

class AppLaunchRequest {
  final String action;
  final String? text;
  final int requestId;

  const AppLaunchRequest({
    required this.action,
    required this.requestId,
    this.text,
  });

  factory AppLaunchRequest.fromMap(Map<Object?, Object?> map) {
    return AppLaunchRequest(
      action: map['action']?.toString() ?? AppLaunchAction.openTranslate,
      text: map['text']?.toString(),
      requestId:
          int.tryParse(map['requestId']?.toString() ?? '') ??
          DateTime.now().microsecondsSinceEpoch,
    );
  }
}

class AppActionService {
  static const MethodChannel _channel = MethodChannel('fanyitong/app_actions');
  static const Duration _nativeTimeout = Duration(seconds: 2);

  static final ValueNotifier<AppLaunchRequest?> pendingRequest =
      ValueNotifier<AppLaunchRequest?>(null);

  static Future<void> init() async {
    try {
      _channel.setMethodCallHandler((call) async {
        try {
          if (call.method == 'launchAction') {
            final request = _decodeRequest(call.arguments);
            if (request != null) {
              pendingRequest.value = request;
            }
            return true;
          }
        } catch (error) {
          debugPrint('Native launch action was ignored: $error');
        }
        return null;
      });

      final initial = await _channel
          .invokeMapMethod<String, dynamic>('consumePendingAction')
          .timeout(_nativeTimeout, onTimeout: () => null);
      final request = _decodeRequest(initial);
      if (request != null) {
        pendingRequest.value = request;
      }
    } catch (error) {
      // Native launch actions are optional. The app still works without them.
      debugPrint('Native launch actions are unavailable: $error');
    }
  }

  static void clearPending() {
    pendingRequest.value = null;
  }

  static AppLaunchRequest? _decodeRequest(Object? arguments) {
    final map = arguments is Map ? arguments : null;
    if (map == null) return null;
    return AppLaunchRequest.fromMap(map.cast<Object?, Object?>());
  }
}
