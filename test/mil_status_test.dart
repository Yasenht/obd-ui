import 'package:flutter_test/flutter_test.dart';

import 'package:drive_scope/obd_protocol.dart';

void main() {
  group('parseMilStatus — فك حالة MIL وجاهزية I/M من رد 0101', () {
    test('الصيغة القياسية 41 01 A B C D — MIL مطفأ بلا أكواد', () {
      // A=00: MIL مطفأ (البت الأعلى 0) وعدد أكواد 0.
      final status = ObdParser.parseMilStatus('41 01 00 00 00 00\r');
      expect(status, isNotNull);
      expect(status!.milOn, isFalse);
      expect(status.dtcCount, 0);
      // B=C=D=00: كل الاختبارات المعروفة مكتملة.
      expect(status.readiness, isNotEmpty);
      expect(status.incompleteTests, isEmpty);
    });

    test('الصيغة القياسية — MIL مضاء مع ثلاثة أكواد', () {
      // A=83: 0x80 (MIL مضاء) + 0x03 (ثلاثة أكواد).
      final status = ObdParser.parseMilStatus('41 01 83 00 00 00\r');
      expect(status!.milOn, isTrue);
      expect(status.dtcCount, 3);
    });

    test('الصيغة القياسية — أعلام جاهزية I/M غير المكتملة من B', () {
      // B=05: بت 0x01 (أخطاء الاشتعال) + بت 0x04 (المكونات) غير مكتملة.
      final status = ObdParser.parseMilStatus('41 01 82 05 00 00\r');
      expect(status!.milOn, isTrue);
      expect(status.dtcCount, 2);
      final names =
          status.incompleteTests.map((t) => t.name).toList();
      expect(names, contains('أخطاء الاشتعال (Misfire)'));
      expect(names, contains('المكونات الرئيسية'));
      // نظام الوقود (بت 0x02) غير مضبوط — مكتمل.
      expect(names, isNot(contains('نظام الوقود')));
      // بايتات C/D صفرية: اختباراتها كلها مكتملة.
      expect(status.incompleteTests.length, 2);
    });

    test('الصيغة القياسية — علم جاهزية من بايت C (نظام التبخير)', () {
      // C=08: نظام التبخير EVAP غير مكتمل.
      final status = ObdParser.parseMilStatus('41 01 00 00 08 00\r');
      expect(status!.incompleteTests
          .map((t) => t.name), contains('نظام التبخير (EVAP)'));
    });

    test('رد الفيرموير الرقمي المباشر: بايت A فقط بلا جاهزية', () {
      // الفيرموير يرد بقيمة بايت A الخام (131 = MIL مضاء + 3 أكواد).
      final status = ObdParser.parseMilStatus('131\r');
      expect(status!.milOn, isTrue);
      expect(status.dtcCount, 3);
      expect(status.readiness, isEmpty);
      expect(status.incompleteTests, isEmpty);
    });

    test('الرد الخطأ وأشكال غير قابلة للفك تعيد null', () {
      expect(ObdParser.parseMilStatus('ERROR\r'), isNull);
      expect(ObdParser.parseMilStatus('NO DATA\r'), isNull);
      expect(ObdParser.parseMilStatus('SEARCHING...\r\nSTOPPED\r'), isNull);
    });
  });
}
