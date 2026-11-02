import 'dart:convert';

import 'package:http/http.dart' as http;

class ObdAnalysisApi {
  static final Uri _endpoint =
      Uri.parse('https://backend-obd.onrender.com/api/sendcoomend');

  Future<Map<String, dynamic>> analyzeCommand({
    required String command,
    required String response,
  }) async {
    final client = http.Client();
    try {
      final httpResponse = await client
          .post(
            _endpoint,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'command': command, 'response': response}),
          )
          // // كانت المهلة 10 ثوانٍ؛ خدمة الاستضافة تبدأ ببرودة (cold start)
          // // وتستغرق حتى ~17-40 ثانية فيبدأ التحليل بالفشل رغم صحته.
          // // التحليل يعمل الآن في الخلفية (unawaited) فلا يؤخر أي أمر.
          // .timeout(const Duration(seconds: 10)),
          .timeout(const Duration(seconds: 30));

      if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
        throw Exception('HTTP ${httpResponse.statusCode}: ${httpResponse.body}');
      }

      final dynamic decoded = jsonDecode(utf8.decode(httpResponse.bodyBytes));
      if (decoded is! Map) {
        throw Exception('صيغة استجابة API غير صالحة');
      }
      if (decoded['status'] != true) {
        throw Exception(decoded['message']?.toString() ?? 'فشل تحليل API');
      }

      final data = decoded['data'];
      if (data is! Map || data['success'] == false) {
        throw Exception('لم تُرجع خدمة API بيانات ناجحة');
      }
      final analysis = data['analysis'];
      if (analysis is! Map) {
        throw Exception('حقل analysis غير موجود في استجابة API');
      }
      return Map<String, dynamic>.from(analysis);
    } finally {
      client.close();
    }
  }
}
