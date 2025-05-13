import 'package:flutter/material.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';
import 'question_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  _CategoryListScreenState createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final QuizService _quizService = QuizService();
  List<QuizCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Ensure default categories are handled by QuizService.initialize -> MongoDatabaseService.seedDefaultData
      // await _dbService.addDefaultCategories(); // Removed

      // 获取所有分类
      _categories = await _quizService.getAllCategories();
    } catch (e) {
      print('加载分类失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('题库分类'),
      ),
      body: _categories.isEmpty
          ? const Center(child: Text('没有分类', style: TextStyle(fontSize: 18)))
          : ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Colors.primaries[index % Colors.primaries.length],
                      child: Text(
                        category.name.isNotEmpty
                            ? category.name.substring(0, 1)
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(category.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              QuestionScreen(category: category.name),
                        ),
                      ).then((_) => _loadCategories()); // 返回时刷新分类列表
                    },
                  ),
                );
              },
            ),
    );
  }
}
