import 'package:hive_flutter/hive_flutter.dart';
import '../models/worship_model.dart';
import '../models/monthly_goal_model.dart';
import '../models/weekly_plan_model.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();

  factory LocalStorageService() {
    return _instance;
  }

  LocalStorageService._internal();

  static const String _worshipBoxName = 'daily_worship';
  static const String _goalsBoxName = 'monthly_goals';
  static const String _plansBoxName = 'weekly_plans';
  static const String _userPrefsBoxName = 'user_preferences';

  Future<void> initializeHive() async {
    try {
      await Hive.initFlutter();
      await Hive.openBox<String>(_worshipBoxName);
      await Hive.openBox<String>(_goalsBoxName);
      await Hive.openBox<String>(_plansBoxName);
      await Hive.openBox<dynamic>(_userPrefsBoxName);
    } catch (e) {
      throw Exception('فشل في تهيئة قاعدة البيانات المحلية: $e');
    }
  }

  // ===== Daily Worship Cache =====
  Future<void> cacheDailyWorship(DailyWorship worship) async {
    try {
      final box = Hive.box<String>(_worshipBoxName);
      await box.put(worship.id, _serializeDailyWorship(worship));
    } catch (e) {
      throw Exception('فشل حفظ العبادة المحلية: $e');
    }
  }

  Future<DailyWorship?> getCachedDailyWorship(String worshipId) async {
    try {
      final box = Hive.box<String>(_worshipBoxName);
      final data = box.get(worshipId);
      if (data != null) {
        return _deserializeDailyWorship(data);
      }
      return null;
    } catch (e) {
      throw Exception('فشل جلب العبادة المحلية: $e');
    }
  }

  Future<List<DailyWorship>> getAllCachedDailyWorship() async {
    try {
      final box = Hive.box<String>(_worshipBoxName);
      return box.values
          .map((data) => _deserializeDailyWorship(data))
          .toList();
    } catch (e) {
      throw Exception('فشل جلب العبادات المحلية: $e');
    }
  }

  Future<void> clearCachedDailyWorship(String worshipId) async {
    try {
      final box = Hive.box<String>(_worshipBoxName);
      await box.delete(worshipId);
    } catch (e) {
      throw Exception('فشل حذف العبادة المحلية: $e');
    }
  }

  // ===== Monthly Goals Cache =====
  Future<void> cacheMonthlyGoal(MonthlyGoal goal) async {
    try {
      final box = Hive.box<String>(_goalsBoxName);
      await box.put(goal.id, _serializeMonthlyGoal(goal));
    } catch (e) {
      throw Exception('فشل حفظ الهدف المحلي: $e');
    }
  }

  Future<MonthlyGoal?> getCachedMonthlyGoal(String goalId) async {
    try {
      final box = Hive.box<String>(_goalsBoxName);
      final data = box.get(goalId);
      if (data != null) {
        return _deserializeMonthlyGoal(data);
      }
      return null;
    } catch (e) {
      throw Exception('فشل جلب الهدف المحلي: $e');
    }
  }

  Future<List<MonthlyGoal>> getAllCachedMonthlyGoals() async {
    try {
      final box = Hive.box<String>(_goalsBoxName);
      return box.values
          .map((data) => _deserializeMonthlyGoal(data))
          .toList();
    } catch (e) {
      throw Exception('فشل جلب الأهداف المحلية: $e');
    }
  }

  // ===== User Preferences =====
  Future<void> saveUserPreference(String key, dynamic value) async {
    try {
      final box = Hive.box<dynamic>(_userPrefsBoxName);
      await box.put(key, value);
    } catch (e) {
      throw Exception('فشل حفظ التفضيل: $e');
    }
  }

  Future<dynamic> getUserPreference(String key, {dynamic defaultValue}) async {
    try {
      final box = Hive.box<dynamic>(_userPrefsBoxName);
      return box.get(key, defaultValue: defaultValue);
    } catch (e) {
      throw Exception('فشل جلب التفضيل: $e');
    }
  }

  Future<void> clearAllCache() async {
    try {
      await Hive.box<String>(_worshipBoxName).clear();
      await Hive.box<String>(_goalsBoxName).clear();
      await Hive.box<String>(_plansBoxName).clear();
    } catch (e) {
      throw Exception('فشل مسح الذاكرة المحلية: $e');
    }
  }

  // ===== Serialization Helpers =====
  String _serializeDailyWorship(DailyWorship worship) {
    return '${worship.id}|${worship.date.toIso8601String()}|${worship.worships.entries.map((e) => '${e.key}:${e.value}').join(',')}|${worship.notes}';
  }

  DailyWorship _deserializeDailyWorship(String data) {
    final parts = data.split('|');
    final id = parts[0];
    final date = DateTime.parse(parts[1]);
    final worshipPairs = parts[2].split(',');
    final worships = <String, bool>{};
    for (var pair in worshipPairs) {
      if (pair.contains(':')) {
        final split = pair.split(':');
        worships[split[0]] = split[1] == 'true';
      }
    }
    final notes = parts.length > 3 ? parts[3] : '';

    return DailyWorship(
      id: id,
      date: date,
      worships: worships,
      notes: notes,
    );
  }

  String _serializeMonthlyGoal(MonthlyGoal goal) {
    return '${goal.id}|${goal.goalTitle}|${goal.currentValue}|${goal.targetValue}|${goal.isCompleted}|${goal.category}';
  }

  MonthlyGoal _deserializeMonthlyGoal(String data) {
    final parts = data.split('|');
    return MonthlyGoal(
      id: parts[0],
      userId: '',
      goalTitle: parts[1],
      goalDescription: '',
      targetValue: int.parse(parts[3]),
      currentValue: int.parse(parts[2]),
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 30)),
      isCompleted: parts[4] == 'true',
      category: parts[5],
    );
  }
}
