import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';
import 'mongo_database_service.dart'; // 引入新的 MongoDB 服务
import 'local_storage_service.dart'; // 引入本地存储服务

class QuizService {
  // 单例模式
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  final MongoDatabaseService _mongoService =
      MongoDatabaseService(); // 新的 MongoDB 服务实例
  final LocalStorageService _localStorageService =
      LocalStorageService(); // 本地存储服务实例

  bool _isInitialized = false;
  bool _isOnlineMode = false; // Default to offline until online confirmed
  bool _isSyncing = false; // To prevent concurrent sync attempts

  // Notifier for UI updates when data state changes significantly
  final ValueNotifier<bool> onStateChange = ValueNotifier(false);

  // Constants for retry logic
  static const String _lastOnlineAttemptKey = 'last_online_attempt_timestamp';
  static const Duration _onlineRetryInterval =
      Duration(minutes: 1); // Retry online every 1 minute if offline

  // 初始化服务
  Future<void> initialize() async {
    if (_isInitialized &&
        !_isOnlineMode &&
        !(await _shouldAttemptOnlineNow())) {
      print(
          'QuizService: Already initialized in offline mode. Skipping online attempt for now.');
      return;
    }
    if (_isInitialized && _isOnlineMode) {
      print('QuizService: Already initialized in online mode.');
      return;
    }
    if (_isSyncing) {
      print('QuizService: Sync already in progress.');
      return;
    }

    _isSyncing = true;
    print('QuizService: Initializing...');
    await _localStorageService.init();

    bool hasCache = _localStorageService.hasQuestionsCache();

    if (hasCache) {
      print('QuizService: Cache found. Initializing with local data first.');
      _isInitialized = true;
      _isOnlineMode = false; // Assume offline initially
      onStateChange.value =
          !onStateChange.value; // Notify UI to load with cache

      // Attempt online sync in background if it's time
      if (await _shouldAttemptOnlineNow()) {
        _backgroundOnlineSync();
      } else {
        print('QuizService: Not time for background online sync yet.');
        _isSyncing = false;
      }
    } else {
      print(
          'QuizService: No cache found. Attempting online connection or default cache.');
      // This will try online, then default cache if online fails.
      await _attemptOnlineAndInitializeOrUseDefault();
    }
    // Note: _isSyncing is reset within the async methods like _backgroundOnlineSync or _attemptOnlineAndInitializeOrUseDefault
  }

  Future<bool> _shouldAttemptOnlineNow() async {
    final prefs = _localStorageService.prefs; // Use public getter
    if (prefs == null) {
      print(
          'QuizService: SharedPreferences not available in LocalStorageService for _shouldAttemptOnlineNow.');
      return true;
    }

    final lastAttemptMillis = prefs.getInt(_lastOnlineAttemptKey);
    if (lastAttemptMillis == null) {
      return true; // No record of last attempt
    }
    final lastAttemptTime =
        DateTime.fromMillisecondsSinceEpoch(lastAttemptMillis);
    final shouldAttempt =
        DateTime.now().difference(lastAttemptTime) > _onlineRetryInterval;
    if (shouldAttempt) print('QuizService: Time to attempt online connection.');
    return shouldAttempt;
  }

  Future<void> _recordOnlineAttempt() async {
    final prefs = _localStorageService.prefs; // Use public getter
    if (prefs == null) {
      print(
          'QuizService: SharedPreferences not available in LocalStorageService for _recordOnlineAttempt.');
      return;
    }
    await prefs.setInt(
        _lastOnlineAttemptKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _backgroundOnlineSync() async {
    print('QuizService: Starting background online sync...');
    await _recordOnlineAttempt();
    try {
      await _mongoService.init(); // This has a 5-second timeout
      if (_mongoService.isConnected) {
        print('QuizService: MongoDB connected (background).');
        _isOnlineMode = true;
        await _mongoService.seedDefaultData();
        await _cacheDataToLocal();
        _isInitialized = true; // Ensure initialized
        print('QuizService: Online data synced and cached (background).');
        onStateChange.value = !onStateChange.value;
      } else {
        print(
            'QuizService: MongoDB connection failed (background). Staying offline.');
        _isOnlineMode = false; // Explicitly stay/switch to offline
        // UI is already running on cache or will be notified if it wasn't initialized
        onStateChange.value = !onStateChange.value;
      }
    } catch (e) {
      print(
          'QuizService: Error during background MongoDB sync: $e. Staying offline.');
      _isOnlineMode = false;
      onStateChange.value = !onStateChange.value;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _attemptOnlineAndInitializeOrUseDefault() async {
    print(
        'QuizService: Attempting initial online connection or default cache...');
    await _recordOnlineAttempt();
    try {
      await _mongoService.init();
      if (_mongoService.isConnected) {
        print('QuizService: MongoDB connected (initial).');
        _isOnlineMode = true;
        await _mongoService.seedDefaultData();
        await _cacheDataToLocal();
        _isInitialized = true;
        print('QuizService: Online data synced and cached (initial).');
      } else {
        print(
            'QuizService: MongoDB connection failed (initial). Attempting default cache.');
        _isOnlineMode = false;
        await _createDefaultCacheAndInitialize();
      }
    } catch (e) {
      print(
          'QuizService: Error during initial MongoDB sync: $e. Attempting default cache.');
      _isOnlineMode = false;
      await _createDefaultCacheAndInitialize();
    } finally {
      _isSyncing = false;
      onStateChange.value = !onStateChange.value; // Notify UI about the outcome
    }
  }

  Future<void> _createDefaultCacheAndInitialize() async {
    print('QuizService: Creating default cache...');
    bool success = await _localStorageService.createDefaultCache();
    if (success) {
      _isInitialized = true;
      _isOnlineMode = false; // Explicitly offline with default cache
      print('QuizService: Default cache created and initialized.');
    } else {
      _isInitialized = false;
      _isOnlineMode = false;
      print('QuizService: CRITICAL - Failed to create default cache.');
    }
  }

  // 缓存在线数据到本地
  Future<void> _cacheDataToLocal() async {
    if (!_isOnlineMode || !_mongoService.isConnected) return;
    try {
      print('QuizService: Caching online data to local storage...');
      final questions = await _mongoService.getAllQuestions();
      final categories = await _mongoService.getAllCategories();
      await _localStorageService.cacheQuestions(questions);
      await _localStorageService.cacheCategories(categories);
      print(
          'QuizService: Data caching complete. ${questions.length} questions, ${categories.length} categories.');
    } catch (e) {
      print('QuizService: Error caching data to local: $e');
    }
  }

  // 获取所有问题
  Future<List<QuizQuestion>> getAllQuestions() async {
    _ensureInitialized('getAllQuestions');
    if (_isOnlineMode && _mongoService.isConnected) {
      try {
        return await _mongoService.getAllQuestions();
      } catch (e) {
        print(
            'QuizService: Online getAllQuestions failed, falling back to cache. Error: $e');
        _isOnlineMode = false; // Switch to offline if online fetch fails
        onStateChange.value = !onStateChange.value;
        return await _localStorageService.getCachedQuestions();
      }
    } else {
      return await _localStorageService.getCachedQuestions();
    }
  }

  // 获取所有分类
  Future<List<QuizCategory>> getAllCategories() async {
    _ensureInitialized('getAllCategories');
    if (_isOnlineMode && _mongoService.isConnected) {
      try {
        return await _mongoService.getAllCategories();
      } catch (e) {
        print(
            'QuizService: Online getAllCategories failed, falling back to cache. Error: $e');
        _isOnlineMode = false; // Switch to offline
        onStateChange.value = !onStateChange.value;
        return await _localStorageService.getCachedCategories();
      }
    } else {
      return await _localStorageService.getCachedCategories();
    }
  }

  // 获取指定分类的问题
  Future<List<QuizQuestion>> getQuestionsByCategory(String categoryName) async {
    _ensureInitialized('getQuestionsByCategory');
    List<QuizQuestion> questions;
    if (_isOnlineMode && _mongoService.isConnected) {
      try {
        questions = await _mongoService.getQuestionsByCategory(categoryName);
      } catch (e) {
        print(
            'QuizService: Online getQuestionsByCategory failed, falling back to cache. Error: $e');
        _isOnlineMode = false;
        onStateChange.value = !onStateChange.value;
        final allCached = await _localStorageService.getCachedQuestions();
        questions =
            allCached.where((q) => q.categoryName == categoryName).toList();
      }
    } else {
      final allCached = await _localStorageService.getCachedQuestions();
      questions =
          allCached.where((q) => q.categoryName == categoryName).toList();
    }
    return questions;
  }

  // 获取单个问题 (通过 String ID)
  Future<QuizQuestion?> getQuestion(String id) async {
    _ensureInitialized('getQuestion');
    QuizQuestion? question;
    if (_isOnlineMode && _mongoService.isConnected) {
      try {
        question = await _mongoService.getQuestionById(id);
      } catch (e) {
        print(
            'QuizService: Online getQuestionById failed, falling back to cache. Error: $e');
        _isOnlineMode = false;
        onStateChange.value = !onStateChange.value;
        final allCached = await _localStorageService.getCachedQuestions();
        try {
          question = allCached.firstWhere((q) => q.id == id);
        } catch (_) {
          question = null;
        }
      }
    } else {
      final allCached = await _localStorageService.getCachedQuestions();
      try {
        question = allCached.firstWhere((q) => q.id == id);
      } catch (_) {
        question = null;
      }
    }
    return question;
  }

  // --- Write operations: require online mode and update cache afterwards ---
  Future<String?> addQuestion(QuizQuestion question) async {
    _ensureOnlineAndInitialized('addQuestion');
    final id = await _mongoService.addQuestion(question);
    if (id != null) await _cacheDataToLocal();
    return id;
  }

  Future<List<String?>> addQuestions(List<QuizQuestion> questions) async {
    _ensureOnlineAndInitialized('addQuestions');
    List<String?> ids = [];
    // Assuming MongoDatabaseService does not have batch add, iterate
    for (var q in questions) {
      ids.add(await _mongoService.addQuestion(q));
    }
    if (ids.any((id) => id != null)) await _cacheDataToLocal();
    return ids;
  }

  Future<String?> addCategory(QuizCategory category) async {
    _ensureOnlineAndInitialized('addCategory');
    final id = await _mongoService.addCategory(category);
    if (id != null) await _cacheDataToLocal();
    return id;
  }

  Future<bool> updateQuestion(QuizQuestion question) async {
    _ensureOnlineAndInitialized('updateQuestion');
    if (question.id == null)
      throw Exception('Question ID cannot be null for update.');
    final success = await _mongoService.updateQuestion(question);
    if (success) await _cacheDataToLocal();
    return success;
  }

  Future<bool> deleteQuestion(String id) async {
    _ensureOnlineAndInitialized('deleteQuestion');
    final success = await _mongoService.deleteQuestion(id);
    if (success) await _cacheDataToLocal();
    return success;
  }

  Future<bool> updateCategory(QuizCategory category) async {
    _ensureOnlineAndInitialized('updateCategory');
    if (category.id == null)
      throw Exception('Category ID cannot be null for update.');
    final success = await _mongoService.updateCategory(category);
    if (success) await _cacheDataToLocal();
    return success;
  }

  Future<bool> deleteCategory(String id) async {
    _ensureOnlineAndInitialized('deleteCategory');
    final success = await _mongoService.deleteCategory(id);
    if (success) await _cacheDataToLocal();
    return success;
  }

  Future<List<String?>> importQuestionsFromAsset(String assetPath) async {
    _ensureOnlineAndInitialized(
        'importQuestionsFromAsset'); // Requires online to add to DB
    final String jsonString = await rootBundle.loadString(assetPath);
    final List<dynamic> jsonList = json.decode(jsonString);
    final questions = jsonList.map((jsonItem) {
      return QuizQuestion(
        questionText: jsonItem['questionText'] ?? jsonItem['question'],
        options: List<String>.from(jsonItem['options']),
        correctOptionIndex:
            jsonItem['correctOptionIndex'] ?? jsonItem['correctAnswer'],
        explanation: jsonItem['explanation'],
        categoryName: jsonItem['categoryName'] ?? jsonItem['category'] ?? '未分类',
        imageAssetPath: jsonItem['imageAssetPath'],
      );
    }).toList();
    return await addQuestions(questions); // This will also cache if successful
  }

  Future<String> exportQuestionsToJson() async {
    _ensureInitialized('exportQuestionsToJson');
    final questions =
        await getAllQuestions(); // Uses current online/offline state
    final jsonList = questions
        .map((q) => {
              '_id': q.id,
              'questionText': q.questionText,
              'options': q.options,
              'correctOptionIndex': q.correctOptionIndex,
              'explanation': q.explanation,
              'categoryName': q.categoryName,
              'imageAssetPath': q.imageAssetPath,
              'isFavorite': q.isFavorite,
              'difficulty': q.difficulty,
              'createdAt': q.createdAt?.toIso8601String(),
              'updatedAt': q.updatedAt?.toIso8601String(),
            })
        .toList();
    return json.encode(jsonList);
  }

  // 确保服务已初始化 (can be called with context for debugging)
  void _ensureInitialized(String operation) {
    if (!_isInitialized) {
      print(
          'QuizService: Attempted $operation before service was initialized.');
      throw Exception(
          'QuizService not initialized. Please wait for initialize() to complete.');
    }
  }

  // 确保在线模式并已初始化
  void _ensureOnlineAndInitialized(String operation) {
    _ensureInitialized(operation);
    if (!_isOnlineMode) {
      print(
          'QuizService: Attempted online operation "$operation" while offline.');
      throw Exception(
          'Operation "$operation" requires an active internet connection and MongoDB access.');
    }
  }

  // 获取服务运行模式
  bool get isOnline => _isOnlineMode;
  bool get isInitialized => _isInitialized;

  // 清除本地缓存
  Future<bool> clearLocalCache() async {
    final result = await _localStorageService.clearCache();
    if (result) {
      // After clearing cache, re-evaluate initialization state
      _isInitialized = false;
      _isOnlineMode = false; // Assume offline after cache clear
      onStateChange.value = !onStateChange.value;
      // Could trigger a re-initialize if desired, or let UI prompt
      initialize();
    }
    return result;
  }

  // 获取本地缓存时间戳
  Future<DateTime?> getLocalCacheTimestamp() async {
    return _localStorageService.getCacheTimestamp();
  }

  // 手动刷新缓存（强制在线获取并更新）
  Future<void> refreshCache() async {
    if (_isSyncing) {
      print('QuizService: Refresh already in progress.');
      return;
    }
    _isSyncing = true;
    print('QuizService: Force refreshing cache from online source...');
    await _recordOnlineAttempt();
    try {
      await _mongoService.init();
      if (_mongoService.isConnected) {
        _isOnlineMode = true; // Ensure online mode is set
        await _mongoService.seedDefaultData();
        await _cacheDataToLocal();
        _isInitialized = true; // Ensure initialized
        print('QuizService: Cache refreshed successfully.');
      } else {
        print('QuizService: Failed to connect online to refresh cache.');
        // Do not switch to offline mode here, let existing state persist or rely on next auto-attempt
      }
    } catch (e) {
      print('QuizService: Error during forced cache refresh: $e');
    } finally {
      _isSyncing = false;
      onStateChange.value =
          !onStateChange.value; // Notify UI of refresh attempt outcome
    }
  }

  // 关闭服务
  Future<void> close() async {
    if (_mongoService.isConnected) {
      await _mongoService.close();
    }
    _isInitialized = false;
    _isOnlineMode = false;
    _isSyncing = false;
    print("QuizService: Closed.");
    onStateChange.value = !onStateChange.value;
  }
}
