class DailyWorship {
  final String id;
  final DateTime date;
  final Map<String, bool> worships;
  final String notes;
  final int prayerCount;
  final int quranPages;

  DailyWorship({
    required this.id,
    required this.date,
    required this.worships,
    this.notes = '',
    this.prayerCount = 0,
    this.quranPages = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'worships': worships,
      'notes': notes,
      'prayerCount': prayerCount,
      'quranPages': quranPages,
    };
  }

  factory DailyWorship.fromMap(Map<String, dynamic> map) {
    return DailyWorship(
      id: map['id'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      worships: Map<String, bool>.from(map['worships'] ?? {}),
      notes: map['notes'] ?? '',
      prayerCount: map['prayerCount'] ?? 0,
      quranPages: map['quranPages'] ?? 0,
    );
  }
}

class WorshipType {
  static const String fajr = 'الفجر';
  static const String dhuhr = 'الظهر';
  static const String asr = 'العصر';
  static const String maghrib = 'المغرب';
  static const String isha = 'العشاء';
  static const String morningRemembrance = 'أذكار الصباح';
  static const String eveningRemembrance = 'أذكار المساء';
  static const String quranRecitation = 'قراءة القرآن';
  static const String charity = 'الصدقة';
  static const String nightPrayer = 'قيام الليل';
  static const String fasting = 'الصيام';
  static const String taraweeh = 'التراويح';

  static List<String> get allTypes => [
    fajr,
    dhuhr,
    asr,
    maghrib,
    isha,
    morningRemembrance,
    eveningRemembrance,
    quranRecitation,
    charity,
    nightPrayer,
    fasting,
    taraweeh,
  ];

  static List<String> get dailyTypes => [
    fajr,
    dhuhr,
    asr,
    maghrib,
    isha,
    morningRemembrance,
    eveningRemembrance,
    quranRecitation,
    charity,
    nightPrayer,
  ];
}
