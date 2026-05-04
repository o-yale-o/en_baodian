import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import '../models/word.dart';

class DbService {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;

    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'en_baodian.db'),
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grade_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (grade_id) REFERENCES grades(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        unit_id INTEGER NOT NULL,
        word TEXT NOT NULL,
        pronunciation TEXT NOT NULL DEFAULT '',
        meaning TEXT NOT NULL DEFAULT '',
        sentence TEXT NOT NULL DEFAULT '',
        sentence_cn TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (unit_id) REFERENCES units(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE word_progress (
        word_id INTEGER PRIMARY KEY,
        is_passed INTEGER NOT NULL DEFAULT 0,
        is_hard INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (word_id) REFERENCES words(id)
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS word_progress (
          word_id INTEGER PRIMARY KEY,
          is_passed INTEGER NOT NULL DEFAULT 0,
          is_hard INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (word_id) REFERENCES words(id)
        )
      ''');
    }
  }

  // ── grades ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getGrades() async {
    final d = await db;
    return d.query('grades', orderBy: 'sort_order');
  }

  static Future<int> insertGrade(String name, int sortOrder) async {
    final d = await db;
    return d.insert('grades', {'name': name, 'sort_order': sortOrder});
  }

  // ── units ───────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getUnits(int gradeId) async {
    final d = await db;
    return d.query('units',
        where: 'grade_id = ?',
        whereArgs: [gradeId],
        orderBy: 'sort_order');
  }

  static Future<int> insertUnit(int gradeId, String name, int sortOrder) async {
    final d = await db;
    return d.insert(
        'units', {'grade_id': gradeId, 'name': name, 'sort_order': sortOrder});
  }

  // ── words ───────────────────────────────────────────────────

  static Future<List<Word>> getWordsByUnit(int unitId, {bool skipPassed = false}) async {
    final d = await db;
    if (skipPassed) {
      final rows = await d.rawQuery('''
        SELECT w.* FROM words w
        LEFT JOIN word_progress wp ON w.id = wp.word_id
        WHERE w.unit_id = ?
          AND (wp.is_passed IS NULL OR wp.is_passed = 0)
        ORDER BY w.id
      ''', [unitId]);
      return rows.map((r) => Word.fromMap(r)).toList();
    }
    final rows = await d.query('words',
        where: 'unit_id = ?', whereArgs: [unitId], orderBy: 'id');
    return rows.map((r) => Word.fromMap(r)).toList();
  }

  static Future<List<Word>> getHardWords() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT w.* FROM words w
      JOIN word_progress wp ON w.id = wp.word_id
      WHERE wp.is_hard = 1
      ORDER BY w.id
    ''');
    return rows.map((r) => Word.fromMap(r)).toList();
  }

  static Future<int> countHardWords() async {
    final d = await db;
    return Sqflite.firstIntValue(
        await d.rawQuery('SELECT COUNT(*) FROM word_progress WHERE is_hard = 1')) ?? 0;
  }

  static Future<int> insertWord(Word word) async {
    final d = await db;
    return d.insert('words', {
      'unit_id': word.unitId,
      'word': word.word,
      'pronunciation': word.pronunciation,
      'meaning': word.meaning,
      'sentence': word.sentence,
      'sentence_cn': word.sentenceCn,
    });
  }

  static Future<void> insertWords(List<Word> words) async {
    final d = await db;
    final batch = d.batch();
    for (final w in words) {
      batch.insert('words', {
        'unit_id': w.unitId,
        'word': w.word,
        'pronunciation': w.pronunciation,
        'meaning': w.meaning,
        'sentence': w.sentence,
        'sentence_cn': w.sentenceCn,
      });
    }
    await batch.commit(noResult: true);
  }

  // ── progress ────────────────────────────────────────────────

  static Future<bool> isPassed(int wordId) async {
    final d = await db;
    final rows = await d.query('word_progress',
        where: 'word_id = ? AND is_passed = 1',
        whereArgs: [wordId],
        limit: 1);
    return rows.isNotEmpty;
  }

  static Future<bool> isHard(int wordId) async {
    final d = await db;
    final rows = await d.query('word_progress',
        where: 'word_id = ? AND is_hard = 1',
        whereArgs: [wordId],
        limit: 1);
    return rows.isNotEmpty;
  }

  static Future<void> _ensureProgress(int wordId) async {
    final d = await db;
    await d.rawInsert(
      'INSERT OR IGNORE INTO word_progress (word_id, is_passed, is_hard) VALUES (?, 0, 0)',
      [wordId],
    );
  }

  static Future<void> setPassed(int wordId, bool v) async {
    final d = await db;
    await _ensureProgress(wordId);
    await d.update('word_progress', {'is_passed': v ? 1 : 0},
        where: 'word_id = ?', whereArgs: [wordId]);
  }

  static Future<void> setHard(int wordId, bool v) async {
    final d = await db;
    await _ensureProgress(wordId);
    await d.update('word_progress', {'is_hard': v ? 1 : 0},
        where: 'word_id = ?', whereArgs: [wordId]);
  }

  static Future<void> resetUnitPassed(int unitId) async {
    final d = await db;
    await d.rawUpdate('''
      UPDATE word_progress SET is_passed = 0
      WHERE word_id IN (SELECT id FROM words WHERE unit_id = ?)
    ''', [unitId]);
  }

  static Future<Map<int, int>> getWordCounts() async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT unit_id, COUNT(*) as cnt FROM words GROUP BY unit_id');
    return {for (final r in rows) r['unit_id'] as int: r['cnt'] as int};
  }

  static Future<Map<int, int>> getPassedCounts() async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT w.unit_id, COUNT(*) as cnt
      FROM words w JOIN word_progress wp ON w.id = wp.word_id
      WHERE wp.is_passed = 1
      GROUP BY w.unit_id
    ''');
    return {for (final r in rows) r['unit_id'] as int: r['cnt'] as int};
  }

  static Future<int> getGradeWordCount(int gradeId) async {
    final d = await db;
    return Sqflite.firstIntValue(await d.rawQuery(
      'SELECT COUNT(*) FROM words WHERE unit_id IN (SELECT id FROM units WHERE grade_id = ?)',
      [gradeId])) ?? 0;
  }

  static Future<int> getGradePassedCount(int gradeId) async {
    final d = await db;
    return Sqflite.firstIntValue(await d.rawQuery('''
      SELECT COUNT(*) FROM word_progress wp
      JOIN words w ON w.id = wp.word_id
      JOIN units u ON u.id = w.unit_id
      WHERE u.grade_id = ? AND wp.is_passed = 1
    ''', [gradeId])) ?? 0;
  }

  // ── seed ────────────────────────────────────────────────────

  static Future<bool> needsSeed() async {
    final d = await db;
    final count = Sqflite.firstIntValue(
        await d.rawQuery('SELECT COUNT(*) FROM grades'));
    return (count ?? 0) == 0;
  }
}
