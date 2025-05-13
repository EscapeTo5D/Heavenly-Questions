import 'package:flutter/material.dart';
import '../screens/main_screen.dart' hide ProfileScreen;
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/about_screen.dart';
import '../screens/astronomy_quiz_screen.dart';
import '../screens/quiz_management_screen.dart';

class AppRoutes {
  static const String main = '/';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String articleDetail = '/article_detail';
  static const String astronomyQuiz = '/astronomy_quiz';
  static const String quizManagement = '/quiz_management';

  static Map<String, WidgetBuilder> routes = {
    main: (context) => const MainScreen(), // 修改主入口直接为主页面
    home: (context) => const MainScreen(),
    profile: (context) => const ProfileScreen(),
    settings: (context) => const SettingsScreen(),
    about: (context) => const AboutScreen(),
    astronomyQuiz: (context) => const AstronomyQuizScreen(),
    quizManagement: (context) => const QuizManagementScreen(),
    // 文章详情页需要传递参数，所以通常不会直接通过命名路由导航
    // 而是使用MaterialPageRoute，如HomeScreen中所示
  };
}
