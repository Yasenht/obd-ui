import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/app_scope.dart';
import '../services/dtc_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'faults_screen.dart';

/// شاشة تفاصيل عطل واحد.
///
/// مصدر البيانات المخطط له: خدمة معلومات الأعطال عبر REST ([DtcInfoRepository]).
/// حتى ربطها، تُعرض المعلومات المعيارية القابلة للاستنتاج المحلي فقط
/// (النظام الذي تشير إليه أول خانة من الكود) وحالة "المعلومات التفصيلية
/// غير متوفرة بعد" — لا نحضّر تشخيصاً مؤكداً من الكود وحده.
class FaultDetailsScreen extends StatefulWidget {
  const FaultDetailsScreen({super.key, required this.code});

  final String code;

  @override
  State<FaultDetailsScreen> createState() => _FaultDetailsScreenState();
}

enum _DetailsState { loading, notConfigured, loaded, notFound, error }

class _FaultDetailsScreenState extends State<FaultDetailsScreen> {
  late final DtcInfoRepository _repository;
  _DetailsState _state = _DetailsState.loading;
  DtcInfo? _info;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _repository = HttpDtcInfoRepository();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _DetailsState.loading);
    try {
      final info = await _repository.fetchInfo(widget.code.toUpperCase());
      if (!mounted) return;
      if (info == null || info.isEmpty) {
        setState(() => _state = _DetailsState.notFound);
      } else {
        setState(() {
          _info = info;
          _state = _DetailsState.loaded;
        });
      }
    } on DtcRepositoryNotConfigured {
      if (!mounted) return;
      setState(() => _state = _DetailsState.notConfigured);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = '$error';
        _state = _DetailsState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final app = context.controller;
    final system = DtcSystem.fromCode(widget.code);
    final detectedInScan =
        app.dtcCodes.any((c) => c.toUpperCase() == widget.code.toUpperCase());

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.code.toUpperCase(),
            style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1)),
        actions: [
          IconButton(
            tooltip: 'إعادة تحميل المعلومات',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ترويسة الكود + النظام + مصدر الاكتشاف
            _HeaderCard(
              code: widget.code.toUpperCase(),
              system: system,
              detectedInScan: detectedInScan,
            ),
            const SizedBox(height: 16),

            // المحتوى الديناميكي حسب حالة تحميل بيانات الخدمة
            switch (_state) {
              _DetailsState.loading => const _LoadingCard(),
              _DetailsState.notConfigured => _NotConfiguredCard(
                  onRetry: _load,
                ),
              _DetailsState.loaded => _LoadedCards(info: _info!),
              _DetailsState.notFound => _NotFoundCard(code: widget.code),
              _DetailsState.error => _ErrorCard(
                  message: _errorText ?? 'خطأ غير معروف',
                  onRetry: _load,
                ),
            },
            const SizedBox(height: 16),

            // إخلاء مسؤولية ثابت — إجباري لعدم التشخيص القاطع من الكود
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(kRadiusSmall),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الأسباب المحتملة تحتاج فحصاً فعلياً لتأكيدها، وقد '
                      'تختلف تسميات ومعاني بعض الأكواد بحسب الشركة '
                      'الصانعة وطراز السيارة. لا تعتمد على الكود وحده '
                      'كقرار إصلاح نهائي.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.text,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ترويسة الشاشة
// ============================================================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.code,
    required this.system,
    required this.detectedInScan,
  });

  final String code;
  final DtcSystem system;
  final bool detectedInScan;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: 2,
                      color: AppColors.error,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'نسخ كود العطل',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم نسخ الكود $code')),
                    );
                  },
                  icon: Icon(Icons.copy_rounded,
                      size: 17, color: palette.textMuted),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        system.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detectedInScan
                            ? 'مُكتشف في آخر فحص فعلي'
                            : 'كود مُدخل يدوياً',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Icon(
                    system.icon,
                    size: 15,
                    color: palette.onPrimary,
                  ),
                  label: Text('النظام: ${system.displayName}'),
                  labelStyle: TextStyle(fontSize: 11.5, color: palette.text),
                ),
                const Chip(label: Text('الخطورة: غير متوفرة')),
                const Chip(label: Text('الحالة: غير متوفرة')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// حالات المحتوى
// ============================================================

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(
              'جارٍ استرجاع تفاصيل العطل...',
              style: TextStyle(fontSize: 13, color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// الحالة الأساسية اليوم: الخدمة لم تربَط بعد — نص وصفي واضح،
/// ومسار مستقبلي جاهز للتنفيذ بلا كود واجهة إضافي.
class _NotConfiguredCard extends StatelessWidget {
  const _NotConfiguredCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmptyState(
              compact: true,
              icon: Icons.cloud_off_rounded,
              title: 'بيانات العطل التفصيلية غير متوفرة بعد',
              message: 'الشرح والأسباب والأعراض تتطلب ربط خدمة معلومات '
                  'الأعطال (REST API). لم تُحدد تفاصيل الخدمة بعد، لذا لا '
                  'تُعرض أي بيانات مفترضة هنا.',
            ),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
            ),
            const SizedBox(height: 10),
            Text(
              'ما هو متاح الآن معرفياً: أول حرف من الكود (P المحرك/ناقل '
              'الحركة، C الشاسي، B الهيكل، U الشبكة) يحدد النظام '
              'المتأثر — وهو استنباط معياري دقيق لا يحتاج الإنترنت.',
              style: TextStyle(
                fontSize: 11,
                color: palette.textMuted,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundCard extends StatelessWidget {
  const _NotFoundCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            EmptyState(
              compact: true,
              icon: Icons.search_off_rounded,
              title: 'الكود غير موجود في قاعدة البيانات',
              message: 'لم تُرجع الخدمة معلومات للكود $code — قد يكون '
                  'خاصاً بمصنّع معين.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            EmptyState(
              compact: true,
              icon: Icons.cloud_off_rounded,
              title: 'فشل تحميل المعلومات',
              message: message,
              action: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقات التفاصيل الكاملة عند توفر بيانات الخدمة فعلاً.
class _LoadedCards extends StatelessWidget {
  const _LoadedCards({required this.info});

  final DtcInfo info;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final sections = <(String, IconData, List<String>)>[
      (
        'الشرح',
        Icons.menu_book_rounded,
        info.description == null ? [] : [info.description!]
      ),
      ('الأسباب المحتملة', Icons.help_outline_rounded, info.causes),
      ('الأعراض الشائعة', Icons.sick_rounded, info.symptoms),
      ('خطوات التشخيص الأولية', Icons.checklist_rounded, info.initialSteps),
      (
        'الإجراءات الموصى بها',
        Icons.build_circle_outlined,
        info.recommendedActions
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (info.name?.isNotEmpty ?? false) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                info.name!,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: palette.text,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        ...sections.where((s) => s.$3.isNotEmpty).map((s) {
          final (title, icon, items) = s;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle_rounded,
                          size: 6, color: palette.onPrimary),
                      const SizedBox(width: 8),
                      Text(title),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Icon(Icons.remove,
                                size: 10, color: palette.textMuted),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: palette.text,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (info.source?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'مصدر المعلومات: ${info.source}',
              style: TextStyle(fontSize: 10.5, color: palette.textMuted),
            ),
          ),
      ],
    );
  }
}
