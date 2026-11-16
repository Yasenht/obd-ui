import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:drive_scope/models/dtc_analysis.dart';
import 'package:drive_scope/obd_protocol.dart';
import 'package:drive_scope/services/report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DiagnosticReportData fullData() {
    return DiagnosticReportData(
      vehicleLabel: '2019 Toyota Corolla',
      vin: 'WVWZZ8ZW123456789',
      scannedAt: DateTime(2026, 11, 15, 14, 30),
      dtcCodes: const <String>['P0128', 'P0301'],
      freezeFrameCodes: const <String>['P0128'],
      milStatus: ObdParser.parseMilStatus('41 01 83 05 00 00\r'),
      liveMetrics: const <String, String>{
        'دورات المحرك': '850 RPM',
        'السرعة': '0 km/h',
        'حرارة سائل التبريد': '76 °C',
      },
      analysis: DtcAnalysisResult(
        success: true,
        status: 'faults_detected',
        title: 'تم اكتشاف أعطال',
        description: 'تم تحليل 2 رمز عطل في السيارة.',
        totalFaults: 2,
        codes: const <String>['P0128', 'P0301'],
        faults: <DtcFault>[
          const DtcFault(
            code: 'P0128',
            success: true,
            title: 'حرارة سائل التبريد أقل من المطلوب',
            nameEn: 'Coolant Thermostat (Coolant Temperature Below '
                'Thermostat Regulating Temperature)',
            description: 'حرارة المحرك أدنى من درجة الحرارة التنظيمية.',
            meaning: 'لا يصل المحرك لدرجة التشغيل الصحيحة.',
            severity: 'high',
            severityPercentage: 65,
            severityExplanation: 'تؤثر على كفاءة الوقود والانبعاثات.',
            possibleCauses: <String>['ترموستات عالق مفتوحاً'],
            possibleSymptoms: <String>['تدفئة ضعيفة'],
            diagnosticSteps: <String>['فحص الترموستات'],
            solutions: <String>['استبدال الترموستات'],
            status: 'confirmed',
            confidence: 0.9,
          ),
          const DtcFault(
            code: 'P0301',
            success: true,
            title: 'خطأ اشتعال في الأسطوانة الأولى',
            nameEn: 'Cylinder 1 Misfire Detected',
            description: 'اكتُشف خطأ اشتعال متكرر في الأسطوانة 1.',
            meaning: 'احتراق غير مكتمل في أسطوانة واحدة.',
            severity: 'critical',
            severityPercentage: 85,
            possibleCauses: <String>['بواجي تالفة', 'مباسل متهالكة'],
            diagnosticSteps: <String>['فحص البواجي'],
            solutions: <String>['استبدال البواجي'],
            status: 'confirmed',
            confidence: 0.85,
          ),
        ],
      ),
    );
  }

  DiagnosticReportData minimalData() {
    return DiagnosticReportData(
      vehicleLabel: null,
      vin: null,
      scannedAt: DateTime(2026, 11, 15),
      dtcCodes: const <String>[],
      freezeFrameCodes: const <String>[],
      milStatus: null,
      liveMetrics: const <String, String>{},
      analysis: null,
    );
  }

  group('DiagnosticReportService.build — توليد تقرير PDF', () {
    test('التقرير الكامل: بايتات PDF صالحة بحجم معقول', () async {
      final bytes = await DiagnosticReportService().build(fullData());

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(1000));
      // ترويسة PDF القياسية.
      final header = String.fromCharCodes(bytes.take(8));
      expect(header, startsWith('%PDF'));
    });

    test('التقرير الأدنى (بلا VIN/تحليل/MIL) لا يفشل ويعيد PDF صالحاً',
        () async {
      final bytes = await DiagnosticReportService().build(minimalData());

      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
