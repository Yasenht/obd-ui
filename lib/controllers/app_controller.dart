import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble_obd_service.dart';
import '../history_repository.dart';
import '../models.dart';
import '../ObdHttpService.dart';
import '../obd_analysis_api.dart';
import '../obd_protocol.dart';

/// الحالة المشتركة للتطبيق: الاتصال، الفحص، البيانات الحية،
/// السجل، وإعدادات المظهر.
///
/// تُستمع إليها من الواجهات عبر InheritedNotifier (AppScope) —
/// منطق الاتصال والفك نفسه في [BleObdService] و[ObdParser]
/// لم يُغيَّر، فقط فُصل عن ملف الواجهة الأحادي.
class AppController extends ChangeNotifier {
  final BleObdService bleService = BleObdService();
  final ObdHttpService httpService = ObdHttpService();
  final ObdAnalysisApi analysisApi = ObdAnalysisApi();
  final HistoryRepository historyRepository = HistoryRepository();

  StreamSubscription<List<DiscoveredObdDevice>>? _scanSubscription;
  StreamSubscription<ObdConnectionStatus>? _statusSubscription;
  StreamSubscription<String>? _debugLogSubscription;

  // ---- وضع العرض (فاتح/داكن/النظام) — محفوظ محلياً ----
  static const String _themekey = 'app_theme_mode_v1';
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

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

  // ---- البيانات الحية عبر BLE (RPM/السرعة/الجهد — كل 5 ثوانٍ) ----
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
  double? _liveBattery;
  double? get liveBattery => _liveBattery;
  DateTime? _liveLastUpdate;
  DateTime? get liveLastUpdate => _liveLastUpdate;

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

  // ---- البث الحي عبر Wi-Fi (TELELOGGER) ----
  bool _httpPollingEnabled = true;
  bool get httpPollingEnabled => _httpPollingEnabled;

  void setHttpPollingEnabled(bool enabled) {
    _httpPollingEnabled = enabled;
    if (enabled) {
      httpService.startPolling(interval: const Duration(milliseconds: 500));
    } else {
      httpService.stopPolling();
    }
    notifyListeners();
  }

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

    // بدء سحب البيانات عبر HTTP تلقائياً عند إقلاع الواجهة.
    if (_httpPollingEnabled) {
      httpService.startPolling(interval: const Duration(milliseconds: 500));
    }
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
    httpService.stopPolling();
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

    final isDtcCommand = apiCommand == '03' ||
        apiCommand.startsWith('DTCS') ||
        apiCommand == 'DTC?';
    final apiResponse = isDtcCommand
        ? cleanedResponse
        : ObdParser.toRawObdResponse(apiCommand, cleanedResponse);
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

  // ============================================================
  // الفحص السريع
  // ============================================================

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

  /// قراءة أكواد الأعطال بأمر "03" القياسي ثم "DTCS؟" (فيرموير مرقّع).
  /// يعيد الرد الخام عند النجاح (للعرض في ورقة النتيجة) أو null.
  Future<String?> readDtc() async {
    // أولاً: الأمر القياسي mode-03 "03\r" — هذا هو الكود الفعلي المطلوب
    // إرساله لقراءة أكواد الأعطال (طلبات OBD-II القياسية عبر أي جسر
    // ELM327/OBD-II). الرد المتوقع "43 <عدد> <أزواج>".
    // ثانياً: إن لم يرد الجسر برد يبدأ بـ "43 ..." (جاء "ERROR" أو لا
    // رد) نجرّب أمر "DTCS?" الخاص بفيرموير telelogger المُرقّع
    // (firmware_patch/telelogger_dtc.patch) والذي يرد رد mode-03
    // من ذاكرة الأكواد المخزنة بنفس الصيغة، لأن "03" غير مدرج في
    // قائمة أوامر processBLE حتى الفيرموير المرقّع.
    final stopwatch = Stopwatch()..start();
    log('DTC FLOW: ================= <start> =================');

    // محاولة واحدة: إرسال، تسجيل ما قبل/ما بعد، وتصنيف مرحلة الفشل
    // عند غياب الرد: "لم يصل رد" (TimeoutException بعد نجاح الكتابة)
    // تعني استقبال (FFE2)، وأي رسالة أخرى تعني إرسال (FFE1/اتصال).
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

    // الإعادة بأمر "DTCS?" تُنفَّذ في الحالتين اللتين رُصدتا:
    // أ) لا رد إطلاقاً (فشل إرسال/استقبال).
    // ب) الرد مؤشر خطأ ("ERROR"/"NO DATA") — الجسر لا يدعم وضع 03
    //    القياسي عبر BLE.
    if (response == null || ObdParser.isError(response)) {
      if (response != null) {
        log('DTC FLOW: رد "03" = "${response.trim()}" لا يمثل أكواداً — '
            'إعادة المحاولة بأمر "DTCS?" (فيرموير مرقّع).');
      } else {
        log('لا رد على "03"؛ إعادة المحاولة بأمر "DTCS?" (فيرموير مرقّع).');
      }
      response = await attempt('DTCS?', ObdCommands.readDtcCached);
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
      _error = 'قراءة أكواد الأعطال: ردّ الجهاز "$trimmed" على الأمرين '
          '"03" و"DTCS?" معاً. تم التحقق من الإرسال (FFE1) والاستقبال '
          '(FFE2) وسجلا طبيعيان — المشكلة في الفيرموير نفسه: الفيرموير '
          'لا يدعم قراءة أكواد الأعطال عبر BLE. الحل: تحميل رقعة '
          'firmware_patch/telelogger_dtc.patch على الجهاز.';
      notifyListeners();
      log('DTC FLOW: ================= <end: ERROR> ==================');
      return null;
    }

    // حارس التسلسل: رد أقراص الأعطال الصالح يجب أن يحتوي على علامة
    // الوضع 03 الإيجابي "43". أي رد آخر (مثل "SEARCHING..." أو نص
    // وسيط من الجسر) ليس رد أكواد أعطال — لا يُفكّ ولا يُعد نجاحاً
    // "بلا أعطال": كانت العملية السابقة تعرض "لا توجد أكواد" كأنها
    // نتيجة حقيقية للجهاز رغم أن رد الأكواد لم يصل أصلاً.
    final hasDtcMarker = RegExp(r'\b43\b').hasMatch(response);
    if (!hasDtcMarker) {
      final trimmed = response.trim();
      log('DTC FLOW: رد بلا علامة "43" — ليس رد أكواد أعطال صالحاً: "$trimmed"');
      _dtcCodes = <String>[];
      _hasReadDtc = false;
      _error = 'قراءة أكواد الأعطال: وصل رد غير صالح ("$trimmed") لا يحتوي '
          'على رد وضع 03 ("43 ..."). أعِد المحاولة، وإن تكرر فالفيرموير '
          'لا يدعم قراءة الأكواد عبر BLE (انظر firmware_patch/).';
      notifyListeners();
      log('DTC FLOW: ================= <end: رد غير صالح> ==================');
      return null;
    }

    // الفك يتم هنا محلياً في التطبيق من الرد الخام حصراً (العرض على
    // المركبة مصدره الرد الحقيقي للجهاز) — ويُرسل في الخلفية (غير
    // حاجب) رد الأعطال مع الأمر الأصلي إلى خدمة التحليل للتحليل
    // الأعمق، كما في _runApiAnalysis.
    final codes = ObdParser.parseDtc(response);
    log('DTC FLOW: الفك محلياً للعرض (والرد الخام يُرسل في الخلفية للتحليل) — النتيجة: $codes');
    log('DTC FLOW: ================= <end: نجاح> ==================');

    _dtcCodes = codes;
    _hasReadDtc = true;
    // نجاح الإعادة بعد فشل أول محاولة: تُزال رسالة الخطأ القديمة
    // حتى لا تُعرض بجانب نتيجة حديثة صحيحة.
    _error = null;
    notifyListeners();
    return response;
  }

  // ============================================================
  // المنفذ اليدوي (أوامر ELM327 مخصصة)
  // ============================================================

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

    // تعقيم المدخل: إزالة المحارف الشائبة ( "-", مسافات، "<" من لوحة
    // الاتجاه RTL، محارف مخفية من لصق النص) بحيث يعمل "-03" مثل "03".
    final normalized =
        typed.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_?=>]'), '');

    if (normalized.isEmpty) {
      _error = 'أمر غير صالح: "$typed"';
      notifyListeners();
      return null;
    }

    // كل معاملات Mode-01 القياسية (0100، 010C، 010D، 0111 ...)
    // تُمرر عبر قارئ PID لتحليلها وعرض قيمتها في ورقة النتيجة.
    final pidMatch = RegExp(r'^01([0-9A-F]{2})$').firstMatch(normalized);
    if (pidMatch != null) {
      final pid = int.parse(pidMatch.group(1)!, radix: 16);
      return (await readPid(pid, 'فحص PID ${pidMatch.group(1)}'))?.raw;
    }

    // أوامر الأعطال: "03" القياسي أو "DTCS?"/"DTC?" (فيرموير مرقّع).
    final dtcMatch = RegExp(r'^(0?3|DTCS\?|DTC\?)$').hasMatch(normalized);
    if (dtcMatch) {
      log('DTC FLOW: الأمر اليدوي "$normalized" أُعيد توجيهه إلى قارئ أكواد الأعطال.');
      return readDtc();
    }

    final command = normalized.endsWith('\r') ? normalized : '$normalized\r';
    return executeCommand('أمر يدوي: $normalized', command);
  }

  // ============================================================
  // البيانات الحية عبر BLE
  // ============================================================

  void toggleLive(bool enabled) {
    _liveEnabled = enabled;
    notifyListeners();
    if (enabled) {
      // قراءة أولى فورية ثم دورة كل 5 ثوانٍ.
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
    // حماية التسلسل: لا قراءة انشغالاً (_busy)، ولا دورة قيد التنفيذ،
    // ولا تلقّي بدون اتصال (القسم يتوقف تلقائياً عند الانقطاع).
    if (!_connected || _busy || _liveFetching) return;
    _liveFetching = true;
    notifyListeners();
    try {
      num? rpm;
      num? speed;
      double? battery;

      // لكل مؤشر: الرد المباشر من الفيرموير ("1616" أو "12.34") وكذلك
      // الصيغة القياسية "41 0C ..." يفكّه ObdParser.parsePid. فشل
      // قراءة مؤشر واحد لا يمنع البقية، ويُحفظ آخر قيمة ناجحة.
      try {
        final response = await bleService.sendCommand(
          '010C\r',
          timeout: const Duration(seconds: 3),
        );
        rpm = ObdParser.parsePid(pid: 0x0C, response: response).value;
        log('LIVE: RPM = $rpm');
      } catch (error) {
        log('LIVE: تعذر قراءة RPM: $error');
      }
      try {
        final response = await bleService.sendCommand(
          '010D\r',
          timeout: const Duration(seconds: 3),
        );
        speed = ObdParser.parsePid(pid: 0x0D, response: response).value;
        log('LIVE: Speed = $speed');
      } catch (error) {
        log('LIVE: تعذر قراءة السرعة: $error');
      }
      try {
        final response = await bleService.sendCommand(
          'BATT\r',
          timeout: const Duration(seconds: 3),
        );
        final volts = response.trim().replaceAll(RegExp(r'[^0-9.\-]'), '');
        battery = double.tryParse(volts);
        if (battery != null) log('LIVE: BATT = $battery');
      } catch (error) {
        log('LIVE: تعذر قراءة الجهد: $error');
      }

      // لا نعرض إلا قيماً ردّ بها الجهاز فعلاً — لا بيانات مصطنعة.
      if (rpm == null && speed == null && battery == null) return;
      if (rpm != null) _liveRpm = rpm;
      if (speed != null) _liveSpeed = speed;
      if (battery != null) _liveBattery = battery;
      _liveLastUpdate = DateTime.now();
      notifyListeners();
    } finally {
      _liveFetching = false;
      notifyListeners();
    }
  }
}
