import 'dart:convert';

import 'models.dart';

/// أوامر OBD القياسية التي يرسلها التطبيق كنص ASCII إلى خاصية FFE1.
class ObdCommands {
  static const initialize = 'ATZ\r';
  static const disableEcho = 'ATE0\r';
  static const disableHeaders = 'ATH0\r';
  static const readDtc = '03\r';
  static const clearDtc = '04\r';
  static const readVin = '0902\r';
  static const readRpm = '010C\r';
  static const readCoolantTemperature = '0105\r';

  static String readPid(int pid) => '01${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}\r';
}

class ObdProtocolException implements Exception {
  const ObdProtocolException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// محلل الردود القادمة عبر FFE2.
///
/// ملاحظة مهمة: الإشعار BLE قد يقسم الرد في منتصف السطر، لذلك تجمع طبقة
/// الاتصال النص أولاً ثم تستدعي هذه الدوال بعد اكتمال الرد أو انتهاء المهلة.
class ObdParser {
  static final RegExp _hexToken = RegExp(r'(?<![0-9A-Fa-f])[0-9A-Fa-f]{2}(?![0-9A-Fa-f])');

  static List<int> hexBytes(String response) {
    return _hexToken
        .allMatches(response)
        .map((match) => int.parse(match.group(0)!, radix: 16))
        .toList();
  }

  static bool isError(String response) {
    final upper = response.toUpperCase();
    return upper.contains('NO DATA') ||
        upper.contains('UNABLE') ||
        upper.contains('ERROR') ||
        upper.contains('TIMEOUT') ||
        upper.contains('?');
  }

  static PidReading parsePid({required int pid, required String response}) {
    if (isError(response)) {
      throw ObdProtocolException('تعذر قراءة PID ${pid.toRadixString(16).toUpperCase()}: ${response.trim()}');
    }

    final bytes = hexBytes(response);
    final marker = <int>[0x41, pid];
    final markerIndex = _indexOf(bytes, marker);
    if (markerIndex < 0 || markerIndex + 2 >= bytes.length) {
      throw const ObdProtocolException('رد PID غير مكتمل أو لا يحتوي على 41/PID.');
    }

    final a = bytes[markerIndex + 2];
    final b = markerIndex + 3 < bytes.length ? bytes[markerIndex + 3] : 0;
    num value;
    String label;
    String unit;

    switch (pid) {
      case 0x0C:
        value = ((a * 256) + b) / 4;
        label = 'دوران المحرك';
        unit = 'RPM';
        break;
      case 0x05:
        value = a - 40;
        label = 'حرارة سائل التبريد';
        unit = '°C';
        break;
      case 0x0D:
        value = a;
        label = 'سرعة المركبة';
        unit = 'km/h';
        break;
      case 0x11:
        value = a * 100 / 255;
        label = 'موضع الخانق';
        unit = '%';
        break;
      default:
        value = a;
        label = 'PID ${pid.toRadixString(16).toUpperCase()}';
        unit = '';
    }

    return PidReading(
      pid: pid,
      label: label,
      value: value is double && value == value.roundToDouble() ? value.toInt() : value,
      unit: unit,
      raw: response.trim(),
    );
  }

  static List<String> parseDtc(String response) {
    if (isError(response) || response.toUpperCase().contains('NO DATA')) return const [];
    final bytes = hexBytes(response);
    final markerIndex = _indexOf(bytes, const [0x43]);
    if (markerIndex < 0) return const [];

    final codes = <String>[];
    for (var index = markerIndex + 1; index + 1 < bytes.length; index += 2) {
      final high = bytes[index];
      final low = bytes[index + 1];
      if (high == 0 && low == 0) break;
      final first = ['P', 'C', 'B', 'U'][(high >> 6) & 0x03];
      final second = ((high >> 4) & 0x03).toRadixString(16).toUpperCase();
      final suffix = '${(high & 0x0F).toRadixString(16).toUpperCase()}${low.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      codes.add('$first$second$suffix');
    }
    return codes;
  }

  static String parseVin(String response) {
    if (isError(response)) throw const ObdProtocolException('تعذر قراءة رقم الهيكل VIN.');
    final bytes = hexBytes(response);
    final markerIndex = _indexOf(bytes, const [0x49, 0x02, 0x01]);
    if (markerIndex < 0) throw const ObdProtocolException('رد VIN غير مكتمل.');

    final vinBytes = bytes.sublist(markerIndex + 3);
    final vin = ascii.decode(vinBytes.where((byte) => byte >= 0x20 && byte <= 0x7E).toList(), allowInvalid: true);
    final cleaned = vin.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (cleaned.length < 11) throw const ObdProtocolException('لم يتم العثور على VIN صالح في الرد.');
    return cleaned.substring(0, cleaned.length > 17 ? 17 : cleaned.length);
  }

  static int _indexOf(List<int> source, List<int> pattern) {
    for (var i = 0; i <= source.length - pattern.length; i++) {
      var found = true;
      for (var j = 0; j < pattern.length; j++) {
        if (source[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }
}
