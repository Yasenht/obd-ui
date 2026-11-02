import 'models.dart';


class ObdCommands {
  static const String readVin = '0902\r';
  static const String battery = 'BATT\r';
  static const String disableEcho = 'ATE0\r';  
  static const String readRpm = '010C\r';
  static const String readCoolantTemperature = '0105\r';
  static const String readSpeed = '010D\r';
  static const String readThrottle = '0111\r';
  static const String readDtc = '03\r';

  // أمر DTC المقترح للفيرموير v5 بعد التحديث (firmware_patch/)؛
  // يعيد رد mode-03 قياسياً مصاغاً ("43 01 08 ...") مخزّناً منذ الإقلاع.
  static const String readDtcCached = 'DTCS?\r';

  // أوامر يدعمها فيرموير Freematics النص (telelogger / firmware_v5)
  // مباشرةً عبر BLE — انظر processBLE() في telelogger.ino:
  // كل أمر آخر غير القائمة يُجاب بـ "ERROR".
  static const String vin = 'VIN\r';
  static const String firmwareOn = 'ON\r';
  static const String uptime = 'UPTIME\r';
  static const String rssi = 'RSSI\r';
  
  static String readPid(int pid) {
    final hexPid = pid
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();

    return '01$hexPid\r';
  }


}

class ObdProtocolException implements Exception {
  const ObdProtocolException(this.message);
  final String message;
  @override
  String toString() => message;
}


class ObdParser {
  static final RegExp _hexToken = RegExp(
    r'(?<![0-9A-Fa-f])[0-9A-Fa-f]{2}(?![0-9A-Fa-f])',
  );

  static final RegExp _directNumber = RegExp(
    r'^\d+(?:\.\d+)?$',
  );

  /// تنظيف الرد من محارف نهاية السطر والمسافات الخارجية.
  static String _cleanResponse(String response) {
    return response
        .replaceAll(RegExp(r'[\r\n>]'), '')
        .trim();
  }

  /// استخراج بايتات hexadecimal من الرد.
  static List<int> hexBytes(String response) {
    return _hexToken
        .allMatches(response)
        .map(
          (match) => int.parse(
        match.group(0)!,
        radix: 16,
      ),
    )
        .toList();
  }

  /// التحقق مما إذا كان الرد يشير إلى خطأ.
  static bool isError(String response) {
    final upper = response.toUpperCase().trim();

    // الردود الوسيطة من جسر ELM (طمأنة البحث عن البروتوكول) ليست
    // ردوداً نهائية وليست نجاحاً — تُعامل كخطوة مؤقتة.
    return upper.isEmpty ||
        upper == 'N/A' ||
        upper.contains('NO DATA') ||
        upper.contains('UNABLE') ||
        upper.contains('ERROR') ||
        upper.contains('TIMEOUT') ||
        upper.contains('STOPPED') ||
        upper.contains('SEARCHING') ||
        upper.contains('BUS INIT') ||
        upper.contains('BUSINIT') ||
        upper.contains('?');
  }

  /// تحليل PID مع دعم تنسيق Freematics المباشر
  /// وتنسيق OBD-II القياسي.
  static PidReading parsePid({
    required int pid,
    required String response,
  }) {
    final cleaned = _cleanResponse(response);

    if (isError(cleaned)) {
      throw ObdProtocolException(
        'تعذر قراءة PID '
            '${pid.toRadixString(16).toUpperCase()}: $cleaned',
      );
    }

    late final num value;
    late final String label;
    late final String unit;

    // اسم القراءة ووحدتها.
    switch (pid) {
      case 0x0C:
        label = 'دوران المحرك';
        unit = 'RPM';
        break;

      case 0x05:
        label = 'حرارة سائل التبريد';
        unit = '°C';
        break;

      case 0x0D:
        label = 'سرعة المركبة';
        unit = 'km/h';
        break;

      case 0x11:
        label = 'موضع الخانق';
        unit = '%';
        break;

      default:
        label = 'PID ${pid.toRadixString(16).toUpperCase()}';
        unit = '';
    }
    // هذه القيم جاهزة للتحويل إلى رقم，
    // ولا تحتاج إلى فك بايتات OBD.
    if (_directNumber.hasMatch(cleaned)) {
      value = num.parse(cleaned);
    } else {
      
      final bytes = hexBytes(cleaned);
      final markerIndex = _indexOf(
        bytes,
        [0x41, pid],
      );

      if (markerIndex < 0 ||
          markerIndex + 2 >= bytes.length) {
        throw ObdProtocolException(
          'رد PID غير معروف أو غير مكتمل: $cleaned',
        );
      }

      final a = bytes[markerIndex + 2];

      final b = markerIndex + 3 < bytes.length
          ? bytes[markerIndex + 3]
          : 0;

      switch (pid) {
        case 0x0C:
          //  RPM = (A * 256 + B) / 4
          value = (a * 256 + b) / 4;
          break;

        case 0x05:
        // درجة الحرارة = A - 40
          value = a - 40;
          break;

        case 0x0D:
        // السرعة بوحدة km/h
          value = a;
          break;

        case 0x11:
        // موضع الخانق كنسبة مئوية
          value = a * 100 / 255;
          break;

        default:
          value = a;
      }
    }

    final normalizedValue = value.toDouble() ==
        value.toDouble().roundToDouble()
        ? value.toInt()
        : value;

    return PidReading(
      pid: pid,
      label: label,
      value: normalizedValue,
      unit: unit,
      raw: cleaned,
    );
  }

  /// تجميع الإطارات المرقّمة (0: 1: 2:) في نص واحد لكل مجموعة إطارات.
  static List<String> _mergeFrames(String response) {
    final lines = response
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceAll('>', '').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merged = <String>[];
    final frameBuffer = StringBuffer();
    for (final line in lines) {
      final m = RegExp(r'^\d+:\s*(.*)$').firstMatch(line);
      if (m != null) {
        frameBuffer.write(' ${m.group(1)}');
      } else {
        if (frameBuffer.isNotEmpty) {
          merged.add(frameBuffer.toString());
          frameBuffer.clear();
        }
        merged.add(line);
      }
    }
    if (frameBuffer.isNotEmpty) merged.add(frameBuffer.toString());
    return merged;
  }

  /// تحليل أكواد الأعطال DTC محلياً من رد أمر "03"/"DTCS?".
  ///
  /// الفك للعرض يتم هنا في التطبيق من رد جهاز OBD مباشرةً، والرد الخام
  /// يُرسل أيضاً في الخلفية (مع الأمر الأصلي) إلى خدمة التحليل
  /// في _runApiAnalysis مباشرةً — دون أي تعديل في محتواه، كالصيغة
  /// القياسية "43 02 01 08 01 09 ..." التي وصلت من الجهاز.
  ///
  /// يدعم الصيغتين المعروفتين:
  ///
  /// 1. فيرموير Freematics v5 المُرقّع (firmware_patch/telelogger_dtc.patch):
  ///    يطبع "43" ثم زوج بايتات "%02X %02X" لكل كود (بلا بايت عدّاد)،
  ///    مثال: "43 01 08 01 09 00 00" → P0108، P0109.
  ///
  /// 2. صيغة ELM327/CAN القياسية (ISO 15765-4): يلي 43 بايت عدد
  ///    الأكواد ثم الأكواد ثم بطانة أصفار، مثال:
  ///    "43 01 02 09 00 00 00 00" → P0209 (عدّاد=01 ثم الكود 02 09).
  ///    تجاهل هذا العدد كان يُزاح فكّ الأكواد بايتاً كاملاً فتظهر
  ///    شيفرات خاطئة على المركبة (السبب في «إسناد خاطئ» لأمر 03).
  ///
  /// تمييز الصيغتين: إطار CAN الأحادي يصل بعدد بايتات فردي بعد الـ43
  /// (43 + عدد + أزواج + بطانة)، وصيغة الفيرموير تصل بعدد زوجي
  /// (أزواج الأكواد + إغلاق اختياري 00 00). ولا يُعتمد بايت العدد
  /// إلا بعد التحقق من مطابقة عدد أزواج الأكواد غير الصفرية لقيمته
  /// وأن تُتبع أزراراً — فلا يُزاح فكّ الأكواد بأي من الصيغتين.
  static List<String> parseDtc(String response) {
    if (isError(response)) return const [];

    final codes = <String>[];
    final merged = _mergeFrames(response);

    for (final text in merged) {
      final bytes = hexBytes(text);
      final marker = _indexOf(bytes, const [0x43]);
      if (marker < 0) continue;

      // البايتات التالية لبايت وضع الطلب 0x43 (يكون دائماً أولاً
      // في رد إيجابي للوضع 03).
      final rest = bytes.sublist(marker + 1);
      if (rest.isEmpty) continue;

      var index = 0;
      if (rest.length.isOdd && _countByteValidates(rest)) {
        index = 1; // تخطّ بايت عدد الأكواد في الصيغة القياسية CAN.
      }

      for (var i = index; i + 1 < rest.length; i += 2) {
        final high = rest[i];
        final low = rest[i + 1];
        if (high == 0 && low == 0) break;

        final first = ['P', 'C', 'B', 'U'][(high >> 6) & 0x03];
        final second = ((high >> 4) & 0x03).toRadixString(16).toUpperCase();
        final suffix =
            '${(high & 0x0F).toRadixString(16).toUpperCase()}'
            '${low.toRadixString(16).padLeft(2, '0').toUpperCase()}';

        final code = '$first$second$suffix';
        if (!codes.contains(code)) codes.add(code);
      }
    }
    return codes;
  }

  /// التحقق من صلاحية بايت عدد الأكواد في الصيغة القياسية CAN:
  /// يجب أن تساوي قيمته عدد أزواج الأكواد غير الصفرية التي تليه،
  /// وأن تُتبع هذه الأزواج بايتات بطانة صفرية كاملة — وإلا يُرفض
  /// العدد وتُفك الصيغة بلا عدد (كما يفهمها فيرموير Freematics).
  static bool _countByteValidates(List<int> rest) {
    final count = rest[0];
    if (count <= 0 || count > 127) return false;

    var nonZeroPairs = 0;
    var endOfPairs = 1; // النهاية الشرعية للأكواد حسب العدد المعلن.
    for (var i = 1; i + 1 < rest.length; i += 2) {
      if (rest[i] == 0 && rest[i + 1] == 0) break;
      nonZeroPairs++;
      endOfPairs = i + 2;
    }
    if (nonZeroPairs != count) return false;

    for (var i = endOfPairs; i < rest.length; i++) {
      if (rest[i] != 0) return false;
    }
    return true;
  }
static bool isValidVin(String vin) {
  final value = vin.trim().toUpperCase();

  if (value.length != 17) return false;

  if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(value)) {
    return false;
  }

  // رفض النتائج الوهمية مثل UUUUUUUUUUUUUUUUU
  if (value.split('').toSet().length < 5) {
    return false;
  }

  return true;
}
  /// تحليل VIN من رد OBD-II القياسي.
  // static String parseVin(String response) {
  //   // تجميع الإطارات المرقّمة أولاً؛ إزالة \n بشكل مباشر تدمج آخر بايت
  //   // من إطار مع رقم الإطار التالي (مثال: "5A 5A" + "1: 38" → "5A5A1").
  //   final merged = _mergeFrames(response).join(' ');

  //   if (isError(merged)) {
  //     throw const ObdProtocolException(
  //       'تعذر قراءة رقم الهيكل VIN.',
  //     );
  //   }

  //   final bytes = hexBytes(merged);

  //   // رد VIN القياسي يبدأ بـ 49 02 01.
  //   final markerIndex = _indexOf(
  //     bytes,
  //     const [0x49, 0x02, 0x01],
  //   );

  //   if (markerIndex < 0) {
  //     throw const ObdProtocolException(
  //       'رد VIN غير مكتمل أو لا يستخدم التنسيق القياسي.',
  //     );
  //   }

  //   final vinBytes = bytes.sublist(markerIndex + 3);

  //   final vin = ascii.decode(
  //     vinBytes
  //         .where((byte) => byte >= 0x20 && byte <= 0x7E)
  //         .toList(),
  //     allowInvalid: true,
  //   );

  //   final cleanedVin = vin.replaceAll(
  //     RegExp(r'[^A-Za-z0-9]'),
  //     '',
  //   );

  //   // قد تحتوي الإطارات على بايتات حشو بعد بايتات الـVIN السبعة عشر،
  //   // لذا نقبل نتيجة أطول ثم نقتطع أول 1/17 محرفاً.
  //   if (cleanedVin.length < 17) {
  //     throw const ObdProtocolException(
  //       'لم يتم العثور على رقم VIN كامل وصالح.',
  //     );
  //   }

  //   return cleanedVin.length == 17 ? cleanedVin : cleanedVin.substring(0, 17);
  // }
static String parseVin(String response) {
  final merged = _mergeFrames(response).join(' ');

  if (isError(merged)) {
    throw const ObdProtocolException(
      'تعذر قراءة رقم الهيكل VIN.',
    );
  }

  final bytes = hexBytes(merged);

  final markerIndex = _indexOf(
    bytes,
    const [0x49, 0x02, 0x01],
  );

  if (markerIndex < 0) {
    throw const ObdProtocolException(
      'رد VIN غير مكتمل أو لا يستخدم التنسيق القياسي.',
    );
  }

  final start = markerIndex + 3;

  if (bytes.length < start + 17) {
    throw const ObdProtocolException(
      'لم يتم العثور على رقم VIN كامل.',
    );
  }

  final vinBytes = bytes.sublist(start, start + 17);

  final vin = String.fromCharCodes(vinBytes);

  if (!isValidVin(vin)) {
    throw const ObdProtocolException(
      'رقم VIN المستخرج غير صالح.',
    );
  }

  return vin;
}
  /// تحليل نصي مباشر لرد أمر "VIN" في فيرموير Freematics.
  ///
  /// فيرموير telelogger يرد بنص VIN مباشرة (17 محرفاً) أو "N/A"،
  /// وليس بصيغة OBD-II القياسية "49 02 01". يعيد null عند الفشل.
  // static String? parsePlainVin(String response) {
  //   final cleaned = _cleanResponse(response);

  //   if (isError(cleaned)) {
  //     return null;
  //   }

  //   // استخراج أول تسلسل من 17 محرفاً صالحاً كـVIN
  //   // (حروف وأرقام دون I/O/Q حسب معيار VIN).
  //   final match = RegExp(r'[A-HJ-NPR-Z0-9]{17}')
  //       .firstMatch(cleaned.toUpperCase());
  //   return match?.group(0);
  // }
static String? parsePlainVin(String response) {
  final cleaned = _cleanResponse(response);

  if (isError(cleaned)) {
    return null;
  }

  final matches = RegExp(
    r'[A-HJ-NPR-Z0-9]{17}',
  ).allMatches(cleaned.toUpperCase());

  for (final match in matches) {
    final vin = match.group(0)!;

    // رفض النتائج المتكررة والوهمية
    if (vin.split('').toSet().length < 5) {
      continue;
    }

    return vin;
  }

  return null;
}
  /// البحث عن تسلسل بايتات داخل قائمة.
  static int _indexOf(
      List<int> source,
      List<int> pattern,
      ) {
    if (pattern.isEmpty || pattern.length > source.length) {
      return -1;
    }

    for (
    var i = 0;
    i <= source.length - pattern.length;
    i++
    ) {
      var found = true;

      for (var j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }

      if (found) {
        return i;
      }
    }

    return -1;
  }

    /// تحويل الرد القادم من Freematics إلى صيغة OBD الخام المطلوبة
    /// من الـ Backend حصراً ("41 0C 1A F8" مثلاً).
    /// أي رد لا يمكن ترميزه بهذه الصيغة يعيد "" (لا يُرسَل للـ API إطلاقاً).
    ///
    /// قواعد الترميز القياسية (JE1979 / ELM327):
    /// - RPM  (0x0C): (A*256+B)/4
    /// - حرارة السائل/الهواء (0x05/0x0F): A-40
    /// - السرعة (0x0D)، ضغط السحب (0x0B)، البارومتر (0x33): A
    /// - الخانق/الحمل/مستوى الوقود (0x04/0x11/0x2F): A*100/255
    /// - الجهد (0x42): (A*256+B)/1000
    ///   "BATT" من فيرموير (فولت مباشرة) يُرمز بصيغة 0x42 نفسها.
  static String toRawObdResponse(String command, String response) {
    final cmd = command.trim().toUpperCase();
    final resp = response.trim();

    String hex(int v) =>
        v.clamp(0, 255).toInt().toRadixString(16).padLeft(2, '0').toUpperCase();

    // التوافق: الرد الخام أصلاً (41 0C ...) يُمرر كما هو
    final compact = resp.toUpperCase().replaceAll(RegExp(r'\s'), '');

    final pidMatch = RegExp(r'^01([0-9A-F]{2})$').firstMatch(cmd);

    if (pidMatch == null) {
      // "BATT" يُرمّز كـ PID 0x42: جهد وحدة التحكم (A*256+B)/1000 فولت
      // مثال: 12.34V -> 12340 = 0x3034 -> "41 42 30 34"
      if (cmd == 'BATT' && RegExp(r'^\d+(?:\.\d+)?$').hasMatch(resp)) {
        final mv = (double.parse(resp) * 1000).round().clamp(0, 65535).toInt();
        return '41 42 ${hex(mv >> 8)} ${hex(mv & 0xFF)}';
      }

      // الأوامر النصية (VIN/DTCS?/غيرها) لا تمتلك صيغة 41 القياسية
      // فلا تُرسَل إلى خدمة التحليل أصلاً (تعاقد أُثبت في الاختبارات:
      // toRawObdResponse تُرجع نصاً فارغاً لأوامر الأعطال — أما إرسال
      // الرد الخام للأعطال مع الأمر الأصلي فيتولاه _runApiAnalysis مباشرةً).
      return '';
    }

    final pidHex = cmd.substring(2);
    final pid = int.parse(pidHex, radix: 16);

    // إذا كان الرد خاماً أصلاً (41 0C ...) لا نغيّره
    if (compact.startsWith('41$pidHex')) return resp;

    // الرد يجب أن يكون رقماً صرفاً لترميزه؛ غير ذلك لا يُرسَل شيء
    if (!RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(resp)) return '';

    final value = num.parse(resp);

    switch (pid) {
      case 0x0C: // RPM = (A*256+B)/4
        final raw = (value * 4).round().clamp(0, 65535).toInt();
        return '41 $pidHex ${hex(raw >> 8)} ${hex(raw & 0xFF)}';

      case 0x0D: // السرعة = A
        return '41 $pidHex ${hex(value.round())}';

      case 0x05: // حرارة السائل = A - 40
      case 0x0F: // حرارة الهواء = A - 40
        return '41 $pidHex ${hex(value.round() + 40)}';

      case 0x04: // الحمل = A*100/255
      case 0x11: // الخانق = A*100/255
      case 0x2F: // مستوى الوقود = A*100/255
        return '41 $pidHex ${hex((value * 255 / 100).round())}';

      case 0x0B: // ضغط السحب المطلق = A
      case 0x33: // ضغط البارومتر = A
        return '41 $pidHex ${hex(value.round())}';

      case 0x42: // جهد الوحدة = (A*256+B)/1000
        final mv = (value * 1000).round().clamp(0, 65535).toInt();
        return '41 $pidHex ${hex(mv >> 8)} ${hex(mv & 0xFF)}';

      default:
        // // القديم كان يرسل الرقم كما هو لـ PID غير معروف
        // return resp;
        // PID بلا صيغة ترميز معروفة: لا نرسل شيئاً بدل تخمين خاطئ
        return '';
    }
  }
}


