import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/dtc_analysis.dart';
import '../obd_protocol.dart';
import 'arabic_shaper.dart';

// ============================================================
// خدمة تقرير التشخيص (PDF): تجميع نتائج آخر فحص فعلي في مستند
// عربي أنيق — معلومات المركبة وVIN، وقت الفحص، الأكواد،
// إطار التجميد، MIL وجاهزية I/M، البيانات الحية، شرح الأعطال
// وتوصيات الفحص والإصلاح.
//
// تشكيل الحروف العربية: كل نص يُمرَّر عبر [shapeArabic]
// (lib/services/arabic_shaper.dart) الذي ينتج نصاً "مرئياً"
// بأشكال سياقية صحيحة وترتيب RTL سليم — ولا نمرر
// textDirection: rtl إلى pw.Text إطلاقاً لأن حزمة pdf
// تعيد عندها تشكيل النص عبر خوارزمية bidi معيبة وتفسد
// الأشكال. النصوص الطويلة تُكسَّر أسطراً يدوياً بقياس
// عروض الحروف من ملف الخط نفسه (TtfParser) لأن الكسر
// التلقائي مع نص مرئي يقلب ترتيب القراءة.
// ============================================================

/// غلاف يمنع تقسيم الودجة على صفحتين: إن لم تتسع في مساحة
/// الصفحة المتبقية تُنقل كاملة إلى الصفحة التالية (الحزمة
/// تقسّم Container/Column تلقائياً وقد تترك جزءاً فارغاً
/// بإطار في أسفل الصفحة). أما الودجة الأطول من صفحة كاملة
/// (_maxKeepHeight) فتُقسَّم كالمعتاد حتى لا يُرفع استثناء.
class _KeepTogether extends pw.SingleChildWidget {
  _KeepTogether(pw.Widget child) : super(child: child);

  /// أطول ارتفاع يُنقل بلا تقسيم (محتوى صفحة A4 بهوامش
  /// التقرير ≈ 772pt، ونحتفظ بهامش أمان).
  static const double _maxKeepHeight = 720;

  bool _spanning = false;

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);
    final height = box?.height ?? 0;
    if (!_spanning) {
      if (height > _maxKeepHeight) _spanning = true;
    } else {
      final more = child is pw.SpanningWidget &&
          (child as pw.SpanningWidget).hasMoreWidgets;
      if (!more) _spanning = false;
    }
  }

  @override
  bool get canSpan => _spanning;

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
  }
}

/// بيانات التقرير كما جمعت من وحدة التحكم لحظة التوليد.
class DiagnosticReportData {
  const DiagnosticReportData({
    required this.vehicleLabel,
    required this.vin,
    required this.scannedAt,
    required this.dtcCodes,
    required this.freezeFrameCodes,
    required this.milStatus,
    required this.liveMetrics,
    required this.analysis,
  });

  /// "سنة الماركة الموديل" من قسم معلومات المركبة (قد يكون null
  /// إن لم يُكمل المستخدم الاختيار).
  final String? vehicleLabel;

  /// رقم الهيكل (VIN) إن قُرئ من الجهاز سابقاً.
  final String? vin;

  /// لحظة آخر فحص DTC ناجح.
  final DateTime scannedAt;

  /// أكواد الأعطال المكتشفة (وضع 03).
  final List<String> dtcCodes;

  /// أكواد إطار التجميد (وضع 02) إن قُرئت.
  final List<String> freezeFrameCodes;

  /// حالة MIL وجاهزية I/M من "0101" (قد تكون null إن لم تُقرأ).
  final MilStatus? milStatus;

  /// البيانات الحية المجموعة لحظة الفحص (تسمية ← قيمة بوحدتها).
  final Map<String, String> liveMetrics;

  /// استجابة خدمة التحليل (شرح الأعطال والتوصيات) إن وصلت.
  final DtcAnalysisResult? analysis;
}

/// أبعاد الصفحة (A4 بهوامش 36) لحساب عرض النصوص القابلة
/// للالتفاف.
const double _pageContentWidth = 595.28 - 36 - 36; // 523.28pt
const double _cardInnerWidth = _pageContentWidth - 28; // بطاقة بحشو 14

/// باني مستند PDF للتقرير.
class DiagnosticReportService {
  TtfParser? _regularMetrics;
  TtfParser? _boldMetrics;

  /// بناء بايتات التقرير — خالص من الواجهة (قابل للاختبار).
  Future<Uint8List> build(DiagnosticReportData data) async {
    final regularBytes = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final boldBytes = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    final regular = pw.Font.ttf(regularBytes);
    final bold = pw.Font.ttf(boldBytes);
    _regularMetrics = TtfParser(regularBytes);
    _boldMetrics = TtfParser(boldBytes);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      title: 'تقرير تشخيص المركبة — DriveScope',
      author: 'DriveScope',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 40),
        footer: (context) => _footer(context),
        build: (context) => [
          _header(data),
          pw.SizedBox(height: 14),
          _KeepTogether(_vehicleSection(data)),
          pw.SizedBox(height: 14),
          _KeepTogether(_statusSection(data)),
          pw.SizedBox(height: 14),
          _KeepTogether(_dtcSection(data)),
          pw.SizedBox(height: 14),
          _KeepTogether(_freezeFrameSection(data)),
          pw.SizedBox(height: 14),
          _KeepTogether(_liveSection(data)),
          pw.SizedBox(height: 14),
          ..._faultsSections(data),
          pw.SizedBox(height: 14),
          _KeepTogether(_recommendationsSection(data)),
          pw.SizedBox(height: 14),
          _KeepTogether(_disclaimer()),
        ],
      ),
    );

    return doc.save();
  }

  // ---------- أدوات النص العربي ----------

  /// تشكيل نص عربي إلى ترتيب مرئي بأشكال صحيحة.
  String _t(String text) => shapeArabic(text);

  /// عرض نص مشكَّل بالنقاط (من مقاييس الخط نفسها التي
  /// يستخدمها محرك pdf) لاستخدامها في كسر الأسطر يدوياً.
  /// [TtfParser.advanceWidth] منسوب مسبقاً لوحدة الخط
  /// (جزء من وحدة em) فيُضرب في حجم الخط مباشرة.
  double _textWidth(String text, {required double fontSize, bool bold = false}) {
    final parser = bold ? _boldMetrics! : _regularMetrics!;
    var width = 0.0;
    for (final code in text.runes) {
      final glyph = parser.charToGlyphIndexMap[code];
      if (glyph == null) continue;
      final metrics = parser.glyphInfoMap[glyph];
      if (metrics == null) continue;
      width += metrics.advanceWidth * fontSize;
    }
    return width;
  }

  /// كسر النص المنطقي إلى أسطر قبل التشكيل — كل سطر يُشكَّل
  /// وحده ثم يُرسم من الأعلى للأسفل فيبقى ترتيب القراءة
  /// صحيحاً. (تشكيل النص كاملاً أولاً ثم كسره يقلب ترتيب
  /// الأسطر لأن النص المرئي يبدأ من آخر الجملة).
  ///
  /// التراكم مطابق لما تفعله حزمة pdf في التفافها الخاص
  /// (`RichText._buildLines`): عرض كل كلمة يليه فراغ كامل
  /// قبل فحص الكلمة التالية، فلا تعيد الحزمة الالتفاف فوق
  /// أسطرنا (إعادة الالتفاف على نص مرئي تقلب ترتيب الأسطر).
  String _flow(
    String text, {
    required double maxWidth,
    required double fontSize,
    bool bold = false,
  }) {
    final spaceWidth = _textWidth(' ', fontSize: fontSize, bold: bold);
    final lines = <String>[];
    for (final paragraph in text.split('\n')) {
      var current = <String>[];
      var accumulated = 0.0; // مجموع الكلمات + فراغ بعد كل كلمة
      for (final word in paragraph.split(' ')) {
        final wordWidth = _textWidth(word, fontSize: fontSize, bold: bold);
        if (current.isNotEmpty && accumulated + wordWidth > maxWidth) {
          lines.add(_t(current.join(' ')));
          current = <String>[];
          accumulated = 0.0;
        }
        current.add(word);
        accumulated += wordWidth + spaceWidth;
      }
      lines.add(_t(current.join(' ')));
    }
    return lines.join('\n');
  }

  /// نص فقرة RTL داخل بطاقة (حشو 14 من كل جهة).
  pw.Text _paragraph(
    String text, {
    double fontSize = 10.5,
    bool bold = false,
    PdfColor? color,
    double maxWidth = _cardInnerWidth,
  }) {
    return pw.Text(
      _flow(text, maxWidth: maxWidth, fontSize: fontSize, bold: bold),
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : null,
        color: color,
      ),
      textAlign: pw.TextAlign.right,
    );
  }

  /// جدول RTL: العمود المنطقي الأول (أعمدة العناوين والقيم
  /// بالترتيب المقروء) يُعرض أقصى اليمين — بتقلب أعمدة
  /// الجدول يدوياً مع تثبيت عروضها، وتشكيل كل خلية وكسرها
  /// لعرض عمودها (حشو الخلية 5×2).
  pw.Widget _rtlTable({
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> widths,
    required double headerFontSize,
    required double cellFontSize,
  }) {
    final columnCount = headers.length;
    String cell(String text, int logicalIndex) => _flow(
          text,
          maxWidth: widths[logicalIndex] - 10,
          fontSize: cellFontSize,
        );

    return pw.TableHelper.fromTextArray(
      headers: <String>[
        for (var i = columnCount - 1; i >= 0; i--) _t(headers[i]),
      ],
      data: <List<String>>[
        for (final row in rows)
          <String>[
            for (var i = columnCount - 1; i >= 0; i--) cell(row[i], i),
          ],
      ],
      columnWidths: <int, pw.TableColumnWidth>{
        for (var i = 0; i < columnCount; i++)
          (columnCount - 1 - i): pw.FixedColumnWidth(widths[i]),
      },
      headerStyle:
          pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: headerFontSize),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFF2E6)),
      cellStyle: pw.TextStyle(fontSize: cellFontSize),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      border: pw.TableBorder.all(
        color: const PdfColor.fromInt(0xFFE3E7DB),
        width: 0.6,
      ),
    );
  }

  // ---------- مكوّنات عامة ----------

  pw.Widget _header(DiagnosticReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF556B2F),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      // RTL: العنوان يمين الشريط والوقت يساره.
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _t(_formatDateTime(data.scannedAt)),
            style: pw.TextStyle(fontSize: 10.5, color: PdfColors.white),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _t('DriveScope — تقرير تشخيص المركبة'),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                _t('نتائج فحص OBD-II الفعلي عبر جهاز التشخيص'),
                style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(
    String title, {
    PdfColor color = const PdfColor.fromInt(0xFF556B2F),
  }) {
    // RTL: الشريط الملون أقصى اليمين ثم العنوان يساره.
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(
          _t(title),
          style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, fontSize: 13.5, color: color),
        ),
        pw.SizedBox(width: 8),
        pw.Container(width: 4, height: 16, color: color),
      ],
    );
  }

  pw.Widget _vehicleSection(DiagnosticReportData data) {
    final vin = data.vin;
    return _sectionCard(
      title: 'معلومات المركبة والفحص',
      children: [
        _rtlTable(
          headers: <String>['البند', 'القيمة'],
          widths: const <double>[170, 325],
          headerFontSize: 11,
          cellFontSize: 11,
          rows: <List<String>>[
            <String>['المركبة', data.vehicleLabel ?? 'غير محددة'],
            <String>['رقم الهيكل (VIN)', vin ?? 'غير متوفر — لم يُقرأ من الجهاز'],
            <String>['تاريخ ووقت الفحص', _formatDateTime(data.scannedAt)],
          ],
        ),
      ],
    );
  }

  pw.Widget _statusSection(DiagnosticReportData data) {
    final status = data.milStatus;
    final incomplete = status?.incompleteTests ?? const <MilReadinessTest>[];

    return _sectionCard(
      title: 'حالة النظام وجاهزية الفحص',
      children: [
        _rtlTable(
          headers: <String>['البند', 'الحالة'],
          widths: const <double>[170, 325],
          headerFontSize: 11,
          cellFontSize: 10.5,
          rows: <List<String>>[
            <String>[
              'مصباح العطل (MIL)',
              status == null
                  ? 'غير متوفر — لم تُقرأ حالة 0101'
                  : (status.milOn ? 'مضاء (عطل نشط)' : 'مطفأ'),
            ],
            <String>[
              'عدد الأكواد المخزنة',
              status == null ? 'غير متوفر' : '${status.dtcCount}',
            ],
            <String>[
              'جاهزية فحص الانبعاثات (I/M)',
              status == null || status.readiness.isEmpty
                  ? 'غير متوفر'
                  : (incomplete.isEmpty
                      ? 'كل الاختبارات مكتملة — جاهز للفحص الرسمي'
                      : 'غير مكتمل: ${incomplete.map((t) => t.name).join('، ')}'),
            ],
          ],
        ),
      ],
    );
  }

  pw.Widget _dtcSection(DiagnosticReportData data) {
    final analysis = data.analysis;
    final rows = <List<String>>[];
    for (final code in data.dtcCodes) {
      final fault = analysis?.faultForCode(code);
      final title = fault?.title?.isNotEmpty == true
          ? fault!.title!
          : (fault?.nameEn?.isNotEmpty == true ? fault!.nameEn! : '—');
      final severity = fault?.severityPercentage;
      final severityText = severity == null ? '—' : '${severity.round()}%';
      rows.add(<String>[code, title, severityText]);
    }

    return _sectionCard(
      title: 'أكواد الأعطال المكتشفة (وضع 03)',
      children: [
        if (rows.isEmpty)
          _paragraph(
            'لا توجد أكواد أعطال مسجلة في وحدة التحكم.',
            color: PdfColors.grey700,
          )
        else
          _rtlTable(
            headers: <String>['الكود', 'العنوان', 'الشدة'],
            widths: const <double>[75, 350, 70],
            headerFontSize: 11,
            cellFontSize: 10.5,
            rows: rows,
          ),
      ],
    );
  }

  pw.Widget _freezeFrameSection(DiagnosticReportData data) {
    final codes = data.freezeFrameCodes;
    return _sectionCard(
      title: 'إطار التجميد (Freeze Frame — وضع 02)',
      children: [
        if (codes.isEmpty)
          _paragraph(
            'غير متوفر — لم تُقرأ بيانات إطار التجميد في هذا '
            'الفحص (تُقرأ بأمر 02 عند الحاجة).',
            color: PdfColors.grey700,
          )
        else
          _paragraph(
            'الأكواد المرتبطة بإطار التجميد المخزّن لحظة تسجيل العطل: '
            '${codes.join('، ')}',
          ),
      ],
    );
  }

  pw.Widget _liveSection(DiagnosticReportData data) {
    final metrics = data.liveMetrics;
    final rows = <List<String>>[
      for (final entry in metrics.entries) <String>[entry.key, entry.value],
    ];

    return _sectionCard(
      title: 'البيانات الحية المجموعة أثناء الفحص',
      children: [
        if (rows.isEmpty)
          _paragraph(
            'لا توجد قراءات حية محفوظة لحظة الفحص — فعّل '
            '«البيانات الحية» ثم أعد الفحص لتضمينها.',
            color: PdfColors.grey700,
          )
        else
          _rtlTable(
            headers: <String>['المؤشر', 'القيمة'],
            widths: const <double>[260, 235],
            headerFontSize: 11,
            cellFontSize: 10.5,
            rows: rows,
          ),
      ],
    );
  }

  /// بطاقة قسم موحدة (عنوان + محتوى).
  pw.Widget _sectionCard({
    required String title,
    required List<pw.Widget> children,
    PdfColor? fill,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: fill,
        border: fill == null
            ? pw.Border.all(color: const PdfColor.fromInt(0xFFE3E7DB))
            : null,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(title),
          pw.SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  /// شرح كل عطل: المعنى، الشدة، الأسباب المحتملة، خطوات الفحص،
  /// والحلول الموصى بها (من استجابة خدمة التحليل).
  List<pw.Widget> _faultsSections(DiagnosticReportData data) {
    final analysis = data.analysis;
    if (analysis == null || data.dtcCodes.isEmpty) {
      return <pw.Widget>[];
    }

    final widgets = <pw.Widget>[];
    var faultsFound = false;

    for (final code in data.dtcCodes) {
      final fault = analysis.faultForCode(code);
      if (fault == null || fault.failed) continue;
      faultsFound = true;

      final children = <pw.Widget>[];

      if (fault.nameEn?.isNotEmpty == true) {
        children.add(pw.Text(
          _t(fault.nameEn!),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ));
        children.add(pw.SizedBox(height: 6));
      }
      if (fault.description?.isNotEmpty == true) {
        children.add(_bullet('الوصف', fault.description!));
      }
      if (fault.meaning?.isNotEmpty == true) {
        children.add(_bullet('المعنى', fault.meaning!));
      }
      if (fault.severityPercentage != null) {
        children.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: _paragraph(
            'الشدة: ${fault.severityPercentage!.round()}% — '
            '${fault.severity ?? ''}',
            bold: true,
          ),
        ));
      }
      if (fault.severityExplanation?.isNotEmpty == true) {
        children.add(_bullet('تفسير الشدة', fault.severityExplanation!));
      }
      if (fault.possibleCauses.isNotEmpty) {
        children.add(_list('الأسباب المحتملة', fault.possibleCauses));
      }
      if (fault.possibleSymptoms.isNotEmpty) {
        children.add(_list('الأعراض الملاحظة', fault.possibleSymptoms));
      }
      if (fault.diagnosticSteps.isNotEmpty) {
        children.add(_list('خطوات الفحص الموصى بها', fault.diagnosticSteps));
      }
      if (fault.solutions.isNotEmpty) {
        children.add(_list('الحلول والإصلاح الموصى به', fault.solutions));
      }
      if (fault.confidence != null) {
        children.add(_paragraph(
          'ثقة التحليل: ${(fault.confidence! * 100).round()}%',
          fontSize: 10,
          color: PdfColors.grey700,
        ));
      }

      widgets.add(_KeepTogether(_sectionCard(
        title: 'شرح العطل: $code',
        children: children,
      )));
      widgets.add(pw.SizedBox(height: 12));
    }

    if (!faultsFound) {
      widgets.add(_explanationsUnavailable());
    }
    return widgets;
  }

  pw.Widget _explanationsUnavailable() {
    return _sectionCard(
      title: 'شرح الأعطال',
      children: [
        _paragraph(
          'شرح الأعطال غير متوفر — لم تصل استجابة خدمة '
          'التحليل لحظة توليد التقرير (تُجلب تلقائياً بعد كل فحص).',
          color: PdfColors.grey700,
        ),
      ],
    );
  }

  pw.Widget _recommendationsSection(DiagnosticReportData data) {
    final analysis = data.analysis;
    final actions = <String>[];

    if (analysis != null && data.dtcCodes.isNotEmpty) {
      for (final code in data.dtcCodes) {
        final fault = analysis.faultForCode(code);
        if (fault == null || fault.failed) continue;
        actions.addAll(fault.solutions.take(3));
      }
    }

    // توصيات عامة حسب الحالة (بلا تركيب — من بيانات الفحص الفعلية).
    final status = data.milStatus;
    if (status?.milOn == true) {
      actions.add('مصباح العطل مضاء: افحص الأكواد المسجلة ولا تتجاهل '
          'القيادة الطويلة بهذه الحالة.');
    }
    final incomplete = status?.incompleteTests ?? const <MilReadinessTest>[];
    if (incomplete.isNotEmpty) {
      actions.add('بعض اختبارات جاهزية الانبعاثات غير مكتملة: قُد المركبة '
          'دورات قيادة كاملة قبل فحص I/M الرسمي.');
    }
    if (data.dtcCodes.isEmpty) {
      actions.add('لا توجد أكواد أعطال: استمر بالفحص الدوري كل '
          'ما يعادل فترة عادية للاطمئنان.');
    }

    return _sectionCard(
      title: 'توصيات الفحص والإصلاح',
      fill: const PdfColor.fromInt(0xFFEFF2E6),
      children: [
        if (actions.isEmpty)
          _paragraph(
            'لا توجد توصيات متاحة من بيانات هذا الفحص.',
            color: PdfColors.grey700,
          )
        else
          ...actions.take(12).map((action) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: _paragraph(action, maxWidth: 483),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      '•',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10.5),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  pw.Widget _bullet(String label, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: _paragraph('$label: $text'),
    );
  }

  pw.Widget _list(String title, List<String> items) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _paragraph(title, bold: true),
          pw.SizedBox(height: 3),
          ...items.take(8).map((item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        _flow(item, maxWidth: 480, fontSize: 10),
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      '-',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  pw.Widget _disclaimer() {
    return pw.Container(
      // عرض كامل: دون هذا يتقلص الصندوق على عرض أطول سطر.
      width: _pageContentWidth,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE8A23A)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: _paragraph(
        'تنبيه: هذا التقرير معلوماتي مُولَّد آلياً من قراءات جهاز OBD-II '
        'وتحليل ذكي؛ لا يغني عن التشخيص الفني المعتمد، وقد تختلف '
        'المعاني بحسب الشركة الصانعة وطراز السيارة.',
        fontSize: 9.5,
        color: PdfColors.grey800,
        maxWidth: _pageContentWidth - 20,
      ),
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColor.fromInt(0xFFE3E7DB), width: 0.6),
        ),
      ),
      // RTL: رقم الصفحة يسار السطر والعلامة يمينه.
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _t('صفحة ${context.pageNumber} من ${context.pagesCount}'),
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
          pw.Text(
            _t('DriveScope — تقرير تشخيص OBD-II'),
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '$y-$m-$d، الساعة $hh:$mm';
  }
}
