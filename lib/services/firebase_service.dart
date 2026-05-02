import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/worship_model.dart';
import '../models/monthly_goal_model.dart';
import '../models/weekly_plan_model.dart';
import '../models/ramadan_model.dart';
import '../models/hajj_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  // ===== Daily Worship Methods =====
  Future<void> saveDailyWorship(String userId, DailyWorship worship) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('daily_worship')
          .doc(worship.id)
          .set(worship.toMap());
    } catch (e) {
      throw Exception('فشل حفظ العبادة اليومية: $e');
    }
  }

  Future<DailyWorship?> getDailyWorship(String userId, String worshipId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('daily_worship')
          .doc(worshipId)
          .get();

      if (doc.exists) {
        return DailyWorship.fromMap(doc.data() ?? {});
      }
      return null;
    } catch (e) {
      throw Exception('فشل جلب العبادة اليومية: $e');
    }
  }

  Future<List<DailyWorship>> getDailyWorshipByDate(String userId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final query = await _db
          .collection('users')
          .doc(userId)
          .collection('daily_worship')
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .get();

      return query.docs
          .map((doc) => DailyWorship.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('فشل جلب العبادات اليومية: $e');
    }
  }

  Future<List<DailyWorship>> getMonthlyWorships(String userId, int year, int month) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final query = await _db
          .collection('users')
          .doc(userId)
          .collection('daily_worship')
          .where('date', isGreaterThanOrEqualTo: startOfMonth.toIso8601String())
          .where('date', isLessThanOrEqualTo: endOfMonth.toIso8601String())
          .get();

      return query.docs
          .map((doc) => DailyWorship.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('فشل جلب عبادات الشهر: $e');
    }
  }

  // ===== Monthly Goal Methods =====
  Future<void> saveMonthlyGoal(String userId, MonthlyGoal goal) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('monthly_goals')
          .doc(goal.id)
          .set(goal.toMap());
    } catch (e) {
      throw Exception('فشل حفظ الهدف الشهري: $e');
    }
  }

  Future<MonthlyGoal?> getMonthlyGoal(String userId, String goalId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('monthly_goals')
          .doc(goalId)
          .get();

      if (doc.exists) {
        return MonthlyGoal.fromMap(doc.data() ?? {}, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('فشل جلب الهدف الشهري: $e');
    }
  }

  Future<List<MonthlyGoal>> getAllMonthlyGoals(String userId) async {
    try {
      final query = await _db
          .collection('users')
          .doc(userId)
          .collection('monthly_goals')
          .get();

      return query.docs
          .map((doc) => MonthlyGoal.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('فشل جلب الأهداف الشهرية: $e');
    }
  }

  Future<void> updateMonthlyGoalProgress(String userId, String goalId, int newValue) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('monthly_goals')
          .doc(goalId)
          .update({'currentValue': newValue});
    } catch (e) {
      throw Exception('فشل تحديث الهدف: $e');
    }
  }

  // ===== Weekly Plan Methods =====
  Future<void> saveWeeklyPlan(String userId, WeeklyPlan plan) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('weekly_plans')
          .doc(plan.id)
          .set(plan.toMap());
    } catch (e) {
      throw Exception('فشل حفظ الخطة الأسبوعية: $e');
    }
  }

  Future<WeeklyPlan?> getWeeklyPlan(String userId, String planId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('weekly_plans')
          .doc(planId)
          .get();

      if (doc.exists) {
        return WeeklyPlan.fromMap(doc.data() ?? {}, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('فشل جلب الخطة الأسبوعية: $e');
    }
  }

  Future<WeeklyPlan?> getCurrentWeeklyPlan(String userId) async {
    try {
      final query = await _db
          .collection('users')
          .doc(userId)
          .collection('weekly_plans')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return WeeklyPlan.fromMap(query.docs.first.data(), query.docs.first.id);
      }
      return null;
    } catch (e) {
      throw Exception('فشل جلب الخطة الأسبوعية الحالية: $e');
    }
  }

  // ===== Ramadan Methods =====
  Future<void> saveRamadanTracking(String userId, RamadanTracking tracking) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('ramadan')
          .doc(tracking.id)
          .set(tracking.toMap());
    } catch (e) {
      throw Exception('فشل حفظ بيانات رمضان: $e');
    }
  }

  Future<RamadanTracking?> getRamadanTracking(String userId, String trackingId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('ramadan')
          .doc(trackingId)
          .get();

      if (doc.exists) {
        return RamadanTracking.fromMap(doc.data() ?? {}, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('فشل جلب بيانات رمضان: $e');
    }
  }

  Future<void> updateRamadanDayRecord(
    String userId,
    String trackingId,
    RamadanDayRecord dayRecord,
  ) async {
    try {
      final tracking = await getRamadanTracking(userId, trackingId);
      if (tracking != null) {
        final updatedRecords = [...tracking.dayRecords];
        final index = updatedRecords.indexWhere((r) => r.dayNumber == dayRecord.dayNumber);
        if (index != -1) {
          updatedRecords[index] = dayRecord;
        } else {
          updatedRecords.add(dayRecord);
        }

        await _db
            .collection('users')
            .doc(userId)
            .collection('ramadan')
            .doc(trackingId)
            .update({'dayRecords': updatedRecords.map((r) => r.toMap()).toList()});
      }
    } catch (e) {
      throw Exception('فشل تحديث يوم رمضان: $e');
    }
  }

  // ===== Hajj Methods =====
  Future<void> saveHajjTracking(String userId, HajjTracking tracking) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('hajj')
          .doc(tracking.id)
          .set(tracking.toMap());
    } catch (e) {
      throw Exception('فشل حفظ بيانات الحج: $e');
    }
  }

  Future<HajjTracking?> getHajjTracking(String userId, String trackingId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('hajj')
          .doc(trackingId)
          .get();

      if (doc.exists) {
        return HajjTracking.fromMap(doc.data() ?? {}, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('فشل جلب بيانات الحج: $e');
    }
  }

  Future<void> updateHajjPillarStatus(
    String userId,
    String trackingId,
    String pillarName,
    bool isCompleted,
  ) async {
    try {
      final tracking = await getHajjTracking(userId, trackingId);
      if (tracking != null) {
        final updatedPillars = tracking.pillars
            .map((p) => p.name == pillarName ? p.copyWith(isCompleted: isCompleted) : p)
            .toList();

        await _db
            .collection('users')
            .doc(userId)
            .collection('hajj')
            .doc(trackingId)
            .update({'pillars': updatedPillars.map((p) => p.toMap()).toList()});
      }
    } catch (e) {
      throw Exception('فشل تحديث ركن الحج: $e');
    }
  }

  Future<void> addSupplication(
    String userId,
    String trackingId,
    SupplicationRecord supplication,
  ) async {
    try {
      final tracking = await getHajjTracking(userId, trackingId);
      if (tracking != null) {
        final updatedSupplications = [...tracking.supplications, supplication];

        await _db
            .collection('users')
            .doc(userId)
            .collection('hajj')
            .doc(trackingId)
            .update({'supplications': updatedSupplications.map((s) => s.toMap()).toList()});
      }
    } catch (e) {
      throw Exception('فشل حفظ الدعاء: $e');
    }
  }

  // ===== User Statistics =====
  Future<Map<String, dynamic>> getUserStatistics(String userId, DateTime date) async {
    try {
      final worships = await getDailyWorshipByDate(userId, date);
      final goals = await getAllMonthlyGoals(userId);

      int completedWorships = 0;
      for (var worship in worships) {
        completedWorships += worship.worships.values.where((v) => v).length;
      }

      return {
        'totalWorship': completedWorships,
        'completedGoals': goals.where((g) => g.isCompleted).length,
        'totalGoals': goals.length,
        'goalProgress': goals.isNotEmpty
            ? goals.fold(0.0, (sum, g) => sum + g.progress) / goals.length
            : 0.0,
      };
    } catch (e) {
      throw Exception('فشل جلب الإحصائيات: $e');
    }
  }
}
