/// Badge levels — determines the visual tier of a badge.
enum BadgeLevel { bronze, silver, gold }

extension BadgeLevelExt on BadgeLevel {
  String get label {
    switch (this) {
      case BadgeLevel.bronze:
        return 'المستوى البرونزي';
      case BadgeLevel.silver:
        return 'المستوى الفضي';
      case BadgeLevel.gold:
        return 'المستوى الذهبي';
    }
  }

  String get emoji {
    switch (this) {
      case BadgeLevel.bronze:
        return '🥉';
      case BadgeLevel.silver:
        return '🥈';
      case BadgeLevel.gold:
        return '🥇';
    }
  }
}

/// Categories of badges — maps to the worship area the badge covers.
enum BadgeCategory { prayer, quran, azkar, fasting, wird, general }

extension BadgeCategoryExt on BadgeCategory {
  String get label {
    switch (this) {
      case BadgeCategory.prayer:
        return 'الصلاة';
      case BadgeCategory.quran:
        return 'القرآن';
      case BadgeCategory.azkar:
        return 'الأذكار';
      case BadgeCategory.fasting:
        return 'الصيام';
      case BadgeCategory.wird:
        return 'الورد';
      case BadgeCategory.general:
        return 'عام';
    }
  }
}

/// A single badge definition — what exists in the catalogue.
class BadgeDefinition {
  final String id;
  final String title;
  final String description;
  final BadgeLevel level;
  final BadgeCategory category;

  /// The target number that drives the progress bar (e.g. 30 prayers).
  final int target;

  /// Icon code point from MaterialIcons (used when no image asset is present).
  final int iconCodePoint;

  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.category,
    required this.target,
    this.iconCodePoint = 0xe55f, // emoji_events
  });
}

/// A user's progress towards (or achievement of) a badge.
class UserBadge {
  final String badgeId;
  final String userId;
  final bool isEarned;
  final DateTime? earnedAt;

  /// Current progress towards the badge target.
  final int currentProgress;

  const UserBadge({
    required this.badgeId,
    required this.userId,
    this.isEarned = false,
    this.earnedAt,
    this.currentProgress = 0,
  });

  Map<String, dynamic> toMap() => {
        'badgeId': badgeId,
        'userId': userId,
        'isEarned': isEarned,
        'earnedAt': earnedAt?.toIso8601String(),
        'currentProgress': currentProgress,
      };

  factory UserBadge.fromMap(Map<String, dynamic> map) => UserBadge(
        badgeId: map['badgeId'] as String,
        userId: map['userId'] as String,
        isEarned: map['isEarned'] as bool? ?? false,
        earnedAt: map['earnedAt'] != null
            ? DateTime.tryParse(map['earnedAt'] as String)
            : null,
        currentProgress: map['currentProgress'] as int? ?? 0,
      );

  UserBadge copyWith({
    bool? isEarned,
    DateTime? earnedAt,
    int? currentProgress,
  }) =>
      UserBadge(
        badgeId: badgeId,
        userId: userId,
        isEarned: isEarned ?? this.isEarned,
        earnedAt: earnedAt ?? this.earnedAt,
        currentProgress: currentProgress ?? this.currentProgress,
      );
}
