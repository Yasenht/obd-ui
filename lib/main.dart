import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'  as intl;

import 'ble_obd_service.dart';
import 'history_repository.dart';
import 'models.dart';
import 'obd_protocol.dart';


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
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFC107),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      cardTheme: const CardThemeData(
        color: Color(0xFF111827),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0xFF2A3345), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A3345)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A3345)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFFC107)),
        ),
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFC107),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF59E0B)),
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD54F), Color(0xFFF59E0B), Color(0xFF0F172A)],
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
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(Icons.directions_car_filled_rounded, size: 64, color: Colors.white),
                ),
                const SizedBox(height: 22),
                const Text(
                  'OBD Scanner',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'فحص السيارات عبر BLE',
                  style: TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 16,
                    letterSpacing: 0.3,
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
  final _historyRepository = HistoryRepository();
  final _manualCommandController = TextEditingController();
  final _scrollController = ScrollController();

  StreamSubscription<List<DiscoveredObdDevice>>? _scanSubscription;
  StreamSubscription<ObdConnectionStatus>? _statusSubscription;
  List<DiscoveredObdDevice> _devices = <DiscoveredObdDevice>[];
  List<InspectionRecord> _history = <InspectionRecord>[];
  Map<int, PidReading> _liveReadings = <int, PidReading>{};
  List<String> _dtcCodes = <String>[];
  ObdConnectionStatus _status = ObdConnectionStatus.disconnected;
  String _lastResponse = '';
  String? _vin;
  String? _error;
  bool _busy = false;

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
    unawaited(_requestRequiredPermissions());
    _loadHistory();
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
    _scanSubscription?.cancel();
    _statusSubscription?.cancel();
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
      final response = await _service.sendCommand(command, timeout: timeout ?? const Duration(seconds: 4));
      if (mounted) {
        setState(() => _lastResponse = response.trim());
        await _saveRecord(
          title: title,
          result: response.trim().isEmpty ? 'لم يصل رد' : response.trim(),
          success: !ObdParser.isError(response),
          rawResponse: response,
        );
      }
      return response;
    } catch (error) {
      if (mounted) setState(() => _error = '$title: $error');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _readDtc() async {
    final response = await _execute('قراءة أكواد الأعطال DTC', ObdCommands.readDtc, timeout: const Duration(seconds: 10));
    if (response == null) return;
    try {
      final codes = ObdParser.parseDtc(response);
      if (mounted) setState(() => _dtcCodes = codes);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _readVin() async {
    final response = await _execute('قراءة رقم الهيكل VIN', ObdCommands.readVin, timeout: const Duration(seconds: 10));
    if (response == null) return;
    try {
      final vin = ObdParser.parseVin(response);
      if (mounted) setState(() => _vin = vin);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _readPid(int pid, String title) async {
    final response = await _execute(title, ObdCommands.readPid(pid));
    if (response == null) return;
    try {
      final reading = ObdParser.parsePid(pid: pid, response: response);
      if (mounted) setState(() => _liveReadings = {..._liveReadings, pid: reading});
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _sendManualCommand() async {
    final typed = _manualCommandController.text.trim();
    if (typed.isEmpty) return;
    final command = typed.endsWith('\r') ? typed : '$typed\r';
    await _execute('أمر يدوي: $typed', command);
  }

  Future<void> _clearDtc() async {
    final response = await _execute('مسح أكواد الأعطال', ObdCommands.clearDtc, timeout: const Duration(seconds: 10));
    if (response != null && mounted) setState(() => _dtcCodes = <String>[]);
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
        return 'جارٍ البحث عن الأجهزة';
      case ObdConnectionStatus.connecting:
        return 'جارٍ الاتصال';
      case ObdConnectionStatus.connected:
        return 'متصل';
      case ObdConnectionStatus.error:
        return 'خطأ في الاتصال';
      case ObdConnectionStatus.disconnected:
        return 'غير متصل';
    }
  }

  Color _statusColor(BuildContext context) => _connected ? Colors.green : Theme.of(context).colorScheme.outline;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    final backgroundTop = isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC);
    final backgroundBottom = isDark ? const Color(0xFF111827) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car_filled_rounded, size: 20),
            const SizedBox(width: 8),
            const Text('فاحص OBD للسيارات'),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFD54F), Color(0xFFF59E0B)],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تبديل الوضع',
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              tooltip: 'تحديث الأجهزة',
              onPressed: _status == ObdConnectionStatus.scanning ? null : _scan,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundTop, backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildConnectionCard(context),
                const SizedBox(height: 12),
                if (_error != null) _buildErrorCard(context),
                _buildQuickActions(context),
                const SizedBox(height: 12),
                _buildManualCommandCard(context),
                const SizedBox(height: 12),
                _buildResultsCard(context),
                const SizedBox(height: 12),
                _buildHistoryCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusColor(context).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bluetooth_connected_rounded, color: _statusColor(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'اتصال Bluetooth / BLE',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  avatar: Icon(Icons.circle, size: 12, color: _statusColor(context)),
                  label: Text(_statusLabel()),
                  backgroundColor: _statusColor(context).withOpacity(0.12),
                  side: BorderSide(color: _statusColor(context).withOpacity(0.3)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _service.connectedDevice == null
                  ? 'ابحث عن جميع الأجهزة القريبة، حتى لو لم تكن متوافقة مع Freematics. أهم شيء هو اسم الجهاز القريب.'
                  : 'الجهاز الحالي: ${_service.connectedDevice!.platformName.isEmpty ? _service.connectedDevice!.remoteId : _service.connectedDevice!.platformName}',
              style: const TextStyle(color: Color(0xFFE5E7EB), height: 1.5),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _busy || _status == ObdConnectionStatus.scanning ? null : _scan,
              icon: const Icon(Icons.search_rounded),
              label: Text(_status == ObdConnectionStatus.scanning ? 'جارٍ البحث...' : 'البحث عن الأجهزة القريبة'),
            ),
            if (_connected) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2A3345)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _busy ? null : _disconnect,
                icon: const Icon(Icons.bluetooth_disabled_rounded),
                label: const Text('فصل الجهاز'),
              ),
            ],
            if (_devices.isNotEmpty) ...[
              const Divider(height: 24, color: Color(0xFF2A3345)),
              Text('الأجهزة المكتشفة (${_devices.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._devices.map((item) => _buildDeviceTile(context, item)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(BuildContext context, DiscoveredObdDevice item) {
    final isFreematics = item.name.toLowerCase().contains('freematics');
    final compatibilityText = isFreematics ? 'متوافق مع Freematics' : 'غير متوافق - يظهر فقط كجهاز BLE قريب';
    final accentColor = isFreematics ? Colors.blue : item.rssi > -70 ? Colors.green : Colors.orange;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.35)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isFreematics ? Icons.car_repair : Icons.bluetooth_searching, color: accentColor),
          ),
          title: Text(item.name, style: TextStyle(color: accentColor, fontWeight: FontWeight.w700)),
          subtitle: Text('${item.id}  •  RSSI ${item.rssi} dBm  •  $compatibilityText'),
          trailing: FilledButton(
            onPressed: _busy ? null : () => _connect(item),
            child: const Text('اتصال'),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Card(
      color: const Color(0xFF2F1D1D),
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Color(0xFFFFA726)),
        title: const Text('تنبيه', style: TextStyle(color: Colors.white)),
        subtitle: Text(_error!, style: const TextStyle(color: Color(0xFFE5E7EB))),
        trailing: IconButton(
          onPressed: () => setState(() => _error = null),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: Color(0xFFFFC107)),
                const SizedBox(width: 8),
                Expanded(child: Text('الأوامر السريعة', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickButton('كشف الأعطال DTC', Icons.warning_amber, _readDtc),
                _quickButton('رقم الهيكل VIN', Icons.confirmation_number, _readVin),
                _quickButton('حرارة المحرك', Icons.thermostat, () => _readPid(0x05, 'قراءة حرارة المحرك')),
                _quickButton('دوران المحرك RPM', Icons.speed, () => _readPid(0x0C, 'قراءة دوران المحرك')),
                _quickButton('مسح الأكواد', Icons.delete_sweep, _clearDtc),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickButton(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF2A3345)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: _busy ? null : onPressed,
      icon: Icon(icon, color: const Color(0xFFFFC107)),
      label: Text(label),
    );
  }

  Widget _buildManualCommandCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal_rounded, color: Color(0xFFFFC107)),
                const SizedBox(width: 8),
                Expanded(child: Text('إرسال أمر يدوي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 8),
            const Text('أدخل الأمر بصيغة ELM327، مثل 010C أو 03. سيضيف التطبيق CR تلقائياً.', style: TextStyle(color: Color(0xFFE5E7EB))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCommandController,
                    textDirection: TextDirection.ltr,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: '010C'),
                    onSubmitted: (_) => _sendManualCommand(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: const Color(0xFF111827),
                  ),
                  onPressed: _busy ? null : _sendManualCommand,
                  icon: const Icon(Icons.send),
                  label: const Text('إرسال'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_rounded, color: Color(0xFFFFC107)),
                const SizedBox(width: 8),
                Expanded(child: Text('نتائج الفحص', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 12),
            if (_vin != null) _resultRow('VIN', _vin!, Icons.confirmation_number),
            if (_dtcCodes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('أكواد الأعطال (${_dtcCodes.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ..._dtcCodes.map((code) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning, color: Colors.orange),
                    title: Text(code, textDirection: TextDirection.ltr),
                    subtitle: const Text('كود تشخيصي يحتاج إلى تفسير حسب السيارة والأعراض.'),
                  )),
            ] else if (_lastResponse.isNotEmpty && _dtcCodes.isEmpty)
              _resultRow('DTC', 'لم يتم العثور على أكواد أو راجع الرد الخام أدناه.', Icons.check_circle_outline),
            ..._liveReadings.values.map((reading) => _resultRow(reading.label, reading.displayValue, Icons.analytics)),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('الرد الخام الأخير'),
                iconColor: const Color(0xFFFFC107),
                collapsedIconColor: const Color(0xFFFFFFFF),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(_lastResponse.isEmpty ? 'لا توجد بيانات بعد.' : _lastResponse, textDirection: TextDirection.ltr),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3345)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFC107)),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: Color(0xFFFFC107)),
                const SizedBox(width: 8),
                Expanded(child: Text('سجل الفحوصات', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                if (_history.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await _historyRepository.clear();
                      if (mounted) setState(() => _history = <InspectionRecord>[]);
                    },
                    child: const Text('مسح السجل', style: TextStyle(color: Color(0xFFFFC107))),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_history.isEmpty)
              const Text('لا توجد فحوصات محفوظة بعد.', style: TextStyle(color: Color(0xFFE5E7EB)))
            else
              ..._history.take(10).map((record) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A3345)),
                    ),
                    child: Row(
                      children: [
                        Icon(record.success ? Icons.check_circle : Icons.error, color: record.success ? Colors.green : Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(record.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(intl.DateFormat('yyyy-MM-dd HH:mm').format(record.createdAt), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 140,
                          child: Text(record.result, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, textAlign: TextAlign.left),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
