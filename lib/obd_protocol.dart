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

  // تعديل الوقود: قصير المدى (STFT) وطويل المدى (LTFT).
  // الصيغة المعيارية: النسبة المئوية = A - 128.
  static const String readStft = '0106\r';
  static const String readLtft = '0107\r';

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
    final hexPid = pid.toRadixString(16).padLeft(2, '0').toUpperCase();

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
    return response.replaceAll(RegExp(r'[\r\n>]'), '').trim();
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

  /// وصف نتيجة أمر يدوي غير 01xx بمعناها ووحدتها — يعيد null إن
  /// لم يصف الأمر خلايا معروفة (مثل "BATT": جهد وحدة التحكم).
  ///
  /// أوامر 01xx تُفك عبر [parsePid] حصرياً (انظر AppController).
  static String? describeCommandResult(String command, String response) {
    final cmd = command.trim().toUpperCase();
    final resp = response.trim();

    if (cmd == 'BATT' && RegExp(r'^-?\d+(?:\.\d+)?$').hasMatch(resp)) {
      return 'جهد وحدة التحكم: $resp V';
    }

    return null;
  }

  /// اسم القراءة ووحدتها من كتالوج أوامر Mode-01 — مفيد لعرض معنى
  /// الأمر قبل الإرسال (عنوان نتيجة الأوامر اليدوية مثلاً).
  static (String, String) pidMetadata(int pid) {
    late final String label;
    late final String unit;
    switch (pid) {
      case 0x00:
        // رد أمر "0100": خريطة بتية للأوامر المدعومة من 01 إلى 20.
        label = 'الأوامر المدعومة (01–20)';
        unit = '';
        break;

      case 0x01:
        // "0101": حالة مصباح العطل (MIL) وعدد الأكواد المخزنة.
        label = 'مصباح العطل (MIL) وعدد الأكواد';
        unit = 'كود';
        break;

      case 0x02:
        // "0102": كود العطل المحفوظ في إطار التجميد.
        label = 'كود العطل في إطار التجميد';
        unit = '';
        break;

      case 0x03:
        // "0103": حالة حلقة الوقود (مفتوحة/مغلقة).
        label = 'حالة نظام الوقود';
        unit = '';
        break;

      case 0x04:
        label = 'حمل المحرك المحسوب';
        unit = '%';
        break;

      case 0x05:
        label = 'حرارة سائل التبريد';
        unit = '°C';
        break;

      case 0x06:
        // "0106": تعديل وقود قصير المدى (STFT) كنسبة مئوية.
        label = 'تعديل وقود قصير المدى (STFT)';
        unit = '%';
        break;

      case 0x07:
        // "0107": تعديل وقود طويل المدى (LTFT) كنسبة مئوية.
        label = 'تعديل وقود طويل المدى (LTFT)';
        unit = '%';
        break;

      case 0x0B:
        label = 'ضغط السحب المطلق';
        unit = 'kPa';
        break;

      case 0x0C:
        label = 'دوران المحرك';
        unit = 'RPM';
        break;

      case 0x0D:
        label = 'سرعة المركبة';
        unit = 'km/h';
        break;

      case 0x0E:
        label = 'زمن الإشعال المتقدم';
        unit = '°';
        break;

      case 0x0F:
        label = 'حرارة هواء السحب';
        unit = '°C';
        break;

      case 0x10:
        label = 'معدل تدفق الهواء (MAF)';
        unit = 'g/s';
        break;

      case 0x11:
        label = 'موضع الخانق';
        unit = '%';
        break;

      case 0x13:
        // "0113": خريطة بتية لحساسات الأكسجين الملاحَظة.
        label = 'حساسات الأكسجين الملاحَظة';
        unit = 'حساس';
        break;

      case 0x1F:
        label = 'مدة تشغيل المحرك';
        unit = 'ث';
        break;

      case 0x21:
        label = 'المسافة بعمل مصباح العطل';
        unit = 'km';
        break;

      case 0x2C:
        label = 'أمر إعادة تدوير العادم (EGR)';
        unit = '%';
        break;

      case 0x2F:
        label = 'مستوى الوقود';
        unit = '%';
        break;

      case 0x30:
        label = 'عمليات الإغلاق منذ مسح الأكواد';
        unit = 'مرة';
        break;

      case 0x31:
        label = 'المسافة منذ مسح الأكواد';
        unit = 'km';
        break;

      case 0x33:
        label = 'الضغط الجوي (البارومتر)';
        unit = 'kPa';
        break;

      case 0x42:
        label = 'جهد وحدة التحكم';
        unit = 'V';
        break;

      case 0x43:
        label = 'الحمل المطلق';
        unit = '%';
        break;

      case 0x45:
        label = 'موضع الخانق النسبي';
        unit = '%';
        break;

      case 0x46:
        label = 'حرارة الهواء الخارجي';
        unit = '°C';
        break;

      case 0x4C:
        label = 'ملعب الخانق (Actuator)';
        unit = '%';
        break;

      case 0x5A:
        label = 'دعسة الوقود النسبية';
        unit = '%';
        break;

      case 0x5C:
        label = 'حرارة زيت المحرك';
        unit = '°C';
        break;

      default:
        label = 'PID ${pid.toRadixString(16).toUpperCase()}';
        unit = '';
    }
    return (label, unit);
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
    var detail = '';

    // اسم القراءة ووحدتها من كتالوج أوامر Mode-01 (انظر [pidMetadata]).
    final (label, unit) = pidMetadata(pid);

    // هذه القيم جاهزة للتحويل إلى رقم،
    // ولا تحتاج إلى فك بايتات OBD.
    if (_directNumber.hasMatch(cleaned)) {
      value = num.parse(cleaned);
    } else {
      final bytes = hexBytes(cleaned);
      final markerIndex = _indexOf(
        bytes,
        [0x41, pid],
      );

      // استثناء "0100": بعض الجسور الفرومية تطبع الخريطة البتية
      // مباشرة "BE 3F B8 13" دون صدى الأمر "41 00" — نقبل الأربع
      // بايتات الأولى قبل أن نرفض الرد ككل.
      if (markerIndex < 0 && pid == 0x00 && bytes.length >= 4) {
        final supported = _decodeSupportedPids(bytes.sublist(0, 4), 1);
        if (supported.isEmpty) {
          throw ObdProtocolException('خريطة أوامر فارغة: $cleaned');
        }
        return PidReading(
          pid: pid,
          label: label,
          value: supported.length,
          unit: unit,
          raw: cleaned,
          detail: _supportedPidsText(supported, 0x01, 0x20),
        );
      }

      if (markerIndex < 0 || markerIndex + 2 >= bytes.length) {
        throw ObdProtocolException(
          'رد PID غير معروف أو غير مكتمل: $cleaned',
        );
      }

      final a = bytes[markerIndex + 2];

      final b = markerIndex + 3 < bytes.length ? bytes[markerIndex + 3] : 0;

      switch (pid) {
        case 0x00:
          // فك خريطة الأوامر المدعومة: بايتات A،B،C،D هي بتات
          // ترتيبها (MSB أولاً) يمثل PIDs من 0x01 إلى 0x20.
          final bitmap = <int>[a];
          var index = markerIndex + 3;
          while (bitmap.length < 4 && index < bytes.length) {
            bitmap.add(bytes[index]);
            index++;
          }
          final supported = _decodeSupportedPids(bitmap, 1);
          if (supported.isEmpty) {
            throw ObdProtocolException('رد 0100 بلا أوامر مدعومة: $cleaned');
          }
          value = supported.length;
          detail = _supportedPidsText(supported, 0x01, 0x20);
          break;

        case 0x01:
          // البت الأعلى في A = حالة مصباح العطل، والبقية = عدد الأكواد.
          final mil = (a & 0x80) != 0;
          final faults = a & 0x7F;
          value = faults;
          detail = 'MIL: ${mil ? 'مضاء' : 'مطفأ'} • عدد الأكواد: $faults';
          break;

        case 0x02:
          // كود العطل في إطار التجميد بنفس صيغة أكواد mode-03.
          final high = a;
          final low = b;
          final first = ['P', 'C', 'B', 'U'][(high >> 6) & 0x03];
          final second = ((high >> 4) & 0x03).toRadixString(16).toUpperCase();
          final suffix = '${(high & 0x0F).toRadixString(16).toUpperCase()}'
              '${low.toRadixString(16).padLeft(2, '0').toUpperCase()}';
          value = a * 256 + b;
          detail = 'كود في إطار التجميد: $first$second$suffix';
          break;

        case 0x03:
          // كل قيمة معروفة للحالة لها معنى قياسي (Open/Closed Loop).
          value = a;
          switch (a) {
            case 0x01:
              detail = 'حلقة مفتوحة (لم تكتمل الظروف بعد)';
              break;
            case 0x02:
              detail = 'حلقة مغلقة (استخدام تقييم حساس O2)';
              break;
            case 0x04:
              detail = 'حلقة مفتوحة بسبب خلل نظام الوقود';
              break;
            case 0x08:
              detail = 'حلقة مفتوحة بسبب خلل خارجي';
              break;
            case 0x10:
              detail = 'حلقة مغلقة، تقييم حساسات الأكسجين مكتمل';
              break;
            default:
              detail = 'قيمة حالة غير معروفة: $a';
          }
          break;

        case 0x04:
          // الحمل المحسوب = A * 100 / 255 %
          value = a * 100 / 255;
          break;

        case 0x0C:
          //  RPM = (A * 256 + B) / 4
          value = (a * 256 + b) / 4;
          break;

        case 0x05:
          // درجة الحرارة = A - 40
          value = a - 40;
          break;

        case 0x06:
        case 0x07:
          // تعديل الوقود قصير/طويل المدى = A - 128 %
          value = a - 128;
          break;

        case 0x0D:
          // السرعة بوحدة km/h
          value = a;
          break;

        case 0x0E:
          // الإشعال المتقدم = A / 2 - 64 درجة
          value = a / 2 - 64;
          break;

        case 0x0F:
          // حرارة هواء السحب = A - 40
          value = a - 40;
          break;

        case 0x10:
          // MAF = (A * 256 + B) / 100 g/s
          value = (a * 256 + b) / 100;
          break;

        case 0x11:
          // موضع الخانق كنسبة مئوية
          value = a * 100 / 255;
          break;

        case 0x13:
          // كل بت مجموع في A يمثل حساس O2 — العدد = عدد البتات المجابوبة.
          value = _bitCount(a);
          detail = 'عدد الحساسات الملاحَظة: ${_bitCount(a)} من 8';
          break;

        case 0x1F:
          // مدة تشغيل المحرك = A * 256 + B ثانية
          value = a * 256 + b;
          break;

        case 0x21:
          // المسافة بعمل مصباح العطل = A * 256 + B كم
          value = a * 256 + b;
          break;

        case 0x2C:
          // أمر EGR = A * 100 / 255 %
          value = a * 100 / 255;
          break;

        case 0x2F:
          // مستوى الوقود كنسبة مئوية
          value = a * 100 / 255;
          break;

        case 0x30:
          // عدد عمليات التسخين منذ مسح الأكواد = A
          value = a;
          break;

        case 0x31:
          // المسافة منذ مسح الأكواد = A * 256 + B كم
          value = a * 256 + b;
          break;

        case 0x33:
          // الضغط الجوي = A بوحدة kPa
          value = a;
          break;

        case 0x42:
          // جهد الوحدة = (A * 256 + B) / 1000 فولت
          value = (a * 256 + b) / 1000;
          break;

        case 0x43:
          // الحمل المطلق = (A * 256 + B) / 2.55 %
          value = (a * 256 + b) * 100 / 255;
          break;

        case 0x45:
          // الخانق النسبي = A * 100 / 255 %
          value = a * 100 / 255;
          break;

        case 0x46:
          // حرارة الهواء الخارجي = A - 40
          value = a - 40;
          break;

        case 0x4C:
          // ملعب الخانق = A * 100 / 255 %
          value = a * 100 / 255;
          break;

        case 0x5A:
          // دعسة الوقود النسبية = A * 100 / 255 %
          value = a * 100 / 255;
          break;

        case 0x5C:
          // حرارة زيت المحرك = A - 40
          value = a - 40;
          break;

        default:
          value = a;
      }
    }

    final normalizedValue = value.toDouble() == value.toDouble().roundToDouble()
        ? value.toInt()
        : value;

    return PidReading(
      pid: pid,
      label: label,
      value: normalizedValue,
      unit: unit,
      raw: cleaned,
      detail: detail,
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
  /// الأسطر الوسيطة من الجسر (SEARCHING.../BUS INIT...) تُتجاهل ولا
  /// تمنع فك الرد 43 الناقل بعدها؛ الخطأ الحقيقي (ERROR/NO DATA)
  /// يستبق ذخيرة الأكواد كاملة.
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
  ///
  /// 3. صيغة نصية مباشرة: بعض الأجهزة ترسل الأكواد كنص حرفي دون
  ///    رد "43" البايتي إطلاقاً، مثال: "P0128, P0420, P0430" أو
  ///    "p0128 p0420 p0430" (حساس/غير حساس للحالة، بأي فاصل — فاصلة
  ///    أو مسافة أو سطر جديد). تُفك هذه الأكواد نصياً وتُدمج مع أي
  ///    أكواد من الصيغ البايتية بالترتيب، مع إزالة التكرار.
  /// الأسطر الوسيطة التي يطبعها جسر ELM327 قبل الرد الحقيقي
  /// (مثل طلب البحث عن البروتوكول) — تُتجاهل ولا تمنع فك الأكواد.
  static bool _isBannerLine(String line) {
    final upper = line.toUpperCase();
    return upper.contains('SEARCHING') ||
        upper.contains('BUS INIT') ||
        upper.contains('BUSINIT') ||
        upper.contains('WAIT');
  }

  /// نمط كود DTC نصي حرفي: حرف نظام (P/C/B/U) + 0-3 (أفقي فرعي) +
  /// ثلاث صيغات سداسية عشرية — مثل P0128 وC0040 وU0155. غير حساس
  /// للحالة، ومحدود من الجانبين كي لا يلتقط أجزاء من كلمات أخرى.
  static final RegExp _textDtcPattern = RegExp(
    r'(?<![0-9A-Za-z])[PCBU][0-3][0-9A-Fa-f]{3}(?![0-9A-Za-z])',
    caseSensitive: false,
  );

  static List<String> parseDtc(String response) {
    // Banner filtering first: a real bridge response may arrive like
    // "SEARCHING...\r\n43 03 30 00 ..." — a full mode-03 reply embedded
    // after an intermediary line. isError() used to throw away these
    // valid codes entirely and make the vehicle appear fault-free.
    final lines = _mergeFrames(response).where((line) {
      if (_isBannerLine(line)) return false;
      return true;
    }).toList();

    final joined = lines.join(' ');
    if (isError(joined)) return const []; // a genuine error (ERROR/NO DATA...)

    final codes = <String>[];

    for (final text in lines) {
      // الصيغة النصية: الأجهزة التي ترسل الأكواد حرفياً (مثل
      // "P0128, P0420, P0430") لا تحمل بايت وضع "43" إطلاقاً —
      // نلتقطها نصياً من كل سطر قبل فحص الصيغ البايتية.
      for (final match in _textDtcPattern.allMatches(text)) {
        final code = match.group(0)!.toUpperCase();
        if (!codes.contains(code)) codes.add(code);
      }

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
        final suffix = '${(high & 0x0F).toRadixString(16).toUpperCase()}'
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

  /// فك خريطة "الأوامر المدعومة": كل بايت يحمل 8 بتات (MSB أولاً)،
  /// البت الأول في أول بايت = PID (01)، الأخير في البايت الرابع =
  /// PID (0x20). يعيد قائمة أرقام PIDs المميزة بالبتات المجابوبة.
  static List<int> _decodeSupportedPids(
    List<int> bitmap,
    int firstPid,
  ) {
    if (bitmap.isEmpty) return const [];

    final supported = <int>[];
    for (var i = 0; i < bitmap.length; i++) {
      for (var bit = 0; bit < 8; bit++) {
        if ((bitmap[i] & (0x80 >> bit)) != 0) {
          supported.add(firstPid + i * 8 + bit);
        }
      }
    }
    return supported;
  }

  /// صياغة قائمة الأوامر المدعومة كنص عربي مقروء: كل رقم بصيغته
  /// الست عشرية القياسية (مثل "0C" يعني 010C).
  static String _supportedPidsText(
    List<int> supported,
    int from,
    int to,
  ) {
    final pids = supported.where((p) => p >= from && p <= to).toList();
    final items = pids
        .map((p) => p.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join('، ');
    final hexFrom = from.toRadixString(16).padLeft(2, '0').toUpperCase();
    final hexTo = to.toRadixString(16).padLeft(2, '0').toUpperCase();
    return 'مدعوم (${pids.length} أمراً في النطاق $hexFrom–$hexTo): $items';
  }

  /// عدّاد البتات المجابوبة في بايت واحد.
  static int _bitCount(int byte) {
    var count = 0;
    var working = byte & 0xFF;
    while (working != 0) {
      count += working & 0x01;
      working >>= 1;
    }
    return count;
  }

  /// البحث عن تسلسل بايتات داخل قائمة.
  static int _indexOf(
    List<int> source,
    List<int> pattern,
  ) {
    if (pattern.isEmpty || pattern.length > source.length) {
      return -1;
    }

    for (var i = 0; i <= source.length - pattern.length; i++) {
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
  /// - تعديل الوقود قصير/طويل المدى (0x06/0x07): A-128
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

      case 0x06: // STFT = A - 128
      case 0x07: // LTFT = A - 128
        return '41 $pidHex ${hex(value.round() + 128)}';

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
