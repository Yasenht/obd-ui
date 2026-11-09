import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:DriveScope/models/dtc_analysis.dart';

void main() {
  test('يفك استجابة /api/analyze/dtc بكل حقول DtcFaultSchema', () {
    final payload = jsonDecode('''
    {
      "success": true,
      "codes": ["P0301"],
      "status": "faults_detected",
      "title": "تم اكتشاف أعطال",
      "description": "تم تحليل 1 رمز عطل في السيارة.",
      "totalFaults": 1,
      "faults": [
        {
          "code": "P0301",
          "category": "Powertrain",
          "type": "Misfire",
          "nameEn": "Cylinder 1 Misfire Detected",
          "title": "خلل في احتراق الأسطوانة الأولى",
          "description": "وصف العطل",
          "system": "Ignition",
          "meaning": "معنى العطل",
          "severity": "high",
          "severityPercentage": 82,
          "severityExplanation": "شرح الخطورة",
          "possibleCauses": ["بوجيه تالف", "ملف إشعال"],
          "possibleSymptoms": ["اهتزاز المحرك"],
          "diagnosticSteps": ["فحص البوجيه"],
          "solutions": ["استبدال البوجيه"],
          "status": "active",
          "confidence": 0.91
        }
      ]
    }
    ''') as Map<String, dynamic>;

    final result = DtcAnalysisResult.fromJson(payload);

    expect(result.success, isTrue);
    expect(result.healthy, isFalse);
    expect(result.totalFaults, 1);
    expect(result.codes, ['P0301']);

    final fault = result.faultForCode('p0301');
    expect(fault, isNotNull);
    expect(fault!.code, 'P0301');
    expect(fault.nameEn, 'Cylinder 1 Misfire Detected');
    expect(fault.title, 'خلل في احتراق الأسطوانة الأولى');
    expect(fault.description, 'وصف العطل');
    expect(fault.severity, 'high');
    expect(fault.severityPercentage, 82);
    expect(fault.confidence, closeTo(0.91, 0.0001));
    expect(fault.possibleCauses, ['بوجيه تالف', 'ملف إشعال']);
    expect(fault.possibleSymptoms, ['اهتزاز المحرك']);
    expect(fault.diagnosticSteps, ['فحص البوجيه']);
    expect(fault.solutions, ['استبدال البوجيه']);
    expect(fault.failed, isFalse);
  });

  test('يعرض مدخل فشل كود واحد كما أرسله الخادم', () {
    final result = DtcAnalysisResult.fromJson({
      'success': true,
      'codes': ['P0301'],
      'status': 'faults_detected',
      'title': 'تم اكتشاف أعطال',
      'description': 'تم تحليل 1 رمز عطل في السيارة.',
      'totalFaults': 1,
      'faults': [
        {
          'code': 'P0301',
          'success': false,
          'error': 'تعذر تحليل رمز العطل',
        }
      ],
    });

    final fault = result.faultForCode('P0301')!;
    expect(fault.failed, isTrue);
    expect(fault.error, 'تعذر تحليل رمز العطل');
    expect(fault.description, isNull);
  });

  test('يفك استجابة السيارة السليمة (أكواد فارغة)', () {
    final result = DtcAnalysisResult.fromJson({
      'success': true,
      'codes': [],
      'status': 'healthy',
      'title': 'السيارة سليمة',
      'description': 'لم يتم العثور على أي رموز أعطال في السيارة.',
      'totalFaults': 0,
      'faults': [],
    });

    expect(result.healthy, isTrue);
    expect(result.codes, isEmpty);
    expect(result.faults, isEmpty);
    expect(result.totalFaults, 0);
    expect(result.title, 'السيارة سليمة');
  });
}
