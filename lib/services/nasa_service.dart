import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/nasa_apod.dart';
import 'translate_service.dart';

class NasaService {
  // NASA API的URL和密钥
  // 注意：这里使用的是NASA的公共API密钥DEMO_KEY，在实际应用中建议申请自己的API密钥
  static const String _baseUrl = 'https://api.nasa.gov/planetary/apod';
  static const String _apiKey = 'n2fbtciV8OTgGTkgOlLbzn8RivfbSKumGjpbWTtp';

  // 翻译服务实例
  final TranslateService _translateService = TranslateService();

  // 定义HTTP客户端，以便能在请求之间共享连接
  final http.Client _client = http.Client();

  // 上次请求时间跟踪，用于限制请求频率
  DateTime _lastRequestTime =
      DateTime.now().subtract(const Duration(seconds: 5));

  // 检查是否需要等待API限流
  Future<void> _checkRateLimit() async {
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastRequestTime);

    // 确保请求间隔至少1秒
    if (timeSinceLastRequest < const Duration(milliseconds: 1200)) {
      final waitTime =
          const Duration(milliseconds: 1200) - timeSinceLastRequest;
      await Future.delayed(waitTime);
    }

    _lastRequestTime = DateTime.now();
  }

  // 获取NASA每日一图数据
  Future<NasaApod> getAstronomyPictureOfDay() async {
    try {
      await _checkRateLimit();

      final response = await _client
          .get(Uri.parse('$_baseUrl?api_key=$_apiKey'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // 解析API返回的JSON数据
        NasaApod apod = NasaApod.fromJson(json.decode(response.body));

        // 使用批量翻译方法翻译单个APOD
        await _batchTranslateApods([apod]);

        return apod;
      } else if (response.statusCode == 429) {
        // 特别处理429错误
        throw Exception('获取NASA每日一图失败: API请求过于频繁(429)，请稍后再试');
      } else {
        throw Exception('获取NASA每日一图失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取NASA每日一图时出错: $e');
    }
  }

  // 获取指定日期的NASA每日一图
  Future<NasaApod> getAstronomyPictureByDate(DateTime date) async {
    try {
      // 检查日期是否为未来日期
      final now = DateTime.now();
      if (date.isAfter(now)) {
        // 处理未来日期的请求
        throw Exception('请求的日期 ${_formatDate(date)} 是未来日期，NASA尚未发布该日的图片');
      }

      await _checkRateLimit();

      // 格式化日期为YYYY-MM-DD
      final formattedDate = _formatDate(date);

      final response = await _client
          .get(Uri.parse('$_baseUrl?api_key=$_apiKey&date=$formattedDate'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        NasaApod apod = NasaApod.fromJson(json.decode(response.body));

        // 使用批量翻译方法翻译单个APOD
        await _batchTranslateApods([apod]);

        return apod;
      } else if (response.statusCode == 429) {
        // 特别处理429错误
        throw Exception('获取指定日期的NASA图片失败: API请求过于频繁(429)，请稍后再试');
      } else {
        throw Exception('获取指定日期的NASA图片失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取指定日期的NASA图片时出错: $e');
    }
  }

  // 格式化日期为YYYY-MM-DD格式
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 一次性获取多个日期的NASA图片
  Future<List<NasaApod>> getBatchAstronomyPictures(
      DateTime startDate, int count) async {
    try {
      List<Future<http.Response>> requests = [];
      List<DateTime> dates = [];

      // 准备多个日期
      DateTime currentDate = startDate;

      // 限制同时请求数，避免429错误
      final actualCount = min(count, 5);

      for (int i = 0; i < actualCount; i++) {
        // 检查日期是否在有效范围内
        if (currentDate.isAfter(DateTime.now())) {
          currentDate = currentDate.subtract(const Duration(days: 1));
          continue;
        }

        if (currentDate.isBefore(DateTime(1995, 6, 16))) {
          break;
        }

        final formattedDate = _formatDate(currentDate);

        dates.add(currentDate);

        // 不再并行请求，而是顺序请求
        await _checkRateLimit();

        try {
          final response = await _client
              .get(Uri.parse('$_baseUrl?api_key=$_apiKey&date=$formattedDate'))
              .timeout(const Duration(seconds: 10));

          requests.add(Future.value(response));
        } catch (e) {
          print('请求日期 $formattedDate 时出错: $e');
          requests.add(Future.error(e));
        }

        currentDate = currentDate.subtract(const Duration(days: 1));
      }

      // 解析响应
      List<NasaApod> validApods = [];
      for (int i = 0; i < requests.length; i++) {
        try {
          final response = await requests[i];
          if (response.statusCode == 200) {
            NasaApod apod = NasaApod.fromJson(json.decode(response.body));
            if (apod.mediaType != 'video') {
              // 过滤掉视频
              validApods.add(apod);
            }
          } else if (response.statusCode == 429) {
            print('API请求过于频繁(429)，跳过当前日期: ${_formatDate(dates[i])}');
          }
        } catch (e) {
          print(
              '处理日期 ${dates.isNotEmpty && i < dates.length ? _formatDate(dates[i]) : "未知"} 的响应时出错: $e');
        }
      }

      // 一次性批量翻译所有图片
      if (validApods.isNotEmpty) {
        await _batchTranslateApods(validApods);
      }

      return validApods;
    } catch (e) {
      throw Exception('批量获取NASA图片时出错: $e');
    }
  }

  // 批量翻译多个APOD对象
  Future<void> _batchTranslateApods(List<NasaApod> apods) async {
    try {
      if (apods.isEmpty) return;

      // 单个处理每个APOD
      const qpsThrottle = Duration(milliseconds: 200); // 控制QPS=5
      int count = 0;

      for (final apod in apods) {
        try {
          // 分开翻译标题和说明，避免JSON格式问题
          final translatedTitle = await _translateService.translate(apod.title,
              from: 'en', to: 'zh');

          // 直接检查翻译结果是否为JSON数组格式
          if (translatedTitle.startsWith('[') &&
              translatedTitle.endsWith(']')) {
            try {
              // 尝试解析JSON数组
              final List<dynamic> titleArray = jsonDecode(translatedTitle);
              if (titleArray.isNotEmpty && titleArray[0] is String) {
                apod.translatedTitle = titleArray[0];
              } else {
                apod.translatedTitle = translatedTitle;
              }
            } catch (e) {
              // JSON解析失败，直接使用原始结果
              apod.translatedTitle = translatedTitle;
            }
          } else {
            // 不是JSON数组，直接使用
            apod.translatedTitle = translatedTitle;
          }

          // 控制QPS
          count++;
          if (count % 5 == 0) await Future.delayed(qpsThrottle);

          // 翻译说明文本
          final translatedExplanation = await _translateService
              .translate(apod.explanation, from: 'en', to: 'zh');

          // 同样检查说明文本的格式
          if (translatedExplanation.startsWith('[') &&
              translatedExplanation.endsWith(']')) {
            try {
              final List<dynamic> expArray = jsonDecode(translatedExplanation);
              if (expArray.isNotEmpty && expArray[0] is String) {
                apod.translatedExplanation = expArray[0];
              } else {
                apod.translatedExplanation = translatedExplanation;
              }
            } catch (e) {
              apod.translatedExplanation = translatedExplanation;
            }
          } else {
            apod.translatedExplanation = translatedExplanation;
          }

          print('NASA图片翻译成功: ${apod.translatedTitle}');
        } catch (e) {
          print('翻译单个APOD失败: $e');
        }

        // 控制QPS
        count++;
        if (count % 5 == 0) await Future.delayed(qpsThrottle);
      }

      print('翻译完成，共处理 ${apods.length} 个NASA图片');
    } catch (e) {
      print('批量翻译NASA内容失败: $e');
    }
  }

  // 检查翻译结果是否有效
  bool _isValidTranslation(String? translated, String original) {
    if (translated == null || translated.isEmpty) return false;

    // 检查翻译结果是否与原文完全相同（未翻译）
    if (translated == original) return false;

    // 检查翻译结果是否包含原始JSON格式（表示翻译API可能未正确处理输入）
    if (translated.contains('[') &&
        translated.contains(']') &&
        translated.contains('"') &&
        translated.contains(',')) {
      try {
        // 尝试解析结果，如果可以解析为JSON数组，则可能是翻译失败
        var decoded = jsonDecode(translated);
        if (decoded is List) return false;
      } catch (e) {
        // 解析失败，不是有效的JSON，可能是正常翻译
      }
    }

    return true;
  }

  // 析构函数，关闭HTTP客户端
  void dispose() {
    _client.close();
  }
}
