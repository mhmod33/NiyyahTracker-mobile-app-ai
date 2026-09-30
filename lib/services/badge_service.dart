import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge_model.dart';

/// All badge definitions in the app.
/// Mirrors the Arabic app shown in the screenshots.
class BadgeCatalogue {
  BadgeCatalogue._();

  static const List<BadgeDefinition> all = [
    // ── Prayer badges ──────────────────────────────────────────────
    BadgeDefinition(
      id: 'prayer_first_10',
      title: 'أول عشرة أنوار',
      description: 'سجّلت أول 10 صلوات. بداية صغيرة، لكنها خطوة حقيقية.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.prayer,
      target: 10,
    ),
    BadgeDefinition(
      id: 'prayer_3_days_complete',
      title: 'ثلاثة أيام كاملة',
      description: 'أكملت صلواتك في 3 أيام. أنت أن اليوم الكامل ممكن.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.prayer,
      target: 3,
    ),
    BadgeDefinition(
      id: 'prayer_7_days',
      title: 'أسبوع من الحضور',
      description: 'أكملت صلواتك في 7 أيام. أسبوع كامل من الحضور والثبات.',
      level: BadgeLevel.silver,
      category: BadgeCategory.prayer,
      target: 7,
    ),
    BadgeDefinition(
      id: 'prayer_10_days',
      title: 'عشرة أيام مكتملة',
      description: 'أكملت صلواتك في 10 أيام. ثباتك بدأ يظهر بوضوح.',
      level: BadgeLevel.silver,
      category: BadgeCategory.prayer,
      target: 10,
    ),
    BadgeDefinition(
      id: 'prayer_streak_3',
      title: 'شرارة الثلاثة',
      description: 'بنيت سلسلة 3 أيام. اشتعلت الشرارة، حافظ عليها.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.prayer,
      target: 3,
    ),
    BadgeDefinition(
      id: 'prayer_streak_10',
      title: 'شعلة العشرة',
      description: 'بنيت سلسلة 10 أيام. أنت ثابت أن الثبات قرار يومي.',
      level: BadgeLevel.silver,
      category: BadgeCategory.prayer,
      target: 10,
    ),
    BadgeDefinition(
      id: 'prayer_no_miss_3',
      title: 'بداية بلا تفويت',
      description: 'مرّت 3 أيام بلا تفويت صلاة. حافظ على هذه البداية الجميلة.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.prayer,
      target: 3,
    ),
    BadgeDefinition(
      id: 'prayer_no_miss_10',
      title: 'عشرة لا تنقطع',
      description: 'مرّت 10 أيام بلا تفويت صلاة. انضباطك يزداد قوة.',
      level: BadgeLevel.silver,
      category: BadgeCategory.prayer,
      target: 10,
    ),
    BadgeDefinition(
      id: 'prayer_no_miss_50',
      title: 'خمسون بلا انقطاع',
      description: 'مرّت 50 يومًا بلا تفويت صلاة. هذا الالتزام حقيقي.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 50,
    ),
    BadgeDefinition(
      id: 'prayer_no_miss_100',
      title: 'مئة بلا انقطاع',
      description: 'مرّت 100 يوم بلا تفويت صلاة. حوّلت النية إلى معيار قوي.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 100,
    ),
    BadgeDefinition(
      id: 'prayer_30_days',
      title: 'ثلاثون يومًا كاملًا',
      description: 'أكملت صلواتك في 30 يومًا في شهر واحد.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 30,
    ),
    BadgeDefinition(
      id: 'prayer_100_days',
      title: 'مئة يوم مكتملة',
      description: 'أكملت صلواتك في 100 يوم. هذا هو الثبات الذي يغيّر الحياة.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 100,
    ),
    BadgeDefinition(
      id: 'prayer_250',
      title: 'جذور راسخة',
      description: 'سجّلت 250 صلاة. ما بدأ كمجاهدة صار جزءًا من حياتك.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 250,
    ),
    BadgeDefinition(
      id: 'prayer_1000',
      title: 'ألف وصلة',
      description: 'سجّلت 1000 صلاة. ألف فرصة اخترت فيها الرجوع والثبات.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 1000,
    ),
    BadgeDefinition(
      id: 'prayer_2000',
      title: 'إرث الصلاة',
      description: 'سجّلت 2000 صلاة. لم تعد مجرد سلسلة، بل إرث تتبع نبيه ﷺ.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 2000,
    ),
    BadgeDefinition(
      id: 'prayer_streak_50',
      title: 'جنة الخمسين',
      description: 'بنيت سلسلة 50 يومًا. زخمك أصبح واضحًا وقويًا.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 50,
    ),
    BadgeDefinition(
      id: 'prayer_streak_90',
      title: 'تسعون يومًا محفوظة',
      description: 'مرّت 90 يومًا بلا تفويت صلاة. فصل كامل من الحفظ والمجاهدة.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 90,
    ),
    BadgeDefinition(
      id: 'prayer_streak_100',
      title: 'معيار المئة',
      description: 'بنيت سلسلة 100 يوم. بنيت معيارًا سيشكرك عليه مستقبلك.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 100,
    ),

    // ── Fajr badges ────────────────────────────────────────────────
    BadgeDefinition(
      id: 'fajr_10',
      title: 'يقظة الفجر',
      description: 'حافظت على الفجر 10 أيام. أنت تنتصر في أول معركة من اليوم.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.prayer,
      target: 10,
    ),
    BadgeDefinition(
      id: 'fajr_50',
      title: 'حارس الفجر',
      description: 'حافظت على الفجر 50 يومًا. صار الصباح الباكر يعرف خطاك.',
      level: BadgeLevel.silver,
      category: BadgeCategory.prayer,
      target: 50,
    ),
    BadgeDefinition(
      id: 'fajr_100',
      title: 'بطل الفجر',
      description: 'حافظت على الفجر 100 يوم. بنيت قوّتك قبل أن يستيقظ العالم.',
      level: BadgeLevel.gold,
      category: BadgeCategory.prayer,
      target: 100,
    ),

    // ── Azkar badges ───────────────────────────────────────────────
    BadgeDefinition(
      id: 'azkar_morning_3',
      title: 'درع الصباح',
      description: 'أتممت أذكار الصباح 3 مرات. بدأت يومك بالذكر والحفظ.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.azkar,
      target: 3,
    ),
    BadgeDefinition(
      id: 'azkar_morning_50',
      title: 'خمسون صباحًا مضيئًا',
      description: 'أتممت أذكار الصباح 50 مرة. أنت تدرّب صباحك أن يبدأ بمعنى.',
      level: BadgeLevel.silver,
      category: BadgeCategory.azkar,
      target: 50,
    ),
    BadgeDefinition(
      id: 'azkar_morning_100',
      title: 'مئة صباح محفوظ',
      description: 'أتممت أذكار الصباح مئة مرة. مئة صباح بدأ بالذكر.',
      level: BadgeLevel.gold,
      category: BadgeCategory.azkar,
      target: 100,
    ),
    BadgeDefinition(
      id: 'azkar_evening_3',
      title: 'سكينة المساء',
      description: 'أتممت أذكار المساء 3 مرات. أنهيت يومك بالذكر والسكينة.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.azkar,
      target: 3,
    ),
    BadgeDefinition(
      id: 'azkar_evening_50',
      title: 'خمسون مساءً هادئًا',
      description: 'أتممت أذكار المساء 50 مرة. تتعلم أن تختم يومك بالطمأنينة.',
      level: BadgeLevel.silver,
      category: BadgeCategory.azkar,
      target: 50,
    ),
    BadgeDefinition(
      id: 'azkar_evening_100',
      title: 'مئة ليلة مطمئنة',
      description: 'أتممت أذكار المساء 100 مرة. مئة ليلة أحاطها الذكر.',
      level: BadgeLevel.gold,
      category: BadgeCategory.azkar,
      target: 100,
    ),

    // ── Fasting badges ─────────────────────────────────────────────
    BadgeDefinition(
      id: 'fasting_5',
      title: 'خمس صيامات من السنة',
      description: 'صمت خمسة أيام من اثنين أو خميس. سنة جميلة بدأت تتّح.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.fasting,
      target: 5,
    ),
    BadgeDefinition(
      id: 'fasting_25',
      title: 'ثبات على السنة',
      description: 'صمت 25 يومًا اثنين أو خميس. تحب النبي ﷺ وتحب سنة صيامه.',
      level: BadgeLevel.silver,
      category: BadgeCategory.fasting,
      target: 25,
    ),
    BadgeDefinition(
      id: 'fasting_100',
      title: 'مئة صيام من السنة',
      description: 'صمت 100 يوم اثنين أو خميس. سنّتان كاملتان من الثبات.',
      level: BadgeLevel.gold,
      category: BadgeCategory.fasting,
      target: 100,
    ),
    BadgeDefinition(
      id: 'fasting_ayyam_beed',
      title: 'أول الأيام البيض',
      description: 'صمت الأيام البيض الثلاثة الأولى من شهر هجري. بداية جميلة.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.fasting,
      target: 3,
    ),
    BadgeDefinition(
      id: 'fasting_ayyam_beed_10',
      title: 'خمسة أشهر من الأيام',
      description: 'صمت خمسة عشر يومًا من الأيام البيض. خمسة أشهر من الثبات.',
      level: BadgeLevel.silver,
      category: BadgeCategory.fasting,
      target: 15,
    ),
    BadgeDefinition(
      id: 'fasting_ayyam_beed_30',
      title: 'عشرة أشهر من النور',
      description: 'صمت ثلاثين يومًا من الأيام البيض. عشرة أشهر من الليالي.',
      level: BadgeLevel.gold,
      category: BadgeCategory.fasting,
      target: 30,
    ),

    // ── Quran / Wird badges ────────────────────────────────────────
    BadgeDefinition(
      id: 'quran_100_pages',
      title: 'أول مئة صفحة',
      description: 'قرأت 100 صفحة من القرآن. كل صفحة كانت اقترابًا من الله.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.quran,
      target: 100,
    ),
    BadgeDefinition(
      id: 'quran_khatma',
      title: 'ختمة كاملة',
      description: 'قرأت كامل المصحف 604 صفحة. ختمة أولى في رحلتك.',
      level: BadgeLevel.gold,
      category: BadgeCategory.quran,
      target: 604,
    ),
    BadgeDefinition(
      id: 'quran_5_khatmas',
      title: 'صاحب القرآن',
      description: 'قرأت 3020 صفحة — خمس ختمات. رفيقك في كل حال هو القرآن.',
      level: BadgeLevel.gold,
      category: BadgeCategory.quran,
      target: 3020,
    ),
    BadgeDefinition(
      id: 'wird_streak_3',
      title: 'ثلاثة أيام بالورد',
      description: 'حافظت على وردك القرآني 3 أيام متتالية.',
      level: BadgeLevel.bronze,
      category: BadgeCategory.wird,
      target: 3,
    ),
    BadgeDefinition(
      id: 'wird_streak_10',
      title: 'عشرة بالورد',
      description: 'حافظت على وردك القرآني 10 أيام متتالية.',
      level: BadgeLevel.silver,
      category: BadgeCategory.wird,
      target: 10,
    ),
    BadgeDefinition(
      id: 'wird_streak_30',
      title: 'شهر بالورد',
      description: 'حافظت على وردك القرآني 30 يومًا متتالية.',
      level: BadgeLevel.gold,
      category: BadgeCategory.wird,
      target: 30,
    ),
  ];

  static BadgeDefinition? findById(String id) {
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Manages reading and writing user badge progress from/to Firestore.
class BadgeService {
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Firestore helpers ─────────────────────────────────────────────────────

  CollectionReference _badgesCol(String userId) =>
      _db.collection('users').doc(userId).collection('badges');

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Fetches all badge progress records for [userId].
  Future<List<UserBadge>> getUserBadges(String userId) async {
    try {
      final snap = await _badgesCol(userId).get();
      return snap.docs
          .map((d) => UserBadge.fromMap(d.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('❌ getUserBadges error: $e', name: 'BadgeService');
      return [];
    }
  }

  /// Returns a map of badgeId → UserBadge for fast lookup.
  Future<Map<String, UserBadge>> getUserBadgesMap(String userId) async {
    final list = await getUserBadges(userId);
    return {for (final b in list) b.badgeId: b};
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> _saveBadge(String userId, UserBadge badge) async {
    try {
      await _badgesCol(userId).doc(badge.badgeId).set(badge.toMap());
    } catch (e) {
      developer.log('❌ _saveBadge error: $e', name: 'BadgeService');
    }
  }

  // ── Evaluation ────────────────────────────────────────────────────────────

  /// Evaluates all badge criteria against [stats] and persists any changes.
  /// Returns badges that were *newly* earned in this call.
  Future<List<BadgeDefinition>> evaluateAndUpdate({
    required String userId,
    required BadgeStats stats,
  }) async {
    final existing = await getUserBadgesMap(userId);
    final newlyEarned = <BadgeDefinition>[];

    for (final def in BadgeCatalogue.all) {
      final progress = _computeProgress(def, stats);
      final prev = existing[def.id];
      final alreadyEarned = prev?.isEarned ?? false;

      final earned = progress >= def.target;
      final updated = UserBadge(
        badgeId: def.id,
        userId: userId,
        isEarned: earned,
        earnedAt: earned ? (prev?.earnedAt ?? (alreadyEarned ? null : DateTime.now())) : null,
        currentProgress: progress,
      );

      // Only write to Firestore if something changed
      final changed = prev == null ||
          prev.isEarned != earned ||
          prev.currentProgress != progress;

      if (changed) {
        await _saveBadge(userId, updated);
        if (earned && !alreadyEarned) {
          newlyEarned.add(def);
        }
      }
    }

    developer.log('✅ Badges evaluated. Newly earned: ${newlyEarned.length}',
        name: 'BadgeService');
    return newlyEarned;
  }

  /// Computes current progress for a single badge definition given [stats].
  int _computeProgress(BadgeDefinition def, BadgeStats stats) {
    switch (def.id) {
      // Prayer totals
      case 'prayer_first_10':
      case 'prayer_250':
      case 'prayer_1000':
      case 'prayer_2000':
        return stats.totalPrayers;

      // Completed prayer days (all 5 prayers)
      case 'prayer_3_days_complete':
      case 'prayer_7_days':
      case 'prayer_10_days':
      case 'prayer_30_days':
      case 'prayer_100_days':
        return stats.completedPrayerDays;

      // Prayer streak (consecutive complete days)
      case 'prayer_streak_3':
      case 'prayer_streak_10':
      case 'prayer_streak_50':
      case 'prayer_streak_90':
      case 'prayer_streak_100':
        return stats.prayerStreak;

      // No-miss days (any prayer logged)
      case 'prayer_no_miss_3':
      case 'prayer_no_miss_10':
      case 'prayer_no_miss_50':
      case 'prayer_no_miss_100':
        return stats.noMissDays;

      // Fajr streaks / counts
      case 'fajr_10':
      case 'fajr_50':
      case 'fajr_100':
        return stats.fajrDays;

      // Azkar
      case 'azkar_morning_3':
      case 'azkar_morning_50':
      case 'azkar_morning_100':
        return stats.morningAzkarCount;

      case 'azkar_evening_3':
      case 'azkar_evening_50':
      case 'azkar_evening_100':
        return stats.eveningAzkarCount;

      // Fasting
      case 'fasting_5':
      case 'fasting_25':
      case 'fasting_100':
        return stats.fastingDays;

      case 'fasting_ayyam_beed':
      case 'fasting_ayyam_beed_10':
      case 'fasting_ayyam_beed_30':
        return stats.ayyamBeedDays;

      // Quran pages
      case 'quran_100_pages':
      case 'quran_khatma':
      case 'quran_5_khatmas':
        return stats.quranPagesTotal;

      // Wird streaks
      case 'wird_streak_3':
      case 'wird_streak_10':
      case 'wird_streak_30':
        return stats.wirdStreak;

      default:
        return 0;
    }
  }

  /// Finds the single badge the user is closest to earning next.
  BadgeDefinition? getClosestUnearned(
    Map<String, UserBadge> userBadges,
    BadgeStats stats,
  ) {
    BadgeDefinition? closest;
    double bestRatio = -1;

    for (final def in BadgeCatalogue.all) {
      final ub = userBadges[def.id];
      if (ub?.isEarned == true) continue;

      final progress = _computeProgress(def, stats);
      final ratio = progress / def.target;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        closest = def;
      }
    }

    return closest;
  }
}

/// A snapshot of a user's worship statistics used for badge evaluation.
/// Collect once and pass to [BadgeService.evaluateAndUpdate].
class BadgeStats {
  final int totalPrayers;
  final int completedPrayerDays;
  final int prayerStreak;
  final int noMissDays;
  final int fajrDays;
  final int morningAzkarCount;
  final int eveningAzkarCount;
  final int fastingDays;
  final int ayyamBeedDays;
  final int quranPagesTotal;
  final int wirdStreak;

  const BadgeStats({
    this.totalPrayers = 0,
    this.completedPrayerDays = 0,
    this.prayerStreak = 0,
    this.noMissDays = 0,
    this.fajrDays = 0,
    this.morningAzkarCount = 0,
    this.eveningAzkarCount = 0,
    this.fastingDays = 0,
    this.ayyamBeedDays = 0,
    this.quranPagesTotal = 0,
    this.wirdStreak = 0,
  });
}
