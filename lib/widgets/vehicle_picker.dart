import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ============================================================
// منتقي قابل للبحث للماركة/الموديل:
// حقل أنيق يفتح ورقة سفلية بمحرك بحث حي فوق القائمة.
// يحل محل DropdownButtonFormField الذي لا يناسب القوائم الطويلة.
// ============================================================

/// حقل الاختيار: يظهر القيمة الحالية أو التلميح، ويفتح
/// [showVehiclePickerSheet] عند الضغط (ما لم يكون معطلاً).
class VehiclePickerField extends StatelessWidget {
  const VehiclePickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.values,
    required this.onChanged,
    this.value,
    this.icon = Icons.directions_car_rounded,
    this.enabled = true,
    this.disabledHint,
  });

  /// العنوان الظاهر أعلى الحقل (مثل "ماركة السيارة").
  final String label;

  /// التلميح عند عدم وجود قيمة مختارة.
  final String hint;

  /// القيمة المختارة حالياً (قد تكون null).
  final String? value;

  /// الخيارات المعروضة داخل الورقة القابلة للبحث.
  final List<String> values;

  /// استدعاء عند الاختيار من الورقة.
  final ValueChanged<String?> onChanged;

  /// أيقونة بادئة الحقل.
  final IconData icon;

  /// تعطيل الحقل (مثلاً: الموديل قبل اختيار الماركة).
  final bool enabled;

  /// نص يظهر بدل التلميح عندما يكون الحقل معطلاً.
  final String? disabledHint;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showVehiclePickerSheet(
      context,
      title: label,
      values: values,
      selected: value,
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final hasValue = value != null && value!.isNotEmpty;
    final hintText = disabledHint ?? hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: palette.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: enabled ? palette.surface : palette.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? () => _openPicker(context) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: enabled
                      ? (hasValue ? palette.onPrimary.withValues(alpha: 0.45) : palette.border)
                      : palette.border.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: enabled
                        ? (hasValue ? palette.onPrimary : palette.textMuted)
                        : palette.textMuted.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasValue ? value! : hintText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
                        color: hasValue
                            ? palette.text
                            : palette.textMuted.withValues(
                                alpha: enabled ? 1 : 0.7),
                      ),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: enabled
                        ? palette.textMuted
                        : palette.textMuted.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// حقل اختيار سنة الصنع — نفس لغة تصميم حقل النص مع قيم رقمية،
/// ويفتح ورقة الاختيار القابلة للبحث (البحث بالأرقام يعمل طبيعياً:
/// "198" يجد 1980-1989 مثلاً).
class VehicleYearPickerField extends StatelessWidget {
  const VehicleYearPickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.values,
    required this.onChanged,
    this.value,
    this.icon = Icons.event_available_rounded,
    this.enabled = true,
    this.disabledHint,
  });

  final String label;
  final String hint;

  /// السنة المختارة حالياً (قد تكون null).
  final int? value;

  /// سنوات الصنع المتاحة (تنازلياً).
  final List<int> values;

  final ValueChanged<int?> onChanged;
  final IconData icon;
  final bool enabled;
  final String? disabledHint;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showVehicleYearPickerSheet(
      context,
      title: label,
      values: values,
      selected: value,
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final hasValue = value != null;
    final hintText = disabledHint ?? hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: palette.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: enabled ? palette.surface : palette.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? () => _openPicker(context) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: enabled
                      ? (hasValue
                          ? palette.onPrimary.withValues(alpha: 0.45)
                          : palette.border)
                      : palette.border.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: enabled
                        ? (hasValue ? palette.onPrimary : palette.textMuted)
                        : palette.textMuted.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hasValue ? '$value' : hintText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
                        color: hasValue
                            ? palette.text
                            : palette.textMuted.withValues(
                                alpha: enabled ? 1 : 0.7),
                      ),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: enabled
                        ? palette.textMuted
                        : palette.textMuted.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ورقة سفلية أنيقة للاختيار مع بحث حي:
/// - حقل بحث يرشّح القائمة لحظياً (غير حساس لحالة الأحرف).
/// - العنصر المختار مميّز بلون العلامة مع أيقونة تأكيد.
/// - حالة فراغ عند عدم تطابق البحث، وعدّاد للنتائج.
Future<String?> showVehiclePickerSheet(
  BuildContext context, {
  required String title,
  required List<String> values,
  String? selected,
  IconData icon = Icons.directions_car_rounded,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Palette.of(context).card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _VehiclePickerSheet(
      title: title,
      values: values,
      selected: selected,
      icon: icon,
    ),
  );
}

/// ورقة اختيار سنة الصنع: نفس لغة التصميم مع قيم رقمية —
/// البحث بالأرقام يعمل طبيعياً ("198" يجد 1980-1989 مثلاً).
Future<int?> showVehicleYearPickerSheet(
  BuildContext context, {
  required String title,
  required List<int> values,
  int? selected,
}) async {
  final picked = await showVehiclePickerSheet(
    context,
    title: title,
    values: <String>[for (final year in values) '$year'],
    selected: selected == null ? null : '$selected',
    icon: Icons.event_available_rounded,
  );
  if (picked == null) return null;
  return int.tryParse(picked);
}

class _VehiclePickerSheet extends StatefulWidget {
  const _VehiclePickerSheet({
    required this.title,
    required this.values,
    required this.selected,
    this.icon = Icons.directions_car_rounded,
  });

  final String title;
  final List<String> values;
  final String? selected;
  final IconData icon;

  @override
  State<_VehiclePickerSheet> createState() => _VehiclePickerSheetState();
}

class _VehiclePickerSheetState extends State<_VehiclePickerSheet> {
  final TextEditingController _search = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.values;
    _search.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _search.removeListener(_applyFilter);
    _search.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.values
          : widget.values
              .where((v) => v.toLowerCase().contains(query))
              .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.78;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // الترويسة: العنوان + العدّاد الحي.
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.onPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon,
                      size: 18, color: palette.onPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: palette.text,
                    ),
                  ),
                ),
                Text(
                  '${_filtered.length} ${_filtered.length == 1 ? 'خيار' : 'خياراً'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // حقل البحث — ترشيح لحظي مع زر إزالة.
            TextField(
              controller: _search,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: palette.textMuted),
                      ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // القائمة: مرشّحة حياً، المختار مميّز.
            Flexible(
              child: _filtered.isEmpty
                  ? _EmptyResults(query: _search.text.trim())
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final item = _filtered[index];
                        final isSelected = item == widget.selected;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Material(
                            color: isSelected
                                ? palette.onPrimary.withValues(alpha: 0.10)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(context).pop(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? palette.onPrimary
                                              : palette.text,
                                        ),
                                        textDirection: TextDirection.ltr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle_rounded,
                                          size: 18, color: palette.onPrimary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حالة عدم وجود نتائج مطابقة للبحث.
class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 34, color: palette.textMuted),
          const SizedBox(height: 10),
          Text(
            query.isEmpty ? 'لا توجد خيارات' : 'لا نتائج مطابقة لـ "$query"',
            style: TextStyle(fontSize: 12.5, color: palette.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
