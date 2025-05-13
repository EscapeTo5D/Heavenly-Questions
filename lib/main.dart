import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/theme.dart';
import 'utils/routes.dart';
import 'services/quiz_service.dart';
import 'services/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 设置状态栏透明
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));

  // 初始化本地存储服务
  await LocalStorageService().init();

  // 使用Future延迟初始化题库服务，不阻塞应用启动
  Future.microtask(() async {
    try {
      print('正在初始化题库服务...');
      await QuizService().initialize();
      print('题库服务初始化成功');
    } catch (e) {
      // 捕获初始化异常，但允许应用继续运行
      print('题库服务初始化失败: $e');
      // 检查是否有本地缓存数据可用
      if (LocalStorageService().hasQuestionsCache()) {
        print('发现本地缓存数据，应用将以离线模式启动');
      } else {
        print('尝试创建默认缓存数据...');
      }
    }
  });

  // 不等待题库服务初始化，直接启动应用
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
