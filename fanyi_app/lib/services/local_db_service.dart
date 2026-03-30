import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDbService {
  static Database? _dictionaryDb;
  static Database? _appDb;
  static String? _dictionaryDbPath;
  static String? _appDbPath;

  static const int maxTranslationHistory = 200;

  static Future<Database> get _dictionaryDatabase async {
    if (_dictionaryDb != null) return _dictionaryDb!;
    _dictionaryDb = await _initDictionaryDatabase();
    return _dictionaryDb!;
  }

  static Future<Database> get _appDatabase async {
    if (_appDb != null) return _appDb!;
    _appDb = await _initAppDatabase();
    return _appDb!;
  }

  static Future<Database> _initDictionaryDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'dictionary_v2.db');
    _dictionaryDbPath = dbPath;

    if (!await File(dbPath).exists()) {
      final ByteData data = await rootBundle.load('assets/dictionary.db');
      await File(dbPath).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return openDatabase(dbPath, readOnly: true);
  }

  static Future<Database> _initAppDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'fanyi_tong_app.db');
    _appDbPath = dbPath;

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE translation_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at INTEGER NOT NULL,
            original TEXT NOT NULL,
            translated TEXT NOT NULL,
            normalized TEXT,
            source TEXT NOT NULL,
            direction TEXT,
            han_zi TEXT,
            explanation TEXT,
            is_slang INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_translation_history_created_at '
          'ON translation_history(created_at DESC)',
        );
      },
    );
  }

  static Future<String> normalizeText(String text) async {
    final db = await _dictionaryDatabase;
    final rules = await db.query('normalization');

    final words = text.split(' ');
    final normalized = words.map((word) {
      final clean = word
          .toLowerCase()
          .replaceAll(RegExp(r'[.,!?。，！？]$'), '');
      final match = rules.firstWhere(
        (r) => r['shortcut'] == clean,
        orElse: () => <String, Object?>{},
      );
      return match.isNotEmpty ? (match['formal'] as String) : word;
    }).toList();

    return normalized.join(' ');
  }

  static Future<OfflineResult> translate(String text) async {
    final db = await _dictionaryDatabase;
    final normalized = await normalizeText(text);
    final query = normalized.trim().toLowerCase();

    var rows = await db.rawQuery(
      'SELECT meaning, han_zi FROM dictionary WHERE LOWER(word) = ?',
      [query],
    );

    if (rows.isNotEmpty) {
      return OfflineResult(
        found: true,
        translated: rows.first['meaning'] as String,
        hanZi: rows.first['han_zi'] as String?,
        normalized: normalized != text ? normalized : null,
        isSlang: false,
      );
    }

    rows = await db.rawQuery(
      'SELECT meaning, explanation FROM slang WHERE LOWER(word) = ?',
      [query],
    );

    if (rows.isNotEmpty) {
      return OfflineResult(
        found: true,
        translated: rows.first['meaning'] as String,
        explanation: rows.first['explanation'] as String?,
        normalized: normalized != text ? normalized : null,
        isSlang: true,
      );
    }

    return OfflineResult(found: false, translated: '');
  }

  static Future<List<Map<String, dynamic>>> search(String q) async {
    final db = await _dictionaryDatabase;
    final pattern = '%${q.trim()}%';

    final dict = await db.rawQuery('''
      SELECT word, han_viet, han_zi, meaning, examples
      FROM dictionary
      WHERE word LIKE ? OR meaning LIKE ? OR han_viet LIKE ? OR han_zi LIKE ?
      LIMIT 20
    ''', [pattern, pattern, pattern, pattern]);

    final slang = await db.rawQuery('''
      SELECT word, meaning, explanation, example
      FROM slang
      WHERE word LIKE ? OR meaning LIKE ? OR explanation LIKE ?
      LIMIT 10
    ''', [pattern, pattern, pattern]);

    return [
      ...dict.map((r) => {...r, 'type': 'dict'}),
      ...slang.map((r) => {...r, 'type': 'slang'}),
    ];
  }

  static Future<List<Map<String, dynamic>>> getAllSlang() async {
    return getSlangPage(limit: maxTranslationHistory, offset: 0);
  }

  static Future<List<Map<String, dynamic>>> getSlangPage({
    required int limit,
    required int offset,
  }) async {
    final db = await _dictionaryDatabase;
    return db.query(
      'slang',
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
  }

  static Future<int> getSlangCount() async {
    final db = await _dictionaryDatabase;
    final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM slang');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  static Future<void> recordTranslation({
    required String original,
    required String translated,
    required String source,
    String? direction,
    String? normalized,
    String? hanZi,
    String? explanation,
    bool isSlang = false,
  }) async {
    final db = await _appDatabase;
    await db.insert('translation_history', {
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'original': original,
      'translated': translated,
      'normalized': normalized,
      'source': source,
      'direction': direction,
      'han_zi': hanZi,
      'explanation': explanation,
      'is_slang': isSlang ? 1 : 0,
    });
    await pruneTranslationHistory();
  }

  static Future<List<Map<String, dynamic>>> getRecentTranslations({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _appDatabase;
    return db.query(
      'translation_history',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
  }

  static Future<int> getTranslationHistoryCount() async {
    final db = await _appDatabase;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM translation_history',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  static Future<void> pruneTranslationHistory({
    int maxEntries = maxTranslationHistory,
  }) async {
    final db = await _appDatabase;
    final count = await getTranslationHistoryCount();
    if (count <= maxEntries) return;

    final deleteCount = count - maxEntries;
    await db.rawDelete(
      '''
      DELETE FROM translation_history
      WHERE id IN (
        SELECT id FROM translation_history
        ORDER BY created_at ASC, id ASC
        LIMIT ?
      )
      ''',
      [deleteCount],
    );
  }

  static Future<void> clearTranslationHistory() async {
    final db = await _appDatabase;
    await db.delete('translation_history');
    await db.execute('VACUUM');
  }

  static Future<AppStorageStats> getStorageStats() async {
    final historyCount = await getTranslationHistoryCount();
    final dictionaryBytes = await _fileSize(_dictionaryDbPath);
    final appBytes = await _fileSize(_appDbPath);

    return AppStorageStats(
      historyCount: historyCount,
      maxHistory: maxTranslationHistory,
      dictionaryBytes: dictionaryBytes,
      appDbBytes: appBytes,
    );
  }

  static Future<int> _fileSize(String? path) async {
    if (path == null) return 0;
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.length();
  }
}

class OfflineResult {
  final bool found;
  final String translated;
  final String? hanZi;
  final String? explanation;
  final String? normalized;
  final bool isSlang;

  OfflineResult({
    required this.found,
    required this.translated,
    this.hanZi,
    this.explanation,
    this.normalized,
    this.isSlang = false,
  });
}

class AppStorageStats {
  final int historyCount;
  final int maxHistory;
  final int dictionaryBytes;
  final int appDbBytes;

  const AppStorageStats({
    required this.historyCount,
    required this.maxHistory,
    required this.dictionaryBytes,
    required this.appDbBytes,
  });
}
