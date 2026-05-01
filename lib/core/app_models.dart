// ─── Worship Types ────────────────────────────────────────────────
enum WorshipType { prayer, dhikr, quran, charity, fasting, qiyam }

extension WorshipTypeExt on WorshipType {
  String get label {
    switch (this) {
      case WorshipType.prayer:   return 'الصلوات الخمس';
      case WorshipType.dhikr:    return 'الأذكار';
      case WorshipType.quran:    return 'قراءة القرآن';
      case WorshipType.charity:  return 'الصدقة';
      case WorshipType.fasting:  return 'الصيام';
      case WorshipType.qiyam:    return 'قيام الليل';
    }
  }
  String get emoji {
    switch (this) {
      case WorshipType.prayer:   return '🕌';
      case WorshipType.dhikr:    return '📿';
      case WorshipType.quran:    return '📖';
      case WorshipType.charity:  return '💚';
      case WorshipType.fasting:  return '🌙';
      case WorshipType.qiyam:    return '⭐';
    }
  }
}

// ─── Worship Log ──────────────────────────────────────────────────
class WorshipLog {
  final WorshipType type;
  final DateTime date;
  final int value; // pages read / minutes / count
  final String? notes;
  final bool completed;

  const WorshipLog({
    required this.type,
    required this.date,
    this.value = 1,
    this.notes,
    this.completed = true,
  });
}

// ─── Goal ────────────────────────────────────────────────────────
class SpiritualGoal {
  final String title;
  final WorshipType type;
  final int targetValue;
  final int currentValue;
  final DateTime startDate;
  final DateTime endDate;

  const SpiritualGoal({
    required this.title,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.startDate,
    required this.endDate,
  });

  double get progress => (currentValue / targetValue).clamp(0.0, 1.0);
}
