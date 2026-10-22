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

      // 0x10C (269 Decimal) -> RPM
      if (pid == 0x10C || pid == 269) {
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
      batteryVoltage: (obd['battery'] ?? 0) / 100.0, 
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

  /// بدء سحب البيانات باستمرار كل 500 مللي ثانية
  void startPolling({Duration interval = const Duration(milliseconds: 500)}) {
    stopPolling();

    _pollingTimer = Timer.periodic(interval, (_) async {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/live'))
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonMap = jsonDecode(response.body);
          final obdData = ObdLiveData.fromJson(jsonMap);
          _dataController.add(obdData);
        }
      } catch (e) {
        // التعامل مع خطأ الانقطاع المؤقت
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