import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Tracking Mode ────────────────────────────────────────────────────────────
enum DawriTrackingMode {
  basic,   // prayers only (الأساسي - فروض فقط)
  custom,  // prayers + selected extras (مخصص)
}

// ─── Extra Activities That Can Be Tracked ─────────────────────────────────────
class DawriExtraActivity {
  final String id;
  final String nameAr;
  final String description;
  final String icon;
  final int pointsPerUnit;

  const DawriExtraActivity({
    required this.id,
    required this.nameAr,
    required this.description,
    required this.icon,
    required this.pointsPerUnit,
  });

  static const sunanRawatib = DawriExtraActivity(
    id: 'sunan_rawatib',
    nameAr: 'السنن الرواتب',
    description: '5 نقاط عن كل سنة راتبة تسجّل.',
    icon: '🕌',
    pointsPerUnit: 5,
  );

  static const fastingMonThur = DawriExtraActivity(
    id: 'fasting_mon_thu',
    nameAr: 'صيام الاثنين والخميس',
    description: '10 نقاط لكل يوم اثنين أو خميس صائم.',
    icon: '🌙',
    pointsPerUnit: 10,
  );

  static const fastingWhiteDays = DawriExtraActivity(
    id: 'fasting_white_days',
    nameAr: 'صيام الأيام البيض (13/14/15)',
    description: '10 نقاط لصيام الأيام البيض من كل شهر هجري.',
    icon: '🌕',
    pointsPerUnit: 10,
  );

  static const quranReading = DawriExtraActivity(
    id: 'quran_reading',
    nameAr: 'قراءة القرآن',
    description: 'نقطة عن كل صفحة قراءة في مصحف التطبيق.',
    icon: '📖',
    pointsPerUnit: 1,
  );

  static const azkar = DawriExtraActivity(
    id: 'azkar',
    nameAr: 'أذكار الصباح والمساء',
    description: 'نقطتان عن كل جلسة أذكار تُتقنها (الصباح والمساء).',
    icon: '📿',
    pointsPerUnit: 2,
  );

  static const qiyamAlLayl = DawriExtraActivity(
    id: 'qiyam_al_layl',
    nameAr: 'قيام الليل',
    description: 'نقطة واحدة لكل ركعة قيام مسجّلة.',
    icon: '⭐',
    pointsPerUnit: 1,
  );

  static List<DawriExtraActivity> get all => [
        sunanRawatib,
        fastingMonThur,
        fastingWhiteDays,
        quranReading,
        azkar,
        qiyamAlLayl,
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'nameAr': nameAr,
        'description': description,
        'icon': icon,
        'pointsPerUnit': pointsPerUnit,
      };
}

// ─── Prayer Log Status ────────────────────────────────────────────────────────
enum PrayerStatus {
  onTime,       // في الوقت  (+10 pts)
  congregation, // في جماعة  (+13 pts)
  mosque,       // في المسجد (+15 pts)
  qada,         // قضاء      (+3 pts)
  missed,       // فائتة     (0 pts)
  notLogged,    // لم يُسجل  (0 pts)
}

extension PrayerStatusExt on PrayerStatus {
  String get labelAr {
    switch (this) {
      case PrayerStatus.onTime:       return 'في الوقت';
      case PrayerStatus.congregation: return 'في جماعة';
      case PrayerStatus.mosque:       return 'في المسجد';
      case PrayerStatus.qada:         return 'قضاء';
      case PrayerStatus.missed:       return 'فائتة';
      case PrayerStatus.notLogged:    return '—';
    }
  }

  int get points {
    switch (this) {
      case PrayerStatus.onTime:       return 10;
      case PrayerStatus.congregation: return 13;
      case PrayerStatus.mosque:       return 15;
      case PrayerStatus.qada:         return 3;
      case PrayerStatus.missed:       return 0;
      case PrayerStatus.notLogged:    return 0;
    }
  }

  String get id {
    switch (this) {
      case PrayerStatus.onTime:       return 'on_time';
      case PrayerStatus.congregation: return 'congregation';
      case PrayerStatus.mosque:       return 'mosque';
      case PrayerStatus.qada:         return 'qada';
      case PrayerStatus.missed:       return 'missed';
      case PrayerStatus.notLogged:    return 'not_logged';
    }
  }

  static PrayerStatus fromId(String? id) {
    switch (id) {
      case 'on_time':       return PrayerStatus.onTime;
      case 'congregation':  return PrayerStatus.congregation;
      case 'mosque':        return PrayerStatus.mosque;
      case 'qada':          return PrayerStatus.qada;
      case 'missed':        return PrayerStatus.missed;
      default:              return PrayerStatus.notLogged;
    }
  }
}

// ─── Prayer Names ─────────────────────────────────────────────────────────────
class DawriPrayer {
  static const String fajr    = 'fajr';
  static const String dhuhr   = 'dhuhr';
  static const String asr     = 'asr';
  static const String maghrib = 'maghrib';
  static const String isha    = 'isha';

  static const List<String> all = [fajr, dhuhr, asr, maghrib, isha];

  static String labelAr(String p) {
    switch (p) {
      case fajr:    return 'الفجر';
      case dhuhr:   return 'الظهر';
      case asr:     return 'العصر';
      case maghrib: return 'المغرب';
      case isha:    return 'العشاء';
      default:      return p;
    }
  }

  static String shortLabelAr(String p) {
    switch (p) {
      case fajr:    return 'فجر';
      case dhuhr:   return 'ظهر';
      case asr:     return 'عصر';
      case maghrib: return 'مغرب';
      case isha:    return 'عشاء';
      default:      return p;
    }
  }
}

// ─── Daily Entry for a member in the league ───────────────────────────────────
class DawriDayEntry {
  final String date; // yyyy-MM-dd
  final Map<String, PrayerStatus> prayers; // prayer id -> status
  // Extra activities: activityId -> count (units done)
  final Map<String, int> extras;
  final int totalPoints;
  // Streak metadata per prayer (days in row at mosque for the badge)
  final Map<String, int> prayerStreaks;

  const DawriDayEntry({
    required this.date,
    required this.prayers,
    this.extras = const {},
    required this.totalPoints,
    this.prayerStreaks = const {},
  });

  factory DawriDayEntry.empty(String date) => DawriDayEntry(
        date: date,
        prayers: {},
        extras: {},
        totalPoints: 0,
        prayerStreaks: {},
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'prayers': prayers.map((k, v) => MapEntry(k, v.id)),
        'extras': extras,
        'totalPoints': totalPoints,
        'prayerStreaks': prayerStreaks,
      };

  factory DawriDayEntry.fromJson(Map<String, dynamic> json) => DawriDayEntry(
        date: json['date'] as String? ?? '',
        prayers: (json['prayers'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, PrayerStatusExt.fromId(v as String?)),
        ),
        extras: Map<String, int>.from(json['extras'] as Map? ?? {}),
        totalPoints: json['totalPoints'] as int? ?? 0,
        prayerStreaks:
            Map<String, int>.from(json['prayerStreaks'] as Map? ?? {}),
      );
}

// ─── Member in the league ─────────────────────────────────────────────────────
class DawriMember {
  final String userId;
  final String name;
  final bool isSupervisor;
  final int totalPoints;
  final int currentStreak;   // consecutive days
  final int missedToday;     // prayers missed today
  final int onTimeToday;     // prayers on time today
  final DateTime joinedAt;
  // Today's prayer statuses
  final Map<String, PrayerStatus> todayPrayers;
  // Activity bits for today
  final Map<String, int> todayExtras;
  // Badges earned
  final List<String> badges;

  const DawriMember({
    required this.userId,
    required this.name,
    this.isSupervisor = false,
    this.totalPoints = 0,
    this.currentStreak = 0,
    this.missedToday = 0,
    this.onTimeToday = 0,
    required this.joinedAt,
    this.todayPrayers = const {},
    this.todayExtras = const {},
    this.badges = const [],
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'isSupervisor': isSupervisor,
        'totalPoints': totalPoints,
        'currentStreak': currentStreak,
        'missedToday': missedToday,
        'onTimeToday': onTimeToday,
        'joinedAt': Timestamp.fromDate(joinedAt),
        'todayPrayers': todayPrayers.map((k, v) => MapEntry(k, v.id)),
        'todayExtras': todayExtras,
        'badges': badges,
      };

  factory DawriMember.fromJson(Map<String, dynamic> json) => DawriMember(
        userId: json['userId'] as String? ?? '',
        name: json['name'] as String? ?? 'مستخدم',
        isSupervisor: json['isSupervisor'] as bool? ?? false,
        totalPoints: json['totalPoints'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        missedToday: json['missedToday'] as int? ?? 0,
        onTimeToday: json['onTimeToday'] as int? ?? 0,
        joinedAt:
            (json['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        todayPrayers:
            (json['todayPrayers'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, PrayerStatusExt.fromId(v as String?)),
        ),
        todayExtras:
            Map<String, int>.from(json['todayExtras'] as Map? ?? {}),
        badges: List<String>.from(json['badges'] as List? ?? []),
      );

  DawriMember copyWith({
    int? totalPoints,
    int? currentStreak,
    int? missedToday,
    int? onTimeToday,
    Map<String, PrayerStatus>? todayPrayers,
    Map<String, int>? todayExtras,
    List<String>? badges,
  }) =>
      DawriMember(
        userId: userId,
        name: name,
        isSupervisor: isSupervisor,
        totalPoints: totalPoints ?? this.totalPoints,
        currentStreak: currentStreak ?? this.currentStreak,
        missedToday: missedToday ?? this.missedToday,
        onTimeToday: onTimeToday ?? this.onTimeToday,
        joinedAt: joinedAt,
        todayPrayers: todayPrayers ?? this.todayPrayers,
        todayExtras: todayExtras ?? this.todayExtras,
        badges: badges ?? this.badges,
      );
}

// ─── League Model ─────────────────────────────────────────────────────────────
class Dawri {
  final String id;
  final String name;
  final String description;
  final DawriTrackingMode trackingMode;
  final String supervisorId;
  final List<String> memberIds;
  final List<DawriMember> members;
  final String inviteCode;
  final List<String> selectedActivityIds; // for custom mode
  final DateTime createdAt;
  final DateTime startDate;
  // End date: one week from start (auto-renewing)
  final DateTime endDate;
  final bool isActive;

  const Dawri({
    required this.id,
    required this.name,
    this.description = '',
    this.trackingMode = DawriTrackingMode.basic,
    required this.supervisorId,
    this.memberIds = const [],
    this.members = const [],
    required this.inviteCode,
    this.selectedActivityIds = const [],
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  bool isSupervisor(String userId) => supervisorId == userId;
  bool isMember(String userId) => memberIds.contains(userId);

  String get trackingModeLabel {
    switch (trackingMode) {
      case DawriTrackingMode.basic:  return 'أساسي (فروض فقط)';
      case DawriTrackingMode.custom: return 'مخصص';
    }
  }

  /// Return the list of extra activities active in this league
  List<DawriExtraActivity> get activeExtras => DawriExtraActivity.all
      .where((a) => selectedActivityIds.contains(a.id))
      .toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'trackingMode': trackingMode == DawriTrackingMode.custom ? 'custom' : 'basic',
        'supervisorId': supervisorId,
        'memberIds': memberIds,
        'inviteCode': inviteCode,
        'selectedActivityIds': selectedActivityIds,
        'createdAt': Timestamp.fromDate(createdAt),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'isActive': isActive,
      };

  factory Dawri.fromJson(Map<String, dynamic> json, String docId) => Dawri(
        id: docId,
        name: json['name'] as String? ?? 'دوري',
        description: json['description'] as String? ?? '',
        trackingMode: (json['trackingMode'] as String?) == 'custom'
            ? DawriTrackingMode.custom
            : DawriTrackingMode.basic,
        supervisorId: json['supervisorId'] as String? ?? '',
        memberIds: List<String>.from(json['memberIds'] as List? ?? []),
        members: (json['members'] as List<dynamic>? ?? [])
            .map((m) => DawriMember.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
        inviteCode: json['inviteCode'] as String? ?? '',
        selectedActivityIds:
            List<String>.from(json['selectedActivityIds'] as List? ?? []),
        createdAt:
            (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        startDate:
            (json['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endDate: (json['endDate'] as Timestamp?)?.toDate() ??
            DateTime.now().add(const Duration(days: 7)),
        isActive: json['isActive'] as bool? ?? true,
      );
}

// ─── Weekly Points Aggregation per member ─────────────────────────────────────
class DawriMemberWeekStats {
  final String userId;
  final String name;
  final int rank;
  final int weekPoints;
  final int totalPoints;
  final int streak;
  final int missedCount;
  final int onTimeCount;
  final Map<String, PrayerStatus> todayPrayers;
  final Map<String, int> todayExtras;
  final bool isSupervisor;
  final List<String> badges;

  const DawriMemberWeekStats({
    required this.userId,
    required this.name,
    required this.rank,
    required this.weekPoints,
    required this.totalPoints,
    required this.streak,
    required this.missedCount,
    required this.onTimeCount,
    required this.todayPrayers,
    this.todayExtras = const {},
    this.isSupervisor = false,
    this.badges = const [],
  });
}
