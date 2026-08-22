import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class HistoryRepository {
  static const _storageKey = 'inspection_history_v1';

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

  Future<void> save(InspectionRecord record) async {
    final records = await load();
    records.insert(0, record);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, encodeHistory(records.take(100).toList()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
