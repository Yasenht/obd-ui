import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ObdLiveData {
  final String vin;
  final double batteryVoltage;
  final int rpm;
  final int speed;
  final int coolantTemp;

  ObdLiveData({
    required this.vin,
    required this.batteryVoltage,
    required this.rpm,
    required this.speed,
    required this.coolantTemp,
  });

  factory ObdLiveData.fromJson(Map<String, dynamic> json) {
    final obd = json['obd'] ?? {};
    final List pids = obd['pid'] ?? [];

    int extractedRpm = 0;
    int extractedSpeed = 0;
    int extractedTemp = 0;

    for (var item in pids) {
      final pid = item['pid'];
      final value = item['value'] ?? 0;

      // 0x10C = 268 (0x100 | PID_RPM 0x0C) -> RPM
      // handlerLiveData في الفيرموير ينشر pid بصيغة 0x100 | PID.
      if (pid == 0x10C || pid == 268) {
        extractedRpm = value;
      }
      // 0x10D (269 Decimal) -> Speed
      else if (pid == 0x10D || pid == 269) {
        extractedSpeed = value;
      }
      // 0x105 (261 Decimal) -> Coolant Temp
      else if (pid == 0x105 || pid == 261) {
        extractedTemp = value;
      }
    }

    return ObdLiveData(
      vin: obd['vin'] ?? 'N/A',
      // الفيرموير يرسل الجهد مباشرة بالفولت (مثل 12.4):
      // في process() داخل telelogger.ino:
      // batteryVoltage = analogRead(A0) * 45 / 4095
      // // القيمة السابقة كانت مقسومة على 100 على افتراض أنها بالملي فولت
      // batteryVoltage: (obd['battery'] ?? 0) / 100.0,
      batteryVoltage: (obd['battery'] as num? ?? 0).toDouble(),
      rpm: extractedRpm,
      speed: extractedSpeed,
      coolantTemp: extractedTemp,
    );
  }
}

class ObdHttpService {
  
  final String baseUrl;
  Timer? _pollingTimer;

  final _dataController = StreamController<ObdLiveData>.broadcast();
  Stream<ObdLiveData> get dataStream => _dataController.stream;

  ObdHttpService({this.baseUrl = 'http://192.168.4.1'});

  /// نقاط النهاية المدعومة بالترتيب:
  ///
  /// 1. "api/live" المسجلة في urlHandlerList داخل telelogger.ino (الإصدار v5).
  /// 2. "live" مسار قديم محتمل في إصدارات الفيرموير الأقدم؛ يُستخدم كاحتياط.
  static const List<String> _endpoints = <String>[
    '/api/live',
    '/live',
  ];

  int _activeEndpoint = 0;

  /// بدء سحب البيانات باستمرار كل 500 مللي ثانية
  void startPolling({Duration interval = const Duration(milliseconds: 500)}) {
    stopPolling();

    _pollingTimer = Timer.periodic(interval, (_) async {
      try {
        // تجربة نقطة النهاية الحالية أولاً، وعند الفشل ننتقل للنقطة التالية.
        final path = _endpoints[_activeEndpoint];
        final response = await http
            .get(Uri.parse('$baseUrl$path'))
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          // نجح المسار الحالي؛ نبقيه محجوزاً.
          final Map<String, dynamic> jsonMap = jsonDecode(response.body);
          final obdData = ObdLiveData.fromJson(jsonMap);
          _dataController.add(obdData);
        } else {
          if (_activeEndpoint < _endpoints.length - 1) {
            _activeEndpoint++;
          }
        }
      } catch (e) {
        // التعامل مع خطأ الانقطاع المؤقت
        if (_activeEndpoint < _endpoints.length - 1) {
          _activeEndpoint++;
        }
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void dispose() {
    stopPolling();
    _dataController.close();
  }
}
