import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 本地数据库服务
///
/// 工作原理：
///   1. APK 安装后首次启动，把 assets/dictionary.db（36KB）复制到手机私有存储
///   2. 此后所有查询都在手机本地执行，零网络消耗
///   3. 提供三大功能：翻译（translate）/ 全文搜索（search）/ 俚语列表（slang）
class LocalDbService {
  static Database? _db;

  /// 获取数据库实例（懒加载，只初始化一次）
  static Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    // 手机上的持久化存储目录（类似 /data/data/com.fanyitong.app/files/）
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'dictionary_v2.db');

    // 首次安装时，从 APK assets 复制词典文件
    if (!await File(dbPath).exists()) {
      final ByteData data = await rootBundle.load('assets/dictionary.db');
      await File(dbPath).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return openDatabase(dbPath, readOnly: true);
  }

  /// Teencode 规范化：把越南网络缩写还原成标准写法
  /// 例如 "k hiu" → "không hiểu"（不明白）
  static Future<String> normalizeText(String text) async {
    final db = await _database;
    final rules = await db.query('normalization');

    final words = text.split(' ');
    final normalized = words.map((word) {
      final clean = word.toLowerCase().replaceAll(RegExp(r'[.,!?。，！？]$'), '');
      final match = rules.firstWhere(
        (r) => r['shortcut'] == clean,
        orElse: () => <String, Object?>{},
      );
      return match.isNotEmpty ? (match['formal'] as String) : word;
    }).toList();

    return normalized.join(' ');
  }

  /// 离线翻译：先查词典，再查俚语，返回结果与来源
  static Future<OfflineResult> translate(String text) async {
    final db = await _database;
    final normalized = await normalizeText(text);
    final query = normalized.trim().toLowerCase();

    // 第一优先：精确匹配词典（COLLATE NOCASE = 忽略大小写）
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

    // 第二优先：精确匹配俚语
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

  /// 全文模糊搜索：支持按越南词、中文释义、汉越音同时检索
  static Future<List<Map<String, dynamic>>> search(String q) async {
    final db = await _database;
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

  /// 获取所有俚语（热门俚语页面使用）
  static Future<List<Map<String, dynamic>>> getAllSlang() async {
    final db = await _database;
    return db.query('slang', orderBy: 'id DESC');
  }
}

/// 离线查询结果的数据模型
class OfflineResult {
  final bool found;
  final String translated;
  final String? hanZi;       // 对应汉字（汉越词专属）
  final String? explanation; // 俚语解释
  final String? normalized;  // 规范化后的文本（Teencode 还原后）
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
