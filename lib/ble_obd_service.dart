import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'obd_protocol.dart';
import 'package:permission_handler/permission_handler.dart';
/// حالة اتصال الجهاز كما تظهر في الواجهة.
enum ObdConnectionStatus { disconnected, scanning, connecting, connected, error }

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
    return idFragment.isNotEmpty ? 'جهاز BLE قريب ($idFragment)' : 'جهاز BLE بدون اسم';
  }

  String get id => result.device.remoteId.toString();
  int get rssi => result.rssi;
}

/// طبقة الاتصال الفعلية مع Freematics ONE+ عبر BLE.
///
/// المسار المستخدم في firmware المرفق:
/// 1. الجهاز يعلن خدمة `ABF0` باسم FreematicsPlus.
/// 2. التطبيق يكتب أوامر ASCII مثل `010C\\r` إلى الخاصية `FFE1`.
/// 3. firmware يضع البيانات المكتوبة في طابور `cmd_cmd_queue`.
/// 4. الردود النصية تصل من الخاصية `FFE2` عبر notification/indication.
/// 5. كل إشعار قد يكون جزءاً من الرد، لذلك نستخدم buffer وننتظر فترة هدوء قصيرة.
class BleObdService {
  static const String serviceUuid = 'ABF0';
  static const String commandCharacteristicUuid = 'FFE1';
  static const String responseCharacteristicUuid = 'FFE2';
  static const String expectedName = 'FreematicsPlus';

  final _scanResults = StreamController<List<DiscoveredObdDevice>>.broadcast();
  final _status = StreamController<ObdConnectionStatus>.broadcast();
  final _rawResponses = StreamController<String>.broadcast();

  Stream<List<DiscoveredObdDevice>> get scanResults => _scanResults.stream;
  Stream<ObdConnectionStatus> get status => _status.stream;
  Stream<String> get rawResponses => _rawResponses.stream;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandCharacteristic;
  BluetoothCharacteristic? _responseCharacteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _responseSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _quietTimer;
  Completer<String>? _responseCompleter;
  StringBuffer _responseBuffer = StringBuffer();

  ObdConnectionStatus _currentStatus = ObdConnectionStatus.disconnected;
  ObdConnectionStatus get currentStatus => _currentStatus;
  BluetoothDevice? get connectedDevice => _device;

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
          .where(
            (entry) => entry.value == PermissionStatus.permanentlyDenied,
          )
          .map((entry) => entry.key)
          .toList();

      if (permanentlyDenied.isNotEmpty) {
        await openAppSettings();
      }

      throw Exception(
        'يجب السماح بصلاحيات Bluetooth للبحث عن أجهزة OBD.',
      );
    }

    return;
  }

  if (Platform.isIOS) {
    final statuses = await [
      Permission.bluetooth,
    ].request();

    final denied = statuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key)
        .toList();

    if (denied.isNotEmpty) {
      throw Exception(
        'يجب السماح بصلاحية Bluetooth للبحث عن أجهزة OBD.',
      );
    }
  }
}

  // Future<void> scan({Duration timeout = const Duration(seconds: 10)}) async {
  //   _setStatus(ObdConnectionStatus.scanning);
  //   await _scanSubscription?.cancel();

  //   final devices = <String, DiscoveredObdDevice>{};
  //   _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
  //     for (final result in results) {
  //       // نعرض كل الأجهزة القريبة حسب متطلب التطبيق، مع إبقاء التوافق
  //       // مع Freematics متاحاً للواجهة كي تضع شارة على الجهاز المناسب.
  //       devices[result.device.remoteId.toString()] = DiscoveredObdDevice(result: result);
  //     }
  //     if (!_scanResults.isClosed) _scanResults.add(devices.values.toList());
  //   }, onError: (_) {
  //     _setStatus(ObdConnectionStatus.error);
  //   });

  //   try {
  //     await FlutterBluePlus.startScan(timeout: timeout);
  //     await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
  //     if (_currentStatus == ObdConnectionStatus.scanning) {
  //       _setStatus(ObdConnectionStatus.disconnected);
  //     }
  //   } catch (_) {
  //     _setStatus(ObdConnectionStatus.error);
  //     rethrow;
  //   }
  // }
// Future<void> scan({
//   Duration timeout = const Duration(seconds: 10),
// }) async {
//   await _requestBluetoothPermissions();

//   if (Platform.isAndroid) {
//     final state = await FlutterBluePlus.adapterState.first;
//     if (state != BluetoothAdapterState.on) {
//       throw Exception('البلوتوث غير مشغّل. قم بتشغيل Bluetooth أولاً.');
//     }
//   }

//   _setStatus(ObdConnectionStatus.scanning);
//   await _scanSubscription?.cancel();

//   final devices = <String, DiscoveredObdDevice>{};
//   if (!_scanResults.isClosed) {
//     _scanResults.add(<DiscoveredObdDevice>[]);
//   }

//   _scanSubscription = FlutterBluePlus.onScanResults.listen(
//     (results) {
//       for (final result in results) {
//         final key = result.device.remoteId.toString();
//         devices[key] = DiscoveredObdDevice(result: result);
//       }

//       final sorted = devices.values.toList()
//         ..sort((a, b) => b.rssi.compareTo(a.rssi));

//       if (!_scanResults.isClosed) {
//         _scanResults.add(sorted);
//       }
//     },
//     onError: (_) {
//       _setStatus(ObdConnectionStatus.error);
//     },
//   );

//   try {
//     await FlutterBluePlus.startScan(
//       timeout: timeout,
//       androidUsesFineLocation: true,
//     );

//     await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;

//     if (_currentStatus == ObdConnectionStatus.scanning) {
//       _setStatus(ObdConnectionStatus.disconnected);
//     }
//   } catch (_) {
//     _setStatus(ObdConnectionStatus.error);
//     rethrow;
//   }
// }
// Future<void> scan({
//   Duration timeout = const Duration(seconds: 10),
// }) async {
//   await _requestBluetoothPermissions();

//   if (Platform.isAndroid) {
//     final state = await FlutterBluePlus.adapterState.first;

//     if (state != BluetoothAdapterState.on) {
//       throw Exception(
//         'البلوتوث غير مشغّل. قم بتشغيل Bluetooth أولاً.',
//       );
//     }
//   }

//   _setStatus(ObdConnectionStatus.scanning);

//   await _scanSubscription?.cancel();
//   _scanSubscription = null;

//   final devices = <String, DiscoveredObdDevice>{};

//   if (!_scanResults.isClosed) {
//     _scanResults.add([]);
//   }

//   _scanSubscription = FlutterBluePlus.onScanResults.listen(
//     (results) {
//       for (final result in results) {
//         final key = result.device.remoteId.toString();

//         devices[key] = DiscoveredObdDevice(
//           result: result,
//         );
//       }

//       final sorted = devices.values.toList()
//         ..sort(
//           (a, b) => b.rssi.compareTo(a.rssi),
//         );

//       if (!_scanResults.isClosed) {
//         _scanResults.add(sorted);
//       }
//     },
//     onError: (error) {
//       _setStatus(ObdConnectionStatus.error);
//     },
//   );

//   try {
//     await FlutterBluePlus.startScan(
//       timeout: timeout,

//       // إذا لا تحتاج تحديد الموقع:
//       androidUsesFineLocation: false,
//     );

//     await FlutterBluePlus.isScanning
//         .where((scanning) => !scanning)
//         .first;

//     if (_currentStatus == ObdConnectionStatus.scanning) {
//       _setStatus(
//         ObdConnectionStatus.disconnected,
//       );
//     }
//   } catch (e) {
//     _setStatus(ObdConnectionStatus.error);
//     rethrow;
//   }
// }
Future<void> scan({
  Duration timeout = const Duration(seconds: 10),
  int minRssi = -85,
}) async {
  await _requestBluetoothPermissions();

  if (Platform.isAndroid) {
    final state = await FlutterBluePlus.adapterState.first;

    if (state != BluetoothAdapterState.on) {
      throw Exception(
        'البلوتوث غير مشغّل. قم بتشغيل Bluetooth أولاً.',
      );
    }
  }

  _setStatus(ObdConnectionStatus.scanning);

  await _scanSubscription?.cancel();
  _scanSubscription = null;

  final devices = <String, DiscoveredObdDevice>{};

  if (!_scanResults.isClosed) {
    _scanResults.add([]);
  }

  const obdNames = <String>[
    'obd',
    'elm327',
    'elm',
    'obdii',
    'obd2',
    'vgate',
    'konnwei',
    'kw902',
    'kw903',
    'icar',
    'icar2',
    'icar pro',
    'carista',
    'veepeak',
    'viecar',
  ];

  bool isObdByName(String name) {
    final normalized = name.trim().toLowerCase();

    if (normalized.isEmpty) {
      return false;
    }

    return obdNames.any(
      (keyword) => normalized.contains(keyword),
    );
  }

  _scanSubscription = FlutterBluePlus.onScanResults.listen(
    (results) {
      for (final result in results) {
        final device = result.device;

        // RSSI فقط لتحديد قوة/قرب الإشارة.
        //
        // لا نرفض الجهاز بسبب الاسم أو Service UUID.
        if (result.rssi < minRssi) {
          continue;
        }

        final advName = result.advertisementData.advName.trim();
        final platformName = device.platformName.trim();

        final name = advName.isNotEmpty
            ? advName
            : platformName;

        final serviceUuids =
            result.advertisementData.serviceUuids
                .map((uuid) => uuid.toString())
                .toList();

        final isObd = isObdByName(name);

        final key = device.remoteId.toString();

        devices[key] = DiscoveredObdDevice(
          result: result,
        );

        // يمكنك هنا تسجيل معلومات الجهاز أثناء التطوير.
        debugPrint(
          'BLE DEVICE: '
          'name="$name", '
          'id="$key", '
          'rssi=${result.rssi}, '
          'services=$serviceUuids, '
          'isOBD=$isObd',
        );
      }

      final sorted = devices.values.toList()
        ..sort(
          (a, b) => b.rssi.compareTo(a.rssi),
        );

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

    await FlutterBluePlus.isScanning
        .where((scanning) => !scanning)
        .first;

    if (_currentStatus == ObdConnectionStatus.scanning) {
      _setStatus(
        ObdConnectionStatus.disconnected,
      );
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

  Future<void> connect(BluetoothDevice device) async {
    await stopScan();
    await disconnect();
    _setStatus(ObdConnectionStatus.connecting);
    _device = device;

    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _commandCharacteristic = null;
        _responseCharacteristic = null;
        _responseSubscription?.cancel();
        _setStatus(ObdConnectionStatus.disconnected);
      }
    });

    try {
      // await device.connect(timeout: const Duration(seconds: 15), mtu: null);
      await device.connect(
  license: License.nonprofit,
  timeout: const Duration(seconds: 15),
  mtu: null,
);
      if (Platform.isAndroid) {
        // نطلب MTU أكبر للردود الطويلة مثل VIN، مع بقاء parser قادراً على
        // التعامل مع التجزئة إذا رفضت المنصة أو الجهاز الطلب.
        try {
          await device.requestMtu(247);
        } catch (_) {
          // ليس خطأً قاتلاً؛ بعض الأجهزة لا تسمح بتغيير MTU.
        }
      }

      // يجب اكتشاف الخدمات بعد كل اتصال جديد، حسب سلوك BLE القياسي.
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (item) => item.uuid == Guid(serviceUuid),
        orElse: () => throw const ObdProtocolException('خدمة ABF0 غير موجودة في الجهاز.'),
      );

      _commandCharacteristic = service.characteristics.firstWhere(
        (item) => item.uuid == Guid(commandCharacteristicUuid),
        orElse: () => throw const ObdProtocolException('خاصية الأوامر FFE1 غير موجودة.'),
      );
      _responseCharacteristic = service.characteristics.firstWhere(
        (item) => item.uuid == Guid(responseCharacteristicUuid),
        orElse: () => throw const ObdProtocolException('خاصية الردود FFE2 غير موجودة.'),
      );

      await _responseCharacteristic!.setNotifyValue(true);
      _responseSubscription = _responseCharacteristic!.onValueReceived.listen(_onBytesReceived);
      _setStatus(ObdConnectionStatus.connected);

      // تهيئة ELM327/جسر OBD بعد جاهزية قناة BLE.
      await sendCommand(ObdCommands.initialize, timeout: const Duration(seconds: 4));
      await sendCommand(ObdCommands.disableEcho);
      await sendCommand(ObdCommands.disableHeaders);
    } catch (_) {
      _setStatus(ObdConnectionStatus.error);
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _quietTimer?.cancel();
    _responseCompleter?.completeError(const ObdProtocolException('تم فصل الجهاز.'));
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
      } catch (_) {
        // قد يكون الجهاز مفصولاً فعلياً بالفعل.
      }
    }
    _setStatus(ObdConnectionStatus.disconnected);
  }

  Future<String> sendCommand(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final characteristic = _commandCharacteristic;
    if (characteristic == null || _currentStatus != ObdConnectionStatus.connected) {
      throw const ObdProtocolException('لا يوجد جهاز متصل لإرسال الأمر.');
    }
    if (_responseCompleter != null) {
      throw const ObdProtocolException('يوجد أمر آخر قيد التنفيذ؛ انتظر الرد أولاً.');
    }

    _responseBuffer = StringBuffer();
    final completer = Completer<String>();
    _responseCompleter = completer;
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(_responseBuffer.toString());
      }
    });

    try {
      final bytes = utf8.encode(command);
      await characteristic.write(
        bytes,
        withoutResponse: characteristic.properties.writeWithoutResponse,
      );
      final response = await completer.future;
      _rawResponses.add(response);
      return response;
    } finally {
      timer.cancel();
      _quietTimer?.cancel();
      _responseCompleter = null;
    }
  }

  void _onBytesReceived(List<int> bytes) {
    final chunk = utf8.decode(bytes, allowMalformed: true);
    _responseBuffer.write(chunk);
    _rawResponses.add(chunk);
    final completer = _responseCompleter;
    if (completer == null) return;

    // نكمل الرد بعد هدوء 250ms. هذا يتجنب افتراض أن notification واحداً
    // يساوي رسالة كاملة، وهو مهم خصوصاً لرد VIN متعدد الإطارات.
    _quietTimer?.cancel();
    _quietTimer = Timer(const Duration(milliseconds: 250), () {
      if (!completer.isCompleted && _responseBuffer.isNotEmpty) {
        completer.complete(_responseBuffer.toString());
      }
    });
  }

  Future<void> dispose() async {
    await disconnect();
    await stopScan();
    await _scanResults.close();
    await _status.close();
    await _rawResponses.close();
  }
}
