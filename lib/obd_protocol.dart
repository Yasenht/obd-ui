import 'dart:convert';
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

    return upper.isEmpty ||
        upper == 'N/A' ||
        upper.contains('NO DATA') ||
        upper.contains('UNABLE') ||
        upper.contains('ERROR') ||
        upper.contains('TIMEOUT') ||
        upper.contains('STOPPED') ||
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

  /// تحليل أكواد الأعطال DTC من رد OBD-II القياسي.
  static List<String> parseDtc(String response) {
    if (isError(response)) return const [];

    final codes = <String>[];
    final merged = _mergeFrames(response);

  for (final text in merged) {
    final bytes = hexBytes(text);
    final marker = _indexOf(bytes, const [0x43]);
    if (marker < 0) continue;

    for (var i = marker + 1; i + 1 < bytes.length; i += 2) {
      final high = bytes[i];
      final low = bytes[i + 1];
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
  // static List<String> parseDtc(String response) {
  //   final cleaned = _cleanResponse(response);

  //   if (isError(cleaned)) {
  //     return const [];
  //   }

  //   final bytes = hexBytes(cleaned);

  //   // رد أكواد الأعطال يبدأ عادةً بـ 43.
  //   final markerIndex = _indexOf(
  //     bytes,
  //     const [0x43],
  //   );

  //   if (markerIndex < 0) {
  //     return const [];
  //   }

  //   final codes = <String>[];

  //   for (
  //   var index = markerIndex + 1;
  //   index + 1 < bytes.length;
  //   index += 2
  //   ) {
  //     final high = bytes[index];
  //     final low = bytes[index + 1];

  //     if (high == 0 && low == 0) {
  //       break;
  //     }

  //     final first = ['P', 'C', 'B', 'U'][
  //     (high >> 6) & 0x03
  //     ];

  //     final second = ((high >> 4) & 0x03)
  //         .toRadixString(16)
  //         .toUpperCase();

  //     final suffix =
  //         '${(high & 0x0F).toRadixString(16).toUpperCase()}'
  //         '${low.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  //     codes.add('$first$second$suffix');
  //   }

  //   return codes;
  // }

  /// تحليل VIN من رد OBD-II القياسي.
  static String parseVin(String response) {
    // تجميع الإطارات المرقّمة أولاً؛ إزالة \n بشكل مباشر تدمج آخر بايت
    // من إطار مع رقم الإطار التالي (مثال: "5A 5A" + "1: 38" → "5A5A1").
    final merged = _mergeFrames(response).join(' ');

    if (isError(merged)) {
      throw const ObdProtocolException(
        'تعذر قراءة رقم الهيكل VIN.',
      );
    }

    final bytes = hexBytes(merged);

    // رد VIN القياسي يبدأ بـ 49 02 01.
    final markerIndex = _indexOf(
      bytes,
      const [0x49, 0x02, 0x01],
    );

    if (markerIndex < 0) {
      throw const ObdProtocolException(
        'رد VIN غير مكتمل أو لا يستخدم التنسيق القياسي.',
      );
    }

    final vinBytes = bytes.sublist(markerIndex + 3);

    final vin = ascii.decode(
      vinBytes
          .where((byte) => byte >= 0x20 && byte <= 0x7E)
          .toList(),
      allowInvalid: true,
    );

    final cleanedVin = vin.replaceAll(
      RegExp(r'[^A-Za-z0-9]'),
      '',
    );

    // قد تحتوي الإطارات على بايتات حشو بعد بايتات الـVIN السبعة عشر،
    // لذا نقبل نتيجة أطول ثم نقتطع أول 1/17 محرفاً.
    if (cleanedVin.length < 17) {
      throw const ObdProtocolException(
        'لم يتم العثور على رقم VIN كامل وصالح.',
      );
    }

    return cleanedVin.length == 17 ? cleanedVin : cleanedVin.substring(0, 17);
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

    /// تحويل القيمة الرقمية القادمة من Freematics إلى صيغة OBD الخام
  /// مثال: command=010C , response=1726  ->  "41 0C 1A F8"
  static String toRawObdResponse(String command, String response) {
    final cmd = command.trim().toUpperCase();
    final resp = response.trim();

    // الأمر يجب أن يكون Mode 01 + PID (مثل 010C)
    if (!RegExp(r'^01[0-9A-F]{2}$').hasMatch(cmd)) return resp;

    final pidHex = cmd.substring(2);
    final pid = int.parse(pidHex, radix: 16);

    // إذا كان الرد خاماً أصلاً (41 0C ...) لا نغيّره
    final compact = resp.toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (compact.startsWith('41$pidHex')) return resp;

    // إذا لم يكن رقماً (يدعم السالب) نرسله كما هو
    if (!RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(resp)) return resp;

    final value = num.parse(resp);
    String hex(int v) =>
        v.clamp(0, 255).toInt().toRadixString(16).padLeft(2, '0').toUpperCase();

    switch (pid) {
      case 0x0C: // RPM = (A*256+B)/4
        final raw = (value * 4).round().clamp(0, 65535).toInt();
        return '41 $pidHex ${hex(raw >> 8)} ${hex(raw & 0xFF)}';

      case 0x05: // حرارة = A - 40
        return '41 $pidHex ${hex(value.round() + 40)}';

      case 0x0D: // السرعة = A
        return '41 $pidHex ${hex(value.round())}';

      case 0x11: // الخانق = A*100/255
        return '41 $pidHex ${hex((value * 255 / 100).round())}';

      default:
        // PID غير معروف: نرسله كما هو بدل تخمين تحويل خاطئ
        return resp;
    }
  }
}


