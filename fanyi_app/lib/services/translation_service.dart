import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_db_service.dart';
import 'mlkit_service.dart';

class TranslationService {
  static const String zhToVi = 'zh->vi';
  static const String viToZh = 'vi->zh';

  static void warmUp() {
    unawaited(MlKitService.initialize());
  }

  static String detectLanguage(String text) {
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(text)) return 'zh';
    if (RegExp(r'[a-zA-Z]').hasMatch(text)) return 'vi';
    return 'vi';
  }

  static Future<TranslationResult> translate(
    String text, {
    String? direction,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return TranslationResult(translated: '', source: TranslationSource.empty);
    }

    final lang = detectLanguage(trimmed);
    final resolvedDirection = direction ?? (lang == 'zh' ? zhToVi : viToZh);

    if (resolvedDirection == viToZh) {
      final offline = await LocalDbService.translate(trimmed);
      if (offline.found) {
        return TranslationResult(
          original: trimmed,
          translated: offline.translated,
          normalized: offline.normalized,
          hanZi: offline.hanZi,
          explanation: offline.explanation,
          isSlang: offline.isSlang,
          direction: resolvedDirection,
          source: TranslationSource.localDb,
        );
      }
    }

    if (MlKitService.isAvailable) {
      final mlResult = resolvedDirection == zhToVi
          ? await MlKitService.zhToVi(trimmed)
          : await MlKitService.viToZh(trimmed);
      if (mlResult != null && mlResult.isNotEmpty) {
        return TranslationResult(
          original: trimmed,
          translated: mlResult,
          direction: resolvedDirection,
          source: TranslationSource.mlKit,
        );
      }
    }

    try {
      final online = await _callMyMemory(trimmed, resolvedDirection);
      return TranslationResult(
        original: trimmed,
        translated: online,
        direction: resolvedDirection,
        source: TranslationSource.myMemory,
      );
    } catch (_) {
      return TranslationResult(
        original: trimmed,
        translated: trimmed,
        direction: resolvedDirection,
        source: TranslationSource.noResult,
      );
    }
  }

  static Future<String> _callMyMemory(String text, String direction) async {
    final langPair = direction == zhToVi ? 'zh-CN|vi' : 'vi|zh-CN';
    final uri = Uri.parse(
      'https://api.mymemory.translated.net/get'
      '?q=${Uri.encodeQueryComponent(text)}'
      '&langpair=$langPair',
    );

    final response = await http
        .get(uri, headers: {'User-Agent': 'FanyiTong/1.0'})
        .timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final translated = data['responseData']?['translatedText'] as String?;
      if (translated != null && translated.isNotEmpty) {
        return translated;
      }
    }

    throw Exception('MyMemory returned an invalid translation result.');
  }
}

enum TranslationSource {
  localDb,
  mlKit,
  myMemory,
  noResult,
  empty,
}

class TranslationResult {
  final String? original;
  final String translated;
  final String? normalized;
  final String? hanZi;
  final String? explanation;
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

  String get sourceLabel {
    switch (source) {
      case TranslationSource.localDb:
        return isSlang ? 'Local slang library' : 'Local dictionary';
      case TranslationSource.mlKit:
        return 'ML Kit offline model';
      case TranslationSource.myMemory:
        return 'MyMemory online';
      case TranslationSource.noResult:
        return 'No translation available';
      case TranslationSource.empty:
        return '';
    }
  }

  int get sourceLabelColor {
    switch (source) {
      case TranslationSource.localDb:
        return 0xFF677D6A;
      case TranslationSource.mlKit:
        return 0xFF1565C0;
      case TranslationSource.myMemory:
        return 0xFF0277BD;
      case TranslationSource.noResult:
        return 0xFFE65100;
      case TranslationSource.empty:
        return 0xFF9E9E9E;
    }
  }

  bool get hasResult =>
      source != TranslationSource.empty && source != TranslationSource.noResult;

  bool get isOffline =>
      source == TranslationSource.localDb || source == TranslationSource.mlKit;

  bool get isOnline => source == TranslationSource.myMemory;

  bool get isMlKit => source == TranslationSource.mlKit;
}
