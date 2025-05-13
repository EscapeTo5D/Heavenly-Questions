import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/theme.dart';
import 'utils/routes.dart';
import 'screens/zodiac_sphere_screen.dart';
import 'services/quiz_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 设置状态栏透明
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  // 初始化题库服务
  await QuizService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '星空探索',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routes: AppRoutes.routes,
      initialRoute: AppRoutes.main,
      debugShowCheckedModeBanner: false,
    );
  }
}
