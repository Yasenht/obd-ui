import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'obd_protocol.dart';
import 'package:permission_handler/permission_handler.dart';

enum ObdConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error
}

class DiscoveredObdDevice {
  const DiscoveredObdDevice({required this.result});
  final ScanResult result;

  BluetoothDevice get device => result.device;
  String get name {
    final advName = result.advertisementData.advName.trim();
    if (advName.isNotEmpty) return advName;

    final localName = result.advertisementData.localName.trim();
    if (localName.isNotEmpty) return localName;

    final platformName = result.device.platformName.trim();
    if (platformName.isNotEmpty) return platformName;

    final idFragment = result.device.remoteId.toString();
    return idFragment.isNotEmpty
        ? 'جهاز BLE قريب ($idFragment)'
        : 'جهاز BLE بدون اسم';
  }

  String get id => result.device.remoteId.toString();
  int get rssi => result.rssi;
}

class BleObdService {
  final _scanResults = StreamController<List<DiscoveredObdDevice>>.broadcast();
  final _status = StreamController<ObdConnectionStatus>.broadcast();
  final _rawResponses = StreamController<String>.broadcast();

  String _normalizeUuid(Guid uuid) {
    final value = uuid.toString().toLowerCase();

    // UUID مختصر مثل abf0 أو ffe1.
    if (value.length == 4) {
      return '0000$value-0000-1000-8000-00805f9b34fb';
    }

    return value;
  }

  Stream<List<DiscoveredObdDevice>> get scanResults => _scanResults.stream;
  Stream<ObdConnectionStatus> get status => _status.stream;
  Stream<String> get rawResponses => _rawResponses.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandCharacteristic;
  BluetoothCharacteristic? _responseCharacteristic;

  /// خاصية استقبال الردود FFE2 للجهاز المتصل حالياً (لأغراض التشخيص).
  BluetoothCharacteristic? get responseCharacteristic =>
      _responseCharacteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _responseSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _quietTimer;
  Completer<String>? _responseCompleter;
  StringBuffer _responseBuffer = StringBuffer();

  ObdConnectionStatus _currentStatus = ObdConnectionStatus.disconnected;
  ObdConnectionStatus get currentStatus => _currentStatus;
  BluetoothDevice? get connectedDevice => _device;

  /// قائمة الأوامر المدعومة في فيرموير Freematics v5 (telelogger.ino
  /// داخل processBLE()). كل أمر خارج هذه القائمة (بما فيها أوامر
  /// ELM327 القياسية مثل ATZ/ATH0/03/0902) يُجاب من الجهاز بـ "ERROR".
  ///
  /// المُعرّفات: "01XX" (أي Mode-01 PID بإزاحة ضمن قائمة obdData
  /// أو قراءة مباشرة عبر جسر OBD) والبادئات الإعدادية APN=/SSID=/WPWD=.
  static const Set<String> _firmwareSupportedCommands = {
    'UPTIME', 'TICK', 'BATT', 'RESET', 'OFF', 'ON', 'ON?', 'FS',
    'APN?', 'NET_OP', 'NET_IP', 'NET_PACKET', 'NET_DATA', 'NET_RATE',
    'RSSI', 'SSID?', 'WPWD?', 'TEMP', 'ACC', 'GYRO', 'GF',
    'ATE0', 'ATE1', 'VIN', 'LAT', 'LNG', 'ALT', 'SAT', 'SPD', 'CRS',
    // أوامر DTC المقترحة (بعد تحديث الفيرموير، انظر firmware_patch/)
    'DTC?', 'DTCS?', 'DTCS>', 'DTCCLR',
    // أوامر وضع 02 (إطار التجميد) ووضع 03 القياسية — مدعومة في
    // processBLE() بالفيرموير v5 (الفرع الموحّد "03"/"02"/"DTCS?").
    '02', '03',
  };

  static const Set<String> _firmwareSupportedPrefixes = {
    '01',
    'APN=',
    'SSID=',
    'WPWD=',
  };

  /// هل الأمر مدعوم في فيرموير v5؟ (للتشخيص وتحذير المستخدم)
  static bool isCommandSupported(String command) {
    final cmd = command.trim().toUpperCase().replaceAll('\r', '');
    if (cmd.isEmpty) return false;
    if (_firmwareSupportedCommands.contains(cmd)) return true;
    for (final prefix in _firmwareSupportedPrefixes) {
      if (cmd.startsWith(prefix)) return true;
    }
    return false;
  }

  void _setStatus(ObdConnectionStatus next) {
    _currentStatus = next;
    if (!_status.isClosed) _status.add(next);
  }

  Future<void> requestPermissions() async {
    await _requestBluetoothPermissions();
  }

  Future<void> _requestBluetoothPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final denied = statuses.entries
          .where((entry) => !entry.value.isGranted)
          .map((entry) => entry.key)
          .toList();

      if (denied.isNotEmpty) {
        final permanentlyDenied = statuses.entries
            .where((entry) => entry.value == PermissionStatus.permanentlyDenied)
            .map((entry) => entry.key)
            .toList();

        if (permanentlyDenied.isNotEmpty) {
          await openAppSettings();
        }

        throw Exception('يجب السماح بصلاحيات Bluetooth للبحث عن أجهزة OBD.');
      }
      return;
    }

    if (Platform.isIOS) {
      final statuses = await [Permission.bluetooth].request();
      final denied = statuses.entries
          .where((entry) => !entry.value.isGranted)
          .map((entry) => entry.key)
          .toList();

      if (denied.isNotEmpty) {
        throw Exception('يجب السماح بصلاحية Bluetooth للبحث عن أجهزة OBD.');
      }
    }
  }

  Future<void> scan({
    Duration timeout = const Duration(seconds: 10),
    int minRssi = -85,
  }) async {
    await _requestBluetoothPermissions();

    if (Platform.isAndroid) {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        throw Exception('البلوتوث غير مشغّل. قم بتشغيل Bluetooth أولاً.');
      }
    }

    _setStatus(ObdConnectionStatus.scanning);

    await _scanSubscription?.cancel();
    _scanSubscription = null;

    final devices = <String, DiscoveredObdDevice>{};

    if (!_scanResults.isClosed) {
      _scanResults.add([]);
    }

    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final result in results) {
          if (result.rssi < minRssi) continue;

          final key = result.device.remoteId.toString();
          devices[key] = DiscoveredObdDevice(result: result);
        }

        final sorted = devices.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));

        if (!_scanResults.isClosed) {
          _scanResults.add(sorted);
        }
      },
      onError: (error) {
        debugPrint('BLE scan error: $error');
        _setStatus(ObdConnectionStatus.error);
      },
    );

    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;

      if (_currentStatus == ObdConnectionStatus.scanning) {
        _setStatus(ObdConnectionStatus.disconnected);
      }
    } catch (e) {
      debugPrint('BLE scan failed: $e');
      _setStatus(ObdConnectionStatus.error);
      rethrow;
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_currentStatus == ObdConnectionStatus.scanning) {
      _setStatus(ObdConnectionStatus.disconnected);
    }
  }

  final StreamController<String> _debugLogController =
      StreamController<String>.broadcast();

  Stream<String> get debugLogs => _debugLogController.stream;

  /// تسجيل رسالة من مستوى التعليمة (مثل طروحات DTC قبل الإرسال
  /// وبعد الاستقبال) في نفس سجل BLE المعروض بالواجهة، لتتبع
  /// أين يقع الخطأ: في الإرسال (FFE1) أم في الاستقبال (FFE2).
  void appLog(String message) => _log(message);

  void _log(String message) {
    debugPrint(message);

    if (!_debugLogController.isClosed) {
      _debugLogController.add(
        '${DateTime.now().toIso8601String()}  $message',
      );
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      _log('========== بدء الاتصال بجهاز BLE ==========');

      await stopScan();
      await disconnect();

      _setStatus(ObdConnectionStatus.connecting);
      _log('حالة الاتصال: connecting');

      _log('الاتصال بالجهاز: ${device.remoteId}');

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _device = device;

      _log('نجح اتصال Bluetooth');

      await _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        _log('Bluetooth connection state: $state');

        if (state == BluetoothConnectionState.disconnected) {
          _commandCharacteristic = null;
          _responseCharacteristic = null;

          _responseSubscription?.cancel();
          _responseSubscription = null;

          // إجهاض أي أمر معلق فورًا عند الانقطاع — بدون هذا الإصلاح كان
          // الأمر المعلّق (مثل "0100" في سجل 15:59) ينتظر مهلة الإرسال
          // الكاملة (30 ثانية) ثم يُنسب الخطأ خطأً إلى "عدم وصول رد"
          // بينما السبب الفعلي انقطاع اتصال BLE أثناء انتظار الرد.
          if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
            _responseCompleter!.completeError(
              const ObdProtocolException(
                'انقطع اتصال Bluetooth أثناء انتظار رد الأمر.',
              ),
            );
          }
          _responseCompleter = null;
          _quietTimer?.cancel();
          _quietTimer = null;
          _responseBuffer = StringBuffer();

          _device = null;
          _setStatus(ObdConnectionStatus.disconnected);

          _log('تم فصل الجهاز؛ الحالة أصبحت disconnected');
        }
      });

      _log('اكتشاف الخدمات');
      final services = await device.discoverServices();

      // التفاوض على MTU أكبر على Android؛ iOS يتفاوض تلقائياً (~185)
      // والقيمة أكبر MTU تتيح حمل ردود DTC الأكبر في إشعار واحد.
      if (Platform.isAndroid) {
        try {
          final mtu = await device.requestMtu(128);
          _log('MTU بعد التفاوض: $mtu');
        } catch (e) {
          _log('تنبيه: تعذر التفاوض على MTU: $e');
        }
      }

      _log('عدد الخدمات المكتشفة: ${services.length}');

      BluetoothService? obdService;

      for (final service in services) {
        _log('SERVICE UUID: ${service.uuid}');

        for (final characteristic in service.characteristics) {
          final p = characteristic.properties;

          _log(
            'CHAR UUID: ${characteristic.uuid} | '
            'WRITE: ${p.write} | '
            'WRITE WITHOUT RESPONSE: ${p.writeWithoutResponse} | '
            'NOTIFY: ${p.notify} | '
            'INDICATE: ${p.indicate}',
          );
        }

        if (_normalizeUuid(service.uuid) ==
            '0000abf0-0000-1000-8000-00805f9b34fb') {
          obdService = service;
        }
      }

      if (obdService == null) {
        throw Exception('لم يتم العثور على خدمة ABF0');
      }

      BluetoothCharacteristic? commandChar;
      BluetoothCharacteristic? notifyChar;

      for (final characteristic in obdService.characteristics) {
        final uuid = _normalizeUuid(characteristic.uuid);
        final p = characteristic.properties;

        if (uuid == '0000ffe1-0000-1000-8000-00805f9b34fb' &&
            (p.write || p.writeWithoutResponse)) {
          commandChar = characteristic;
        }

        if (uuid == '0000ffe2-0000-1000-8000-00805f9b34fb' &&
            (p.notify || p.indicate)) {
          notifyChar = characteristic;
        }
      }

      if (commandChar == null) {
        throw Exception('FFE1 غير موجودة أو لا تدعم الكتابة');
      }

      if (notifyChar == null) {
        throw Exception('FFE2 غير موجودة أو لا تدعم الإشعارات');
      }

      _commandCharacteristic = commandChar;
      _responseCharacteristic = notifyChar;

      // إلغاء أي مستمع قديم قبل إنشاء مستمع جديد.
      await _responseSubscription?.cancel();

      _responseSubscription = notifyChar.onValueReceived.listen(
        _onBytesReceived,
        onError: (Object error, StackTrace stackTrace) {
          _log('خطأ استقبال BLE: $error');
          _log('$stackTrace');
        },
      );

      // تفعيل الإشعارات بعد تسجيل المستمع.
      await notifyChar.setNotifyValue(true);

      _log('تم تفعيل إشعارات FFE2');
      _log('FFE1: ${commandChar.uuid}');
      _log('FFE2: ${notifyChar.uuid}');

      // لا تعلن الاتصال الكامل إلا بعد تجهيز الخصائص والإشعارات.
      _setStatus(ObdConnectionStatus.connected);
      _log('حالة الاتصال: connected');
      _log('========== اكتمل اتصال BLE ==========');

      // 1. تعطيل صدى الأوامر Echo
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        await sendCommand('ATE0');
        _log('تم إرسال ATE0 لتعطيل Echo بنجاح');
      } catch (e) {
        _log('تنبيه: تعذر إرسال ATE0: $e');
      }

      // 2. إرسال أمر ON لإيقاظ الفيرموير وبدء تهيئة OBD مع السيارة
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        final onResp = await sendCommand('ON');
        _log('تنشيط رابط OBD عبر أمر ON: $onResp');
      } catch (e) {
        _log('تنبيه: تعذر إرسال أمر ON: $e');
      }
    } catch (e, st) {
      _log('فشل الاتصال: $e');
      _log('$st');

      _setStatus(ObdConnectionStatus.error);

      try {
        await disconnect();
      } catch (disconnectError) {
        _log('خطأ أثناء التنظيف بعد فشل الاتصال: $disconnectError');
      }

      rethrow;
    }
  }

  Future<void> disconnect() async {
    _quietTimer?.cancel();
    if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
      _responseCompleter!
          .completeError(const ObdProtocolException('تم فصل الجهاز.'));
    }
    _responseCompleter = null;
    await _responseSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _responseSubscription = null;
    _connectionSubscription = null;

    final device = _device;
    _device = null;
    _commandCharacteristic = null;
    _responseCharacteristic = null;

    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _setStatus(ObdConnectionStatus.disconnected);
  }

  Future<String> sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final characteristic = _commandCharacteristic;

    _log('BLE TX command: $command');
    _log('BLE TX bytes: ${command.codeUnits}');
    _log('إرسال أمر OBD: $command');
    if (characteristic == null ||
        _currentStatus != ObdConnectionStatus.connected) {
      throw const ObdProtocolException(
        'لا يوجد جهاز متصل وجاهز لإرسال الأمر.',
      );
    }

    if (_responseCompleter != null) {
      throw const ObdProtocolException(
        'يوجد أمر آخر قيد التنفيذ؛ انتظر الرد أولاً.',
      );
    }

    final normalizedCommand = command.trim();

    if (normalizedCommand.isEmpty) {
      throw const ObdProtocolException('لا يمكن إرسال أمر فارغ.');
    }
    final wireCommand = normalizedCommand.endsWith('\r')
        ? normalizedCommand
        : '$normalizedCommand\r';

    final bytes = utf8.encode(wireCommand);

    // حد خاصية الأوامر في فيرموير Freematics هو SPP_CMD_MAX_LEN = 20 بايت
    // (انظر ble_spp_server.h)؛ كل عملية كتابة واحدة على FFE1 تُعامل كأمر
    // مستقل تماماً (لا يوجد تجميع للأمر المجزأ على جانب الجهاز).
    if (bytes.length > 20) {
      throw const ObdProtocolException(
        'طول الأمر يتجاوز 20 بايت؛ خاصية الأوامر FFE1 في جهاز'
        ' Freematics ترفض أوامر أطول من ذلك.',
      );
    }

    // تجهيز استقبال الرد قبل إرسال الأمر.
    _responseBuffer = StringBuffer();

    // تحذير تشخيصي: أمر غير مدعوم في فيرموير telelogger v5
    // (سيُجاب غالباً بـ "ERROR" — لم نحظر الإرسال لتوافق ذات bridge
    // ELM327 الأصلية في إصدارات الفيرموير الأخرى).
    if (!isCommandSupported(normalizedCommand)) {
      _log('تحذير: أمر "$normalizedCommand" غير مدرج في قائمة أوامر'
          ' فيرموير Freematics v5؛ قد يرد الجهاز "ERROR".');
    }

    final completer = Completer<String>();
    _responseCompleter = completer;

    _quietTimer?.cancel();

    _log('BLE TX command: ${jsonEncode(wireCommand)}');

    _log('BLE TX bytes: $bytes');

    final timeoutTimer = Timer(timeout, () {
      if (completer.isCompleted) return;

      final partialResponse = _responseBuffer.toString();

      if (partialResponse.trim().isNotEmpty) {
        completer.complete(partialResponse);
      } else {
        completer.completeError(
          TimeoutException(
            'لم يصل رد من جهاز OBD على الأمر: $normalizedCommand',
            timeout,
          ),
        );
      }
    });

    try {
      final properties = characteristic.properties;

      final bool withoutResponse;

      if (properties.write) {
        withoutResponse = false;
      } else if (properties.writeWithoutResponse) {
        withoutResponse = true;
      } else {
        throw const ObdProtocolException(
          'خاصية FFE1 لا تدعم الكتابة المطلوبة.',
        );
      }

      await characteristic.write(
        bytes,
        withoutResponse: withoutResponse,
      );

      _log('تم إرسال الأمر إلى FFE1 بنجاح');

      final response = await completer.future;

      _log('BLE RX response: ${jsonEncode(response)}');

      if (!_rawResponses.isClosed) {
        _rawResponses.add(response);
      }

      return response;
    } catch (e, st) {
      _log('فشل إرسال الأمر أو انتظار الرد: $e');
      _log('$st');
      rethrow;
    } finally {
      timeoutTimer.cancel();
      _quietTimer?.cancel();

      if (identical(_responseCompleter, completer)) {
        _responseCompleter = null;
      }
    }
  }

  void _onBytesReceived(List<int> bytes) {
    _log('BLE RX bytes: $bytes');

    final chunk = utf8.decode(bytes, allowMalformed: true);
    _log('BLE RX text: ${jsonEncode(chunk)}');

    _responseBuffer.write(chunk);

    if (!_rawResponses.isClosed) {
      _rawResponses.add(chunk);
    }

    final completer = _responseCompleter;
    if (completer == null || completer.isCompleted) return;

    final currentResponse = _responseBuffer.toString();
    final payload = currentResponse.replaceAll(
      RegExp(r'[\r\n\s>]'),
      '',
    );

    if (payload.isEmpty) {
      _log('BLE RX: وصل فاصل سطر فقط؛ انتظار بيانات إضافية.');
      return;
    }

    // انتظر قليلًا لتجميع أجزاء الرد قبل إكمال الأمر.
    //
    // فيرموير Freematics (telelogger) يرسل كل رد ضمن إشعار BLE واحد
    // وينهيه بمحرف \r، لذا إن وصل محرف نهاية السطر والرد قصير
    // (سطر واحد) نُكمل الرد بعد مهلة قصيرة (60ms) بدل انتظار فترة
    // الهدوء الكاملة (550ms) لتقليل زمن كل أمر. أما الردود متعددة
    // الأسطر أو المجزأة فتبقى تنتظر فترة الهدوء كما كان.
    // ردود أكواد الأعطال تبدأ بـ "43 " وقد تُقطع على عدة إشعارات،
    // لذا تُجمع دائماً عبر فترة الهدوء الكاملة (550ms) دون المسار السريع.
    // يشمل الالتقاط أيضاً الإطارات CAN المرقّمة ("0: 43 04 ...") —
    // سابقاً كانت السطر الأول فقط يُكمل الأمر عبر المسار السريع (60ms)
    // وباقي الأسطر ("1: ...") تضيع فتظهر أكواد ناقصة أو مختلّة.
    final trimmedResponse = currentResponse.trimLeft();
    final isDtcFrame = trimmedResponse.startsWith('43 ') ||
        RegExp(r'^\d{1,2}:\s').hasMatch(trimmedResponse);

    // ردود "وسيطة" من جسر ELM/OBD (مثل "SEARCHING..." أو "BUS INIT")
    // تصل كأول سطر قبل الرد الحقيقي؛ إن أُكمل الأمر عليها بمسار EOL
    // السريع (60ms) فلن يصل رد الأكواد الحقيقي أصلاً — إشارة
    // استخراج الأعطال كلها تضيع. تُجمع هذه الظاهرة عبر فترة الهدوء
    // الكاملة مثل إطارات DTC.
    final isInterimStatus =
        currentResponse.toUpperCase().contains('SEARCHING') ||
            currentResponse.toUpperCase().contains('BUS INIT') ||
            currentResponse.toUpperCase().contains('BUSINIT');

    _quietTimer?.cancel();
    final isEolTerminated = chunk.contains('\r') &&
        payload.length <= 32 &&
        !isDtcFrame &&
        !isInterimStatus;
    _quietTimer = Timer(
      Duration(milliseconds: isEolTerminated ? 60 : 550),
      () {
        if (!completer.isCompleted) {
          final response = _responseBuffer.toString();
          _log(
              'BLE RX complete (${isEolTerminated ? 'EOL' : 'quiet'}): ${jsonEncode(response)}');
          completer.complete(response);
        }
      },
    );
  }

  Future<void> dispose() async {
    await disconnect();
    await stopScan();
    await _scanResults.close();
    await _status.close();
    await _rawResponses.close();
    await _debugLogController.close();
  }
}
