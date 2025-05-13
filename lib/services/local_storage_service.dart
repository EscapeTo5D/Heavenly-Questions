import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nasa_apod.dart';
import '../models/quiz_question.dart';

/// 本地存储服务，用于缓存题库数据
class LocalStorageService {
  // 单例模式
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // 缓存键
  static const String _questionsKey = 'cached_questions';
  static const String _categoriesKey = 'cached_categories';
  static const String _cacheTimestampKey = 'cache_timestamp'; // 缓存时间戳

  SharedPreferences? _prefs;

  /// 初始化本地存储
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    print('本地存储服务初始化完成');
  }

  // Make prefs accessible to QuizService for _lastOnlineAttemptKey
  SharedPreferences? get prefs => _prefs;

  /// 检查是否有缓存的题库数据
  bool hasQuestionsCache() {
    return _prefs?.containsKey(_questionsKey) == true &&
        _prefs?.containsKey(_categoriesKey) == true;
  }

  /// 获取缓存的上次更新时间戳
  DateTime? getCacheTimestamp() {
    final timestamp = _prefs?.getInt(_cacheTimestampKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// 缓存问题列表到本地存储
  Future<bool> cacheQuestions(List<QuizQuestion> questions) async {
    if (_prefs == null) {
      await init();
    }

    try {
      // 将问题列表转换为JSON字符串
      final questionsJson =
          jsonEncode(questions.map((question) => question.toMap()).toList());

      // 保存到本地存储
      final result = await _prefs!.setString(_questionsKey, questionsJson);

      // 更新缓存时间戳
      await _prefs!
          .setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);

      print('成功缓存 ${questions.length} 个问题到本地存储');
      return result;
    } catch (e) {
      print('缓存问题到本地存储失败: $e');
      return false;
    }
  }

  /// 缓存分类列表到本地存储
  Future<bool> cacheCategories(List<QuizCategory> categories) async {
    if (_prefs == null) {
      await init();
    }

    try {
      // 将分类列表转换为JSON字符串
      final categoriesJson =
          jsonEncode(categories.map((category) => category.toMap()).toList());

      // 保存到本地存储
      final result = await _prefs!.setString(_categoriesKey, categoriesJson);

      print('成功缓存 ${categories.length} 个分类到本地存储');
      return result;
    } catch (e) {
      print('缓存分类到本地存储失败: $e');
      return false;
    }
  }

  /// 从本地存储获取缓存的问题列表
  Future<List<QuizQuestion>> getCachedQuestions() async {
    if (_prefs == null) {
      await init();
    }

    try {
      final questionsJson = _prefs?.getString(_questionsKey);
      if (questionsJson == null || questionsJson.isEmpty) {
        return [];
      }

      final questionsList = jsonDecode(questionsJson) as List;
      return questionsList.map((json) => QuizQuestion.fromMap(json)).toList();
    } catch (e) {
      print('从本地存储获取缓存的问题失败: $e');
      return [];
    }
  }

  /// 从本地存储获取缓存的分类列表
  Future<List<QuizCategory>> getCachedCategories() async {
    if (_prefs == null) {
      await init();
    }

    try {
      final categoriesJson = _prefs?.getString(_categoriesKey);
      if (categoriesJson == null || categoriesJson.isEmpty) {
        return [];
      }

      final categoriesList = jsonDecode(categoriesJson) as List;
      return categoriesList.map((json) => QuizCategory.fromMap(json)).toList();
    } catch (e) {
      print('从本地存储获取缓存的分类失败: $e');
      return [];
    }
  }

  /// 清除所有缓存
  Future<bool> clearCache() async {
    if (_prefs == null) {
      await init();
    }

    try {
      await _prefs!.remove(_questionsKey);
      await _prefs!.remove(_categoriesKey);
      await _prefs!.remove(_cacheTimestampKey);
      print('成功清除本地缓存');
      return true;
    } catch (e) {
      print('清除本地缓存失败: $e');
      return false;
    }
  }

  static Database? _database;
  static const String _dbName = 'nasa_apods.db';
  static const String _tableName = 'apods';
  static const String _prefsCurrentDate = 'current_date';
  static const String _prefsScrollPosition = 'scroll_position';
  static const String _prefsInitialized = 'initialized';
  static const String _prefsCachedApods = 'cached_apods_keys';

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

  /// 创建默认缓存（当无法连接到MongoDB且没有现有缓存时使用）
  Future<bool> createDefaultCache() async {
    if (_prefs == null) {
      await init();
    }

    try {
      // 创建默认分类
      final defaultCategories = [
        QuizCategory(
          name: '天文基础',
          description: '基础天文学知识和概念',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        QuizCategory(
          name: '太阳系',
          description: '关于太阳系的行星和天体',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // 创建默认题目
      final defaultQuestions = [
        QuizQuestion(
          questionText: '太阳系中最大的行星是哪一个？',
          options: ['木星', '土星', '天王星', '海王星'],
          correctOptionIndex: 0,
          explanation: '木星是太阳系中最大的行星，其质量是地球的318倍。',
          categoryName: '太阳系',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        QuizQuestion(
          questionText: '下列哪项不是太阳系的八大行星之一？',
          options: ['水星', '金星', '冥王星', '海王星'],
          correctOptionIndex: 2,
          explanation: '冥王星在2006年被重新归类为矮行星，不再是八大行星之一。',
          categoryName: '太阳系',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        QuizQuestion(
          questionText: '哪个行星被称为"红色星球"？',
          options: ['金星', '火星', '木星', '土星'],
          correctOptionIndex: 1,
          explanation: '火星因表面富含氧化铁而呈现红色，故被称为"红色星球"。',
          categoryName: '太阳系',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        QuizQuestion(
          questionText: '天文学中，天体绕太阳公转一周的时间被称为什么？',
          options: ['公转周期', '自转周期', '轨道周期', '恒星年'],
          correctOptionIndex: 0,
          explanation: '公转周期是指天体围绕太阳运行一周所需的时间。',
          categoryName: '天文基础',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        QuizQuestion(
          questionText: '下列哪项不是观测宇宙的工具？',
          options: ['光学望远镜', '射电望远镜', '引力波探测器', '质谱仪'],
          correctOptionIndex: 3,
          explanation: '质谱仪主要用于分析物质的化学成分，而非直接观测宇宙。',
          categoryName: '天文基础',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      // 缓存默认数据
      await cacheCategories(defaultCategories);
      await cacheQuestions(defaultQuestions);

      print('成功创建默认缓存数据');
      return true;
    } catch (e) {
      print('创建默认缓存数据失败: $e');
      return false;
    }
  }
}
