/// نقطة الربط لخدمة معلومات الأعطال (Fault Details API).
///
/// ⚠️ لم تُحدد تفاصيل الـ API بعد (العنوان الأساسي، المسارات،
/// صيغة الاستجابة). لذا هذه الخدمة غير مهيأَة بعد: أي
/// نداء لـ [fetchInfo] يرمي [DtcRepositoryNotConfigured] ولا يعيد
/// بيانات مصطنعة أبداً. عند توفير المواصفات:
///   1. عيِّن [baseUrl] والمسارات أدناه.
///   2. عدِّل [fromJson] لتحويل الاستجابة إلى [DtcInfo].
///   3. أضف مفتاح الـ API إلى متغير بيئة / خادم وسيط — ولا
///      تُضمّن أي مفاتيح سرية في كود التطبيق.
abstract class DtcInfoRepository {
  Future<DtcInfo?> fetchInfo(String code);
}

/// حجرة الاستثناء: الخدمة لم تُربَط بعد بالخادم.
class DtcRepositoryNotConfigured implements Exception {
  const DtcRepositoryNotConfigured();

  @override
  String toString() => 'لم تُربَط خدمة معلومات الأعطال بعد.';
}

/// بيانات عطل واحدة قادمة من الـ API.
class DtcInfo {
  const DtcInfo({
    required this.code,
    this.name,
    this.description,
    this.causes = const <String>[],
    this.symptoms = const <String>[],
    this.initialSteps = const <String>[],
    this.recommendedActions = const <String>[],
    this.severity,
    this.source,
  });

  final String code;
  final String? name;
  final String? description;
  final List<String> causes;
  final List<String> symptoms;
  final List<String> initialSteps;
  final List<String> recommendedActions;

  /// مستوى الخطورة (نص حر — يتوقف على ما يدعمه الـ API فعلاً).
  final String? severity;
  final String? source;

  bool get isEmpty => this == const DtcInfo(code: '');

  factory DtcInfo.fromJson(String code, Map<String, dynamic> json) {
    List<String> listOf(dynamic raw) => raw is List
        ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    return DtcInfo(
      code: code,
      name: json['name']?.toString(),
      description: json['description']?.toString(),
      causes: listOf(json['causes']),
      symptoms: listOf(json['symptoms']),
      initialSteps: listOf(json['initialSteps']),
      recommendedActions: listOf(json['recommendedActions']),
      severity: json['severity']?.toString(),
      source: json['source']?.toString(),
    );
  }
}

/// التنفيذ الافتراضي: غير مهيأَ حتَّى تُوفر تفاصيل الخدمة.
class HttpDtcInfoRepository implements DtcInfoRepository {
  // TODO(API): عيِّن العنوان الأساسي بمجرد توفير المواصفات — مثال:
  // static const String? baseUrl = 'https://<your-api-host>';
  static const String? baseUrl = null;

  @override
  Future<DtcInfo?> fetchInfo(String code) async {
    // لا نضاهي نجاحاً باطلاً: نصرّح بوضع عدم التهيئة صراحة.
    throw const DtcRepositoryNotConfigured();
  }
}
