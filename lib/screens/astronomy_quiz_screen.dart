import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';

class AstronomyQuizScreen extends StatefulWidget {
  const AstronomyQuizScreen({super.key});

  @override
  State<AstronomyQuizScreen> createState() => _AstronomyQuizScreenState();
}

class _AstronomyQuizScreenState extends State<AstronomyQuizScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _quizCompleted = false;
  bool _isLoading = true;
  String? _selectedCategory;

  List<QuizQuestion> _allQuestions = [];
  List<QuizCategory> _categories = [];
  List<QuizQuestion> _currentQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadQuizData();
  }

  // 加载题库数据
  Future<void> _loadQuizData() async {
    setState(() => _isLoading = true);

    try {
      final quizService = QuizService();
      final categories = await quizService.getAllCategories();
      final questions = await quizService.getAllQuestions();

      setState(() {
        _categories = categories;
        _allQuestions = questions;
        _isLoading = false;

        // 默认选择所有问题
        _selectedCategory = null;
        _updateCurrentQuestions();
      });
    } catch (e) {
      print('加载题库失败: $e');
      setState(() => _isLoading = false);
    }
  }

  // 根据选择的分类更新当前题目列表
  void _updateCurrentQuestions() {
    if (_selectedCategory == null) {
      // 如果没有选择分类，显示所有题目
      _currentQuestions = List.from(_allQuestions);
    } else {
      // 否则筛选指定分类的题目
      _currentQuestions = _allQuestions
          .where((q) => q.categoryName == _selectedCategory)
          .toList();
    }

    // 重置问题索引和分数
    _currentQuestionIndex = 0;
    _score = 0;
    _quizCompleted = false;
  }

  void _checkAnswer(int selectedOptionIndex) {
    if (_currentQuestions.isEmpty) return;

    final correctAnswerIndex =
        _currentQuestions[_currentQuestionIndex].correctOptionIndex;
    final bool isCorrect = selectedOptionIndex == correctAnswerIndex;

    if (isCorrect) {
      setState(() {
        _score++;
      });
    }

    _showAnswerDialog(isCorrect);
  }

  void _showAnswerDialog(bool isCorrect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.midBlue,
          title: Text(
            isCorrect ? '回答正确！' : '回答错误',
            style: TextStyle(
              color: isCorrect ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentQuestions[_currentQuestionIndex].explanation,
                style: const TextStyle(color: AppTheme.white),
              ),
              const SizedBox(height: 16),
              Text(
                '当前分数: $_score / ${_currentQuestionIndex + 1}',
                style: const TextStyle(
                    color: AppTheme.lightBlue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _nextQuestion();
              },
              child: const Text(
                '继续',
                style: TextStyle(color: AppTheme.purple),
              ),
            ),
          ],
        );
      },
    );
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _currentQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      setState(() {
        _quizCompleted = true;
      });
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _score = 0;
      _quizCompleted = false;
    });
  }

  // 选择分类对话框
  Future<void> _showCategorySelector() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.midBlue,
          title: const Text(
            '选择题目分类',
            style: TextStyle(color: AppTheme.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                // 添加"全部"选项
                ListTile(
                  title: const Text(
                    '全部类别',
                    style: TextStyle(color: AppTheme.white),
                  ),
                  tileColor: _selectedCategory == null
                      ? AppTheme.purple.withOpacity(0.2)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedCategory = null;
                      _updateCurrentQuestions();
                    });
                    Navigator.pop(context);
                  },
                ),
                const Divider(color: AppTheme.purple),
                ..._categories.map((category) {
                  return ListTile(
                    title: Text(
                      category.name,
                      style: const TextStyle(color: AppTheme.white),
                    ),
                    subtitle: category.description != null
                        ? Text(
                            category.description!,
                            style: TextStyle(
                                color: AppTheme.white.withOpacity(0.7)),
                          )
                        : null,
                    tileColor: _selectedCategory == category.name
                        ? AppTheme.purple.withOpacity(0.2)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCategory = category.name;
                        _updateCurrentQuestions();
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '取消',
                style: TextStyle(color: AppTheme.purple),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlue,
        title: const Text(
          '天文学习',
          style: TextStyle(color: AppTheme.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.category, color: AppTheme.white),
            onPressed: _isLoading ? null : _showCategorySelector,
            tooltip: '选择题目分类',
          ),
        ],
        iconTheme: const IconThemeData(color: AppTheme.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingView()
            : _currentQuestions.isEmpty
                ? _buildEmptyView()
                : _quizCompleted
                    ? _buildQuizCompletedView()
                    : _buildQuizView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.7,
          colors: [AppTheme.midBlue, AppTheme.darkBlue],
        ),
      ),
      child: Stack(
        children: [
          _buildStars(),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
                ),
                SizedBox(height: 16),
                Text(
                  '加载题库中...',
                  style: TextStyle(
                    color: AppTheme.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.7,
          colors: [AppTheme.midBlue, AppTheme.darkBlue],
        ),
      ),
      child: Stack(
        children: [
          _buildStars(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppTheme.purple,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedCategory == null
                      ? '题库为空，请添加题目'
                      : '${_selectedCategory}分类下没有题目',
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _showCategorySelector,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.purple,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    '选择其他分类',
                    style: TextStyle(
                      color: AppTheme.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.7,
          colors: [AppTheme.midBlue, AppTheme.darkBlue],
        ),
      ),
      child: Stack(
        children: [
          _buildStars(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressIndicator(),
                const SizedBox(height: 24),
                _buildQuestionCard(),
                const SizedBox(height: 24),
                _buildAnswerOptions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars() {
    return CustomPaint(
      painter: StarPainter(),
      size: const Size(double.infinity, double.infinity),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '问题 ${_currentQuestionIndex + 1}/${_currentQuestions.length}',
              style: const TextStyle(
                color: AppTheme.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '得分: $_score',
              style: const TextStyle(
                color: AppTheme.lightBlue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _currentQuestions.length,
          backgroundColor: AppTheme.darkBlue,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.purple),
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }

  Widget _buildQuestionCard() {
    // 获取当前问题
    final currentQuestion = _currentQuestions[_currentQuestionIndex];

    // 问题区域
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 显示图片 (如果存在)
          if (currentQuestion.imageAssetPath != null &&
              currentQuestion.imageAssetPath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ClipRRect(
                // 添加圆角
                borderRadius: BorderRadius.circular(12.0),
                child: Image.asset(
                  currentQuestion.imageAssetPath!,
                  fit: BoxFit.cover, // 图片填充方式
                  // 可以添加加载指示器或错误占位符
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      color: AppTheme.midBlue.withOpacity(0.5),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // 问题序号和文本
          Text(
            '问题 ${_currentQuestionIndex + 1} / ${_currentQuestions.length}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.lightBlue,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            currentQuestion.questionText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerOptions() {
    final options = _currentQuestions[_currentQuestionIndex].options;

    return Expanded(
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _checkAnswer(index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkBlue.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.purple.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.purple.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      String.fromCharCode(65 + index), // A, B, C, D...
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      options[index],
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuizCompletedView() {
    final percentage = (_score / _currentQuestions.length) * 100;

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.7,
          colors: [AppTheme.midBlue, AppTheme.darkBlue],
        ),
      ),
      child: Stack(
        children: [
          _buildStars(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '你的得分: $_score/${_currentQuestions.length}',
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedCategory != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '分类: $_selectedCategory',
                    style: TextStyle(
                      color: AppTheme.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  _getResultMessage(percentage),
                  style: const TextStyle(
                    color: AppTheme.lightBlue,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _restartQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.purple,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        '再次挑战',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _showCategorySelector,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkBlue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        '切换分类',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getResultMessage(double percentage) {
    if (percentage >= 80) {
      return '太棒了！你对天文学知识掌握得非常好！';
    } else if (percentage >= 60) {
      return '做得不错！你对天文学有很好的理解！';
    } else if (percentage >= 40) {
      return '还不错！多学习可以做得更好！';
    } else {
      return '继续努力！多学习天文知识！';
    }
  }
}

// 为应用绘制星空背景的自定义画笔
class StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = DateTime.now().millisecondsSinceEpoch;
    const numberOfStars = 100;

    for (var i = 0; i < numberOfStars; i++) {
      final x = (random * (i + 1) * 7) % size.width;
      final y = (random * (i + 1) * 13) % size.height;
      final radius = (random * (i + 1)) % 2 + 0.5;
      final opacity = (random * (i + 1)) % 100 / 100 * 0.5 + 0.3;

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
