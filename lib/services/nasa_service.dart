import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nasa_apod.dart';

class NasaService {
  // NASA API的URL和密钥
  // 注意：这里使用的是NASA的公共API密钥DEMO_KEY，在实际应用中建议申请自己的API密钥
  static const String _baseUrl = 'https://api.nasa.gov/planetary/apod';
  static const String _apiKey = 'n2fbtciV8OTgGTkgOlLbzn8RivfbSKumGjpbWTtp';

  // 获取NASA每日一图数据
  Future<NasaApod> getAstronomyPictureOfDay() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?api_key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        // 解析API返回的JSON数据
        return NasaApod.fromJson(json.decode(response.body));
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
      // 格式化日期为YYYY-MM-DD
      final formattedDate =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final response = await http.get(
        Uri.parse('$_baseUrl?api_key=$_apiKey&date=$formattedDate'),
      );

      if (response.statusCode == 200) {
        return NasaApod.fromJson(json.decode(response.body));
      } else {
        throw Exception('获取指定日期的NASA图片失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取指定日期的NASA图片时出错: $e');
    }
  }
}
