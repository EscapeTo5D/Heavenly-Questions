import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quiz_question.dart';
// import 'quiz_database.dart'; // 移除旧的 SQLite 数据库服务
import 'mongo_database_service.dart'; // 引入新的 MongoDB 服务

class QuizService {
  // 单例模式
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  // final _database = QuizDatabase.instance; // 旧的 SQLite 实例
  final MongoDatabaseService _mongoService =
      MongoDatabaseService(); // 新的 MongoDB 服务实例
  bool _isInitialized = false;

  // 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      print('正在初始化 MongoDB 服务...');
      await _mongoService.init();
      if (_mongoService.isConnected) {
        print('MongoDB 服务连接成功。');
        // 可选：在这里进行数据种子填充
        await _mongoService.seedDefaultData();
        _isInitialized = true;
        print('题库服务 (MongoDB) 初始化完成。');
      } else {
        print('MongoDB 服务连接失败。');
        throw Exception('无法连接到 MongoDB 服务');
      }
    } catch (e) {
      print('题库服务 (MongoDB) 初始化失败: $e');
      _isInitialized = false; // 确保在失败时状态正确
      rethrow; // 重新抛出异常，让应用知道初始化失败
    }
  }

  // 获取所有问题
  Future<List<QuizQuestion>> getAllQuestions() async {
    _ensureInitialized();
    return await _mongoService.getAllQuestions();
  }

  // 获取指定分类的问题
  Future<List<QuizQuestion>> getQuestionsByCategory(String categoryName) async {
    _ensureInitialized();
    return await _mongoService.getQuestionsByCategory(categoryName);
  }

  // 获取单个问题 (通过 String ID)
  Future<QuizQuestion?> getQuestion(String id) async {
    _ensureInitialized();
    return await _mongoService.getQuestionById(id);
  }

  // 获取所有分类
  Future<List<QuizCategory>> getAllCategories() async {
    _ensureInitialized();
    return await _mongoService.getAllCategories();
  }

  // 添加新问题 (返回 String? questionId)
  Future<String?> addQuestion(QuizQuestion question) async {
    _ensureInitialized();
    return await _mongoService.addQuestion(question);
  }

  // 批量添加问题 (根据 MongoDatabaseService 的实现调整)
  // MongoDatabaseService 当前没有批量添加，如果需要可以添加，或者在这里循环调用 addQuestion
  Future<List<String?>> addQuestions(List<QuizQuestion> questions) async {
    _ensureInitialized();
    List<String?> ids = [];
    for (var q in questions) {
      ids.add(await _mongoService.addQuestion(q));
    }
    return ids;
  }

  // 添加分类 (返回 String? categoryId)
  Future<String?> addCategory(QuizCategory category) async {
    _ensureInitialized();
    return await _mongoService.addCategory(category);
  }

  // 更新问题 (返回 bool)
  Future<bool> updateQuestion(QuizQuestion question) async {
    _ensureInitialized();
    if (question.id == null) {
      throw Exception('更新问题失败：ID不能为空');
    }
    return await _mongoService.updateQuestion(question);
  }

  // 删除问题 (通过 String ID, 返回 bool)
  Future<bool> deleteQuestion(String id) async {
    _ensureInitialized();
    return await _mongoService.deleteQuestion(id);
  }

  // 更新分类 (返回 bool)
  Future<bool> updateCategory(QuizCategory category) async {
    _ensureInitialized();
    if (category.id == null) {
      throw Exception('更新分类失败：ID不能为空');
    }
    return await _mongoService.updateCategory(category);
  }

  // 删除分类及其问题 (通过 String ID, 返回 bool)
  // 注意：MongoDatabaseService.deleteCategory 目前只删除分类本身。
  // 如果需要级联删除问题，需要在 QuizService 或 MongoDatabaseService 中实现该逻辑。
  Future<bool> deleteCategory(String id) async {
    _ensureInitialized();
    // 示例：如果需要删除该分类下的所有问题
    // final questionsInCategory = await getQuestionsByCategory(categoryToDelete.name);
    // for (var q in questionsInCategory) {
    //   if (q.id != null) await deleteQuestion(q.id!);
    // }
    return await _mongoService.deleteCategory(id);
  }

  // 从JSON文件导入题目
  Future<List<String?>> importQuestionsFromAsset(String assetPath) async {
    _ensureInitialized();
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = json.decode(jsonString);

      final questions = jsonList.map((json) {
        // 使用新的模型字段名
        return QuizQuestion(
          questionText: json['questionText'] ?? json['question'], // 兼容旧字段
          options: List<String>.from(json['options']),
          correctOptionIndex:
              json['correctOptionIndex'] ?? json['correctAnswer'], // 兼容旧字段
          explanation: json['explanation'],
          categoryName:
              json['categoryName'] ?? json['category'] ?? '未分类', // 兼容旧字段
          imageAssetPath: json['imageAssetPath'],
          // createdAt 和 updatedAt 会在 addQuestion 时自动设置
        );
      }).toList();

      return await addQuestions(questions);
    } catch (e) {
      print('导入题库 (MongoDB) 失败: $e');
      return [];
    }
  }

  // 导出题目为JSON字符串
  Future<String> exportQuestionsToJson() async {
    _ensureInitialized();
    final questions = await getAllQuestions();
    final jsonList = questions
        .map((q) => {
              // 使用新的模型字段名
              '_id': q.id, // 可以选择是否导出 MongoDB 的 _id
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

  // 确保服务已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('题库服务 (MongoDB) 未初始化，请先调用initialize()方法');
    }
  }

  // 关闭服务
  Future<void> close() async {
    if (_isInitialized) {
      await _mongoService.close();
      _isInitialized = false;
      print("题库服务 (MongoDB) 已关闭。");
    }
  }
}
