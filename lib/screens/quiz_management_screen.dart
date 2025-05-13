import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart'
    show MongoDartError; // Added for MongoDartError
// import 'package:sqflite/sqflite.dart'; // Removed SQLite import
import '../constants/theme.dart';
import '../models/quiz_question.dart';
import '../services/quiz_service.dart';
import '../utils/routes.dart';

class QuizManagementScreen extends StatefulWidget {
  const QuizManagementScreen({super.key});

  // 静态变量，记录当前应用生命周期内是否已通过验证
  static bool isGlobalAuthenticated = false;

  @override
  State<QuizManagementScreen> createState() => _QuizManagementScreenState();
}

class _QuizManagementScreenState extends State<QuizManagementScreen> {
  final QuizService _quizService = QuizService();
  List<QuizQuestion> _questions = [];
  List<QuizCategory> _categories = [];
  bool _isLoading = true;
  String? _selectedCategory;
  final TextEditingController _passwordController = TextEditingController();
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    print(
        "QuizManagementScreen: initState called. isGlobalAuthenticated = ${QuizManagementScreen.isGlobalAuthenticated}");
    // 检查全局认证状态
    if (QuizManagementScreen.isGlobalAuthenticated) {
      print(
          "QuizManagementScreen: Globally authenticated. Setting local state.");
      setState(() {
        _isAuthenticated = true;
      });
      _loadData();
    } else {
      print(
          "QuizManagementScreen: Not globally authenticated. Scheduling password dialog.");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print("QuizManagementScreen: Showing password dialog now.");
          _showPasswordDialog();
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // 显示密码验证对话框
  Future<void> _showPasswordDialog() async {
    print("QuizManagementScreen: _showPasswordDialog called.");
    _passwordController.clear();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.midBlue,
          title: const Text('请输入管理密码', style: TextStyle(color: AppTheme.white)),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: AppTheme.white),
            decoration: const InputDecoration(
              hintText: '输入密码',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.purple),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.purple, width: 2),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('取消', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                final password = _passwordController.text.trim();
                if (password == '7172') {
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('密码错误'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('确认', style: TextStyle(color: AppTheme.purple)),
            ),
          ],
        );
      },
    );
    print("QuizManagementScreen: Password dialog result: $result");

    if (result == true) {
      print(
          "QuizManagementScreen: Password correct. Setting global and local auth state.");
      // 设置全局验证状态和局部状态
      QuizManagementScreen.isGlobalAuthenticated = true;
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
        _loadData();
      }
    } else {
      print("QuizManagementScreen: Password incorrect or dialog cancelled.");
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // 加载题库数据
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final questions = await _quizService.getAllQuestions();
      final categories = await _quizService.getAllCategories();

      setState(() {
        _questions = questions;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      print('加载题库失败: $e');
      setState(() {
        _isLoading = false;
      });
      // 显示友好的错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('加载题库失败: 请重启应用或联系开发者'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: '确定',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  // 过滤指定分类的问题
  List<QuizQuestion> _getFilteredQuestions() {
    if (_selectedCategory == null) {
      return _questions;
    } else {
      return _questions
          .where((q) => q.categoryName == _selectedCategory)
          .toList();
    }
  }

  // 添加新问题
  Future<void> _addQuestion() async {
    final result = await Navigator.push<QuizQuestion>(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionEditScreen(
          categories: _categories,
        ),
      ),
    );

    if (result != null) {
      try {
        await _quizService.addQuestion(result);
        _loadData(); // 重新加载数据
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加题目失败: $e')),
        );
      }
    }
  }

  // 编辑问题
  Future<void> _editQuestion(QuizQuestion question) async {
    final result = await Navigator.push<QuizQuestion>(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionEditScreen(
          question: question,
          categories: _categories,
        ),
      ),
    );

    if (result != null) {
      try {
        await _quizService.updateQuestion(result);
        _loadData(); // 重新加载数据
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新题目失败: $e')),
        );
      }
    }
  }

  // 删除问题
  Future<void> _deleteQuestion(QuizQuestion question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.midBlue,
        title: const Text('确认删除', style: TextStyle(color: AppTheme.white)),
        content: const Text('确定要删除该题目吗？此操作不可撤销。',
            style: TextStyle(color: AppTheme.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppTheme.purple)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && question.id != null) {
      try {
        await _quizService.deleteQuestion(question.id!);
        _loadData(); // 重新加载数据
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除题目失败: $e')),
        );
      }
    }
  }

  // 添加新分类
  Future<void> _addCategory() async {
    final result = await showDialog<QuizCategory>(
      context: context,
      builder: (context) => const CategoryEditDialog(),
    );

    if (result != null) {
      try {
        await _quizService.addCategory(result);
        _loadData(); // 重新加载数据
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('分类 "${result.name}" 添加成功'),
                backgroundColor: Colors.green),
          );
        }
      } on MongoDartError catch (e) {
        if (mounted) {
          if (e.message.contains('E11000 duplicate key error')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('添加失败：分类名称 "${result.name}" 已存在'),
                  backgroundColor: Colors.orange),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('添加分类时数据库错误: ${e.message}'),
                  backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加分类失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // 显示分类筛选对话框
  void _showCategoryFilterDialog() {
    // 实现分类筛选对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.midBlue,
        title: const Text('选择分类', style: TextStyle(color: AppTheme.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                // "全部分类" 选项
                return ListTile(
                  title: const Text('全部分类',
                      style: TextStyle(color: AppTheme.white)),
                  selected: _selectedCategory == null,
                  onTap: () {
                    setState(() {
                      _selectedCategory = null;
                    });
                    Navigator.pop(context);
                  },
                  selectedTileColor: AppTheme.purple.withOpacity(0.2),
                  selectedColor: AppTheme.purple,
                );
              } else {
                // 单个分类选项
                final category = _categories[index - 1];
                return ListTile(
                  title: Text(category.name,
                      style: const TextStyle(color: AppTheme.white)),
                  selected: _selectedCategory == category.name,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category.name;
                    });
                    Navigator.pop(context);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: '删除分类',
                    onPressed: () {
                      // 关闭当前对话框，然后显示确认删除对话框
                      Navigator.pop(context);
                      _confirmDeleteCategory(category);
                    },
                  ),
                  selectedTileColor: AppTheme.purple.withOpacity(0.2),
                  selectedColor: AppTheme.purple,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  // 确认删除分类的对话框
  Future<void> _confirmDeleteCategory(QuizCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.midBlue,
        title: const Text('确认删除分类', style: TextStyle(color: AppTheme.white)),
        content: Text(
          '确定要删除分类 "${category.name}" 吗？\n注意：删除分类会同时删除该分类下的所有问题！此操作不可撤销。',
          style: const TextStyle(color: AppTheme.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppTheme.purple)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && category.id != null) {
      try {
        await _quizService.deleteCategory(category.id!);
        // 如果删除的是当前选中的分类，则清除选中状态
        if (_selectedCategory == category.name) {
          setState(() {
            _selectedCategory = null;
          });
        }
        _loadData(); // 重新加载数据
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('分类 "${category.name}" 已删除'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除分类失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        "QuizManagementScreen: build called. _isAuthenticated = $_isAuthenticated");
    final filteredQuestions = _getFilteredQuestions();

    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlue,
        title: const Text(
          '题库管理',
          style: TextStyle(color: AppTheme.white),
        ),
        actions: _isAuthenticated
            ? [
                IconButton(
                  icon: const Icon(Icons.category, color: AppTheme.white),
                  onPressed: _addCategory,
                  tooltip: '添加分类',
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list, color: AppTheme.white),
                  onPressed: _showCategoryFilterDialog,
                  tooltip: '筛选分类',
                ),
              ]
            : null,
        iconTheme: const IconThemeData(color: AppTheme.white),
        elevation: 0,
      ),
      body: !_isAuthenticated
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
              ),
            )
          : _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
                  ),
                )
              : filteredQuestions.isEmpty
                  ? _buildEmptyView()
                  : _buildQuestionsList(filteredQuestions),
      floatingActionButton: _isAuthenticated
          ? FloatingActionButton(
              onPressed: _addQuestion,
              backgroundColor: AppTheme.purple,
              child: const Icon(Icons.add, color: AppTheme.white),
            )
          : null,
    );
  }

  // 空列表视图
  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 80,
              color: AppTheme.purple.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              '暂无题目',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedCategory == null
                  ? '点击下方的加号按钮添加第一道题目'
                  : '当前分类没有题目，请添加或选择其他分类',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 题目列表
  Widget _buildQuestionsList(List<QuizQuestion> questions) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: AppTheme.midBlue,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分类标签
                if (question.categoryName.isNotEmpty)
                  Chip(
                    label: Text(
                      question.categoryName,
                      style: const TextStyle(
                        color: AppTheme.white,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: AppTheme.purple.withOpacity(0.6),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(height: 8),
                // 题目文本
                Text(
                  question.questionText,
                  style: const TextStyle(
                    color: AppTheme.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // 选项列表
                ...question.options.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: entry.key == question.correctOptionIndex
                                    ? Colors.green.withOpacity(0.7)
                                    : AppTheme.darkBlue.withOpacity(0.7),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(
                                      65 + entry.key), // A, B, C, D
                                  style: const TextStyle(
                                    color: AppTheme.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color:
                                      entry.key == question.correctOptionIndex
                                          ? Colors.green
                                          : AppTheme.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                // 解释文本 (如果有)
                if (question.explanation.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.darkBlue),
                  const SizedBox(height: 8),
                  Text(
                    '解释: ${question.explanation}',
                    style: TextStyle(
                      color: AppTheme.white.withOpacity(0.7),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                // 操作按钮
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppTheme.white),
                      onPressed: () => _editQuestion(question),
                      tooltip: '编辑',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteQuestion(question),
                      tooltip: '删除',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 问题编辑屏幕
class QuestionEditScreen extends StatefulWidget {
  final QuizQuestion? question;
  final List<QuizCategory> categories;

  const QuestionEditScreen({
    super.key,
    this.question,
    required this.categories,
  });

  @override
  State<QuestionEditScreen> createState() => _QuestionEditScreenState();
}

// 问题编辑屏幕状态
class _QuestionEditScreenState extends State<QuestionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final _imageAssetPathController = TextEditingController(); // 新增图片路径控制器
  int _correctAnswerIndex = 0;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();

    if (widget.question != null) {
      // 编辑模式：加载现有题目数据
      _questionController.text = widget.question!.questionText;
      _explanationController.text = widget.question!.explanation;
      _correctAnswerIndex = widget.question!.correctOptionIndex;
      _selectedCategory = widget.question!.categoryName;
      _imageAssetPathController.text =
          widget.question!.imageAssetPath ?? ''; // 初始化图片路径

      // 加载选项
      for (int i = 0; i < widget.question!.options.length; i++) {
        if (i < _optionControllers.length) {
          _optionControllers[i].text = widget.question!.options[i];
        }
      }
    } else {
      // 新建模式：设置默认分类
      _selectedCategory =
          widget.categories.isNotEmpty ? widget.categories.first.name : null;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    _imageAssetPathController.dispose(); // 释放图片路径控制器
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveQuestion() {
    if (_formKey.currentState?.validate() != true) return;

    // 收集选项
    final options =
        _optionControllers.map((controller) => controller.text.trim()).toList();
    final imagePath = _imageAssetPathController.text.trim(); // 获取图片路径

    final newQuestion = QuizQuestion(
      id: widget.question?.id, // 编辑模式保留原ID
      questionText: _questionController.text.trim(),
      options: options,
      correctOptionIndex: _correctAnswerIndex,
      explanation: _explanationController.text.trim(),
      categoryName: _selectedCategory ?? '未分类',
      imageAssetPath:
          imagePath.isNotEmpty ? imagePath : null, // 如果路径非空则使用，否则为null
    );

    Navigator.pop(context, newQuestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBlue,
        title: Text(
          widget.question != null ? '编辑题目' : '添加题目',
          style: const TextStyle(color: AppTheme.white),
        ),
        iconTheme: const IconThemeData(color: AppTheme.white),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _saveQuestion,
            icon: const Icon(Icons.save, color: AppTheme.white),
            label: const Text(
              '保存',
              style: TextStyle(color: AppTheme.white),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 分类选择
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: '选择分类',
                labelStyle: TextStyle(color: AppTheme.white),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.purple),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightBlue),
                ),
              ),
              dropdownColor: AppTheme.midBlue,
              items: widget.categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category.name,
                  child: Text(
                    category.name,
                    style: const TextStyle(color: AppTheme.white),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请选择分类';
                }
                return null;
              },
              style: const TextStyle(color: AppTheme.white),
            ),
            const SizedBox(height: 16),

            // 问题文本
            TextFormField(
              controller: _questionController,
              style: const TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: '问题',
                labelStyle: const TextStyle(color: AppTheme.white),
                hintText: '请输入问题内容',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.purple),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightBlue),
                ),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '问题不能为空';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 图片资源路径输入框 (新增)
            TextFormField(
              controller: _imageAssetPathController,
              style: const TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: '图片资源路径 (可选)',
                labelStyle: const TextStyle(color: AppTheme.white),
                hintText: '例如: assets/quiz_images/earth.png',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.purple),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightBlue),
                ),
              ),
              // 这里可以添加 validator，例如检查路径格式，但暂时保持简单
            ),
            const SizedBox(height: 24),

            // 选项
            const Text(
              '选项',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 选项列表
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // 正确答案选择
                    Radio<int>(
                      value: index,
                      groupValue: _correctAnswerIndex,
                      onChanged: (value) {
                        setState(() {
                          _correctAnswerIndex = value!;
                        });
                      },
                      activeColor: AppTheme.purple,
                    ),
                    // 选项标识
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _correctAnswerIndex == index
                            ? AppTheme.purple.withOpacity(0.2)
                            : AppTheme.darkBlue,
                        border: Border.all(color: AppTheme.purple),
                      ),
                      child: Text(
                        String.fromCharCode(65 + index),
                        style: TextStyle(
                          color: _correctAnswerIndex == index
                              ? AppTheme.purple
                              : AppTheme.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 选项内容
                    Expanded(
                      child: TextFormField(
                        controller: _optionControllers[index],
                        style: const TextStyle(color: AppTheme.white),
                        decoration: InputDecoration(
                          hintText: '选项 ${String.fromCharCode(65 + index)}',
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.7)),
                          border: const OutlineInputBorder(),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.purple),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.lightBlue),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '选项不能为空';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // 答案解释
            TextFormField(
              controller: _explanationController,
              style: const TextStyle(color: AppTheme.white),
              decoration: InputDecoration(
                labelText: '答案解释',
                labelStyle: const TextStyle(color: AppTheme.white),
                hintText: '请输入答案解释',
                hintStyle: TextStyle(color: AppTheme.white.withOpacity(0.7)),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.purple),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightBlue),
                ),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '答案解释不能为空';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 分类编辑对话框
class CategoryEditDialog extends StatefulWidget {
  final QuizCategory? category;

  const CategoryEditDialog({super.key, this.category});

  @override
  State<CategoryEditDialog> createState() => _CategoryEditDialogState();
}

// 分类编辑对话框状态
class _CategoryEditDialogState extends State<CategoryEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      if (widget.category!.description != null) {
        _descriptionController.text = widget.category!.description!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (_formKey.currentState?.validate() != true) return;

    final newCategory = QuizCategory(
      id: widget.category?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
    );

    Navigator.pop(context, newCategory);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.midBlue,
      title: Text(
        widget.category != null ? '编辑分类' : '添加分类',
        style: const TextStyle(color: AppTheme.white),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              style: const TextStyle(color: AppTheme.white),
              decoration: const InputDecoration(
                labelText: '分类名称',
                labelStyle: TextStyle(color: AppTheme.white),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.purple),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightBlue),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '分类名称不能为空';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              style: const TextStyle(color: AppTheme.white),
              decoration: const InputDecoration(
                labelText: '分类描述 (可选)',
                labelStyle: TextStyle(color: AppTheme.white),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.purple),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.lightBlue),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: AppTheme.white)),
        ),
        TextButton(
          onPressed: _saveCategory,
          child: const Text('保存', style: TextStyle(color: AppTheme.purple)),
        ),
      ],
    );
  }
}
