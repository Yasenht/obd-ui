import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../controllers/app_controller.dart';
import '../controllers/app_scope.dart';
import '../models.dart';
import '../obd_protocol.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// الشاشة الثالثة: سجل عمليات التشخيص السابقة (محفوظة محلياً).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _query = '';
  bool _showAll = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// بحث تفاعلي مع مهلة تسويف قصيرة (300ms) لتخفيف ضغط الاستعلام.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted && value != _query) {
        setState(() => _query = value.trim().toLowerCase());
      }
    });
  }

  List<InspectionRecord> _filtered(List<InspectionRecord> records) {
    // السجل مرتب سلفاً من الأحدث إلى الأقدم في المستودع — نضمن
    // الترتيب هنا أيضاً لموقف إعادة التحميل.
    final sorted = [...records]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_query.isEmpty) return sorted;
    return sorted.where((r) {
      final time = DateFormat('d MMM yyyy • HH:mm', 'ar').format(r.createdAt);
      return r.title.toLowerCase().contains(_query) ||
          r.result.toLowerCase().contains(_query) ||
          r.rawResponse.toLowerCase().contains(_query) ||
          time.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.controller;
    final palette = Palette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التشخيص'),
        actions: [
          if (controller.history.isNotEmpty)
            IconButton(
              tooltip: 'مسح السجل',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('مسح كامل السجل؟'),
                    content: const Text(
                        'سيُحذف نهائياً سجل عمليات التشخيص من التطبيق. '
                        'هذا الإجراء لا يمكن التراجع عنه.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.error),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('مسح نهائياً'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await controller.clearHistory();
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'ابحث في السجل: كود، نتيجة، عنوان، تاريخ...',
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: Icon(Icons.manage_search_rounded),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _buildList(context, controller, palette)),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    AppController controller,
    Palette palette,
  ) {
    if (controller.historyLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('جارٍ تحميل السجل...'),
          ],
        ),
      );
    }

    if (controller.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.history_toggle_off_rounded,
          title: 'لا توجد سجلات بعد',
          message: 'ستظهر هنا كل عمليات الفحص التي تتم عبر جهاز التشخيص '
              '(قراءات، أوامر، أكواد أعطال) محفوظة على جهازك.',
        ),
      );
    }

    final filtered = _filtered(controller.history);
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          compact: true,
          icon: Icons.search_off_rounded,
          title: 'لا نتائج مطابقة',
          message: 'جرّب كلمة أو كوداً آخر — البحث يشمل العنوان، '
              'النتيجة، الرد الخام والتاريخ.',
        ),
      );
    }

    final shown = _showAll ? filtered : filtered.take(10).toList();

    return RefreshIndicator(
      onRefresh: controller.loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: shown.length + (_showAll ? 0 : 1),
        itemBuilder: (context, index) {
          if (!_showAll && index == shown.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showAll = true),
                icon: const Icon(Icons.expand_more_rounded, size: 18),
                label: Text('عرض المزيد (${filtered.length - shown.length})'),
              ),
            );
          }
          return _RecordTile(
            record: shown[index],
            highlight: _query,
          );
        },
      ),
    );
  }
}

// ============================================================
/// بطاقة سجل عملية واحدة — يفتح التفاصيل الكاملة عند الضغط.
// ============================================================

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.highlight});

  final InspectionRecord record;
  final String highlight;

  bool get _isDtcScan => record.title.contains('أكواد الأعطال');

  /// هل الرد المسجل رد وضع 03 صالح (يحتوي علامة 43)؟
  bool get _scanConclusive =>
      record.success && RegExp(r'\b43\b').hasMatch(record.rawResponse);

  /// أكواد الأعطال الموجودة فعلاً في الرد المسجل — عبر نفس محلل الجهاز.
  List<String> get faultCodes {
    final codes = <String>{};
    if (record.rawResponse.isNotEmpty) {
      try {
        codes.addAll(ObdParser.parseDtc(record.rawResponse));
      } catch (_) {
        // رد غير قابل للفك — لا نستنتج شيئاً.
      }
    }
    codes.addAll(
      RegExp(r'[PCBU][0-3][0-9A-F]{3}')
          .allMatches('${record.result} ${record.rawResponse}')
          .map((m) => m.group(0)!),
    );
    return codes.toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openDetails(context, palette),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    record.success
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: record.success ? palette.onPrimary : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: palette.text,
                      ),
                    ),
                  ),
                  // وسم المصدر: السجل محلي بهذا الإصدار (لكل الأسطر).
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.onPrimary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_iphone_rounded,
                            size: 10, color: palette.onPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'محلي',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: palette.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                record.result,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: palette.textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              // ملخص فحص الأعطال (يُستخرج من الرد الفعلي المسجل فقط).
              if (_isDtcScan) ...[
                Row(
                  children: [
                    Icon(
                      !record.success
                          ? Icons.error_outline_rounded
                          : !_scanConclusive
                              ? Icons.help_outline_rounded
                              : faultCodes.isEmpty
                                  ? Icons.verified_rounded
                                  : Icons.warning_amber_rounded,
                      size: 12,
                      color: !record.success
                          ? AppColors.error
                          : (_scanConclusive && faultCodes.isEmpty)
                              ? palette.onPrimary
                              : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      !record.success
                          ? 'الفحص لم يكتمل'
                          : !_scanConclusive
                              ? 'نتيجة غير مكتملة'
                              : faultCodes.isEmpty
                                  ? 'لا أعطال مسجلة'
                                  : '${faultCodes.length} ${faultCodes.length == 1 ? 'عطل' : 'أعطال'}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: palette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 12, color: palette.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    formatRecordTime(record.createdAt.toLocal()),
                    style: TextStyle(fontSize: 10.5, color: palette.textMuted),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, Palette palette) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: palette.text,
                      ),
                    ),
                  ),
                  Icon(
                    record.success
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: record.success ? palette.onPrimary : AppColors.error,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatRecordTime(record.createdAt.toLocal()),
                style: TextStyle(fontSize: 11, color: palette.textMuted),
              ),
              const SizedBox(height: 14),
              Text(
                'النتيجة',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: palette.onPrimary,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                record.result,
                style: TextStyle(
                    fontSize: 12.5,
                    color: palette.text,
                    height: 1.5,
                    fontFamily: 'monospace'),
                textDirection: TextDirection.ltr,
              ),
              if (record.rawResponse.isNotEmpty &&
                  record.rawResponse != record.result) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'الرد الخام',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: palette.onPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.copy_rounded,
                          size: 18, color: palette.textMuted),
                      tooltip: 'نسخ الرد الخام',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: record.rawResponse));
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم النسخ')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(kRadiusSmall),
                    border: Border.all(color: palette.border),
                  ),
                  child: SelectableText(
                    record.rawResponse,
                    style: TextStyle(
                        fontSize: 12,
                        color: palette.text,
                        height: 1.5,
                        fontFamily: 'monospace'),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
