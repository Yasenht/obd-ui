import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class HistoryRepository {
  static const _storageKey = 'inspection_history_v1';

  /// سلسلة عمليات الحفظ — كل حفظ يقرأ ويكتب نفس المفتاح في
  /// SharedPreferences، وتشغيل حفظين متزامنين كان يقرأ كلاهما نفس
  /// القائمة فيلغي أحدهما سجل الآخر (read-modify-write race).
  Future<void> _saveQueue = Future.value();

  Future<List<InspectionRecord>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return <InspectionRecord>[];
    try {
      final records = decodeHistory(raw);
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return records;
    } catch (_) {
      return <InspectionRecord>[];
    }
  }

  Future<void> save(InspectionRecord record) {
    // إدراج العملية في طابور الحفظ بحيث لا تتداخل عمليتا قراءة-كتابة.
    final operation = _saveQueue.then((_) => _saveNow(record));
    // إبقاء الطابور حياً حتى لو فشلت عملية ما (بلا تسريب Unhandled).
    _saveQueue = operation.catchError((Object error, StackTrace stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'HistoryRepository',
          context: ErrorDescription('حفظ سجل الفحص'),
        ),
      );
    });
    return operation;
  }

  Future<void> _saveNow(InspectionRecord record) async {
    final records = await load();
    records.insert(0, record);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _storageKey, encodeHistory(records.take(100).toList()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
