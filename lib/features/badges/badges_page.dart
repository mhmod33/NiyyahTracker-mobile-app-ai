import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import '../../models/badge_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/badge_service.dart';
import '../../services/firebase_service.dart';
import '../../services/wird_service.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) =>
    GoogleFonts.ibmPlexSansArabic(
        fontSize: sz, fontWeight: fw, color: c, height: h);

// ── Filter tabs ──────────────────────────────────────────────────────────────

enum _FilterTab { all, earned, locked }

extension _FilterTabExt on _FilterTab {
  String get label {
    switch (this) {
      case _FilterTab.all:
        return 'الكل';
      case _FilterTab.earned:
        return 'المكتسبة';
      case _FilterTab.locked:
        return 'مقفلة';
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  final BadgeService _badgeService = BadgeService();
  final FirebaseService _firebaseService = FirebaseService();
  final WirdService _wirdService = WirdService();

  bool _isLoading = true;
  Map<String, UserBadge> _userBadges = {};
  BadgeStats _stats = const BadgeStats();
  _FilterTab _filter = _FilterTab.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Build stats from Firestore + WirdService
      final stats = await _buildStats(userId);

      // Evaluate badges (writes newly earned ones to Firestore)
      await _badgeService.evaluateAndUpdate(userId: userId, stats: stats);

      // Reload after evaluation
      final badgesMap = await _badgeService.getUserBadgesMap(userId);

      if (mounted) {
        setState(() {
          _stats = stats;
          _userBadges = badgesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<BadgeStats> _buildStats(String userId) async {
    // Fetch all worship records
    final now = DateTime.now();
    final allWorships = await _firebaseService.getWorshipsInRange(
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

    // Streak computation
    final daySet = <String>{};
    final completeDaySet = <String>{};

    for (final w in allWorships) {
      final key =
          '${w.date.year}-${w.date.month.toString().padLeft(2, '0')}-${w.date.day.toString().padLeft(2, '0')}';

      totalPrayers += w.prayerCount;
      quranPages += w.quranPages;

      if (w.prayerCount > 0) {
        daySet.add(key);
        noMissDays++;
      }

      if (w.prayerCount >= 5) {
        completedPrayerDays++;
        completeDaySet.add(key);
      }

      // Fajr: prayerCount ≥ 1 means at least fajr is done
      if (w.prayerCount >= 1) fajrDays++;

      if (w.worships['azkar_done'] == true) morningAzkar++;
      if (w.worships['evening_azkar_done'] == true) eveningAzkar++;
      if (w.worships['fasting'] == true) fastingDays++;
      if (w.worships['fasting_ayyam_beed'] == true) ayyamBeedDays++;
    }

    // Compute prayer streak from sorted complete days
    final sortedDays = completeDaySet.toList()..sort();
    int streak = 0;
    int maxStreak = 0;
    DateTime? prev;
    for (final key in sortedDays) {
      final d = DateTime.tryParse(key);
      if (d == null) continue;
      if (prev == null || d.difference(prev).inDays == 1) {
        streak++;
      } else {
        streak = 1;
      }
      if (streak > maxStreak) maxStreak = streak;
      prev = d;
    }
    // Check if streak is current (includes today or yesterday)
    int currentStreak = 0;
    {
      final today = DateTime(now.year, now.month, now.day);
      var check = today;
      for (int i = 0; i < 400; i++) {
        final key =
            '${check.year}-${check.month.toString().padLeft(2, '0')}-${check.day.toString().padLeft(2, '0')}';
        if (completeDaySet.contains(key)) {
          currentStreak++;
          check = check.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // Wird streak from WirdService (local + cloud)
    await _wirdService.init();
    _wirdService.setUserId(userId);
    final wirdStreak = _wirdService.getCurrentStreak();

    // Also count wird pages toward quran total
    final wirdPages = _wirdService.getTotalPagesRead();
    final totalQuranPages = quranPages + wirdPages;

    return BadgeStats(
      totalPrayers: totalPrayers,
      completedPrayerDays: completedPrayerDays,
      prayerStreak: currentStreak > 0 ? currentStreak : maxStreak,
      noMissDays: noMissDays,
      fajrDays: fajrDays,
      morningAzkarCount: morningAzkar,
      eveningAzkarCount: eveningAzkar,
      fastingDays: fastingDays,
      ayyamBeedDays: ayyamBeedDays,
      quranPagesTotal: totalQuranPages,
      wirdStreak: wirdStreak,
    );
  }

  List<BadgeDefinition> get _filteredBadges {
    switch (_filter) {
      case _FilterTab.all:
        return BadgeCatalogue.all;
      case _FilterTab.earned:
        return BadgeCatalogue.all
            .where((d) => _userBadges[d.id]?.isEarned == true)
            .toList();
      case _FilterTab.locked:
        return BadgeCatalogue.all
            .where((d) => _userBadges[d.id]?.isEarned != true)
            .toList();
    }
  }

  int get _earnedCount =>
      BadgeCatalogue.all.where((d) => _userBadges[d.id]?.isEarned == true).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7F6);
    final filtered = _filteredBadges;
    final total = BadgeCatalogue.all.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: _buildHeader(isDark, total),
                  ),

                  // ── Filter Tabs ──
                  SliverToBoxAdapter(
                    child: _buildFilterTabs(isDark),
                  ),

                  // ── Badge Grid ──
                  if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmpty(isDark),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.78,
                        children: filtered
                            .map((def) => _BadgeCard(
                                  definition: def,
                                  userBadge: _userBadges[def.id],
                                  isDark: isDark,
                                  stats: _stats,
                                  onTap: () =>
                                      _showBadgeDetail(context, def, isDark),
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, int total) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 28,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0D2818), const Color(0xFF0A3D22)]
              : [const Color(0xFF145A3A), const Color(0xFF1E8255)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const DirectionalIcon(
                      isBack: true, size: 18, color: Colors.white),
                ),
              ),
              Expanded(
                child: Text(
                  'الأوسمة',
                  textAlign: TextAlign.center,
                  style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white),
                ),
              ),
              // Spacer to balance the back button
              const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 20),
          // Summary row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                // Circular progress
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: total > 0 ? _earnedCount / total : 0,
                        strokeWidth: 6,
                        backgroundColor: Colors.white12,
                        color: AppColors.gold,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '${((_earnedCount / (total > 0 ? total : 1)) * 100).toInt()}%',
                      style: _f(
                          sz: 11, fw: FontWeight.w800, c: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_earnedCount من $total وسام مكتسب',
                        style: _f(
                            sz: 15, fw: FontWeight.w800, c: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'واصل رحلتك لكسب المزيد',
                        style: _f(sz: 12, c: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🏅 $_earnedCount',
                    style: _f(
                        sz: 13, fw: FontWeight.bold, c: AppColors.gold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: _FilterTab.values.map((tab) {
          final selected = _filter == tab;
          int count;
          switch (tab) {
            case _FilterTab.all:
              count = BadgeCatalogue.all.length;
              break;
            case _FilterTab.earned:
              count = _earnedCount;
              break;
            case _FilterTab.locked:
              count = BadgeCatalogue.all.length - _earnedCount;
              break;
          }
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filter = tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.darkGreen
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppColors.darkGreen
                        : (isDark
                            ? Colors.white12
                            : AppColors.paleGreen),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      tab.label,
                      style: _f(
                        sz: 13,
                        fw: FontWeight.w700,
                        c: selected
                            ? Colors.white
                            : (isDark ? Colors.white60 : AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      '$count',
                      style: _f(
                        sz: 11,
                        c: selected ? Colors.white70 : AppColors.gray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد أوسمة هنا بعد',
            style:
                _f(sz: 16, fw: FontWeight.w600, c: AppColors.gray),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetail(
      BuildContext context, BadgeDefinition def, bool isDark) {
    final ub = _userBadges[def.id];
    final isEarned = ub?.isEarned == true;
    final currentProgress = ub?.currentProgress ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BadgeDetailSheet(
        definition: def,
        userBadge: ub,
        currentProgress: currentProgress,
        isEarned: isEarned,
        isDark: isDark,
      ),
    );
  }
}

// ── Badge Card ───────────────────────────────────────────────────────────────

class _BadgeCard extends StatelessWidget {
  final BadgeDefinition definition;
  final UserBadge? userBadge;
  final bool isDark;
  final BadgeStats stats;
  final VoidCallback onTap;

  const _BadgeCard({
    required this.definition,
    required this.userBadge,
    required this.isDark,
    required this.stats,
    required this.onTap,
  });

  bool get isEarned => userBadge?.isEarned == true;
  int get currentProgress => userBadge?.currentProgress ?? 0;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final progress =
        (currentProgress / definition.target).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEarned
                ? AppColors.gold.withValues(alpha: 0.5)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
            width: isEarned ? 1.5 : 1,
          ),
          boxShadow: isEarned
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Badge icon / medal ──
            Expanded(
              flex: 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _BadgeMedal(
                    definition: definition,
                    isEarned: isEarned,
                    size: 90,
                  ),
                  if (!isEarned)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black54
                              : Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_rounded,
                            size: 14,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey[500]),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Title ──
            Text(
              definition.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _f(
                sz: 13,
                fw: FontWeight.w700,
                c: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 4),

            // ── Short description ──
            Text(
              definition.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _f(sz: 10, c: AppColors.gray),
            ),

            const SizedBox(height: 8),

            // ── Progress bar + counter ──
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor:
                          isDark ? Colors.white12 : Colors.grey[200],
                      color: isEarned ? AppColors.gold : AppColors.midGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${math.min(currentProgress, definition.target)}',
                  style: _f(
                    sz: 11,
                    fw: FontWeight.w700,
                    c: isEarned ? AppColors.gold : AppColors.midGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // ── Target label ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // earned date or "in progress"
                if (isEarned && userBadge?.earnedAt != null)
                  Text(
                    'اكتُسب ${_formatDate(userBadge!.earnedAt!)}',
                    style: _f(sz: 9, c: AppColors.gold),
                  )
                else
                  Text(
                    isEarned ? 'مكتسب' : 'قيد التنفيذ',
                    style: _f(
                        sz: 9,
                        c: isEarned ? AppColors.gold : AppColors.gray),
                  ),
                Text(
                  '${definition.target}',
                  style: _f(sz: 9, c: AppColors.gray),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ── Badge Medal Widget ────────────────────────────────────────────────────────
// Draws an Islamic-style medal using Canvas: outer ring, inner circle, and icon.

class _BadgeMedal extends StatelessWidget {
  final BadgeDefinition definition;
  final bool isEarned;
  final double size;

  const _BadgeMedal({
    required this.definition,
    required this.isEarned,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MedalPainter(
        level: definition.level,
        isEarned: isEarned,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            _categoryIcon(definition.category),
            size: size * 0.32,
            color: isEarned
                ? _levelColor(definition.level)
                : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(BadgeCategory cat) {
    switch (cat) {
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

  Color _levelColor(BadgeLevel level) {
    switch (level) {
      case BadgeLevel.bronze:
        return const Color(0xFFCD7F32);
      case BadgeLevel.silver:
        return const Color(0xFFC0C0C0);
      case BadgeLevel.gold:
        return AppColors.gold;
    }
  }
}

class _MedalPainter extends CustomPainter {
  final BadgeLevel level;
  final bool isEarned;

  _MedalPainter({required this.level, required this.isEarned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final primaryColor = isEarned ? _levelPrimary : Colors.grey[400]!;
    final secondaryColor = isEarned ? _levelSecondary : Colors.grey[300]!;

    // Outer decorative ring (serrated / star-like)
    _drawDecorativeRing(canvas, center, radius * 0.96, primaryColor);

    // Main circle background
    final bgPaint = Paint()
      ..color = isEarned ? secondaryColor.withValues(alpha: 0.25) : Colors.grey[200]!
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.72, bgPaint);

    // Outer circle border
    final borderPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius * 0.72, borderPaint);

    // Inner accent circle
    final innerBorderPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.58, innerBorderPaint);
  }

  void _drawDecorativeRing(
      Canvas canvas, Offset center, double radius, Color color) {
    const segments = 24;
    final paint = Paint()
      ..color = color.withValues(alpha: isEarned ? 0.6 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < segments; i++) {
      final angle = (i / segments) * 2 * math.pi;
      final inner = Offset(
        center.dx + (radius * 0.80) * math.cos(angle),
        center.dy + (radius * 0.80) * math.sin(angle),
      );
      final outer = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  Color get _levelPrimary {
    switch (level) {
      case BadgeLevel.bronze:
        return const Color(0xFFCD7F32);
      case BadgeLevel.silver:
        return const Color(0xFF9E9E9E);
      case BadgeLevel.gold:
        return AppColors.gold;
    }
  }

  Color get _levelSecondary {
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
  bool shouldRepaint(_MedalPainter old) =>
      old.level != level || old.isEarned != isEarned;
}

// ── Badge Detail Bottom Sheet ─────────────────────────────────────────────────

class _BadgeDetailSheet extends StatelessWidget {
  final BadgeDefinition definition;
  final UserBadge? userBadge;
  final int currentProgress;
  final bool isEarned;
  final bool isDark;

  const _BadgeDetailSheet({
    required this.definition,
    required this.userBadge,
    required this.currentProgress,
    required this.isEarned,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final progress =
        (currentProgress / definition.target).clamp(0.0, 1.0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Close + lock indicator row
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close,
                          size: 16,
                          color: isDark ? Colors.white54 : Colors.grey),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isEarned
                          ? AppColors.gold.withValues(alpha: 0.15)
                          : (isDark ? Colors.white12 : Colors.grey[100]),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEarned
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                      size: 16,
                      color: isEarned
                          ? AppColors.gold
                          : (isDark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Medal
            _BadgeMedal(
              definition: definition,
              isEarned: isEarned,
              size: 130,
            ),

            const SizedBox(height: 20),

            // Level badge chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _levelChipColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _levelChipColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                definition.level.label,
                style: _f(
                    sz: 12,
                    fw: FontWeight.w700,
                    c: _levelChipColor),
              ),
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              definition.title,
              style: _f(
                sz: 22,
                fw: FontWeight.w800,
                c: isDark ? Colors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            // Description
            Text(
              definition.description,
              style: _f(sz: 14, c: AppColors.gray, h: 1.6),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // Progress row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.paleGreen.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEarned ? 'مكتمل ✓' : 'قيد التنفيذ',
                        style: _f(
                          sz: 13,
                          fw: FontWeight.w600,
                          c: isEarned
                              ? AppColors.gold
                              : (isDark ? Colors.white70 : AppColors.gray),
                        ),
                      ),
                      Text(
                        '${definition.target} / ${currentProgress.clamp(0, definition.target)}',
                        style: _f(
                          sz: 13,
                          fw: FontWeight.w700,
                          c: isEarned
                              ? AppColors.gold
                              : (isDark
                                  ? Colors.white
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor:
                          isDark ? Colors.white12 : Colors.grey[200],
                      color: isEarned ? AppColors.gold : AppColors.midGreen,
                    ),
                  ),
                ],
              ),
            ),

            // Earned date
            if (isEarned && userBadge?.earnedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'اكتُسب في ${_formatFullDate(userBadge!.earnedAt!)}',
                style: _f(sz: 12, c: AppColors.gray),
              ),
            ],

            const SizedBox(height: 20),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('تم',
                    style: _f(
                        sz: 16,
                        fw: FontWeight.bold,
                        c: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _levelChipColor {
    switch (definition.level) {
      case BadgeLevel.bronze:
        return const Color(0xFFCD7F32);
      case BadgeLevel.silver:
        return const Color(0xFF9E9E9E);
      case BadgeLevel.gold:
        return AppColors.gold;
    }
  }

  String _formatFullDate(DateTime d) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
