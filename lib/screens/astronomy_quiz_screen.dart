import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';
import 'package:intl/intl.dart';

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
  int? _selectedOptionIndex;
  String? _loadError;
  DateTime? _cacheTimestamp;

  List<QuizQuestion> _allQuestions = [];
  List<QuizCategory> _categories = [];
  List<QuizQuestion> _currentQuestions = [];

  final QuizService _quizService = QuizService();

  @override
  void initState() {
    super.initState();
    _quizService.onStateChange.addListener(_onQuizServiceStateChanged);
    if (_quizService.isInitialized) {
      _loadQuizData();
    } else {
      if (!_isLoading) setState(() => _isLoading = true);
    }
  }

  @override
  void dispose() {
    _quizService.onStateChange.removeListener(_onQuizServiceStateChanged);
    super.dispose();
  }

  void _onQuizServiceStateChanged() {
    if (mounted) {
      print(
          'AstronomyQuizScreen: Detected QuizService state change. Reloading data.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadQuizData();
      });
    }
  }

  Future<void> _loadQuizData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      if (!_quizService.isInitialized) {
        print(
            'AstronomyQuizScreen: QuizService not initialized yet. Waiting...');
        return;
      }

      final categories = await _quizService.getAllCategories();
      final questions = await _quizService.getAllQuestions();
      final cacheTimestamp = await _quizService.getLocalCacheTimestamp();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _allQuestions = questions;
        _cacheTimestamp = cacheTimestamp;
        _isLoading = false;
        _updateCurrentQuestions();
      });
    } catch (e) {
      print('AstronomyQuizScreen: Error loading quiz data: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
        if (_allQuestions.isEmpty && _categories.isEmpty) {
          _showErrorDialog('加载失败', '无法加载题库数据: $e\n\n请稍后重试或检查应用更新。');
        }
      });
    }
  }

  void _updateCurrentQuestions() {
    if (_allQuestions.isEmpty) {
      _currentQuestions = [];
    } else if (_selectedCategory == null) {
      _currentQuestions = List.from(_allQuestions);
    } else {
      _currentQuestions = _allQuestions
          .where((q) => q.categoryName == _selectedCategory)
          .toList();
    }
    _currentQuestionIndex = 0;
    _score = 0;
    _quizCompleted = false;
    _selectedOptionIndex = null;
  }

  void _checkAnswer(int selectedOptionIndex) {
    if (_currentQuestions.isEmpty) return;

    final correctAnswerIndex =
        _currentQuestions[_currentQuestionIndex].correctOptionIndex;
    final bool isCorrect = selectedOptionIndex == correctAnswerIndex;

    if (isCorrect) {
      setState(() {
        _score++;
        _selectedOptionIndex = selectedOptionIndex;
      });

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showAnswerDialog(true);
          setState(() {
            _selectedOptionIndex = null;
          });
        }
      });
    } else {
      _showAnswerDialog(false);
    }
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
                }),
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

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.midBlue,
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.white),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                '确定',
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
    final bool isOfflineMode =
        !_quizService.isOnline && _quizService.isInitialized;

    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlue,
        title: const Text(
          '天文学习',
          style: TextStyle(color: AppTheme.white),
        ),
        actions: [
          if (isOfflineMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Tooltip(
                message: '当前处于离线模式',
                child: Icon(
                  Icons.offline_bolt,
                  color: Colors.amber,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.category, color: AppTheme.white),
            onPressed: (_isLoading || !_quizService.isInitialized)
                ? null
                : _showCategorySelector,
            tooltip: '选择题目分类',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.white),
            onPressed: (_isLoading || !_quizService.isInitialized)
                ? null
                : _refreshData,
            tooltip: isOfflineMode ? '尝试重新连接并刷新' : '刷新题库数据 (已在线)',
          ),
        ],
        iconTheme: const IconThemeData(color: AppTheme.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingView()
            : !_quizService.isInitialized && _loadError == null
                ? _buildLoadingView()
                : _currentQuestions.isEmpty
                    ? _buildEmptyView()
                    : _quizCompleted
                        ? _buildQuizCompletedView()
                        : _buildQuizView(),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (!_quizService.isInitialized) {
      print("AstronomyQuizScreen: Cannot refresh, QuizService not ready.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_quizService.isOnline) {
        await _quizService.refreshCache();
      } else {
        await _quizService.initialize();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_quizService.isOnline ? '题库数据已尝试刷新' : '已尝试重新连接并获取最新数据'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('AstronomyQuizScreen: Refresh data failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('刷新失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final bool isOffline = !_quizService.isOnline && _quizService.isInitialized;
    String message = '';
    IconData icon = Icons.error_outline;
    Color iconColor = AppTheme.purple;

    if (_loadError != null) {
      message = '加载题库时出错。\n$_loadError';
      icon = Icons.cloud_off;
      iconColor = Colors.red;
    } else if (isOffline) {
      message = '当前为离线模式。';
      icon = Icons.offline_bolt;
      iconColor = Colors.amber;
      if (_currentQuestions.isEmpty) {
        message += '\n本地没有题目数据。';
        if (_cacheTimestamp == null) message += '\n也未能加载默认题目。';
      }
    } else if (_currentQuestions.isEmpty && _quizService.isInitialized) {
      message = _selectedCategory == null
          ? '题库为空，请在线时尝试刷新或添加题目。'
          : '$_selectedCategory 分类下没有题目。';
    }

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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: iconColor, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(color: AppTheme.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  if (isOffline && _cacheTimestamp != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '本地数据最后更新于: ${_formatDateTime(_cacheTimestamp!)}',
                      style: TextStyle(
                          color: AppTheme.white.withOpacity(0.7), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_loadError != null ||
                      (isOffline && _currentQuestions.isEmpty))
                    ElevatedButton(
                      onPressed: _refreshData,
                      child: Text(isOffline ? '尝试重新连接' : '重试加载'),
                    )
                  else if (_currentQuestions.isEmpty &&
                      _quizService.isInitialized)
                    ElevatedButton(
                      onPressed: _showCategorySelector,
                      child: const Text('选择其他分类'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
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
    final currentQuestion = _currentQuestions[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (currentQuestion.imageAssetPath != null &&
              currentQuestion.imageAssetPath!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.asset(
                  currentQuestion.imageAssetPath!,
                  fit: BoxFit.cover,
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
          final bool isSelectedCorrectOption = _selectedOptionIndex != null &&
              index == _selectedOptionIndex &&
              index ==
                  _currentQuestions[_currentQuestionIndex].correctOptionIndex;

          return GestureDetector(
            onTap:
                _selectedOptionIndex != null ? null : () => _checkAnswer(index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelectedCorrectOption
                    ? Colors.green.withOpacity(0.3)
                    : AppTheme.darkBlue.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelectedCorrectOption
                      ? Colors.green
                      : AppTheme.purple.withOpacity(0.3),
                  width: isSelectedCorrectOption ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelectedCorrectOption
                          ? Colors.green.withOpacity(0.5)
                          : AppTheme.purple.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: isSelectedCorrectOption
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : Text(
                            String.fromCharCode(65 + index),
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
                      style: TextStyle(
                        color: isSelectedCorrectOption
                            ? Colors.green
                            : AppTheme.white,
                        fontSize: 16,
                        fontWeight: isSelectedCorrectOption
                            ? FontWeight.bold
                            : FontWeight.normal,
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
