import 'dart:convert';

/// نتيجة قراءة PID واحدة بعد فك ترميز رد ELM327.
class PidReading {
  const PidReading({
    required this.pid,
    required this.label,
    required this.value,
    required this.unit,
    required this.raw,
  });

  final int pid;
  final String label;
  final num value;
  final String unit;
  final String raw;

  String get displayValue => '$value $unit'.trim();
}

/// سجل فحص محفوظ محلياً لكي يظهر حتى بعد إعادة تشغيل التطبيق.
class InspectionRecord {
  const InspectionRecord({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.result,
    required this.success,
    this.rawResponse = '',
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String result;
  final bool success;
  final String rawResponse;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'result': result,
        'success': success,
        'rawResponse': rawResponse,
      };

  factory InspectionRecord.fromJson(Map<String, dynamic> json) {
    return InspectionRecord(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      title: json['title'] as String? ?? 'فحص',
      result: json['result'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      rawResponse: json['rawResponse'] as String? ?? '',
    );
  }
}

String encodeHistory(List<InspectionRecord> records) =>
    jsonEncode(records.map((record) => record.toJson()).toList());

List<InspectionRecord> decodeHistory(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! List) return <InspectionRecord>[];
  return decoded
      .whereType<Map>()
      .map((item) => InspectionRecord.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
