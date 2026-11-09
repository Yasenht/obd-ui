import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dtc_analysis.dart';

/// خطأ في خدمة تحليل أكواد الأعطال برسالة عربية مفهومة.
class DtcAnalysisException implements Exception {
  const DtcAnalysisException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// عميل خدمة تحليل أكواد الأعطال:
///
/// `POST /api/analyze/dtc` بالجسم `{ "codes": ["P0301", ...] }`
/// حسب `InputAnalyzeDtcSchema` (مصفوفة نصوص، حتى 100 عنصر).
class DtcAnalysisService {
  DtcAnalysisService({
    this.endpoint = 'https://backend-obd.onrender.com/api/analyze/dtc',
    this.timeout = const Duration(seconds: 90),
  });

  /// نقطة النهاية المعتمدة لتحليل أكواد mode-03.
  final String endpoint;

  /// تحليل عدة أكواد عبر Gemini يستغرق وقتاً — المهلة قابلة للتعديل.
  final Duration timeout;

  /// إرسال الأكواد المستخرجة من الجهاز إلى الخدمة.
  ///
  /// يعيد [DtcAnalysisResult] عند نجاح الطلب، ويرمي
  /// [DtcAnalysisException] عند فشل الشبكة/المهلة/الاستجابة.
  Future<DtcAnalysisResult> analyzeCodes(List<String> codes) async {
    // مطابقة قيود المخطط: نصوص فريدة بحروف كبيرة، بحد أقصى 100.
    final normalized = <String>[];
    for (final code in codes) {
      final value = code.trim().toUpperCase();
      if (value.isEmpty || normalized.contains(value)) continue;
      normalized.add(value);
      if (normalized.length >= 100) break;
    }

    final client = http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(endpoint),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode({'codes': normalized}),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DtcAnalysisException(
          'تعذر تحليل الأكواد (HTTP ${response.statusCode}).',
        );
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));

      // الخادم يعيد كائن التحليل مباشرة؛ ونتسامح مع تغليف {data: ...}
      // إن اختلف شكل الغلاف مستقبلاً.
      Map<String, dynamic>? payload;
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map['faults'] is List || map.containsKey('success')) {
          payload = map;
        } else if (map['data'] is Map) {
          payload = Map<String, dynamic>.from(map['data'] as Map);
        }
      }

      if (payload == null) {
        throw const DtcAnalysisException(
            'صيغة استجابة تحليل الأكواد غير صالحة.');
      }

      final result = DtcAnalysisResult.fromJson(payload);
      if (!result.success) {
        throw DtcAnalysisException(
          payload['message']?.toString() ?? 'فشل تحليل الأكواد في الخادم.',
        );
      }
      return result;
    } on TimeoutException {
      throw const DtcAnalysisException(
        'انتهت مهلة تحليل الأكواد. تحقق من الاتصال وأعد المحاولة.',
      );
    } on http.ClientException {
      throw const DtcAnalysisException(
        'تعذر الاتصال بخدمة تحليل الأكواد. تحقق من الإنترنت وأعد المحاولة.',
      );
    } on FormatException {
      throw const DtcAnalysisException(
        'استجابة خدمة التحليل ليست JSON صالحاً.',
      );
    } finally {
      client.close();
    }
  }
}
