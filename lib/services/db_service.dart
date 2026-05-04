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
      version: 1,
      onCreate: _onCreate,
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

  static Future<List<Word>> getWordsByUnit(int unitId) async {
    final d = await db;
    final rows = await d.query('words',
        where: 'unit_id = ?', whereArgs: [unitId], orderBy: 'id');
    return rows.map((r) => Word.fromMap(r)).toList();
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

  // ── seed ────────────────────────────────────────────────────

  static Future<bool> needsSeed() async {
    final d = await db;
    final count = Sqflite.firstIntValue(
        await d.rawQuery('SELECT COUNT(*) FROM grades'));
    return (count ?? 0) == 0;
  }
}
