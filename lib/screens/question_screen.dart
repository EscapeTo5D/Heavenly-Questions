import 'package:flutter/material.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';

class QuestionScreen extends StatefulWidget {
  final String? questionId;
  final String? category;

  const QuestionScreen({super.key, this.questionId, this.category});

  @override
  _QuestionScreenState createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  final QuizService _quizService = QuizService();
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedOption;
  bool _showAnswer = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.questionId != null) {
        final question = await _quizService.getQuestion(widget.questionId!);
        if (question != null) {
          _questions = [question];
        }
      } else if (widget.category != null) {
        _questions =
            await _quizService.getQuestionsByCategory(widget.category!);
      } else {
        _questions = await _quizService.getAllQuestions();
      }
    } catch (e) {
      print('加载问题失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkAnswer(int optionIndex) {
    if (_showAnswer) return;

    setState(() {
      _selectedOption = optionIndex;
      _showAnswer = true;
    });

    // 记录答题结果 - Temporarily removed
    // if (_questions.isNotEmpty) {
    //   final question = _questions[_currentIndex];
    //   final isCorrect = optionIndex == question.correctOptionIndex; // Changed field name
    //   // _quizService.recordQuestionAttempt(question.id!, isCorrect); // Method doesn't exist
    // }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _showAnswer = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有题目已完成！')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_questions.isEmpty || _questions[_currentIndex].id == null) return;

    QuizQuestion currentQuestion = _questions[_currentIndex];
    QuizQuestion updatedQuestion = currentQuestion.copyWith(
      isFavorite: !currentQuestion.isFavorite,
    );

    try {
      bool success = await _quizService.updateQuestion(updatedQuestion);
      if (success) {
        setState(() {
          _questions[_currentIndex] = updatedQuestion;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新收藏状态失败')),
        );
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新收藏状态时出错: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('没有题目')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('没有找到题目', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];
    final isCorrectToShow =
        _showAnswer && _selectedOption == question.correctOptionIndex;
    final isWrongToShow =
        _showAnswer && _selectedOption != question.correctOptionIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text('题目 ${_currentIndex + 1}/${_questions.length}'),
        actions: [
          if (_questions.isNotEmpty)
            IconButton(
              icon: Icon(
                _questions[_currentIndex].isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: _questions[_currentIndex].isFavorite ? Colors.red : null,
              ),
              onPressed: _toggleFavorite,
              tooltip: '收藏',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 问题内容 - Assuming content was secondary or part of explanation
            // Text(
            //   question.content, // Field doesn't exist
            //   style: const TextStyle(fontSize: 16),
            // ),
            // const SizedBox(height: 16),

            if (_questions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    const Text('难度: ', style: TextStyle(fontSize: 16)),
                    if (question.difficulty >
                        0) // Ensure difficulty is positive
                      ...List.generate(
                        question.difficulty.clamp(0,
                            5), // Clamp difficulty between 0 and 5 for display
                        (i) => const Icon(Icons.star,
                            color: Colors.amber, size: 20),
                      ),
                    if (question.difficulty <=
                        0) // Display for undefined/zero difficulty
                      const Text('未定义',
                          style: TextStyle(
                              fontSize: 16, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            const SizedBox(height: 16), // Adjust spacing as needed

            Expanded(
              child: ListView.builder(
                itemCount: question.options.length,
                itemBuilder: (context, index) {
                  final isCorrectOption = index == question.correctOptionIndex;
                  Color? optionColor;
                  TextStyle optionTextStyle =
                      const TextStyle(); // Default text style
                  Color? leadingAvatarBackgroundColor;
                  TextStyle leadingAvatarTextStyle =
                      const TextStyle(); // Default for A, B, C
                  Color? trailingIconColor =
                      Colors.green; // Default for check icon

                  if (_showAnswer) {
                    if (isCorrectOption) {
                      optionColor = Colors.green; // Stronger green background
                      optionTextStyle = const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold);
                      leadingAvatarBackgroundColor = Colors.white;
                      leadingAvatarTextStyle = const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold);
                      trailingIconColor = Colors.white;
                    } else if (index == _selectedOption) {
                      optionColor = Colors.red.shade100;
                      // Potentially adjust text color for red.shade100 if needed, but default might be fine
                    }
                  }

                  return Card(
                    color: optionColor,
                    elevation: _showAnswer && isCorrectOption
                        ? 4.0
                        : 1.0, // Slightly more elevation for correct answer
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: leadingAvatarBackgroundColor,
                        child: Text(
                          String.fromCharCode(65 + index), // A, B, C, D...
                          style: leadingAvatarTextStyle,
                        ),
                      ),
                      title:
                          Text(question.options[index], style: optionTextStyle),
                      trailing: _showAnswer && isCorrectOption
                          ? Icon(Icons.check_circle, color: trailingIconColor)
                          : null,
                      onTap: () => _checkAnswer(index),
                    ),
                  );
                },
              ),
            ),

            // 答案解析
            if (_showAnswer && question.explanation != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrectToShow ? Icons.check_circle : Icons.cancel,
                          color: isCorrectToShow ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCorrectToShow ? '回答正确！' : '回答错误',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrectToShow ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '解析:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(question.explanation!),
                  ],
                ),
              ),

            // 底部按钮
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_showAnswer)
                    ElevatedButton(
                      onPressed: _nextQuestion,
                      child: Text(
                          _currentIndex < _questions.length - 1 ? '下一题' : '完成'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
