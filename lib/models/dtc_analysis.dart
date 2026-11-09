/// نماذج استجابة خدمة تحليل أكواد الأعطال:
/// `POST https://backend-obd.onrender.com/api/analyze/dtc`
///
/// الحقول مطابقة حرفياً لـ `AnalyzeDtcSchema` و`DtcFaultSchema`
/// المرسلين من الخادم — لا حقول مضافة.
library;

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _asInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString() ?? '')
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

/// عطل واحد من `faults` في الاستجابة.
///
/// ملاحظة: عند فشل تحليل كود معيّن يرسل الخادم كائناً مختصراً
/// `{code, success: false, error}` بدل `DtcFaultSchema` الكامل؛
/// لذلك كل حقول التفاصيل هنا قابلة للعدم.
class DtcFault {
  const DtcFault({
    required this.code,
    this.success = true,
    this.error,
    this.category,
    this.type,
    this.nameEn,
    this.title,
    this.description,
    this.system,
    this.meaning,
    this.severity,
    this.severityPercentage,
    this.severityExplanation,
    this.possibleCauses = const <String>[],
    this.possibleSymptoms = const <String>[],
    this.diagnosticSteps = const <String>[],
    this.solutions = const <String>[],
    this.status,
    this.confidence,
  });

  final String code;
  final bool success;
  final String? error;

  final String? category;
  final String? type;
  final String? nameEn;
  final String? title;
  final String? description;
  final String? system;
  final String? meaning;
  final String? severity;
  final double? severityPercentage;
  final String? severityExplanation;
  final List<String> possibleCauses;
  final List<String> possibleSymptoms;
  final List<String> diagnosticSteps;
  final List<String> solutions;
  final String? status;
  final double? confidence;

  bool get failed => success == false;

  factory DtcFault.fromJson(Map<String, dynamic> json) {
    return DtcFault(
      code: json['code']?.toString() ?? '',
      success: json['success'] is bool ? json['success'] as bool : true,
      error: json['error']?.toString(),
      category: json['category']?.toString(),
      type: json['type']?.toString(),
      nameEn: json['nameEn']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      system: json['system']?.toString(),
      meaning: json['meaning']?.toString(),
      severity: json['severity']?.toString(),
      severityPercentage: _asDouble(json['severityPercentage']),
      severityExplanation: json['severityExplanation']?.toString(),
      possibleCauses: _asStringList(json['possibleCauses']),
      possibleSymptoms: _asStringList(json['possibleSymptoms']),
      diagnosticSteps: _asStringList(json['diagnosticSteps']),
      solutions: _asStringList(json['solutions']),
      status: json['status']?.toString(),
      confidence: _asDouble(json['confidence']),
    );
  }

  /// بحث مطابق للكود (حروف كبيرة).
  bool matches(String other) => code.toUpperCase() == other.toUpperCase();
}

/// الاستجابة النهائية لتحليل مجموعة أكواد.
class DtcAnalysisResult {
  const DtcAnalysisResult({
    required this.success,
    required this.status,
    required this.title,
    required this.description,
    required this.totalFaults,
    required this.codes,
    required this.faults,
  });

  final bool success;
  final String status;
  final String title;
  final String description;
  final int totalFaults;
  final List<String> codes;
  final List<DtcFault> faults;

  bool get healthy => status == 'healthy';

  DtcFault? faultForCode(String code) {
    for (final fault in faults) {
      if (fault.matches(code)) return fault;
    }
    return null;
  }

  factory DtcAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawFaults = json['faults'];
    final parsedFaults = rawFaults is List
        ? rawFaults
            .whereType<Map>()
            .map((item) => DtcFault.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <DtcFault>[];

    return DtcAnalysisResult(
      success: json['success'] == true,
      status: json['status']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      totalFaults: _asInt(json['totalFaults']) ?? parsedFaults.length,
      codes: _asStringList(json['codes']),
      faults: parsedFaults,
    );
  }
}
