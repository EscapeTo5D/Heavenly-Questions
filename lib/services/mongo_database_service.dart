import 'package:mongo_dart/mongo_dart.dart'
    hide
        State; // Added hide State to avoid conflict if any with Flutter's State
import '../models/quiz_question.dart';

class MongoDatabaseService {
  Db? _db;
  DbCollection? _questionsCollection;
  DbCollection? _categoriesCollection;

  // 例如: 'mongodb+srv://<username>:<password>@<cluster-url>/<databaseName>?retryWrites=true&w=majority'
  // 强烈建议不要硬编码，而是从安全的地方读取，例如配置文件或环境变量。
  static const String _connectionString =
      'mongodb+srv://root:root@guichen.sxtgsoe.mongodb.net/heavenly_questions_db?retryWrites=true&w=majority&appName=guichen'; // <<< MODIFIED: Explicitly added database name
  static const String _dbName = 'heavenly_questions_db'; // 您在 Atlas 中创建的数据库名
  static const String _questionsCollectionName = 'questions';
  static const String _categoriesCollectionName = 'categories';

  Future<void> init() async {
    if (_db != null && _db!.isConnected) {
      print("MongoDB already connected.");
      return;
    }
    try {
      _db = await Db.create(_connectionString);
      await _db!.open();
      print("MongoDB connected successfully!");

      _questionsCollection = _db!.collection(_questionsCollectionName);
      _categoriesCollection = _db!.collection(_categoriesCollectionName);

      await _categoriesCollection!.createIndex(
          key: 'name', unique: true, name: 'category_name_unique_idx');
      await _questionsCollection!
          .createIndex(key: 'categoryName', name: 'question_categoryName_idx');

      print("MongoDB Collections and Indexes initialized/verified.");
    } catch (e) {
      print('Error connecting to MongoDB: $e');
      _db = null;
      rethrow;
    }
  }

  Db? get database => _db;
  bool get isConnected => _db != null && _db!.isConnected;

  Future<void> close() async {
    if (_db != null && _db!.isConnected) {
      await _db!.close();
      _db = null;
      print("MongoDB connection closed.");
    }
  }

  // --- Category Methods ---

  Future<String?> addCategory(QuizCategory category) async {
    if (!isConnected || _categoriesCollection == null)
      throw Exception('MongoDB not connected or collection not initialized');
    try {
      final now = DateTime.now();
      final categoryMap =
          category.copyWith(createdAt: now, updatedAt: now).toMap();
      categoryMap.remove('id');
      categoryMap.removeWhere((key, value) => key == '_id' && value == null);

      final result = await _categoriesCollection!.insertOne(categoryMap);
      if (result.isSuccess && result.id != null) {
        return (result.id as ObjectId).toHexString();
      }
      print(
          'Add category failed: ${result.writeError?.errmsg} Code: ${result.writeError?.code}');
      return null;
    } catch (e) {
      print('Error adding category: $e');
      return null;
    }
  }

  Future<List<QuizCategory>> getAllCategories() async {
    if (!isConnected || _categoriesCollection == null)
      throw Exception('MongoDB not connected or collection not initialized');
    try {
      final categoriesMap = await _categoriesCollection!.find().toList();
      return categoriesMap.map((map) => QuizCategory.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all categories: $e');
      return [];
    }
  }

  Future<QuizCategory?> getCategoryByName(String name) async {
    if (!isConnected || _categoriesCollection == null)
      throw Exception('MongoDB not connected or collection not initialized');
    try {
      final categoryMap =
          await _categoriesCollection!.findOne(where.eq('name', name));
      if (categoryMap != null) {
        return QuizCategory.fromMap(categoryMap);
      }
      return null;
    } catch (e) {
      print('Error getting category by name: $e');
      return null;
    }
  }

  Future<bool> updateCategory(QuizCategory category) async {
    if (!isConnected || category.id == null || _categoriesCollection == null)
      throw Exception(
          'MongoDB not connected, category ID is null, or collection not initialized');
    try {
      final now = DateTime.now();
      final Map<String, dynamic> updateDoc = {
        r'$set': category.copyWith(updatedAt: now).toMap()
          ..remove('id')
          ..remove('_id')
      };

      final result = await _categoriesCollection!.updateOne(
        where.id(ObjectId.fromHexString(category.id!)),
        updateDoc,
      );
      if (result.isSuccess && result.nModified == 1) {
        return true;
      }
      print(
          'Update category failed: ${result.writeError?.errmsg} Code: ${result.writeError?.code}');
      return false;
    } catch (e) {
      print('Error updating category: $e');
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    if (!isConnected || _categoriesCollection == null)
      throw Exception('MongoDB not connected or collection not initialized');
    try {
      final result = await _categoriesCollection!
          .deleteOne(where.id(ObjectId.fromHexString(categoryId)));
      if (result.isSuccess && result.nRemoved == 1) {
        return true;
      }
      print(
          'Delete category failed: ${result.writeError?.errmsg} Code: ${result.writeError?.code}');
      return false;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }

  // --- Question Methods ---

  Future<String?> addQuestion(QuizQuestion question) async {
    if (!isConnected || _questionsCollection == null)
      throw Exception('MongoDB未连接或集合未初始化');
    try {
      final now = DateTime.now();
      final questionMap =
          question.copyWith(createdAt: now, updatedAt: now).toMap();
      questionMap.remove('id');
      questionMap.removeWhere((key, value) => key == '_id' && value == null);

      final result = await _questionsCollection!.insertOne(questionMap);
      if (result.isSuccess && result.id != null) {
        final newId = (result.id as ObjectId).toHexString();
        print('成功添加题目，ID: $newId，题目: ${question.questionText}');
        return newId;
      }
      print(
          '添加题目失败: ${result.writeError?.errmsg} 错误码: ${result.writeError?.code}. 题目: ${question.questionText}');
      return null;
    } catch (e) {
      print('添加题目时发生错误: $e. 题目: ${question.questionText}');
      return null;
    }
  }

  Future<List<QuizQuestion>> getAllQuestions() async {
    if (!isConnected || _questionsCollection == null)
      throw Exception('MongoDB not connected or collection not initialized');
    try {
      final questionsMap = await _questionsCollection!.find().toList();
      return questionsMap.map((map) => QuizQuestion.fromMap(map)).toList();
    } catch (e) {
      print('Error getting all questions: $e');
      return [];
    }
  }

  Future<List<QuizQuestion>> getQuestionsByCategory(String categoryName) async {
    if (!isConnected || _questionsCollection == null)
      throw Exception('MongoDB not connected or collection not initialized');
    try {
      final questionsMap = await _questionsCollection!
          .find(where.eq('categoryName', categoryName))
          .toList();
      return questionsMap.map((map) => QuizQuestion.fromMap(map)).toList();
    } catch (e) {
      print('Error getting questions by category: $e');
      return [];
    }
  }

  Future<QuizQuestion?> getQuestionById(String questionId) async {
    if (!isConnected || _questionsCollection == null)
      throw Exception('MongoDB not connected or collection not initialized');
    try {
      final questionMap = await _questionsCollection!
          .findOne(where.id(ObjectId.fromHexString(questionId)));
      if (questionMap != null) {
        return QuizQuestion.fromMap(questionMap);
      }
      return null;
    } catch (e) {
      print('Error getting question by id: $e');
      return null;
    }
  }

  Future<bool> updateQuestion(QuizQuestion question) async {
    if (!isConnected || question.id == null || _questionsCollection == null)
      throw Exception(
          'MongoDB not connected, question ID is null, or collection not initialized');
    try {
      final now = DateTime.now();
      final Map<String, dynamic> updateDoc = {
        r'$set': question.copyWith(updatedAt: now).toMap()
          ..remove('id')
          ..remove('_id')
      };

      final result = await _questionsCollection!.updateOne(
        where.id(ObjectId.fromHexString(question.id!)),
        updateDoc,
      );
      if (result.isSuccess && result.nModified == 1) {
        return true;
      }
      print(
          'Update question failed: ${result.writeError?.errmsg} Code: ${result.writeError?.code}');
      return false;
    } catch (e) {
      print('Error updating question: $e');
      return false;
    }
  }

  Future<bool> deleteQuestion(String questionId) async {
    if (!isConnected || _questionsCollection == null)
      throw Exception('MongoDB not connected or collection not initialized');
    try {
      final result = await _questionsCollection!
          .deleteOne(where.id(ObjectId.fromHexString(questionId)));
      if (result.isSuccess && result.nRemoved == 1) {
        return true;
      }
      print(
          'Delete question failed: ${result.writeError?.errmsg} Code: ${result.writeError?.code}');
      return false;
    } catch (e) {
      print('Error deleting question: $e');
      return false;
    }
  }

  // --- Data Initialization/Seeding ---
  Future<void> seedDefaultData() async {
    if (!isConnected ||
        _categoriesCollection == null ||
        _questionsCollection == null) {
      print(
          'MongoDB not connected or collections not initialized. Skipping data seeding check.');
      // Optionally throw an exception if collections must be initialized here
      // throw Exception('MongoDB not connected or collections not initialized');
      return; // Exit if not connected or collections are null
    }

    print("Checking for existing data in MongoDB...");

    // Check categories
    final categoryCount = await _categoriesCollection!.count();
    if (categoryCount == 0) {
      print(
          "Categories collection is empty. Default categories will not be seeded by this method.");
      print(
          "Please add categories through the application interface or other external tools.");
    } else {
      print(
          "Categories collection already contains ${categoryCount} categor(y/ies). No default categories will be added.");
    }

    // Check questions
    final questionCount = await _questionsCollection!.count();
    if (questionCount == 0) {
      print(
          "Questions collection is empty. Default questions will not be seeded by this method.");
      print(
          "Please add questions through the application interface or other external tools.");
    } else {
      print(
          "Questions collection already contains ${questionCount} question(s). No default questions will be added.");
    }
    print(
        "Data seeding process completed. Database content relies on external/manual input.");
  }
}
