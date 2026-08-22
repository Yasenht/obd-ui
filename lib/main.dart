import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

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
                  'نظام التشخيص الفني للسيارات عبر BLE',
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

              // 4. Results Section
              _buildSectionHeader(
                context,
                title: 'نتائج وقراءات الفحص',
                subtitle: 'عرض بيانات الحساسات وأكواد الأعطال الحالية',
                icon: Icons.analytics_rounded,
              ),
              const SizedBox(height: 8),
              _buildResultsCard(context),
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
          '${item.id}  •  ${item.rssi} dBm',
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
              _error!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              crossAxisCount: constraints.maxWidth > 500 ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              children: [
                _quickActionButton(
                  context,
                  label: 'كشف الأعطال DTC',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: _readDtc,
                ),
                _quickActionButton(
                  context,
                  label: 'رقم الهيكل VIN',
                  icon: Icons.fingerprint_rounded,
                  color: const Color(0xFF3B82F6),
                  onTap: _readVin,
                ),
                _quickActionButton(
                  context,
                  label: 'حرارة المحرك',
                  icon: Icons.thermostat_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => _readPid(0x05, 'قراءة حرارة المحرك'),
                ),
                _quickActionButton(
                  context,
                  label: 'دوران المحرك RPM',
                  icon: Icons.speed_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => _readPid(0x0C, 'قراءة دوران المحرك'),
                ),
                _quickActionButton(
                  context,
                  label: 'مسح الأكواد DTC',
                  icon: Icons.delete_sweep_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: _clearDtc,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _quickActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualCommandCard(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualCommandController,
                    textDirection: TextDirection.ltr,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'مثال: 010C أو 03',
                      prefixIcon: Icon(Icons.code_rounded, size: 20),
                    ),
                    onSubmitted: (_) => _sendManualCommand(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _busy ? null : _sendManualCommand,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('إرسال'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final hasData = _vin != null || _dtcCodes.isNotEmpty || _liveReadings.isNotEmpty || _lastResponse.isNotEmpty;

    if (!hasData) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.query_stats_rounded, size: 40, color: Theme.of(context).hintColor.withOpacity(0.4)),
              const SizedBox(height: 12),
              const Text(
                'لا توجد نتائج فحص حتى الآن',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 4),
              const Text(
                'قم بتنفيذ أحد الأوامر السريعة أو اليدوية لعرض البيانات هنا',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_vin != null) ...[
              _buildMetricTile(
                context,
                title: 'رقم الهيكل VIN',
                value: _vin!,
                icon: Icons.fingerprint_rounded,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 10),
            ],
            if (_dtcCodes.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'أكواد الأعطال المكتشفة (${_dtcCodes.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dtcCodes
                          .map((code) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            ..._liveReadings.values.map((reading) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildMetricTile(
                    context,
                    title: reading.label,
                    value: reading.displayValue,
                    icon: Icons.bar_chart_rounded,
                    color: primaryColor,
                  ),
                )),
            if (_lastResponse.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('الاستجابة الخام (Raw Output)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  iconColor: primaryColor,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        _lastResponse,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context) {
    if (_history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'لا توجد فحوصات محفوظة في السجل',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _history.take(8).length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final record = _history[index];
          final statusColor = record.success ? const Color(0xFF10B981) : const Color(0xFFEF4444);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(
              record.success ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded,
              color: statusColor,
              size: 22,
            ),
            title: Text(record.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(
              intl.DateFormat('yyyy/MM/dd - hh:mm a').format(record.createdAt),
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            trailing: SizedBox(
              width: 120,
              child: Text(
                record.result,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
      ),
    );
  }
}