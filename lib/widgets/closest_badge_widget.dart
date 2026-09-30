import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/badge_model.dart';
import '../providers/auth_provider.dart';
import '../services/badge_service.dart';
import '../services/firebase_service.dart';
import '../services/wird_service.dart';
import '../features/badges/badges_page.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c);

/// A card that shows the badge the current user is closest to earning.
/// Intended for the Dashboard and Analytics pages.
class ClosestBadgeWidget extends StatefulWidget {
  final bool isDark;
  const ClosestBadgeWidget({super.key, required this.isDark});

  @override
  State<ClosestBadgeWidget> createState() => _ClosestBadgeWidgetState();
}

class _ClosestBadgeWidgetState extends State<ClosestBadgeWidget> {
  final BadgeService _badgeService = BadgeService();
  final FirebaseService _firebase = FirebaseService();
  final WirdService _wird = WirdService();

  bool _loading = true;
  BadgeDefinition? _closest;
  int _currentProgress = 0;
  int _earnedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Build lightweight stats
      final stats = await _buildStats(userId);
      final badgesMap = await _badgeService.getUserBadgesMap(userId);
      final closest = _badgeService.getClosestUnearned(badgesMap, stats);

      int earned = badgesMap.values.where((b) => b.isEarned).length;

      if (mounted) {
        setState(() {
          _closest = closest;
          _earnedCount = earned;
          if (closest != null) {
            _currentProgress = badgesMap[closest.id]?.currentProgress ?? 0;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<BadgeStats> _buildStats(String userId) async {
    final now = DateTime.now();
    final allWorships = await _firebase.getWorshipsInRange(
      userId,
      DateTime(2020),
      now,
    );

    int totalPrayers = 0;
    int completedPrayerDays = 0;
    int noMissDays = 0;
    int fajrDays = 0;
    int morningAzkar = 0;
    int eveningAzkar = 0;
    int fastingDays = 0;
    int ayyamBeedDays = 0;
    int quranPages = 0;
    final completeDaySet = <String>{};

    for (final w in allWorships) {
      totalPrayers += w.prayerCount;
      quranPages += w.quranPages;
      if (w.prayerCount > 0) noMissDays++;
      if (w.prayerCount >= 5) {
        completedPrayerDays++;
        final key =
            '${w.date.year}-${w.date.month.toString().padLeft(2, '0')}-${w.date.day.toString().padLeft(2, '0')}';
        completeDaySet.add(key);
      }
      if (w.prayerCount >= 1) fajrDays++;
      if (w.worships['azkar_done'] == true) morningAzkar++;
      if (w.worships['evening_azkar_done'] == true) eveningAzkar++;
      if (w.worships['fasting'] == true) fastingDays++;
      if (w.worships['fasting_ayyam_beed'] == true) ayyamBeedDays++;
    }

    // Current prayer streak
    int streak = 0;
    {
      final today = DateTime(now.year, now.month, now.day);
      var check = today;
      for (int i = 0; i < 400; i++) {
        final key =
            '${check.year}-${check.month.toString().padLeft(2, '0')}-${check.day.toString().padLeft(2, '0')}';
        if (completeDaySet.contains(key)) {
          streak++;
          check = check.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    await _wird.init();
    _wird.setUserId(userId);
    final wirdStreak = _wird.getCurrentStreak();
    final wirdPages = _wird.getTotalPagesRead();

    return BadgeStats(
      totalPrayers: totalPrayers,
      completedPrayerDays: completedPrayerDays,
      prayerStreak: streak,
      noMissDays: noMissDays,
      fajrDays: fajrDays,
      morningAzkarCount: morningAzkar,
      eveningAzkarCount: eveningAzkar,
      fastingDays: fastingDays,
      ayyamBeedDays: ayyamBeedDays,
      quranPagesTotal: quranPages + wirdPages,
      wirdStreak: wirdStreak,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.gold, strokeWidth: 2)),
      );
    }

    if (_closest == null) return const SizedBox.shrink();

    final def = _closest!;
    final progress = (_currentProgress / def.target).clamp(0.0, 1.0);
    final isDark = widget.isDark;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BadgesPage()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : AppColors.paleGreen,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  'أقرب وسام',
                  style: _f(
                    sz: 15,
                    fw: FontWeight.w800,
                    c: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '🏅 $_earnedCount',
                    style: _f(sz: 11, fw: FontWeight.w600, c: AppColors.gold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content row
            Row(
              children: [
                // Medal visual
                _SmallMedal(definition: def),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.title,
                        style: _f(
                          sz: 14,
                          fw: FontWeight.w700,
                          c: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        def.description,
                        style: _f(sz: 11, c: AppColors.gray),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor:
                              isDark ? Colors.white12 : Colors.grey[200],
                          color: AppColors.midGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${math.min(_currentProgress, def.target)} / ${def.target}',
                            style: _f(
                                sz: 11,
                                fw: FontWeight.w700,
                                c: AppColors.midGreen),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: _f(sz: 11, c: AppColors.gray),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallMedal extends StatelessWidget {
  final BadgeDefinition definition;
  const _SmallMedal({required this.definition});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(64, 64),
      painter: _SmallMedalPainter(level: definition.level),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Center(
          child: Icon(
            _icon,
            size: 22,
            color: _levelColor,
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    switch (definition.category) {
      case BadgeCategory.prayer:
        return Icons.mosque_rounded;
      case BadgeCategory.quran:
        return Icons.menu_book_rounded;
      case BadgeCategory.azkar:
        return Icons.front_hand_rounded;
      case BadgeCategory.fasting:
        return Icons.nights_stay_rounded;
      case BadgeCategory.wird:
        return Icons.auto_stories_rounded;
      case BadgeCategory.general:
        return Icons.emoji_events_rounded;
    }
  }

  Color get _levelColor {
    switch (definition.level) {
      case BadgeLevel.bronze:
        return const Color(0xFFCD7F32);
      case BadgeLevel.silver:
        return const Color(0xFF9E9E9E);
      case BadgeLevel.gold:
        return AppColors.gold;
    }
  }
}

class _SmallMedalPainter extends CustomPainter {
  final BadgeLevel level;
  _SmallMedalPainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Decorative ring
    const segments = 20;
    final ringPaint = Paint()
      ..color = _primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < segments; i++) {
      final angle = (i / segments) * 2 * math.pi;
      final inner = Offset(
        center.dx + (radius * 0.76) * math.cos(angle),
        center.dy + (radius * 0.76) * math.sin(angle),
      );
      final outer = Offset(
        center.dx + radius * 0.94 * math.cos(angle),
        center.dy + radius * 0.94 * math.sin(angle),
      );
      canvas.drawLine(inner, outer, ringPaint);
    }

    // Fill
    final fillPaint = Paint()
      ..color = _secondary.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.7, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = _primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius * 0.7, borderPaint);
  }

  Color get _primary {
    switch (level) {
      case BadgeLevel.bronze:
        return const Color(0xFFCD7F32);
      case BadgeLevel.silver:
        return const Color(0xFF9E9E9E);
      case BadgeLevel.gold:
        return AppColors.gold;
    }
  }

  Color get _secondary {
    switch (level) {
      case BadgeLevel.bronze:
        return const Color(0xFFE8A96E);
      case BadgeLevel.silver:
        return const Color(0xFFE0E0E0);
      case BadgeLevel.gold:
        return const Color(0xFFFDF3D7);
    }
  }

  @override
  bool shouldRepaint(_SmallMedalPainter old) => old.level != level;
}
