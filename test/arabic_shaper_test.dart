import 'package:flutter_test/flutter_test.dart';

import 'package:drive_scope/services/arabic_shaper.dart';

/// قيم متوقعة محسوبة يدوياً من جدول الأشكال السياقية
/// (Unicode Arabic Presentation Forms-B) — الكتابة
/// بالأكواد السداسية لوضوح أشكال الاتصال.
void main() {
  group('shapeArabic — تشكيل الحروف وترتيبها المرئي', () {
    test('سلام: س ابتدائي + ليغاتورة لام-ألف نهائية + م معزول', () {
      // الحرف المنطقي الأخير (م) يُرسم أقصى اليسار.
      // FEFC = ليغاتورة لام-ألف النهائية (لام متصلة بس).
      expect(shapeArabic('سلام'), '\u0645\uFEFC\uFEB3');
    });

    test('كود: الواو لا تتصل بما بعدها فالدال معزولة', () {
      expect(shapeArabic('كود'), '\u062F\uFEEE\uFEDB');
    });

    test('عدد: الدال الثانية نهائية متصلة بالدال الأولى', () {
      expect(shapeArabic('عدد'), '\u062F\uFEAA\uFECB');
    });

    test('لا منفردة: ليغاتورة لام-ألف معزولة', () {
      expect(shapeArabic('لا'), '\uFEFB');
    });

    test('مرشّح: الشدة تلتصق بالشين بعد العكس (عنقود)', () {
      // ح ف(شّ) ر م من اليسار — الشدة تبقى بعد شينها.
      expect(shapeArabic('مرشّح'), '\uFEA2\uFEB7\u0651\uFEAE\uFEE3');
    });

    test('كلمة واحدة منتصفها رقم لاتيني يبقى بترتيبه الداخلي', () {
      // 'P0301' غير عربية تُمرَّر كما هي.
      expect(shapeArabic('P0301'), 'P0301');
      expect(shapeArabic('85%'), '85%');
    });

    test('سطر مختلط: الكلمات العربية تُعكس والمقاطع اللاتينية تبقى', () {
      // قراءة RTL: كود (يمين) P0301 الشدة 85% (يسار).
      final out = shapeArabic('كود P0301 الشدة 85%');
      expect(out, '85% \u0629\uFEAA\uFEB8\uFEDF\u0627 P0301 \u062F\uFEEE\uFEDB');
    });

    test('سطر يبدأ بكلمة لاتينية: تبقى في مكانها والعربي يُعكس داخلياً', () {
      final out = shapeArabic('DriveScope — تقرير تشخيص المركبة');
      expect(
        out,
        'DriveScope — '
        '\uFE94\uFE92\uFEDB\uFEAE\uFEE4\uFEDF\u0627 ' // المركبة
        '\uFEBA\uFEF4\uFEA8\uFEB8\uFE97 ' // تشخيص
        '\uFEAE\uFEF3\uFEAE\uFED8\uFE97', // تقرير
      );
    });

    test('قوس لاتيني داخل جملة عربية يبقى سليماً على اليسار', () {
      final out = shapeArabic('مصباح العطل (MIL)');
      expect(
        out,
        '(MIL) '
        '\uFEDE\uFEC4\uFECC\uFEDF\u0627 ' // العطل
        '\u062D\uFE8E\uFE92\uFEBC\uFEE3', // مصباح (ح معزول بعد ا)
      );
    });

    test('فاصلة عربية ملحقة برقم تظليل بين العنصرين', () {
      // P0128، P0301: الفاصلة تظهر بين الكودين بعد العكس.
      final out = shapeArabic('العطل: P0128، P0301');
      // النقطتان تلحقان بنهاية الكلمة (يسارها) بعد العكس —
      // وهذا موضعها الصحيح في العرض.
      expect(out,
          'P0301 \u060C' 'P0128 :\uFEDE\uFEC4\uFECC\uFEDF\u0627');
    });

    test('أرقام بين كلمات عربية تُعكس مواضعها مع الجملة', () {
      final out = shapeArabic('صفحة 1 من 2');
      expect(out, '2 \uFEE6\uFEE3 1 \uFE94\uFEA4\uFED4\uFEBB');
    });

    test('النص اللاتيني الخالص يُمرَّر دون تغيير', () {
      expect(shapeArabic('Cylinder 1 Misfire Detected'),
          'Cylinder 1 Misfire Detected');
      expect(shapeArabic('WVWZZ8ZW123456789'), 'WVWZZ8ZW123456789');
    });

    test('التشكيل مُعرِف (idempotent) — تمريره مرة ثانية لا يغيّره', () {
      const input = 'كود P0301 الشدة 85% مرشّح';
      final once = shapeArabic(input);
      expect(shapeArabic(once), once);
    });

    test('سلاسل فارغة', () {
      expect(shapeArabic(''), '');
    });
  });
}
