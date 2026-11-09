import 'package:flutter/material.dart';

import '../../ble_obd_service.dart';
import '../../controllers/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';

/// أقسام الشاشة الرئيسية القابلة للتجميع: كارت الاتصال وقسم البيانات الحية.
/// مجزأة من ملف الواجهة السابق لتقليل التشابك وإعادة رؤوس الأقسام نفسها.
class HomeSections {
  HomeSections._();

  // مفاتيح العرض للتمرير البرمجي (زر «بيانات حية» ثم التمرير إلى القسم).
  static final GlobalKey scrollKey = GlobalKey(debugLabel: 'home-scroll');
  static final GlobalKey liveSectionKey = GlobalKey(debugLabel: 'live-section');
  static final GlobalKey connectionCardKey =
      GlobalKey(debugLabel: 'connection-card');

  static void scrollInto(BuildContext context, GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  /// زر «البيانات الحية»: تفعيل القسم والتمرير إليه.
  static void scrollToLiveSection(BuildContext context) =>
      scrollInto(context, liveSectionKey);

  static void scrollToConnection(BuildContext context) =>
      scrollInto(context, connectionCardKey);

  // ============================================================
  // كارت الاتصال بجهاز التشخيص
  // ============================================================

  static Widget connectionCard(
    BuildContext context, {
    required bool showAllDevices,
    required VoidCallback onToggleShowAll,
  }) {
    final controller = context.controller;
    final palette = Palette.of(context);
    final statusColor = StatusPill.colorOf(controller.status, context);
    final scanning = controller.status == ObdConnectionStatus.scanning;

    Widget deviceList;
    if (controller.devices.isEmpty) {
      deviceList = scanning
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : EmptyState(
              compact: true,
              icon: Icons.bluetooth_searching_rounded,
              title: 'لم يُعثر على أجهزة بعد',
              message: 'اضغط «البحث عن الأجهزة» مع اقتراب جهاز التشخيص '
                  'وتأكد من تشغيل Bluetooth ومنح الأذونات.',
            );
    } else {
      // عرض أول 3 أجهزة فقط، وزر «عرض المزيد» يكشف البقية.
      final visible = showAllDevices
          ? controller.devices
          : controller.devices.take(3).toList();
      final hasMore = controller.devices.length > 3;
      deviceList = Column(
        children: [
          ...visible.map((device) => _DeviceTile(
                device: device,
                busy: controller.busy,
                onConnect: () => controller.connect(device),
              )),
          if (hasMore)
            TextButton.icon(
              onPressed: onToggleShowAll,
              icon: Icon(
                showAllDevices
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(showAllDevices
                  ? 'عرض أقل'
                  : 'عرض المزيد (${controller.devices.length - 3})'),
            ),
        ],
      );
    }

    return Card(
      key: connectionCardKey,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ترويسة الكارت
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    switch (controller.status) {
                      ObdConnectionStatus.connected =>
                        Icons.bluetooth_connected_rounded,
                      ObdConnectionStatus.connecting ||
                      ObdConnectionStatus.scanning =>
                        Icons.bluetooth_searching_rounded,
                      ObdConnectionStatus.error =>
                        Icons.bluetooth_disabled_rounded,
                      ObdConnectionStatus.disconnected =>
                        Icons.bluetooth_rounded,
                    },
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الاتصال بجهاز التشخيص',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        controller.connected
                            ? 'متصل: ${controller.connectedDeviceName}'
                            : switch (controller.status) {
                                ObdConnectionStatus.scanning =>
                                  'جارٍ البحث عن أجهزة OBD-II القريبة...',
                                ObdConnectionStatus.connecting =>
                                  'جارٍ إنشاء اتصال BLE...',
                                ObdConnectionStatus.error =>
                                  'تعذر الاتصال — جرّب مرة أخرى',
                                _ => 'غير متصل — ابحث عن جهازك لبدء الفحص',
                              },
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // زر البحث / زر الفصل
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed:
                          controller.busy || scanning ? null : controller.scan,
                      icon: scanning
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.search_rounded, size: 20),
                      label: Text(scanning
                          ? 'جارٍ البحث...'
                          : 'البحث عن الأجهزة القريبة'),
                    ),
                  ),
                ),
                if (controller.connected) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Tooltip(
                      message: 'فصل الجهاز',
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                              color: AppColors.error.withOpacity(0.5)),
                        ),
                        onPressed:
                            controller.busy ? null : controller.disconnect,
                        child: const Icon(
                          Icons.power_settings_new_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (scanning && controller.devices.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.wifi_tethering_rounded,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    'ما زال البحث جارياً — قد تظهر أجهزة أخرى',
                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                  ),
                ],
              ),
            ],
            if (!controller.connected && controller.devices.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'الأجهزة المكتشفة',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: palette.text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${controller.devices.length} جهاز',
                    style: TextStyle(
                      fontSize: 11,
                      color: palette.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              deviceList,
            ],
            // ملاحظة توافق تقنية: التطبيق يتصل بأجهزة BLE (GATT) فقط.
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13, color: palette.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'يدعم التطبيق أجهزة BLE المتوافقة (مثل Freematics). '
                    'بعض وحدات ELM327 تعمل بـ Bluetooth Classic أو Wi-Fi '
                    'ولا تظهر هنا.',
                    style: TextStyle(
                      fontSize: 10,
                      color: palette.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
/// عنصر جهاز واحد قابلة للنقر للاتصال.
// ============================================================

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.busy,
    required this.onConnect,
  });

  final DiscoveredObdDevice device;
  final bool busy;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final likelyObd = device.name.toLowerCase().contains('freematics') ||
        device.name.toLowerCase().contains('obd') ||
        device.name.toLowerCase().contains('elm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(kRadiusSmall),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadiusSmall),
          onTap: busy ? null : onConnect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: likelyObd
                        ? palette.onPrimary.withOpacity(0.12)
                        : palette.textMuted.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    likelyObd
                        ? Icons.directions_car_rounded
                        : Icons.bluetooth_rounded,
                    color: likelyObd ? palette.onPrimary : palette.textMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name.isEmpty ? 'جهاز غير معروف' : device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${device.id} • ${device.rssi} dBm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: palette.onPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'متاح • ${device.rssi > -60 ? 'إشارة قوية' : device.rssi > -75 ? 'إشارة متوسطة' : 'إشارة ضعيفة'}',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: busy ? null : onConnect,
                  child: const Text('اتصال'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// قسم البيانات الحية: قراءات BLE المحلية فقط (RPM/السرعة/الحرارة/الجهد).
// ============================================================

Widget liveDataSection(
  BuildContext context, {
  Key? key,
}) {
  final controller = context.controller;
  final palette = Palette.of(context);

  String formatValue(num? value,
      {required String unit, required int fractionDigits}) {
    if (value == null) return '—';
    final v = value.toDouble();
    final text = v.roundToDouble() == v
        ? value.round().toString()
        : v.toStringAsFixed(fractionDigits);
    return '$text $unit';
  }

  String liveStatus;
  Color liveStatusColor;
  if (!controller.connected) {
    liveStatus = 'بانتظار الاتصال بجهاز BLE';
    liveStatusColor = palette.textMuted;
  } else if (!controller.liveEnabled) {
    liveStatus = 'موقوف — فعّل التحديث لبدء القراءة';
    liveStatusColor = palette.textMuted;
  } else if (controller.liveFetching) {
    liveStatus = 'جارٍ القراءة...';
    liveStatusColor = AppColors.warning;
  } else {
    liveStatus = 'يعمل — تحديث كل 5 ثوانٍ';
    liveStatusColor = palette.onPrimary;
  }

  return Column(
    children: [
      SectionHeader(
        title: 'البيانات الحية',
        subtitle: 'قراءة مباشرة من الجهاز عبر BLE (كل 5 ثوانٍ)',
        icon: Icons.monitor_heart_rounded,
      ),
      const SizedBox(height: 10),
      Card(
        key: key,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // مفتاح التحديث الحي + الحالة
              Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: controller.liveEnabled
                        ? palette.onPrimary
                        : palette.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'القراءة الحية عبر BLE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: palette.text,
                      ),
                    ),
                  ),
                  Switch(
                    value: controller.liveEnabled && controller.connected,
                    onChanged:
                        controller.connected ? controller.toggleLive : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  MetricTile(
                    icon: Icons.speed_rounded,
                    label: 'RPM',
                    value: formatValue(controller.liveRpm,
                        unit: '', fractionDigits: 0),
                    color: const Color(0xFF4E7F3A),
                  ),
                  const SizedBox(width: 8),
                  MetricTile(
                    icon: Icons.directions_car_rounded,
                    label: 'كلم/س',
                    value: formatValue(controller.liveSpeed,
                        unit: '', fractionDigits: 0),
                    color: const Color(0xFF2E7D6B),
                  ),
                  const SizedBox(width: 8),
                  MetricTile(
                    icon: Icons.thermostat_rounded,
                    label: 'حرارة التبريد (°م)',
                    value: formatValue(controller.liveCoolant,
                        unit: '', fractionDigits: 0),
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  MetricTile(
                    icon: Icons.battery_charging_full_rounded,
                    label: 'جهد (V)',
                    value: formatValue(controller.liveBattery,
                        unit: '', fractionDigits: 2),
                    color: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.update_rounded, size: 13, color: liveStatusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      controller.liveLastUpdate == null
                          ? liveStatus
                          : 'آخر تحديث: '
                              '${controller.liveLastUpdate!.toLocal().hour.toString().padLeft(2, '0')}:'
                              '${controller.liveLastUpdate!.toLocal().minute.toString().padLeft(2, '0')}:'
                              '${controller.liveLastUpdate!.toLocal().second.toString().padLeft(2, '0')} • $liveStatus',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: liveStatusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              // تعديلات الوقود: تُقرأ عند ضغط الزر حصراً — كل ضغطة تُرسل
              // "0106" (STFT) و"0107" (LTFT) وتعيد حساب النتائج والمجموع.
              Row(
                children: [
                  MetricTile(
                    icon: Icons.local_gas_station_rounded,
                    label: 'STFT %',
                    value: formatValue(controller.liveStft,
                        unit: '', fractionDigits: 1),
                    color: const Color(0xFF4E7F3A),
                  ),
                  const SizedBox(width: 8),
                  MetricTile(
                    icon: Icons.schedule_rounded,
                    label: 'LTFT %',
                    value: formatValue(controller.liveLtft,
                        unit: '', fractionDigits: 1),
                    color: const Color(0xFF2E7D6B),
                  ),
                  const SizedBox(width: 8),
                  MetricTile(
                    icon: Icons.summarize_rounded,
                    label: 'المجموع %',
                    value: formatValue(controller.fuelTrimSum,
                        unit: '', fractionDigits: 1),
                    color: AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calculate_rounded,
                    size: 13,
                    color: controller.fuelTrimReading
                        ? AppColors.warning
                        : palette.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      controller.fuelTrimReading
                          ? 'جارٍ الإرسال والحساب...'
                          : controller.fuelTrimLastUpdate == null
                              ? 'اضغط الزر لإرسال الأوامر 0106 / 0107'
                              : 'آخر حساب: '
                                  '${controller.fuelTrimLastUpdate!.toLocal().hour.toString().padLeft(2, '0')}:'
                                  '${controller.fuelTrimLastUpdate!.toLocal().minute.toString().padLeft(2, '0')}:'
                                  '${controller.fuelTrimLastUpdate!.toLocal().second.toString().padLeft(2, '0')} '
                                  '(مجموع = STFT + LTFT)',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: controller.fuelTrimReading
                            ? AppColors.warning
                            : palette.textMuted,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: controller.connected && !controller.busy
                        ? controller.readFuelTrims
                        : null,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('قراءة وحساب'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
