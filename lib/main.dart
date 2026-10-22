import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'ble_obd_service.dart';
import 'history_repository.dart';
import 'models.dart';
import 'ObdHttpService.dart'; //
import 'obd_protocol.dart';
import 'obd_analysis_api.dart';
import 'dart:async';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ObdScannerApp());
}

class ObdScannerApp extends StatefulWidget {
  const ObdScannerApp({super.key});

  @override
  State<ObdScannerApp> createState() => _ObdScannerAppState();
}

class _ObdScannerAppState extends State<ObdScannerApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'فاحص OBD',
      themeMode: _themeMode,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      home: _showSplash
          ? const Directionality(
        textDirection: TextDirection.rtl,
        child: SplashScreen(),
      )
          : Directionality(
        textDirection: TextDirection.rtl,
        child: ObdHomePage(
          themeMode: _themeMode,
          onToggleTheme: _toggleTheme,
        ),
      ),
    );
  }

  ThemeData _darkTheme() {
    const primaryColor = Color(0xFF06B6D4); // Cyan Accent
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  ThemeData _lightTheme() {
    const primaryColor = Color(0xFF0284C7); // Light Cyan/Blue Accent
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.directions_car_filled_rounded, size: 60, color: Color(0xFF22D3EE)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'OBD Scanner',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'نظام التشخيص الفني للسيارات عبر BLE / Wi-Fi',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ObdHomePage extends StatefulWidget {
  const ObdHomePage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<ObdHomePage> createState() => _ObdHomePageState();
}

class _ObdHomePageState extends State<ObdHomePage> {
  final _service = BleObdService();
  final _httpService = ObdHttpService();
  final _analysisApi = ObdAnalysisApi();
  final _historyRepository = HistoryRepository();
  final _manualCommandController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<DiscoveredObdDevice>>? _scanSubscription;
  StreamSubscription<ObdConnectionStatus>? _statusSubscription;
  StreamSubscription<String>? _debugLogSubscription;

  final List<String> _debugLogs = <String>[];
  List<DiscoveredObdDevice> _devices = <DiscoveredObdDevice>[];
  List<InspectionRecord> _history = <InspectionRecord>[];
  Map<int, PidReading> _liveReadings = <int, PidReading>{};
  List<String> _dtcCodes = <String>[];
  bool _hasReadDtc = false;
  ObdConnectionStatus _status = ObdConnectionStatus.disconnected;
  String _lastResponse = '';
  String? _vin;
  String? _error;
  bool _busy = false;
  bool _apiLoading = false;
  Map<String, dynamic>? _lastApiAnalysis;
  String? _apiError;
  String _lastApiCommand = '';
  String _lastApiRawResponse = '';

  bool get _connected => _status == ObdConnectionStatus.connected;

  @override
  void initState() {
    super.initState();
    _scanSubscription = _service.scanResults.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
    _statusSubscription = _service.status.listen((status) {
      if (mounted) setState(() => _status = status);
    });
    _debugLogSubscription = _service.debugLogs.listen((message) {
      if (!mounted) return;

      setState(() {
        _debugLogs.add(message);

        // الاحتفاظ بآخر 200 رسالة فقط
        if (_debugLogs.length > 200) {
          _debugLogs.removeAt(0);
        }
      });
    });
    unawaited(_requestRequiredPermissions());
    _loadHistory();

    // 3. بدء سحب البيانات عبر HTTP تلقائياً عند إقلاع الواجهة
    _httpService.startPolling(
      interval: const Duration(milliseconds: 500),
    );
  }

  Future<void> _requestRequiredPermissions() async {
    try {
      await _service.requestPermissions();
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'يجب منح الأذونات لاكتشاف الأجهزة: $error');
      }
    }
  }

  Future<void> _loadHistory() async {
    final records = await _historyRepository.load();
    if (mounted) setState(() => _history = records);
  }

  @override
  void dispose() {
    // 4. إيقاف سحب HTTP وتنظيف الموارد
    _httpService.stopPolling();
    _httpService.dispose();

    _scanSubscription?.cancel();
    _statusSubscription?.cancel();
    _debugLogSubscription?.cancel();
    _manualCommandController.dispose();
    _scrollController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _error = null);
    try {
      await _service.scan();
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذر البحث عن الأجهزة: $error');
    }
  }

  Future<void> _connect(DiscoveredObdDevice item) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.connect(item.device);
    } catch (error) {
      if (mounted) setState(() => _error = 'فشل الاتصال أو اكتشاف خصائص الجهاز: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await _service.disconnect();
  }

  Future<String?> _execute(String title, String command, {Duration? timeout}) async {
    if (!_connected) {
      setState(() => _error = 'اتصل بجهاز BLE أولاً.');
      return null;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _service.sendCommand(command, timeout: timeout ?? const Duration(seconds: 10));
      if (mounted) {
        setState(() => _lastResponse = response.trim());
        await _saveRecord(
          title: title,
          result: response.trim().isEmpty ? 'لم يصل رد' : response.trim(),
          success: !ObdParser.isError(response),
          rawResponse: response,
        );
      }

      
      final apiCommand = command.replaceAll(RegExp(r'[\r\n>]'), '').trim().toUpperCase();
      final cleanedResponse = response.replaceAll(RegExp(r'[\r\n>]'), ' ').trim();
    final apiResponse = ObdParser.toRawObdResponse(apiCommand, cleanedResponse);
    _log('API SEND: command=$apiCommand response=$apiResponse');
      if (apiCommand.isNotEmpty &&
          !apiCommand.startsWith('AT') &&
          apiResponse.isNotEmpty &&
          !ObdParser.isError(response)) {
        if (mounted) {
          setState(() {
            _apiLoading = true;
            _apiError = null;
            _lastApiCommand = apiCommand;
            _lastApiRawResponse = apiResponse;
          });
        }
        try {
          final analysis = await _analysisApi.analyzeCommand(
            command: apiCommand,
            response: apiResponse,
          );
          if (mounted) setState(() => _lastApiAnalysis = analysis);
        } catch (error) {
          if (mounted) setState(() => _apiError = 'تعذر تحليل الرد عبر API: $error');
        } finally {
          if (mounted) setState(() => _apiLoading = false);
        }
      }
      return response;
    } catch (error) {
      if (mounted) setState(() => _error = '$title: $error');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readBattery() async {
    final response = await _execute(
      'قراءة جهد البطارية',
      ObdCommands.battery,
      timeout: const Duration(seconds: 10),
    );

    if (response == null) return;

    final voltage = double.tryParse(response.trim());

    if (voltage == null) {
      if (mounted) {
        setState(() => _error = 'تعذرت قراءة جهد البطارية: $response');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _error = '';
      });
    }
  }

  Future<void> _readVin() async {
    final response = await _execute('قراءة رقم الهيكل ', ObdCommands.readVin, timeout: const Duration(seconds: 10));
    if (response == null) return;
    try {
      final vin = ObdParser.parseVin(response);
      if (mounted) setState(() => _vin = vin);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _log(String message) {
    debugPrint(message);
  }


Future<void> _readDtc(int pid, String title) async {
  final response = await _execute(title,
      ObdCommands.readDtc,);
  _log('DTC raw response: ${response ?? "NULL"}');
  if (response == null) return;

  final codes = ObdParser.parseDtc(response);
  _log('DTC parsed: $codes');

  if (mounted) {
    setState(() {
      _dtcCodes = codes;
      _hasReadDtc = true;
    });
  }
}
  Future<void> _readPid(int pid, String title) async {
    _log('READ PID START: $pid');
    final response = await _execute(
      title,
      ObdCommands.readPid(pid),
    );
    _log('READ PID RESPONSE: ${response ?? "NULL"}');
    if (response == null) return;

    _log('PID: 0x${pid.toRadixString(16).toUpperCase()}');
    _log('PID raw response: ${response.trim()}');

    try {
      final reading = ObdParser.parsePid(
        pid: pid,
        response: response,
      );

      _log('PID parsed value: ${reading.value} ${reading.unit}');

      if (mounted) {
        setState(() {
          _liveReadings = {
            ..._liveReadings,
            pid: reading,
          };
        });
      }
    } catch (error) {
      _log('PID parsing error: $error');

      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  Future<void> _sendManualCommand() async {
    final typed = _manualCommandController.text.trim();
    if (typed.isEmpty || _busy) return;

    final normalized = typed.toUpperCase().trim();

    if (normalized == '010C') {
      await _readPid(0x0C, 'دوران المحرك');
      return;
    }
    else if (normalized == '03') {
    await _readDtc(0x03, 'قراءة أكواد الأعطال');
    return;
  }

    final command = typed.endsWith('\r') ? typed : '$typed\r';
    await _execute('أمر يدوي: $typed', command);
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
    await _historyRepository.save(record);
    if (mounted) setState(() => _history = [record, ..._history].take(100).toList());
  }

  String _statusLabel() {
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

  Color _statusColor(BuildContext context) {
    switch (_status) {
      case ObdConnectionStatus.connected:
        return const Color(0xFF10B981); // Emerald
      case ObdConnectionStatus.connecting:
      case ObdConnectionStatus.scanning:
        return const Color(0xFF06B6D4); // Cyan
      case ObdConnectionStatus.error:
        return const Color(0xFFEF4444); // Red
      case ObdConnectionStatus.disconnected:
        return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.minor_crash_rounded, color: primaryColor, size: 24),
            const SizedBox(width: 10),
            const Text('منصة التشخيص OBD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'تبديل المظهر',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
          IconButton(
            tooltip: 'تحديث الأجهزة',
            onPressed: _status == ObdConnectionStatus.scanning ? null : _scan,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                _buildErrorCard(context),
                const SizedBox(height: 16),
              ],

              // 1. Bluetooth Connection Section
              _buildSectionHeader(
                context,
                title: 'إدارة الاتصال (Bluetooth)',
                subtitle: 'البحث عن أجهزة OBD2 وربط التطبيق',
                icon: Icons.bluetooth_searching_rounded,
              ),
              const SizedBox(height: 8),

              _buildConnectionCard(context),
              const SizedBox(height: 12),

              _buildSectionHeader(
                context,
                title: 'سجل تشخيص Bluetooth',
                subtitle: 'تفاصيل الاتصال والخدمات والخصائص',
                icon: Icons.terminal_rounded,
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'BLE Debug Log',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            tooltip: 'مسح السجل',
                            onPressed: () {
                              setState(() => _debugLogs.clear());
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _debugLogs.isEmpty
                            ? const Text(
                          'لم تصل رسائل بعد. اضغط اتصال بجهاز BLE.',
                          style: TextStyle(color: Colors.white70),
                        )
                            : SingleChildScrollView(
                          child: SelectableText(
                            _debugLogs.join('\n\n'),
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Quick Commands Section
              _buildSectionHeader(
                context,
                title: 'الأوامر التشخيصية السريعة',
                subtitle: 'قراءة المؤشرات والأعطال بنقرة واحدة',
                icon: Icons.speed_rounded,
              ),
              const SizedBox(height: 8),
              _buildQuickActions(context),
              const SizedBox(height: 8),
              _buildDtcCard(context),
              const SizedBox(height: 20),

              // 3. Manual Terminal Commands Section
              _buildSectionHeader(
                context,
                title: 'المنفذ اليدوي (Terminal)',
                subtitle: 'إرسال أوامر ELM327 مخصصة وتلقي الرد المباشر',
                icon: Icons.terminal_rounded,
              ),
              const SizedBox(height: 8),
              _buildManualCommandCard(context),
              const SizedBox(height: 20),

              // 4. Results & Wi-Fi Live Stream Section
              _buildSectionHeader(
                context,
                title: 'نتائج وقراءات الفحص الحية (Wi-Fi / HTTP)',
                subtitle: 'عرض بيانات الحساسات الحية المجمعة عبر السيرفر',
                icon: Icons.wifi_tethering_rounded,
              ),
              const SizedBox(height: 8),
              _buildResultsCard(context),
              const SizedBox(height: 20),

              _buildSectionHeader(
                context,
                title: 'تحليل رد جهاز OBD',
                subtitle: 'تحليل الأمر والرد عبر API وعرض التشخيص',
                icon: Icons.health_and_safety_rounded,
              ),
              const SizedBox(height: 8),
              _buildApiAnalysisCard(context),
              const SizedBox(height: 20),

              // 5. History Logs Section
              _buildSectionHeader(
                context,
                title: 'سجل العمليات السابق',
                subtitle: 'الأوامر المسجلة ونتائج التشخيص السابقة',
                icon: Icons.history_rounded,
                action: _history.isNotEmpty
                    ? TextButton.icon(
                  onPressed: () async {
                    await _historyRepository.clear();
                    if (mounted) setState(() => _history = <InspectionRecord>[]);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  label: const Text('مسح السجل', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                )
                    : null,
              ),
              const SizedBox(height: 8),
              _buildHistoryCard(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        Widget? action,
      }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildConnectionCard(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final statusCol = _statusColor(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusCol.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusCol.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    _connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    color: statusCol,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusLabel(),
                          style: TextStyle(fontWeight: FontWeight.bold, color: statusCol, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _service.connectedDevice == null
                              ? 'لم يتم الاتصال بأي جهاز حالياً'
                              : 'الجهاز: ${_service.connectedDevice!.platformName.isEmpty ? _service.connectedDevice!.remoteId : _service.connectedDevice!.platformName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_connected)
                    IconButton(
                      tooltip: 'فصل الجهاز',
                      onPressed: _busy ? null : _disconnect,
                      icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _busy || _status == ObdConnectionStatus.scanning ? null : _scan,
                icon: _status == ObdConnectionStatus.scanning
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.search_rounded, size: 20),
                label: Text(
                  _status == ObdConnectionStatus.scanning ? 'جارٍ البحث عن الأجهزة...' : 'البحث عن الأجهزة القريبة',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_devices.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الأجهزة المكتشفة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${_devices.length} أجهزة', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildDeviceTile(context, _devices[index]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(BuildContext context, DiscoveredObdDevice item) {
    final isFreematics = item.name.toLowerCase().contains('freematics');
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFreematics ? primaryColor.withOpacity(0.5) : const Color(0xFF334155).withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isFreematics ? primaryColor.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isFreematics ? Icons.directions_car_rounded : Icons.bluetooth_rounded,
            color: isFreematics ? primaryColor : Colors.grey,
            size: 22,
          ),
        ),
        title: Text(
          item.name.isEmpty ? 'جهاز غير معروف' : item.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${item.id} | ${item.rssi} dBm',
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        trailing: OutlinedButton(
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            side: BorderSide(color: primaryColor),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _busy ? null : () => _connect(item),
          child: const Text('اتصال', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? '',
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFEF4444)),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionButton(
          title: 'دوران المحرك (RPM)',
          icon: Icons.speed_rounded,
          onPressed: _busy ? null : () => _readPid(0x0C, 'دوران المحرك'),
        ),
        _buildActionButton(
          title: 'جهد البطارية',
          icon: Icons.battery_charging_full_rounded,
          onPressed: _busy ? null : _readBattery,
        ),
        _buildActionButton(
          title: 'رقم الهيكل (VIN)',
          icon: Icons.fingerprint_rounded,
          onPressed: _busy ? null : _readVin,
        ),
        _buildActionButton(
          title: 'أكواد الأعطال (DTC)',
          icon: Icons.error_outline_rounded,
          onPressed: _busy ? null : () => _readDtc(0x03, 'قراءة أكواد الأعطال'),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(title, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildDtcCard(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const errorColor = Color(0xFFEF4444); // Red
    const successColor = Color(0xFF10B981); // Emerald
    final primaryColor = Theme.of(context).colorScheme.primary;
    final mutedColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _dtcCodes.isNotEmpty
                      ? Icons.error_rounded
                      : (_hasReadDtc ? Icons.verified_rounded : Icons.published_with_changes_rounded),
                  color: _dtcCodes.isEmpty ? (_hasReadDtc ? successColor : mutedColor) : errorColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _dtcCodes.isEmpty
                        ? (_hasReadDtc ? 'لا توجد أكواد أعطال مسجلة' : 'لم تُقرأ أكواد الأعطال بعد')
                        : '${_dtcCodes.length} ${_dtcCodes.length == 1 ? 'كود عطل مكتشف' : 'أكواد أعطال مكتشفة'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _dtcCodes.isEmpty
                          ? (_hasReadDtc ? successColor : mutedColor)
                          : errorColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_dtcCodes.isNotEmpty)
              ..._dtcCodes.map((code) => _buildDtcTile(context, code, errorColor))
            else
              Text(
                _hasReadDtc
                    ? 'وحدة التحكم لا تُبلغ عن أي أعطال حالياً.'
                    : 'اضغط زر «أكواد الأعطال (DTC)» أعلاه أو أدخل الأمر 03 في المنفذ اليدوي لقراءة الأكواد المكتشفة.',
                style: TextStyle(fontSize: 12, color: mutedColor, height: 1.5),
                textDirection: TextDirection.rtl,
              ),
            if (_dtcCodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'الحرف الأول من الكود يدل على النظام: P المحرك، C الشاسي، B هيكل السيارة، U الشبكة والاتصالات.',
                style: TextStyle(fontSize: 11, color: primaryColor.withOpacity(0.8)),
                textDirection: TextDirection.rtl,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDtcTile(BuildContext context, String code, Color color) {
    String system;
    switch (code.isNotEmpty ? code[0] : '') {
      case 'P':
        system = 'المحرك / ناقل الحركة';
        break;
      case 'C':
        system = 'الشاسي';
        break;
      case 'B':
        system = 'هيكل السيارة';
        break;
      case 'U':
        system = 'الشبكة والاتصالات';
        break;
      default:
        system = 'نظام غير معروف';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.warning_amber_rounded, color: color, size: 20),
        ),
        title: Text(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          textDirection: TextDirection.ltr,
        ),
        subtitle: Text(
          system,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildManualCommandCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manualCommandController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'أدخل الأمر مثل: 010C أو BATT',
                  isDense: true,
                ),
                onSubmitted: (_) => _sendManualCommand(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _busy ? null : _sendManualCommand,
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiAnalysisCard(BuildContext context) {
    final analysis = _lastApiAnalysis;
    final values = analysis?['values'] is Map
        ? Map<String, dynamic>.from(analysis!['values'] as Map)
        : <String, dynamic>{};
    final dtcs = analysis?['dtcs'] is List
        ? (analysis!['dtcs'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final confidence = analysis?['confidence'];
    final severity = analysis?['severity']?.toString();
    final status = analysis?['status']?.toString();

    String label(String? value) {
      switch (value?.toLowerCase()) {
        case 'warning': return 'تحذير';
        case 'error': return 'خطأ';
        case 'critical': return 'حرج';
        case 'high': return 'مرتفع';
        case 'medium': return 'متوسط';
        case 'low': return 'منخفض';
        case 'info': return 'معلومات';
        case 'success': return 'سليم';
        default: return value ?? 'غير محدد';
      }
    }

    Widget detail(String title, dynamic value, {IconData? icon}) {
      if (value == null || value.toString().trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8)],
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(value.toString()),
            ])),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _apiLoading && analysis == null
            ? const Center(child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('جارٍ إرسال الرد إلى خدمة التحليل...')]),
              ))
            : _apiError != null && analysis == null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 30),
                    const SizedBox(height: 8),
                    Text(_apiError!, style: const TextStyle(color: Colors.orangeAccent)),
                    if (_lastApiCommand.isNotEmpty) Text('الأمر: $_lastApiCommand\nالرد: $_lastApiRawResponse'),
                  ])
                : analysis == null
                    ? const Text('أرسل أمر OBD بعد الاتصال بالجهاز لعرض التحليل هنا.')
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_apiLoading) const LinearProgressIndicator(),
                        Row(children: [
                          const Icon(Icons.analytics_rounded, color: Colors.cyanAccent, size: 28),
                          const SizedBox(width: 8),
                          Expanded(child: Text(analysis['title']?.toString() ?? 'نتيجة التحليل', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        ]),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          Chip(label: Text('الحالة: ${label(status)}')),
                          Chip(label: Text('الخطورة: ${label(severity)}')),
                          if (confidence is num) Chip(label: Text('الثقة: ${(confidence * 100).toStringAsFixed(0)}%')),
                        ]),
                        const Divider(height: 24),
                        detail('شرح التحليل', analysis['explanation'], icon: Icons.info_outline),
                        detail('المشكلة المحتملة', analysis['problem'], icon: Icons.warning_amber_rounded),
                        detail('التوصية', analysis['recommendation'], icon: Icons.build_circle_outlined),
                        if (values.isNotEmpty) detail('القيم المستخرجة', values.entries.map((e) => '${e.key}: ${e.value}').join(' | '), icon: Icons.sensors),
                        if (dtcs.isNotEmpty) detail('رموز الأعطال (DTC)', dtcs.join(', '), icon: Icons.error_outline),
                        if (dtcs.isEmpty) detail('رموز الأعطال (DTC)', 'لم تُرجع الخدمة رموز أعطال.'),
                        const Divider(height: 20),
                        Text('الأمر: $_lastApiCommand', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('رد الجهاز: $_lastApiRawResponse', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        if (_apiError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_apiError!, style: const TextStyle(color: Colors.orangeAccent))),
                      ]),
      ),
    );
  }

  // 5. كارت النتائج المدمج بـ StreamBuilder لـ ObdHttpService
  Widget _buildResultsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<ObdLiveData>(
          stream: _httpService.dataStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'جاري الاتصال بـ Freematics Wi-Fi واستقبال البيانات الحية...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                'تنبيه HTTP: تأكد من اتصال هاتفك بشبكة Wi-Fi الخاصة بـ Freematics.\n${snapshot.error}',
                style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
              );
            }

            if (snapshot.hasData) {
              final data = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'رقم الشاسي (VIN): ${data.vin}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'البطارية: ${data.batteryVoltage.toStringAsFixed(2)} V',
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.speed_rounded, color: Colors.cyanAccent),
                    title: const Text('دوران المحرك (RPM)'),
                    trailing: Text(
                      '${data.rpm} RPM',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.navigation_rounded, color: Colors.lightGreenAccent),
                    title: const Text('سرعة السيارة'),
                    trailing: Text(
                      '${data.speed} km/h',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.lightGreenAccent),
                    ),
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.thermostat_rounded, color: Colors.orangeAccent),
                    title: const Text('حرارة سائل التبريد'),
                    trailing: Text(
                      '${data.coolantTemp} °C',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orangeAccent),
                    ),
                  ),
                ],
              );
            }

            return const Text('لا توجد بيانات متاحة حالياً.');
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
    if (_history.isEmpty) {
      return const Center(child: Text('لا يوجد سجل عمليات سابق', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length > 5 ? 5 : _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return ListTile(
          dense: true,
          title: Text(item.title),
          subtitle: Text(item.result),
          trailing: Icon(
            item.success ? Icons.check_circle_rounded : Icons.error_rounded,
            color: item.success ? Colors.green : Colors.red,
            size: 18,
          ),
        );
      },
    );
  }
}