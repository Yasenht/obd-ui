import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble_obd_service.dart';
import '../history_repository.dart';
import '../models.dart';
import '../models/dtc_analysis.dart';
import '../obd_analysis_api.dart';
import '../obd_protocol.dart';
import '../services/dtc_analysis_service.dart';
import '../services/vehicle_catalog.dart';

/// الحالة المشتركة للتطبيق: الاتصال، الفحص، البيانات الحية،
/// السجل، وإعدادات المظهر.
///
/// تُستمع إليها من الواجهات عبر InheritedNotifier (AppScope) —
/// منطق الاتصال والفك نفسه في [BleObdService] و[ObdParser]
/// لم يُغيَّر، فقط فُصل عن ملف الواجهة الأحادي.
class AppController extends ChangeNotifier {
  final BleObdService bleService = BleObdService();
  final ObdAnalysisApi analysisApi = ObdAnalysisApi();
  final HistoryRepository historyRepository = HistoryRepository();
  final DtcAnalysisService dtcAnalysisService = DtcAnalysisService();

  StreamSubscription<List<DiscoveredObdDevice>>? _scanSubscription;
  StreamSubscription<ObdConnectionStatus>? _statusSubscription;
  StreamSubscription<String>? _debugLogSubscription;

  // ---- وضع العرض (فاتح/داكن/النظام) — محفوظ محلياً ----
  static const String _themekey = 'app_theme_mode_v1';
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  // ---- معلومات المركبة (الماركة/الموديل/سنة الصنع) — محفوظة محلياً ----
  static const String _vehicleMakeKey = 'vehicle_make_v1';
  static const String _vehicleModelKey = 'vehicle_model_v1';
  static const String _vehicleYearKey = 'vehicle_year_v1';

  /// أصغر سنة مدعومة: 2005 وما قبلها لا تدعم الفحص (انظر [VehicleCatalog]).
  static const int minObdYear = VehicleCatalog.minSupportedYear;

  String? _vehicleMake;
  String? _vehicleModel;
  int? _vehicleYear;

  String? get vehicleMake => _vehicleMake;
  String? get vehicleModel => _vehicleModel;
  int? get vehicleYear => _vehicleYear;

  /// هل اختار المستخدم مركبة كاملة (ماركة + موديل + سنة)؟
  bool get hasVehicleSelection =>
      _vehicleMake != null && _vehicleModel != null && _vehicleYear != null;

  /// وصف المركبة المختارة (مثل "1980 Toyota Corolla") أو null.
  String? get vehicleLabel =>
      hasVehicleSelection ? '$_vehicleYear $_vehicleMake $_vehicleModel' : null;

  /// هل المركبة المختارة (إن وُجدت) من سنوات لا تدعم OBD-II؟
  /// عندئذ تُمنع كل الأوامر والفحوصات حتى يغيّر الاختيار.
  bool get vehicleUnsupported =>
      hasVehicleSelection && _vehicleYear! < minObdYear;

  /// تحديث اختيار المركبة: تغيير الماركة يعيد ضبط الموديل.
  /// القيم غير المتغيّرة تبقى كما هي، ويُحفظ الاختيار محلياً.
  Future<void> setVehicle({
    String? make,
    String? model,
    int? year,
  }) async {
    if (make != null && make != _vehicleMake) {
      _vehicleMake = make;
      // قوائم الموديلات تتبع الماركة — إعادة الضبط إجبارية.
      _vehicleModel = null;
    }
    if (model != null) _vehicleModel = model;
    if (year != null) _vehicleYear = year;
    notifyListeners();

    await _persistVehicle();
  }

  /// مسح اختيار المركبة (يعيد السماح بكل الأوامر.
  Future<void> clearVehicle() async {
    _vehicleMake = null;
    _vehicleModel = null;
    _vehicleYear = null;
    notifyListeners();

    await _persistVehicle();
  }

  Future<void> _persistVehicle() async {
    final prefs = await SharedPreferences.getInstance();
    if (_vehicleMake == null) {
      await prefs.remove(_vehicleMakeKey);
      await prefs.remove(_vehicleModelKey);
      await prefs.remove(_vehicleYearKey);
      return;
    }
    await prefs.setString(_vehicleMakeKey, _vehicleMake!);
    if (_vehicleModel != null) {
      await prefs.setString(_vehicleModelKey, _vehicleModel!);
    }
    if (_vehicleYear != null) {
      await prefs.setInt(_vehicleYearKey, _vehicleYear!);
    }
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themekey);
    if (saved == 'light') {
      _themeMode = ThemeMode.light;
    } else if (saved == 'system') {
      _themeMode = ThemeMode.system;
    } else if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    }

    // استعادة اختيار المركبة المحفوظ (الاختيار الناقص يُستعاد جزئياً).
    final make = prefs.getString(_vehicleMakeKey);
    final model = prefs.getString(_vehicleModelKey);
    final year = prefs.getInt(_vehicleYearKey);
    if (make != null &&
        model != null &&
        year != null &&
        VehicleCatalog.modelsFor(make).contains(model)) {
      _vehicleMake = make;
      _vehicleModel = model;
      _vehicleYear = year;
    } else if (make != null && year != null) {
      // موديل محفوظ بلا ماركة صالحة (قائمة متغيّرة) — استعادة بلا موديل
      // ليختار المستخدم الموديل من جديد دون فقد الماركة والسنة.
      _vehicleMake = make;
      _vehicleModel = null;
      _vehicleYear = year;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    final String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    await prefs.setString(_themekey, value);
    notifyListeners();
  }

  // ---- الاتصال ----
  ObdConnectionStatus _status = ObdConnectionStatus.disconnected;
  ObdConnectionStatus get status => _status;
  bool get connected => _status == ObdConnectionStatus.connected;

  bool get _connected => connected;

  List<DiscoveredObdDevice> _devices = <DiscoveredObdDevice>[];
  List<DiscoveredObdDevice> get devices => List.unmodifiable(_devices);

  final List<String> _debugLogs = <String>[];
  List<String> get debugLogs => List.unmodifiable(_debugLogs);

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearDebugLogs() {
    _debugLogs.clear();
    notifyListeners();
  }

  void log(String message) {
    debugPrint(message);
    // إظهار رسائل مستوى التعليمة في سجل BLE داخل التطبيق
    // (مشاهدة الأدوات الفنية في شاشة الإعدادات).
    bleService.appLog(message);
  }

  // ---- الفحص والأعطال ----
  List<String> _dtcCodes = <String>[];
  List<String> get dtcCodes => List.unmodifiable(_dtcCodes);

  bool _hasReadDtc = false;
  bool get hasReadDtc => _hasReadDtc;

  // ---- تحليل أكواد الأعطال عبر /api/analyze/dtc ----
  DtcAnalysisResult? _dtcAnalysis;
  DtcAnalysisResult? get dtcAnalysis => _dtcAnalysis;

  bool _dtcAnalysisLoading = false;
  bool get dtcAnalysisLoading => _dtcAnalysisLoading;

  String? _dtcAnalysisError;
  String? get dtcAnalysisError => _dtcAnalysisError;

  /// وقت آخر فحص ناجح لأكواد الأعطال.
  DateTime? get lastDtcScanTime => _history
      .where((r) => r.title.contains('أكواد الأعطال') && r.success)
      .map((r) => r.createdAt)
      .fold<DateTime?>(null, (a, b) => a == null ? b : (b.isAfter(a) ? b : a));

  String _lastResponse = '';
  String get lastResponse => _lastResponse;

  String? _vin;
  String? get vin => _vin;

  Map<int, PidReading> _readings = <int, PidReading>{};
  List<PidReading> get readings {
    final values = _readings.values.toList()
      ..sort((a, b) => a.pid.compareTo(b.pid));
    return List.unmodifiable(values);
  }

  /// آخر قراءة PID مفكوكة (لعرض معناها في ورقة نتيجة الأوامر اليدوية).
  PidReading? _lastPidReading;
  PidReading? get lastPidReading => _lastPidReading;

  // ---- البيانات الحية عبر BLE (RPM/السرعة/حرارة التبريد/الجهد — كل 5 ثوانٍ) ----
  static const Duration _liveRefreshInterval = Duration(seconds: 5);
  Timer? _liveTimer;
  bool _liveEnabled = false;
  bool get liveEnabled => _liveEnabled;
  bool _liveFetching = false;
  bool get liveFetching => _liveFetching;
  num? _liveRpm;
  num? get liveRpm => _liveRpm;
  num? _liveSpeed;
  num? get liveSpeed => _liveSpeed;
  num? _liveCoolant;
  num? get liveCoolant => _liveCoolant;
  double? _liveBattery;
  double? get liveBattery => _liveBattery;
  DateTime? _liveLastUpdate;
  DateTime? get liveLastUpdate => _liveLastUpdate;

  // ---- تعديل الوقود (STFT 0106 / LTFT 0107) — قراءة عند ضغط الزر ----
  num? _liveStft;
  num? get liveStft => _liveStft;
  num? _liveLtft;
  num? get liveLtft => _liveLtft;
  DateTime? _fuelTrimLastUpdate;
  DateTime? get fuelTrimLastUpdate => _fuelTrimLastUpdate;

  /// مجموع التعديلين (STFT + LTFT) كنسبة مئوية — مؤشر صحة خليط الوقود.
  num? get fuelTrimSum => _liveStft == null || _liveLtft == null
      ? null
      : _liveStft! + _liveLtft!;

  bool _fuelTrimReading = false;
  bool get fuelTrimReading => _fuelTrimReading;

  // ---- API التحليل (fire-and-forget) ----
  bool get apiLoading => _apiLoading;
  bool _apiLoading = false;
  Map<String, dynamic>? _lastApiAnalysis;
  Map<String, dynamic>? get lastApiAnalysis => _lastApiAnalysis;
  String? _apiError;
  String? get apiError => _apiError;
  String _lastApiCommand = '';
  String get lastApiCommand => _lastApiCommand;
  String _lastApiRawResponse = '';
  String get lastApiRawResponse => _lastApiRawResponse;

  // ---- السجل ----
  List<InspectionRecord> _history = <InspectionRecord>[];
  List<InspectionRecord> get history => List.unmodifiable(_history);
  bool _historyLoading = true;
  bool get historyLoading => _historyLoading;

  Future<void> loadHistory() async {
    final records = await historyRepository.load();
    _history = records;
    _historyLoading = false;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await historyRepository.clear();
    _history = <InspectionRecord>[];
    notifyListeners();
  }

  Future<void> _saveRecord({
    required String title,
    required String result,
    required bool success,
    String rawResponse = '',
  }) async {
    final record = InspectionRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      title: title,
      result: result,
      success: success,
      rawResponse: rawResponse,
    );
    await historyRepository.save(record);
    _history = [record, ..._history].take(100).toList();
    notifyListeners();
  }

  // ============================================================
  // الإقلاع والتنظيف
  // ============================================================

  bool _started = false;

  void startServices() {
    if (_started) return;
    _started = true;

    _scanSubscription = bleService.scanResults.listen((devices) {
      _devices = devices;
      notifyListeners();
    });
    _statusSubscription = bleService.status.listen((status) {
      _status = status;
      notifyListeners();
      // انقطاع الاتصال يوقف قسم البيانات الحية تلقائياً (لا مثمن للطلب).
      if (status != ObdConnectionStatus.connected) _stopLive();
    });
    _debugLogSubscription = bleService.debugLogs.listen((message) {
      _debugLogs.add(message);
      // الاحتفاظ بآخر 200 رسالة فقط
      if (_debugLogs.length > 200) {
        _debugLogs.removeAt(0);
      }
      notifyListeners();
    });

    unawaited(_requestRequiredPermissions());
  }

  Future<void> _requestRequiredPermissions() async {
    try {
      await bleService.requestPermissions();
    } catch (error) {
      _error = 'يجب منح الأذونات لاكتشاف الأجهزة: $error';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _statusSubscription?.cancel();
    _debugLogSubscription?.cancel();
    _liveTimer?.cancel();
    bleService.dispose();
    super.dispose();
  }

  // ============================================================
  // الاتصال: بحث / ربط / فصل
  // ============================================================

  Future<void> scan() async {
    _error = null;
    notifyListeners();
    try {
      await bleService.scan();
    } catch (error) {
      _error = 'تعذر البحث عن الأجهزة: $error';
      notifyListeners();
    }
  }

  Future<void> connect(DiscoveredObdDevice item) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await bleService.connect(item.device);
    } catch (error) {
      _error = 'فشل الاتصال أو اكتشاف خصائص الجهاز: $error';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await bleService.disconnect();
  }

  String get statusLabel {
    switch (_status) {
      case ObdConnectionStatus.scanning:
        return 'جارٍ البحث...';
      case ObdConnectionStatus.connecting:
        return 'جارٍ الاتصال...';
      case ObdConnectionStatus.connected:
        return 'متصل بالجهاز';
      case ObdConnectionStatus.error:
        return 'خطأ بالاتصال';
      case ObdConnectionStatus.disconnected:
        return 'غير متصل';
    }
  }

  String get connectedDeviceName {
    final device = bleService.connectedDevice;
    if (device == null) return '';
    final name = device.platformName;
    return name.isEmpty ? device.remoteId.toString() : name;
  }

  // ============================================================
  // تنفيذ الأوامر (عام — للفحص السريع والمنفذ اليدوي)
  // ============================================================

  /// إرسال أمر عبر BLE مع تسجيل السجل وتفويض/تحليل الرد.
  /// يعيد الرد الخام أو null عند الفشل.
  Future<String?> executeCommand(
    String title,
    String command, {
    Duration? timeout,
  }) async {
    // حارس الدعم: المركبة المختارة من سنوات لا تدعم OBD-II (2005 وما
    // قبلها) لا تُرسل إليها أوامر إطلاقاً — اتصال الجهاز وحده متاح.
    if (vehicleUnsupported) {
      _error = 'المركبة غير مدعومة: $vehicleLabel (سنة الصنع 2005 وما '
          'قبلها لا تستخدم بروتوكول OBD-II). تم منع إرسال الأوامر — '
          'اختر مركبة من سنة 2006 فأحدث من قسم «معلومات المركبة».';
      notifyListeners();
      return null;
    }

    if (!_connected) {
      _error = 'اتصل بجهاز BLE أولاً.';
      notifyListeners();
      return null;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final response = await bleService.sendCommand(
        command,
        timeout: timeout ?? const Duration(seconds: 30),
      );
      _lastResponse = response.trim();
      // نجاح الأمر يمسح خطأ الأمر السابق — لعرض نتيجة ناضجة بلا تضليل.
      _error = null;
      notifyListeners();

      await _saveRecord(
        title: title,
        result: response.trim().isEmpty ? 'لم يصل رد' : response.trim(),
        success: !ObdParser.isError(response),
        rawResponse: response,
      );

      // تحليل الرد عبر API: fire-and-forget في الخلفية — لا يحظر
      // `_busy` ولا انتظار رد BLE التالي.
      unawaited(_runApiAnalysis(command, response));
      return response;
    } catch (error) {
      _error = '$title: $error';
      notifyListeners();
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// تحليل الرد عبر API في الخلفية دون حجب دورة الأوامر.
  Future<void> _runApiAnalysis(String command, String response) async {
    final apiCommand =
        command.replaceAll(RegExp(r'[\r\n>]'), '').trim().toUpperCase();

    final cleanedResponse = response.replaceAll(RegExp(r'[\r\n>]'), ' ').trim();

    // أوامر الأعطال ("03"/"DTCS?"/"DTC?") تُحلَّل عبر
    // `POST /api/analyze/dtc` بمصفوفة الأكواد المستخرجة من الجهاز
    // (انظر [analyzeDtcCodes]) — لا تُرسَل إلى خدمة تحليل الردود.
    if (apiCommand == '03' ||
        apiCommand.startsWith('DTCS') ||
        apiCommand == 'DTC?') {
      return;
    }

    final apiResponse = ObdParser.toRawObdResponse(apiCommand, cleanedResponse);
    log('API SEND: command=$apiCommand response=$apiResponse');

    if (apiCommand.isEmpty ||
        apiCommand.startsWith('AT') ||
        apiResponse.isEmpty ||
        ObdParser.isError(response)) {
      return;
    }

    _apiLoading = true;
    _apiError = null;
    _lastApiCommand = apiCommand;
    _lastApiRawResponse = apiResponse;
    notifyListeners();

    try {
      final analysis = await analysisApi.analyzeCommand(
        command: apiCommand,
        response: apiResponse,
      );
      _lastApiAnalysis = analysis;
    } catch (error) {
      _apiError = 'تعذر تحليل الرد عبر API: $error';
    } finally {
      _apiLoading = false;
      notifyListeners();
    }
  }



  Future<PidReading?> readPid(int pid, String title) async {
    log('READ PID START: $pid');
    final response = await executeCommand(title, ObdCommands.readPid(pid));
    log('READ PID RESPONSE: ${response ?? "NULL"}');
    if (response == null) return null;

    log('PID: 0x${pid.toRadixString(16).toUpperCase()}');
    log('PID raw response: ${response.trim()}');

    try {
      final reading = ObdParser.parsePid(
        pid: pid,
        response: response,
      );
      log('PID parsed value: ${reading.value} ${reading.unit}');
      _lastPidReading = reading;
      _readings = {..._readings, pid: reading};
      notifyListeners();
      return reading;
    } catch (error) {
      log('PID parsing error: $error');
      _error = '$error';
      notifyListeners();
      return null;
    }
  }

  Future<String?> readBattery() async {
    final response = await executeCommand(
      'قراءة جهد البطارية',
      ObdCommands.battery,
      timeout: const Duration(seconds: 30),
    );
    if (response == null) return null;

    final voltage = double.tryParse(response.trim());
    if (voltage == null) {
      _error = 'تعذرت قراءة جهد البطارية: $response';
      notifyListeners();
      return null;
    }
    _error = null;
    notifyListeners();
    return response.trim();
  }

  /// قراءة رقم الهيكل (VIN) — يعيد الرقم عند النجاح.
  Future<String?> readVin() async {
    // فيرموير Freematics (telelogger) يرد على أمر "VIN" نصاً مباشرة.
    // أمر "0902" القياسي غير مدعوم في هذا الفيرموير ويُجاب بـ "ERROR".
    final response = await executeCommand(
      'قراءة رقم الهيكل ',
      ObdCommands.vin,
      timeout: const Duration(seconds: 30),
    );
    if (response == null) return null;
    try {
      // أولاً: التحليل النصي المباشر المسند من فيرموير Freematics
      // ثم صيغة OBD-II القياسية 49 02 01 (لتوافق أي جسر ELM327 أولي).
      final vin =
          ObdParser.parsePlainVin(response) ?? ObdParser.parseVin(response);
      if (vin.isNotEmpty) {
        _vin = vin;
        notifyListeners();
        return vin;
      }
      _error = 'تعذر استخراج رقم الهيكل من الرد: ${response.trim()}';
      notifyListeners();
      return null;
    } catch (error) {
      _error = '$error';
      notifyListeners();
      return null;
    }
  }
 
  static List<String> splitDtcTokens(String response) {
    return response
        .split(RegExp(r'[,;\s]+'))
        .map((token) => token.trim().toUpperCase())
        .where((token) => token.isNotEmpty)
        .toList();
  }

  /// قراءة أكواد الأعطال بأمر "03" القياسي ثم "DTCS?" (فيرموير مرقّع).
  /// يعيد الرد الخام عند النجاح (للعرض في ورقة النتيجة) أو null.
  ///
  /// الرد نفسه لا يُفكّ محلياً إطلاقاً: يُوجّه مباشرةً إلى الباك إند
  /// عبر [analyzeDtcCodes] بعد تقسيمه إلى عناصر فقط — فلا اشتراط
  /// لصيغة "43 ..." البايتية، ويكفي رد نصي مثل "P0128, P0420, P0430".
  Future<String?> readDtc() async {
    
    final stopwatch = Stopwatch()..start();
    log('DTC FLOW: ================= <start> =================');

    
    _resetDtcAnalysis();
    notifyListeners();

 
    Future<String?> attempt(String label, String command) async {
      log('DTC FLOW: قبل الإرسال — "$label" عبر خاصية الكتابة FFE1 '
          '(الحالة: $_status، الجهاز: ${bleService.connectedDevice != null ? 'موجود' : 'مفقود'})');
      final response = await executeCommand('قراءة أكواد الأعطال', command);
      log('DTC FLOW: بعد الاستقبال — "$label" استغرق '
          '${stopwatch.elapsedMilliseconds}ms، الرد الخام: ${response ?? "NULL"}');
      stopwatch.reset();
      if (response == null) {
        final errorText = _error ?? '';
        final failedStage = errorText.contains('لم يصل رد')
            ? 'الاستقبال (FFE2)'
            : 'الإرسال (FFE1)';
        log('DTC FLOW: فشل "$label" في مرحلة $failedStage — التفاصيل: $errorText');
      }
      return response;
    }

    var response = await attempt('03', ObdCommands.readDtc);

   
    var codes = response == null
        ? const <String>[]
        : splitDtcTokens(response);

    
    if (response == null || ObdParser.isError(response)) {
      if (response != null) {
        log('DTC FLOW: رد "03" = "${response.trim()}" خطأ — إعادة '
            'المحاولة بأمر "DTCS?" (فيرموير مرقّع).');
      } else {
        log('لا رد على "03"؛ إعادة المحاولة بأمر "DTCS?" (فيرموير مرقّع).');
      }
      response = await attempt('DTCS?', ObdCommands.readDtcCached);
      codes = response == null ? const <String>[] : splitDtcTokens(response);
    }

    if (response == null) {
      log('DTC FLOW: ================= <end: فشل> ==================');
      return null;
    }

    // الجسر ردّ بخطأ على الأمرين "03" و"DTCS?" معاً؛ نتعامل مع الرد
    // الخاطئ صراحة بدل إظهار "لا توجد أكواد".
    if (ObdParser.isError(response)) {
      final trimmed = response.trim();
      log('DTC FLOW: الأمران "03" و"DTCS?" ردّا معاً بخطأ: "$trimmed" '
          '— السبب يقينياً فيرموير غير مرقّع لا يدعم قراءة الأكواد عبر BLE.');
      _dtcCodes = <String>[];
      _hasReadDtc = false;
      _resetDtcAnalysis();
      _error = 'قراءة أكواد الأعطال: ردّ الجهاز "$trimmed" على الأمرين '
          '"03" و"DTCS?" معاً. تم التحقق من الإرسال (FFE1) والاستقبال '
          '(FFE2) وسجلا طبيعيان — المشكلة في الفيرموير نفسه: الفيرموير '
          'لا يدعم قراءة أكواد الأعطال عبر BLE. الحل: تحميل رقعة '
          'firmware_patch/telelogger_dtc.patch على الجهاز.';
      notifyListeners();
      log('DTC FLOW: ================= <end: ERROR> ==================');
      return null;
    }

    // توجيه مباشر: نص الرد كما وصل من الجهاز (مثل "P0128, P0420,
    // P0430" أو بأي صيغة أخرى) يُقسّم على الفواصل/المسافات فقط —
    // بلا فك أو تحقق محلي (لا parseDtc) — وتُرسل العناصر كلها إلى
    // `POST /api/analyze/dtc` لعرض تفاصيل كل عطل من استجابة الخدمة
    // في شاشة الأعطال. (التسوية: uppercase/إزالة التكرار/الحد 100
    // تجري داخل DtcAnalysisService حصراً وفق قيود المخطط.)
    log('DTC FLOW: توجيه مباشر للرد الخام — العناصر: $codes؛ '
        'إرسالها إلى /api/analyze/dtc دون فك محلي');
    log('DTC FLOW: ================= <end: نجاح> ==================');

    _dtcCodes = codes;
    _hasReadDtc = true;
    // نجاح الإعادة بعد فشل أول محاولة: تُزال رسالة الخطأ القديمة
    // حتى لا تُعرض بجانب نتيجة حديثة صحيحة.
    _error = null;
    notifyListeners();

    // لا نحظر عرض الأكواد المحلية بانتظار التحليل؛ الشاشة تعرض
    // حالة "جارٍ التحليل" ثم تُحدَّث تلقائياً عند وصول الاستجابة.
    unawaited(analyzeDtcCodes(codes));
    return response;
  }

  /// قراءة أكواد الأعطال من إطار التجميد (وضع 02 — الأمر "02").
  ///
  /// الفيرموير v5 يرد بصيغة وضع 03 نفسها لكن بايت الوضع "42" بدل "43"
  /// (مثال كودين: "42 02 01 08 01 09" → P0108، P0109). الرد بايتي،
  /// لذا يُفك محلياً بـ [ObdParser.parseDtc] أولاً ثم تُرسل الأكواد
  /// المفكوكة (لا الرموز الخام مثل "42"/"02") إلى خدمة التحليل —
  /// على خلاف [readDtc] الذي يمرّر نص الرد كما وصل.
  Future<String?> readDtcFreezeFrame() async {
    final stopwatch = Stopwatch()..start();
    log('DTC FLOW (02): ================= <start> =================');

    _resetDtcAnalysis();
    notifyListeners();

    final response = await executeCommand(
      'قراءة أكواد إطار التجميد (02)',
      ObdCommands.readFreezeFrame,
    );
    log('DTC FLOW (02): الرد الخام (${stopwatch.elapsedMilliseconds}ms): '
        '${response ?? "NULL"}');

    if (response == null) {
      log('DTC FLOW (02): ================= <end: فشل> ==================');
      return null;
    }

    if (ObdParser.isError(response)) {
      final trimmed = response.trim();
      log('DTC FLOW (02): ردّ بخطأ: "$trimmed"');
      _dtcCodes = <String>[];
      _hasReadDtc = false;
      _resetDtcAnalysis();
      _error = 'قراءة أكواد إطار التجميد: ردّ الجهاز "$trimmed". '
          'تأكد من تحميل الفيرموير v5 المحدّث (دعم الأمر "02") على الجهاز.';
      notifyListeners();
      log('DTC FLOW (02): ================= <end: ERROR> ==================');
      return null;
    }

    // فك محلي: الصيغة البايتية "42 ..." تُفك بـ parseDtc (الذي يقبل
    // بايتي الرد 43 و42 بنفس المنطق) قبل أي عرض أو إرسال للتحليل.
    final codes = ObdParser.parseDtc(response);
    log('DTC FLOW (02): أكواد مفكوكة محلياً: $codes');

    _dtcCodes = codes;
    _hasReadDtc = true;
    _error = null;
    notifyListeners();

    // لا نحظر عرض الأكواد المحلية بانتظار التحليل؛ الشاشة تعرض
    // حالة "جارٍ التحليل" ثم تُحدَّث تلقائياً عند وصول الاستجابة.
    unawaited(analyzeDtcCodes(codes));
    log('DTC FLOW (02): ================= <end: نجاح> ==================');
    return response;
  }

  
  Future<String?> clearFaultCodes() async {
    final response = await executeCommand(
      'مسح أكواد الأعطال (04)',
      ObdCommands.clearDtc,
    );
    if (response == null) return null;

    // ردّ الجهاز بخطأ: ذاكرة الأكواد لم تُمسح — لا نغيّر الحالة المحلية.
    if (ObdParser.isError(response)) {
      _error = 'فشل مسح الأكواد: ردّ الجهاز "${response.trim()}" — '
          'لم تُمسح ذاكرة الأكواد.';
      notifyListeners();
      return null;
    }

    // المسح نجح: القائمة المحلية (آخر قراءة) لم تعد تعبّر عن الوحدة.
    _dtcCodes = <String>[];
    _hasReadDtc = true;
    _resetDtcAnalysis();
    _error = null;
    notifyListeners();
    log('DTC CLEAR: الأمر "04" نُفّذ — ذاكرة الأكواد مُمسحة');
    return response;
  }

  /// إرسال أكواد الأعطال المستخرجة من رد الجهاز إلى خدمة التحليل.
  /// [codes] هي عناصر الرد الخام بعد تقسيمها فقط (توجيه مباشر بلا فك
  /// محلي؛ قد تكون فارغة، وحينها تعيد الخدمة حالة "السيارة سليمة").
  Future<void> analyzeDtcCodes(List<String> codes) async {
    _dtcAnalysisLoading = true;
    _dtcAnalysisError = null;
    notifyListeners();

    try {
      final result = await dtcAnalysisService.analyzeCodes(codes);
      _dtcAnalysis = result;
    } catch (error) {
      _dtcAnalysis = null;
      _dtcAnalysisError = error is DtcAnalysisException
          ? error.message
          : 'تعذر تحليل أكواد الأعطال: $error';
    } finally {
      _dtcAnalysisLoading = false;
      notifyListeners();
    }
  }

  void _resetDtcAnalysis() {
    _dtcAnalysis = null;
    _dtcAnalysisError = null;
    _dtcAnalysisLoading = false;
  }



  Future<String?> sendManualCommand(String typed) async {
    typed = typed.trim();

    if (typed.isEmpty) {
      _error = 'أدخل أمراً أولاً (مثال: 010C أو BATT).';
      notifyListeners();
      return null;
    }
    if (_busy) {
      _error = 'هناك أمر قيد التنفيذ حالياً؛ انتظر انتهاءه ثم أعد الإرسال.';
      notifyListeners();
      return null;
    }

    _lastPidReading = null;

    
    final normalized =
        typed.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_?=>]'), '');

    if (normalized.isEmpty) {
      _error = 'أمر غير صالح: "$typed"';
      notifyListeners();
      return null;
    }

   
    final pidMatch = RegExp(r'^01([0-9A-F]{2})$').firstMatch(normalized);
    if (pidMatch != null) {
      final pid = int.parse(pidMatch.group(1)!, radix: 16);
      final (label, _) = ObdParser.pidMetadata(pid);
      return (await readPid(pid, 'فحص $label'))?.raw;
    }

    // أوامر الأعطال: "03" القياسي أو "DTCS?"/"DTC?" (فيرموير مرقّع)
    // → قارئ وضع 03، و"02" القياسي → قارئ إطار التجميد (وضع 02).
    final dtcMatch = RegExp(r'^(0?3|DTCS\?|DTC\?)$').hasMatch(normalized);
    if (dtcMatch) {
      log('DTC FLOW: الأمر اليدوي "$normalized" أُعيد توجيهه إلى قارئ أكواد الأعطال.');
      return readDtc();
    }
    final freezeMatch = RegExp(r'^0?2$').hasMatch(normalized);
    if (freezeMatch) {
      log('DTC FLOW (02): الأمر اليدوي "$normalized" أُعيد توجيهه إلى '
          'قارئ أكواد إطار التجميد.');
      return readDtcFreezeFrame();
    }

    final command = normalized.endsWith('\r') ? normalized : '$normalized\r';
    return executeCommand('أمر يدوي: $normalized', command);
  }

  

  void toggleLive(bool enabled) {
    // المركبات غير المدعومة (≤ 2005) لا تُقرأ منها بيانات حية.
    if (enabled && vehicleUnsupported) {
      _error = 'المركبة غير مدعومة: $vehicleLabel — القراءة الحية '
          'متاحة لمركبات سنة 2006 فأحدث فقط.';
      notifyListeners();
      return;
    }
    _liveEnabled = enabled;
    notifyListeners();
    if (enabled) {
      unawaited(_liveTick());
      _liveTimer?.cancel();
      _liveTimer =
          Timer.periodic(_liveRefreshInterval, (_) => unawaited(_liveTick()));
    } else {
      _liveTimer?.cancel();
      _liveTimer = null;
    }
  }

  void _stopLive() {
    _liveTimer?.cancel();
    _liveTimer = null;
    if (_liveEnabled) {
      _liveEnabled = false;
      notifyListeners();
    }
  }

  Future<void> _liveTick() async {
  
    if (!_connected || _busy || _liveFetching || vehicleUnsupported) return;
    _liveFetching = true;
    notifyListeners();
    try {
     
      final rpm = await _readLiveMetric<num>(
        label: 'RPM',
        command: '010C\r',
        parse: (response) => ObdParser.parsePid(pid: 0x0C, response: response).value,
      );
      final speed = await _readLiveMetric<num>(
        label: 'Speed',
        command: '010D\r',
        parse: (response) => ObdParser.parsePid(pid: 0x0D, response: response).value,
      );
      final coolant = await _readLiveMetric<num>(
        label: 'حرارة التبريد',
        command: ObdCommands.readCoolantTemperature,
        parse: (response) => ObdParser.parsePid(pid: 0x05, response: response).value,
      );
      final double? battery = await _readLiveMetric<double>(
        label: 'BATT',
        command: ObdCommands.battery,
        parse: (response) =>
            double.tryParse(response.trim().replaceAll(RegExp(r'[^0-9.\-]'), '')),
      );

      // لا نعرض إلا قيماً ردّ بها الجهاز فعلاً — لا بيانات مصطنعة.
      if (rpm == null && speed == null && coolant == null && battery == null) {
        return;
      }
      if (rpm != null) _liveRpm = rpm;
      if (speed != null) _liveSpeed = speed;
      if (coolant != null) _liveCoolant = coolant;
      if (battery != null) _liveBattery = battery;
      _liveLastUpdate = DateTime.now();
      notifyListeners();
    } finally {
      _liveFetching = false;
      notifyListeners();
    }
  }


  Future<void> readFuelTrims() async {

    if (!_connected || _busy || _fuelTrimReading || vehicleUnsupported) return;
    _fuelTrimReading = true;
    notifyListeners();
    try {
    
      final stft = await _readLiveMetric<num>(
        label: 'STFT',
        command: ObdCommands.readStft,
        timeout: const Duration(seconds: 5),
        parse: (response) => ObdParser.parsePid(pid: 0x06, response: response).value,
      );
      final ltft = await _readLiveMetric<num>(
        label: 'LTFT',
        command: ObdCommands.readLtft,
        timeout: const Duration(seconds: 5),
        parse: (response) => ObdParser.parsePid(pid: 0x07, response: response).value,
      );

      // لا نعرض إلا قيماً ردّ بها الجهاز فعلاً — لا بيانات مصطنعة.
      if (stft == null && ltft == null) return;
      if (stft != null) _liveStft = stft;
      if (ltft != null) _liveLtft = ltft;
      _fuelTrimLastUpdate = DateTime.now();
      log('FUEL TRIM: STFT = $stft% • LTFT = $ltft% • SUM = $fuelTrimSum%');
      notifyListeners();
    } finally {
      _fuelTrimReading = false;
      notifyListeners();
    }
  }

  Future<T?> _readLiveMetric<T extends num>({
    required String label,
    required String command,
    required T? Function(String response) parse,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final response = await bleService.sendCommand(
        command,
        timeout: timeout,
      );
      final value = parse(response);
      if (value != null) log('LIVE: $label = $value');
      return value;
    } catch (error) {
      log('LIVE: تعذر قراءة $label: $error');
      return null;
    }
  }
}
