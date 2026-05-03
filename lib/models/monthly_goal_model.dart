import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyGoal {
  final String id;
  final String userId;
  final String goalTitle;
  final String goalDescription;
  final int targetValue;
  final int currentValue;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCompleted;
  final String category;
  final String? customCategoryLabel;

  MonthlyGoal({
    required this.id,
    required this.userId,
    required this.goalTitle,
    required this.goalDescription,
    required this.targetValue,
    this.currentValue = 0,
    required this.startDate,
    required this.endDate,
    this.isCompleted = false,
    this.category = 'quran',
    this.customCategoryLabel,
  });

  double get progress => targetValue > 0 ? currentValue / targetValue : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'goalTitle': goalTitle,
      'goalDescription': goalDescription,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isCompleted': isCompleted,
      'category': category,
      'customCategoryLabel': customCategoryLabel,
    };
  }

  factory MonthlyGoal.fromMap(Map<String, dynamic> map, String docId) {
    return MonthlyGoal(
      id: docId,
      userId: map['userId'] ?? '',
      goalTitle: map['goalTitle'] ?? '',
      goalDescription: map['goalDescription'] ?? '',
      targetValue: map['targetValue'] ?? 0,
      currentValue: map['currentValue'] ?? 0,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 30)),
      isCompleted: map['isCompleted'] ?? false,
      category: map['category'] ?? 'quran',
      customCategoryLabel: map['customCategoryLabel'],
    );
  }

  MonthlyGoal copyWith({
    String? goalTitle,
    String? goalDescription,
    int? currentValue,
    bool? isCompleted,
    String? customCategoryLabel,
  }) {
    return MonthlyGoal(
      id: id,
      userId: userId,
      goalTitle: goalTitle ?? this.goalTitle,
      goalDescription: goalDescription ?? this.goalDescription,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      startDate: startDate,
      endDate: endDate,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category,
      customCategoryLabel: customCategoryLabel ?? this.customCategoryLabel,
    );
  }
}

class GoalCategory {
  static const String quran = 'quran';
  static const String fajr = 'fajr';
  static const String charity = 'charity';
  static const String fastingDays = 'fastingDays';
  static const String nightPrayer = 'nightPrayer';
  static const String memorization = 'memorization';
  static const String custom = 'custom';

  static Map<String, String> categoryLabels = {
    quran: 'ختم القرآن الكريم',
    fajr: 'صلاة الفجر يومياً',
    charity: 'الصدقات',
    fastingDays: 'أيام الصيام',
    nightPrayer: 'قيام الليل',
    memorization: 'حفظ آيات',
    custom: 'مخصص',
  };

  static Map<String, String> categoryIcons = {
    quran: '📖',
    fajr: '🌅',
    charity: '💝',
    fastingDays: '🌙',
    nightPrayer: '⭐',
    memorization: '💭',
    custom: '🎯',
  };

  static List<String> get allCategories => [
    quran,
    fajr,
    charity,
    fastingDays,
    nightPrayer,
    memorization,
  ];

  static String getCategoryLabel(String category, {String? customLabel}) {
    if (category == custom && customLabel != null) {
      return customLabel;
    }
    return categoryLabels[category] ?? category;
  }

  static String getCategoryIcon(String category) {
    return categoryIcons[category] ?? '🎯';
  }
}
