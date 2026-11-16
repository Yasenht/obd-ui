// ============================================================
// مُشكِّل الحروف العربية للتقارير المطبوعة (PDF).
//
// حزمة `pdf` لا تشكّل الحروف العربية بشكل سليم في مساريها
// الافتراضيين: مسار bidi (الافتراضي) يفصل أحرف النهاية
// (د ذ ر ز و ة) عن ما قبلها ويستعمل أشكالاً معزولة خطأً،
// ومسار arabic (علم use_arabic) يترك أحرف النهاية بعد
// أحرف نهاية أخرى بلا تشكيل (كود، عدد) ويرتب الكلمات
// اللاتينية بترتيب خاطئ.
//
// لذلك نشكّل بأنفسنا: نستبدل كل حرف بشكله السياقي الصحيح
// (متصِل/متوسط/نهائي/معزول من Unicode Arabic Presentation
// Forms) مع ليغاتورة لام-ألف، ثم نرتب السطر بصرياً
// (RTL) مع إبقاء المقاطع اللاتينية والأرقام سليمة
// داخلياً. الناتج نص "مرئي" جاهز للرسم من اليسار إلى
// اليمين دون أي معالجة لاحقة من الحزمة (لا نمرّر
// textDirection: rtl لـ pw.Text إطلاقاً — وإلا أعادت
// الحزمة تشكيل النص وتفسده).
// ============================================================

/// الأشكال السياقية لكل حرف: [نهائي، ابتدائي، متوسط]
/// (الشكل المعزول هو الحرف الأساسي نفسه — نفس الرمز
/// في Amiri فيرسمه كما هو).
const Map<int, List<int?>> _forms = <int, List<int?>>{
  0x0621: <int?>[null, null, null], // ء — غير متصل
  0x0622: <int?>[0xFE82, null, null], // آ
  0x0623: <int?>[0xFE84, null, null], // أ
  0x0624: <int?>[0xFE86, null, null], // ؤ
  0x0625: <int?>[0xFE88, null, null], // إ
  0x0626: <int?>[0xFE8A, 0xFE8B, 0xFE8C], // ئ
  0x0627: <int?>[0xFE8E, null, null], // ا
  0x0628: <int?>[0xFE90, 0xFE91, 0xFE92], // ب
  0x0629: <int?>[0xFE94, null, null], // ة
  0x062A: <int?>[0xFE96, 0xFE97, 0xFE98], // ت
  0x062B: <int?>[0xFE9A, 0xFE9B, 0xFE9C], // ث
  0x062C: <int?>[0xFE9E, 0xFE9F, 0xFEA0], // ج
  0x062D: <int?>[0xFEA2, 0xFEA3, 0xFEA4], // ح
  0x062E: <int?>[0xFEA6, 0xFEA7, 0xFEA8], // خ
  0x062F: <int?>[0xFEAA, null, null], // د
  0x0630: <int?>[0xFEAC, null, null], // ذ
  0x0631: <int?>[0xFEAE, null, null], // ر
  0x0632: <int?>[0xFEB0, null, null], // ز
  0x0633: <int?>[0xFEB2, 0xFEB3, 0xFEB4], // س
  0x0634: <int?>[0xFEB6, 0xFEB7, 0xFEB8], // ش
  0x0635: <int?>[0xFEBA, 0xFEBB, 0xFEBC], // ص
  0x0636: <int?>[0xFEBE, 0xFEBF, 0xFEC0], // ض
  0x0637: <int?>[0xFEC2, 0xFEC3, 0xFEC4], // ط
  0x0638: <int?>[0xFEC6, 0xFEC7, 0xFEC8], // ظ
  0x0639: <int?>[0xFECA, 0xFECB, 0xFECC], // ع
  0x063A: <int?>[0xFECE, 0xFECF, 0xFED0], // غ
  0x0641: <int?>[0xFED2, 0xFED3, 0xFED4], // ف
  0x0642: <int?>[0xFED6, 0xFED7, 0xFED8], // ق
  0x0643: <int?>[0xFEDA, 0xFEDB, 0xFEDC], // ك
  0x0644: <int?>[0xFEDE, 0xFEDF, 0xFEE0], // ل
  0x0645: <int?>[0xFEE2, 0xFEE3, 0xFEE4], // م
  0x0646: <int?>[0xFEE6, 0xFEE7, 0xFEE8], // ن
  0x0647: <int?>[0xFEEA, 0xFEEB, 0xFEEC], // ه
  0x0648: <int?>[0xFEEE, null, null], // و
  0x0649: <int?>[0xFEF0, 0xFBE8, 0xFBE9], // ى
  0x064A: <int?>[0xFEF2, 0xFEF3, 0xFEF4], // ي
  0x0640: <int?>[0x0640, 0x0640, 0x0640], // ـ تطويل (يتصل من الجهتين)
};

/// حروف تتصل بما بعدها (ثنائية الاتصال) — البقية
/// (ا د ذ ر ز و ة ؤ ى آ أ إ) تتصل بما قبلها فقط،
/// و(ء) لا تتصل إطلاقاً.
const Set<int> _dualJoining = <int>{
  0x0626, 0x0628, 0x062A, 0x062B, 0x062C, 0x062D, 0x062E, //
  0x0633, 0x0634, 0x0635, 0x0636, 0x0637, 0x0638, 0x0639,
  0x063A, 0x0641, 0x0642, 0x0643, 0x0644, 0x0645, 0x0646,
  0x0647, 0x0649, 0x064A, 0x0640,
};

/// ليغاتورة لام-ألف: [المعزولة، النهائية] لكل نوع ألف.
const Map<int, List<int>> _lamAlef = <int, List<int>>{
  0x0622: <int>[0xFEF5, 0xFEF6], // آ
  0x0623: <int>[0xFEF7, 0xFEF8], // أ
  0x0625: <int>[0xFEF9, 0xFEFA], // إ
  0x0627: <int>[0xFEFB, 0xFEFC], // ا
};

/// حركات تُمرَّر كما هي (عرض صفري) وتلتصق عنقودياً
/// بالحرف الذي قبلها عند عكس الترتيب.
bool _isDiacritic(int c) =>
    (c >= 0x064B && c <= 0x0652) || c == 0x0670;

bool _isArabicLetter(int c) => c >= 0x0621 && c <= 0x064A;

/// علامات ترقيم عربية تُعامل كنص RTL (تُعكس مع الجملة).
bool _isArabicPunctuation(int c) =>
    c == 0x060C || c == 0x061B || c == 0x061F;

/// تشكيل نص عربي وإخراجه بترتيب مرئي جاهز للرسم.
///
/// النصوص اللاتينية الخالصة تُمرَّر كما هي، والنصوص
/// المختلطة تُرتَّب حسب اتجاه أول حرف قوي في السطر.
String shapeArabic(String input) {
  if (input.isEmpty || !_containsArabic(input)) return input;
  // نص سبق تشكيله (يحوي أشكالاً عرضية) يُمرَّر كما هو —
  // إعادة التشكيل قد تفسد ترتيبه المرئي.
  if (_containsPresentationForms(input)) return input;
  return input.split('\n').map(_shapeLine).join('\n');
}

bool _containsPresentationForms(String text) {
  for (final c in text.runes) {
    if ((c >= 0xFB50 && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF)) {
      return true;
    }
  }
  return false;
}

bool _containsArabic(String text) {
  for (final c in text.runes) {
    if (_isArabicLetter(c)) return true;
  }
  return false;
}

/// عنصر سطر: إما مقطع عربي (عدة كلمات) أو كلمة غير عربية.
class _Segment {
  _Segment.arabic(this.arabicTokens) : plainToken = null;
  _Segment.plain(this.plainToken) : arabicTokens = null;

  final List<String>? arabicTokens;
  final String? plainToken;

  bool get isArabic => arabicTokens != null;
}

String _shapeLine(String line) {
  if (!_containsArabic(line)) return line;

  // تجميع الكلمات المتتالية ذات المحتوى العربي في مقاطع.
  final segments = <_Segment>[];
  for (final token in line.split(' ')) {
    if (_containsArabic(token) || _hasArabicPunctuation(token)) {
      if (segments.isNotEmpty && segments.last.isArabic) {
        segments.last.arabicTokens!.add(token);
      } else {
        segments.add(_Segment.arabic(<String>[token]));
      }
    } else {
      segments.add(_Segment.plain(token));
    }
  }

  // اتجاه السطر: أول حرف قوي يحدد الأساس. سطر يبدأ
  // بكلمة لاتينية يبقى مقاطعه بترتيبها مع عكس المقطع
  // العربي داخلياً؛ وما عدا ذلك يُعكس ترتيب المقاطع
  // كلياً (عرض RTL).
  final baseRtl = _firstStrongIsArabic(line);
  final ordered =
      baseRtl ? segments.reversed.toList(growable: false) : segments;

  final out = <String>[];
  for (final segment in ordered) {
    if (segment.isArabic) {
      for (final token in segment.arabicTokens!.reversed) {
        out.add(_shapeToken(token));
      }
    } else {
      out.add(segment.plainToken!);
    }
  }
  return out.join(' ');
}

bool _hasArabicPunctuation(String token) {
  for (final c in token.runes) {
    if (_isArabicPunctuation(c)) return true;
  }
  return false;
}

bool _firstStrongIsArabic(String line) {
  for (final c in line.runes) {
    if (_isArabicLetter(c) || _isArabicPunctuation(c)) return true;
    if ((c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A) ||
        (c >= 0x30 && c <= 0x39)) {
      return false;
    }
  }
  return true;
}

/// تشكيل كلمة واحدة: تُقسَّم إلى مدارات RTL (عربية) وLTR
/// (لاتينية/أرقام) — وعلامات التعادل (نقطتان، أقواس، ...)
/// تلحق بالمدار السابق — ثم تُعكس مدارات الكلمة بترتيبها،
/// وتُشكَّل مدارات RTL وتُعكس عنقودياً.
String _shapeToken(String token) {
  if (!_containsArabic(token) && !_hasArabicPunctuation(token)) {
    return token;
  }

  final runTypes = <int>[]; // 1 = RTL، 0 = LTR
  final runCodes = <List<int>>[];
  var pending = <int>[]; // محايدات قبل أول مدار

  void startRun(int type, int firstCode) {
    runTypes.add(type);
    runCodes.add(<int>[...pending, firstCode]);
    pending = <int>[];
  }

  for (final c in token.runes) {
    final type = _charDirectionClass(c);
    if (type < 0) {
      // محايد: يلحق بالمدار الجاري إن وجد، وإلا ينتظر
      // المدار التالي.
      if (runTypes.isNotEmpty) {
        runCodes.last.add(c);
      } else {
        pending.add(c);
      }
      continue;
    }
    if (runTypes.isNotEmpty && runTypes.last == type) {
      runCodes.last.add(c);
    } else {
      startRun(type, c);
    }
  }
  if (pending.isNotEmpty) {
    if (runTypes.isNotEmpty) {
      runCodes.last.addAll(pending);
    } else {
      runTypes.add(1);
      runCodes.add(pending);
    }
  }

  // عكس ترتيب المدارات (عرض RTL)، مع تشكيل مدارات RTL.
  final out = StringBuffer();
  for (var i = runTypes.length - 1; i >= 0; i--) {
    if (runTypes[i] == 1) {
      out.write(String.fromCharCodes(_shapeArabicRun(runCodes[i])));
    } else {
      out.write(String.fromCharCodes(runCodes[i]));
    }
  }
  return out.toString();
}

/// تصنيف اتجاه الحرف: 1 = RTL (عربي)، 0 = LTR
/// (لاتيني/أرقام)، -1 = محايد.
int _charDirectionClass(int c) {
  if (_isArabicLetter(c) || _isArabicPunctuation(c) || _isDiacritic(c)) {
    return 1;
  }
  if ((c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0x30 && c <= 0x39) ||
      (c >= 0x0660 && c <= 0x0669)) {
    return 0;
  }
  return -1;
}

/// تشكيل مدار عربي واحد: استبدال الأشكال السياقية
/// بالترتيب المنطقي، ثم عكس ترتيب "العناقيد" (حرف +
/// حركاته) لإخراج الترتيب المرئي.
List<int> _shapeArabicRun(List<int> chars) {
  final units = <List<int>>[]; // عنقود = [شكل الحرف + حركاته]
  int? prevLetter;

  var i = 0;
  while (i < chars.length) {
    final c = chars[i];

    // الحركات تلتصق بالحرف السابق (عنقود واحد).
    if (_isDiacritic(c)) {
      if (units.isNotEmpty) {
        units.last.add(c);
      } else {
        units.add(<int>[c]);
      }
      i++;
      continue;
    }

    // غير قابل للتشكيل (ترقيم/محايد): يكسر الاتصال.
    if (!_isShapeableLetter(c)) {
      units.add(<int>[c]);
      prevLetter = null;
      i++;
      continue;
    }

    // الحرف التالي الفعلي (مع تجاوز الحركات).
    var j = i + 1;
    while (j < chars.length && _isDiacritic(chars[j])) {
      j++;
    }
    final nextLetter =
        (j < chars.length && _isShapeableLetter(chars[j])) ? chars[j] : null;

    // ليغاتورة لام-ألف: الشكل النهائي إذا كان اللام
    // متصلاً بما قبله، وإلا المعزول.
    if (c == 0x0644 && nextLetter != null && _lamAlef.containsKey(nextLetter)) {
      final connected = prevLetter != null && _isDualJoining(prevLetter);
      final ligature = _lamAlef[nextLetter]![connected ? 1 : 0];
      final unit = <int>[ligature];
      // حركات عابرة بين اللام والألف (نادرة) تُحفظ.
      for (var k = i + 1; k < j; k++) {
        unit.add(chars[k]);
      }
      units.add(unit);
      prevLetter = null; // الألف لا تتصل بما بعدها
      i = j + 1;
      continue;
    }

    final connectsPrev = prevLetter != null && _isDualJoining(prevLetter);
    final connectsNext = _isDualJoining(c) && nextLetter != null;

    var code = c; // الشكل المعزول = الحرف الأساسي
    if (connectsPrev || connectsNext) {
      final forms = _forms[c]!;
      if (connectsPrev && connectsNext) {
        code = forms[2] ?? c; // متوسط
      } else if (connectsPrev) {
        code = forms[0] ?? c; // نهائي
      } else {
        code = forms[1] ?? c; // ابتدائي
      }
    }
    units.add(<int>[code]);
    prevLetter = c;
    i++;
  }

  // العكس عنقودياً: كل عنقود (حرف + حركاته) يبقى متماسكاً.
  final out = <int>[];
  for (final unit in units.reversed) {
    out.addAll(unit);
  }
  return out;
}

bool _isShapeableLetter(int c) => _forms.containsKey(c);

bool _isDualJoining(int c) => _dualJoining.contains(c);
