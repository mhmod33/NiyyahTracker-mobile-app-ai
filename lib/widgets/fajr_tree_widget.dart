import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../core/app_colors.dart';

TextStyle _tf({double sz = 13, FontWeight fw = FontWeight.w400, Color? c}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c);

// ── Tree growth stages ────────────────────────────────────────────────────────

enum TreeStage { seed, sprout, sapling, youngTree, fullTree }

TreeStage stageForStreak(int streak) {
  if (streak <= 0) return TreeStage.seed;
  if (streak <= 2) return TreeStage.sprout;
  if (streak <= 5) return TreeStage.sapling;
  if (streak <= 9) return TreeStage.youngTree;
  return TreeStage.fullTree;
}

String fajrDayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Consecutive Fajr days ending today — or yesterday if today isn't logged
/// yet, so the tree doesn't reset before Fajr time. Crosses month boundaries.
int fajrStreakFromDays(Set<String> prayedDayKeys, [DateTime? now]) {
  final n = now ?? DateTime.now();
  var day = DateTime(n.year, n.month, n.day);
  if (!prayedDayKeys.contains(fajrDayKey(day))) {
    day = day.subtract(const Duration(days: 1));
  }
  int streak = 0;
  while (prayedDayKeys.contains(fajrDayKey(day))) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

// Stage metadata
const _stageLabel = {
  TreeStage.seed:      'بذرة 🌱',
  TreeStage.sprout:    'بادرة 🌿',
  TreeStage.sapling:   'غرسة 🪴',
  TreeStage.youngTree: 'شجيرة 🌳',
  TreeStage.fullTree:  'شجرة كاملة 🌲',
};

const _stageNextMsg = {
  TreeStage.seed:      'صلِّ الفجر يوماً واحداً للوصول للمرحلة التالية',
  TreeStage.sprout:    'استيقظ 3 أيام متتالية للوصول للمرحلة التالية',
  TreeStage.sapling:   'استيقظ 6 أيام متتالية للوصول للمرحلة التالية',
  TreeStage.youngTree: 'استيقظ 10 أيام متتالية للوصول للمرحلة التالية',
  TreeStage.fullTree:  'وصلت إلى أعلى مرحلة! أكمل على نفس المستوى 🏆',
};

/// Public widget — drop into any parent.
///
/// [streak]    consecutive Fajr days (drives growth stage).
/// [weekDays]  7 booleans [oldest…today] — Fajr prayed that day?
/// [weekStart] DateTime of weekDays[0].
/// [onTap]     opens the streak tracker page.
class FajrTreeWidget extends StatefulWidget {
  final int streak;
  final List<bool> weekDays;
  final DateTime weekStart;
  final bool isDark;
  final VoidCallback? onTap;

  const FajrTreeWidget({
    super.key,
    required this.streak,
    required this.weekDays,
    required this.weekStart,
    this.isDark = false,
    this.onTap,
  });

  @override
  State<FajrTreeWidget> createState() => _FajrTreeWidgetState();
}

class _FajrTreeWidgetState extends State<FajrTreeWidget>
    with TickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _floatAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -7, end: 7).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final stage = stageForStreak(widget.streak);
    final cardBg = isDark ? const Color(0xFF0F1A12) : Colors.white;
    final subCol = isDark ? Colors.white54 : AppColors.textSecondary;

    final startLabel = _fmtDate(widget.weekStart);
    final endLabel   = _fmtDate(widget.weekStart.add(const Duration(days: 6)));

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Island scene ──────────────────────────────────────────────
            SizedBox(
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Sky gradient background
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDark
                                ? [
                                    const Color(0xFF0D1B2A),
                                    const Color(0xFF1A2E1A),
                                  ]
                                : [
                                    const Color(0xFFDFF0FF),
                                    const Color(0xFFEFFFF4),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Ambient glow behind island
                  AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, __) => Container(
                      width: 200,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4CAF50)
                                .withValues(alpha: _glowAnim.value * 0.35),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating island + tree
                  AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _floatAnim.value),
                      child: _IslandScene(stage: stage, isDark: isDark),
                    ),
                  ),

                  // Cloud left
                  AnimatedBuilder(
                    animation: _floatCtrl,
                    builder: (_, __) {
                      final dy = sin(_floatCtrl.value * pi) * 5;
                      return Positioned(
                        left: 20,
                        top: 28 + dy,
                        child: _Cloud(opacity: isDark ? 0.18 : 0.85, scale: 1.0),
                      );
                    },
                  ),

                  // Cloud right (smaller)
                  AnimatedBuilder(
                    animation: _floatCtrl,
                    builder: (_, __) {
                      final dy = sin(_floatCtrl.value * pi + 1) * 4;
                      return Positioned(
                        right: 30,
                        top: 50 + dy,
                        child: _Cloud(opacity: isDark ? 0.12 : 0.65, scale: 0.65),
                      );
                    },
                  ),

                  // Stage badge (top-right)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.lightGreen.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _stageLabel[stage] ?? '',
                        style: _tf(sz: 11, fw: FontWeight.w700,
                            c: AppColors.darkGreen),
                      ),
                    ),
                  ),

                  // Streak counter (top-left)
                  if (widget.streak > 0)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.darkGreen.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                size: 13, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text('${widget.streak} يوم',
                                style: _tf(sz: 11, fw: FontWeight.w700,
                                    c: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                  // Tap hint
                  Positioned(
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 12,
                              color: isDark ? Colors.white38 : Colors.black38),
                          const SizedBox(width: 4),
                          Text('اضغط لتسجيل صلاة الفجر',
                              style: _tf(sz: 10,
                                  c: isDark ? Colors.white38 : Colors.black38)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Next stage message ────────────────────────────────────────
            if (stage != TreeStage.fullTree)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Text(
                  _stageNextMsg[stage] ?? '',
                  style: _tf(sz: 11, c: subCol),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Date range ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(18, stage != TreeStage.fullTree ? 6 : 10, 18, 0),
              child: Text(
                '$startLabel – $endLabel',
                style: _tf(sz: 11, c: subCol),
                textAlign: TextAlign.center,
              ),
            ),

            // ── Week row ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              child: _WeekRow(
                  weekDays: widget.weekDays,
                  weekStart: widget.weekStart,
                  onDayTap: widget.onTap),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
        'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Tree scene widget (Lottie only, no island) ───────────────────────────────

class _IslandScene extends StatelessWidget {
  final TreeStage stage;
  final bool isDark;
  const _IslandScene({required this.stage, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _TreeLottie(stage: stage);
  }
}

// ── Tree widget (Lottie + emoji fallback) ────────────────────────────────────

class _TreeLottie extends StatelessWidget {
  final TreeStage stage;
  const _TreeLottie({required this.stage});

  // tree_stage_0 → seed / sprout  (first LottieFiles animation)
  // tree_stage_1 → sapling        (second LottieFiles animation)
  // tree_stage_2 → young + full   (third LottieFiles animation)
  String get _assetPath {
    switch (stage) {
      case TreeStage.seed:
      case TreeStage.sprout:
        return 'assets/lottie/tree_stage_0.json';
      case TreeStage.sapling:
        return 'assets/lottie/tree_stage_1.json';
      case TreeStage.youngTree:
      case TreeStage.fullTree:
        return 'assets/lottie/tree_stage_2.json';
    }
  }

  double get _size {
    switch (stage) {
      case TreeStage.seed:      return 160;
      case TreeStage.sprout:    return 180;
      case TreeStage.sapling:   return 210;
      case TreeStage.youngTree: return 230;
      case TreeStage.fullTree:  return 250;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Lottie.asset(
        _assetPath,
        fit: BoxFit.contain,
        repeat: true,
        animate: true,
        errorBuilder: (_, __, ___) => _TreeEmoji(stage: stage),
      ),
    );
  }
}

class _TreeEmoji extends StatelessWidget {
  final TreeStage stage;
  const _TreeEmoji({required this.stage});

  @override
  Widget build(BuildContext context) {
    switch (stage) {
      case TreeStage.seed:
        return const Text('🌱', style: TextStyle(fontSize: 42));

      case TreeStage.sprout:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌿', style: TextStyle(fontSize: 32)),
            Text('🌱', style: TextStyle(fontSize: 22)),
          ],
        );

      case TreeStage.sapling:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🍃', style: TextStyle(fontSize: 24)),
            Text('🪴', style: TextStyle(fontSize: 48)),
          ],
        );

      case TreeStage.youngTree:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌳', style: TextStyle(fontSize: 72)),
          ],
        );

      case TreeStage.fullTree:
        return Stack(
          alignment: Alignment.bottomCenter,
          children: const [
            Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text('🌲', style: TextStyle(fontSize: 90)),
            ),
            Positioned(
              left: -12,
              bottom: 20,
              child: Text('🍃', style: TextStyle(fontSize: 22)),
            ),
            Positioned(
              right: -12,
              bottom: 30,
              child: Text('🍃', style: TextStyle(fontSize: 18)),
            ),
          ],
        );
    }
  }
}

// ── Cloud widget ──────────────────────────────────────────────────────────────

class _Cloud extends StatelessWidget {
  final double opacity;
  final double scale;
  const _Cloud({required this.opacity, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: CustomPaint(
        size: const Size(80, 44),
        painter: _CloudPainter(opacity: opacity),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  final double opacity;
  const _CloudPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity);
    final cx = size.width / 2;
    final cy = size.height * 0.7;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy),
            width: size.width, height: size.height * 0.5), paint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 16, cy - 10), width: 34, height: 30),
        paint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 10, cy - 12), width: 40, height: 32),
        paint);
  }

  @override
  bool shouldRepaint(_CloudPainter old) => old.opacity != opacity;
}

// ── Week row ──────────────────────────────────────────────────────────────────

class _WeekRow extends StatelessWidget {
  final List<bool> weekDays;
  final DateTime weekStart;
  final VoidCallback? onDayTap;

  const _WeekRow({
    required this.weekDays,
    required this.weekStart,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();

    const dayNames = {
      1: 'الإثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس',
      5: 'الجمعة',  6: 'السبت',    7: 'الأحد',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final date = weekStart.add(Duration(days: i));
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        final isFuture = date.isAfter(today);
        final done = i < weekDays.length ? weekDays[i] : false;
        final label = dayNames[date.weekday] ?? '';

        return GestureDetector(
          onTap: onDayTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.darkGreen
                      : (isToday
                          ? Colors.transparent
                          : (isFuture
                              ? Colors.transparent
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFF0F4F2)))),
                  border: isToday
                      ? Border.all(color: AppColors.darkGreen, width: 2)
                      : (isFuture
                          ? Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                              width: 1)
                          : null),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : (isToday
                          ? Icon(Icons.close_rounded,
                              color: AppColors.darkGreen, size: 16)
                          : null),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: _tf(
                  sz: isToday ? 10.5 : 9.5,
                  fw: isToday ? FontWeight.w800 : FontWeight.w500,
                  c: isToday
                      ? AppColors.darkGreen
                      : (isDark ? Colors.white38 : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
