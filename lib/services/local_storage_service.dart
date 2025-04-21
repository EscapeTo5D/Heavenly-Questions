import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nasa_apod.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  static Database? _database;
  static const String _dbName = 'nasa_apods.db';
  static const String _tableName = 'apods';
  static const String _prefsCurrentDate = 'current_date';
  static const String _prefsScrollPosition = 'scroll_position';
  static const String _prefsInitialized = 'initialized';
  static const String _prefsCachedApods = 'cached_apods_keys';

  factory LocalStorageService() {
    return _instance;
  }

  LocalStorageService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            date TEXT PRIMARY KEY,
            title TEXT,
            explanation TEXT,
            url TEXT,
            hdurl TEXT,
            media_type TEXT,
            copyright TEXT,
            translated_title TEXT,
            translated_explanation TEXT,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  // 保存NASA APOD数据到数据库
  Future<void> saveApod(NasaApod apod) async {
    final db = await database;
    await db.insert(
      _tableName,
      {
        'date': apod.date,
        'title': apod.title,
        'explanation': apod.explanation,
        'url': apod.url,
        'hdurl': apod.hdurl ?? '',
        'media_type': apod.mediaType,
        'copyright': apod.copyright ?? '',
        'translated_title': apod.translatedTitle ?? '',
        'translated_explanation': apod.translatedExplanation ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 更新缓存的APOD日期键列表
    await _updateCachedApodKeys(apod.date);
  }

  // 更新缓存的APOD日期键列表
  Future<void> _updateCachedApodKeys(String newDate) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedKeys = prefs.getStringList(_prefsCachedApods) ?? [];

    if (!cachedKeys.contains(newDate)) {
      cachedKeys.add(newDate);
      await prefs.setStringList(_prefsCachedApods, cachedKeys);
    }
  }

  // 批量保存NASA APOD数据
  Future<void> saveApods(List<NasaApod> apods) async {
    final db = await database;
    final batch = db.batch();

    for (final apod in apods) {
      batch.insert(
        _tableName,
        {
          'date': apod.date,
          'title': apod.title,
          'explanation': apod.explanation,
          'url': apod.url,
          'hdurl': apod.hdurl ?? '',
          'media_type': apod.mediaType,
          'copyright': apod.copyright ?? '',
          'translated_title': apod.translatedTitle ?? '',
          'translated_explanation': apod.translatedExplanation ?? '',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _updateCachedApodKeys(apod.date);
    }

    await batch.commit();
  }

  // 获取所有保存的NASA APOD数据
  Future<List<NasaApod>> getAllApods() async {
    final db = await database;

    // 按日期降序排列，最新日期在前
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) {
      return NasaApod(
        date: maps[i]['date'],
        title: maps[i]['title'],
        explanation: maps[i]['explanation'],
        url: maps[i]['url'],
        hdurl: maps[i]['hdurl'].isEmpty ? null : maps[i]['hdurl'],
        mediaType: maps[i]['media_type'],
        copyright: maps[i]['copyright'].isEmpty ? null : maps[i]['copyright'],
        translatedTitle: maps[i]['translated_title'],
        translatedExplanation: maps[i]['translated_explanation'],
      );
    });
  }

  // 获取指定日期的APOD
  Future<NasaApod?> getApodByDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'date = ?',
      whereArgs: [date],
    );

    if (maps.isEmpty) {
      return null;
    }

    return NasaApod(
      date: maps[0]['date'],
      title: maps[0]['title'],
      explanation: maps[0]['explanation'],
      url: maps[0]['url'],
      hdurl: maps[0]['hdurl'].isEmpty ? null : maps[0]['hdurl'],
      mediaType: maps[0]['media_type'],
      copyright: maps[0]['copyright'].isEmpty ? null : maps[0]['copyright'],
      translatedTitle: maps[0]['translated_title'],
      translatedExplanation: maps[0]['translated_explanation'],
    );
  }

  // 检查APOD是否已缓存
  Future<bool> isApodCached(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'date = ?',
      whereArgs: [date],
    );
    return maps.isNotEmpty;
  }

  // 获取已缓存APOD的日期列表
  Future<List<String>> getCachedApodDates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsCachedApods) ?? [];
  }

  // 保存当前日期
  Future<void> saveCurrentDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCurrentDate, date.toIso8601String());
  }

  // 获取保存的当前日期
  Future<DateTime?> getSavedCurrentDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_prefsCurrentDate);
    return dateStr != null ? DateTime.parse(dateStr) : null;
  }

  // 保存滚动位置
  Future<void> saveScrollPosition(double position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsScrollPosition, position);
  }

  // 获取保存的滚动位置
  Future<double> getSavedScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_prefsScrollPosition) ?? 0.0;
  }

  // 设置初始化标志
  Future<void> setInitialized(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsInitialized, value);
  }

  // 获取初始化标志
  Future<bool> getInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsInitialized) ?? false;
  }

  // 清除所有缓存数据
  Future<void> clearAllCache() async {
    final db = await database;
    await db.delete(_tableName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
