import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

class TranslateService {
  final Dio _dio = Dio();
  // 百度翻译API信息
  static const String _appId = "20210203000689126";
  static const String _appSecret = "oqGThN39FXq5K8xq0Auy";
  static const String _baseUrl =
      "https://fanyi-api.baidu.com/api/trans/vip/translate";

  // 用于存储已翻译内容的缓存
  static final Map<String, String> _translationCache = {};

  // 获取缓存中的所有翻译结果
  Map<String, String> get translationCache =>
      Map.unmodifiable(_translationCache);

  // 清除缓存
  void clearCache() {
    _translationCache.clear();
  }

  // 添加翻译结果到缓存
  void addToCache(String key, String translatedText) {
    _translationCache[key] = translatedText;
  }

  // 从缓存中获取翻译结果
  String? getFromCache(String key) {
    return _translationCache[key];
  }

  // 翻译文本
  Future<String> translate(String text,
      {String from = 'auto', String to = 'zh'}) async {
    // 如果文本为空，直接返回
    if (text.isEmpty) {
      return text;
    }

    // 检查缓存
    final cacheKey = "$from-$to-$text";
    if (_translationCache.containsKey(cacheKey)) {
      print('从缓存中获取翻译结果: "$text" -> "${_translationCache[cacheKey]!}"');
      return _translationCache[cacheKey]!;
    }

    try {
      // 生成随机数
      final salt = _generateSalt();

      // 生成签名: appid+q+salt+密钥
      final sign = _generateSign(text, salt);

      // 准备请求数据
      Map<String, String> params = {
        'q': text,
        'from': from,
        'to': to,
        'appid': _appId,
        'salt': salt,
        'sign': sign,
      };

      // 打印请求参数（不包含密钥）
      Map<String, String> debugParams = Map.from(params);
      debugParams.remove('sign');
      print('百度翻译请求参数: $debugParams');

      // 使用Dio发送请求
      final options = Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      final response = await _dio.post(
        _baseUrl,
        data: FormData.fromMap(params),
        options: options,
      );

      // 打印完整响应
      print('百度翻译响应码: ${response.statusCode}');
      print('百度翻译响应头: ${response.headers}');
      print('百度翻译响应体: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;

        // 检查结果
        if (data['trans_result'] != null && data['trans_result'].isNotEmpty) {
          final translatedText = data['trans_result'][0]['dst'];

          // 存入缓存
          _translationCache[cacheKey] = translatedText;

          return translatedText;
        } else {
          print('翻译结果为空，但API返回成功');
          return text; // 返回原文
        }
      } else {
        print('翻译请求失败: ${response.statusCode}, 响应: ${response.data}');
        return text; // 返回原文
      }
    } catch (e) {
      print('翻译过程发生异常: $e');
      // 翻译失败时返回原文
      return text;
    }
  }

  // 批量翻译多个文本
  Future<Map<String, String>> batchTranslate(List<String> texts,
      {String from = 'auto', String to = 'zh'}) async {
    final Map<String, String> results = {};

    if (texts.isEmpty) {
      return results;
    }

    // 筛选出需要翻译的文本（过滤掉空文本和已缓存的文本）
    Map<String, String> cachedResults = {};
    List<String> textsToTranslate = [];

    for (final text in texts) {
      if (text.isEmpty) {
        results[text] = text;
        continue;
      }

      // 检查缓存
      final cacheKey = "$from-$to-$text";
      if (_translationCache.containsKey(cacheKey)) {
        cachedResults[text] = _translationCache[cacheKey]!;
        print('从缓存中获取批量翻译结果: "$text" -> "${_translationCache[cacheKey]!}"');
      } else {
        textsToTranslate.add(text);
      }
    }

    // 将缓存结果添加到结果中
    results.addAll(cachedResults);

    // 如果没有需要翻译的文本，直接返回缓存结果
    if (textsToTranslate.isEmpty) {
      return results;
    }

    try {
      // 由于百度翻译对长文本有限制，最好一次处理一个文本
      for (final text in textsToTranslate) {
        if (text.isNotEmpty) {
          final translated = await translate(text, from: from, to: to);
          results[text] = translated;
        } else {
          results[text] = text;
        }
      }
    } catch (e) {
      print('批量翻译过程发生异常: $e');
      // 错误处理：对未完成的文本进行单独翻译
      for (final text in textsToTranslate) {
        if (!results.containsKey(text)) {
          try {
            final translated = await translate(text, from: from, to: to);
            results[text] = translated;
          } catch (e) {
            print('单独翻译文本失败: $e');
            results[text] = text; // 失败时返回原文
          }
        }
      }
    }

    return results;
  }

  // 生成盐值（随机数）
  String _generateSalt() {
    var random = Random();
    return random.nextInt(1000000).toString();
  }

  // 生成签名
  String _generateSign(String text, String salt) {
    String signStr = _appId + text + salt + _appSecret;
    return md5.convert(utf8.encode(signStr)).toString();
  }
}
