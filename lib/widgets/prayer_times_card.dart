import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../core/hijri_utils.dart';

TextStyle _f({double sz = 13, FontWeight fw = FontWeight.w400, Color? c}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c);

/// Redesigned prayer-times card.
///
/// Header: title + Hijri date + day name + Gregorian date.
/// Body: horizontally scrollable row of all 6 prayer chips.
/// The current/next prayer chip is highlighted with a gold background
/// and shows an animated circular countdown ring.
class PrayerTimesCard extends StatefulWidget {
  /// All prayers today: [{name, key, time}, ...]  length 6
  final List<Map<String, dynamic>> allPrayers;

  /// Name of the next/upcoming prayer
  final String nextPrayerName;

  /// Time of the next/upcoming prayer (for countdown ring)
  final DateTime? nextPrayerTime;

  /// Time of the prayer after next (for ring interval)
  final DateTime? afterPrayerTime;

  final bool loading;
  final VoidCallback? onTap;
  final bool isDark;

  const PrayerTimesCard({
    super.key,
    required this.allPrayers,
    required this.nextPrayerName,
    this.nextPrayerTime,
    this.afterPrayerTime,
    this.loading = false,
    this.onTap,
    this.isDark = false,
  });

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;
  Timer? _ticker;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _ringAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut),
    );
    _updateCountdown();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (widget.nextPrayerTime == null) return;
    setState(() {
      _timeLeft = widget.nextPrayerTime!.difference(DateTime.now());
      if (_timeLeft.isNegative) _timeLeft = Duration.zero;
    });
  }

  @override
  void didUpdateWidget(PrayerTimesCard old) {
    super.didUpdateWidget(old);
    if (old.nextPrayerTime != widget.nextPrayerTime) _updateCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String _fmtCountdown(Duration d) {
    if (d.isNegative || d.inSeconds == 0) return '00:00:00';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inHours)}:${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}';
  }

  String _fmtTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'م' : 'ص'}';
  }

  double get _ringProgress {
    if (widget.nextPrayerTime == null) return 0.5;
    if (widget.afterPrayerTime != null) {
      final interval =
          widget.afterPrayerTime!.difference(widget.nextPrayerTime!).inSeconds;
      final total = interval > 0 ? interval : 7200;
      return ((total - _timeLeft.inSeconds) / total).clamp(0.0, 1.0);
    }
    return ((7200 - _timeLeft.inSeconds) / 7200).clamp(0.0, 1.0);
  }

  // Hijri date (Umm Al-Qura approximation)
  static String _hijriDate(DateTime g) {
    final h = HijriDate.fromGregorian(g);
    final month = h.month;
    final day = h.day;
    final year = h.year;
    const m = [
      'محرم','صفر','ربيع الأول','ربيع الآخر','جمادى الأولى','جمادى الآخرة',
      'رجب','شعبان','رمضان','شوال','ذو القعدة','ذو الحجة',
    ];
    return '$day ${(month >= 1 && month <= 12) ? m[month - 1] : m[0]} ${year}هـ';
  }

  static String _arabicDay(DateTime d) {
    const days = ['الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    return days[d.weekday - 1];
  }

  static String _arabicDate(DateTime d) {
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
        'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static IconData _icon(String key) {
    switch (key) {
      case 'fajr':    return Icons.wb_twilight_rounded;
      case 'sunrise': return Icons.wb_sunny_outlined;
      case 'dhuhr':   return Icons.light_mode_rounded;
      case 'asr':     return Icons.cloud_queue_rounded;
      case 'maghrib': return Icons.wb_cloudy_rounded;
      case 'isha':    return Icons.nights_stay_rounded;
      default:        return Icons.access_time_rounded;
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final now = DateTime.now();
    final cardBg = isDark ? const Color(0xFF111B14) : Colors.white;
    final subCol = isDark ? Colors.white54 : AppColors.textSecondary;
    final textCol = isDark ? Colors.white : AppColors.textPrimary;
    final divCol = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.paleGreen,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          size: 15, color: AppColors.darkGreen),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('مواقيت الصلاة',
                      style: _f(sz: 15, fw: FontWeight.w800, c: textCol)),
                  const SizedBox(width: 5),
                  Text('(حسب توقيتك المحلي)',
                      style: _f(sz: 10, c: subCol)),
                ],
              ),
            ),

            // ── Date row ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
              child: Row(
                children: [
                  Text(_hijriDate(now), style: _f(sz: 11, c: subCol)),
                  const Spacer(),
                  Text(_arabicDay(now),
                      style: _f(sz: 13, fw: FontWeight.w800,
                          c: AppColors.darkGreen)),
                  const SizedBox(width: 8),
                  Text(_arabicDate(now), style: _f(sz: 11, c: subCol)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Divider(height: 1, color: divCol),
            ),

            const SizedBox(height: 12),

            // ── Prayer chips ─────────────────────────────────────────────────
            if (widget.loading)
              _LoadingSkeleton(isDark: isDark)
            else
              _PrayerScroll(
                prayers: widget.allPrayers,
                nextPrayerName: widget.nextPrayerName,
                timeLeft: _timeLeft,
                ringProgress: _ringProgress,
                ringAnim: _ringAnim,
                isDark: isDark,
                fmtTime: _fmtTime,
                fmtCountdown: _fmtCountdown,
                iconOf: _icon,
              ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ── Horizontal prayer scroll ──────────────────────────────────────────────────

class _PrayerScroll extends StatelessWidget {
  final List<Map<String, dynamic>> prayers;
  final String nextPrayerName;
  final Duration timeLeft;
  final double ringProgress;
  final Animation<double> ringAnim;
  final bool isDark;
  final String Function(DateTime) fmtTime;
  final String Function(Duration) fmtCountdown;
  final IconData Function(String) iconOf;

  const _PrayerScroll({
    required this.prayers,
    required this.nextPrayerName,
    required this.timeLeft,
    required this.ringProgress,
    required this.ringAnim,
    required this.isDark,
    required this.fmtTime,
    required this.fmtCountdown,
    required this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prayers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final p = prayers[i];
          final name = p['name'] as String;
          final time = p['time'] as DateTime;
          final key  = p['key']  as String? ?? '';
          final isActive = name == nextPrayerName;
          return _PrayerChip(
            name: name,
            time: time,
            key_: key,
            isActive: isActive,
            isDark: isDark,
            timeLeft: isActive ? timeLeft : null,
            ringProgress: isActive ? ringProgress : null,
            ringAnim: isActive ? ringAnim : null,
            fmtTime: fmtTime,
            fmtCountdown: fmtCountdown,
            iconOf: iconOf,
          );
        },
      ),
    );
  }
}

// ── Single prayer chip ────────────────────────────────────────────────────────

class _PrayerChip extends StatelessWidget {
  final String name;
  final DateTime time;
  final String key_;
  final bool isActive;
  final bool isDark;
  final Duration? timeLeft;
  final double? ringProgress;
  final Animation<double>? ringAnim;
  final String Function(DateTime) fmtTime;
  final String Function(Duration) fmtCountdown;
  final IconData Function(String) iconOf;

  const _PrayerChip({
    required this.name,
    required this.time,
    required this.key_,
    required this.isActive,
    required this.isDark,
    required this.fmtTime,
    required this.fmtCountdown,
    required this.iconOf,
    this.timeLeft,
    this.ringProgress,
    this.ringAnim,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE9A824);
    const goldBg = Color(0xFFFFF8E7);
    const goldBgDark = Color(0xFF2A2210);

    final bg = isActive
        ? (isDark ? goldBgDark : goldBg)
        : (isDark ? const Color(0xFF1A1F1C) : const Color(0xFFF8FAF9));

    final border = isActive
        ? gold.withValues(alpha: 0.6)
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06));

    final nameColor = isActive
        ? (isDark ? gold : const Color(0xFF8B6200))
        : (isDark ? Colors.white : AppColors.textPrimary);

    final timeColor = isActive
        ? (isDark ? Colors.white : AppColors.textPrimary)
        : (isDark ? Colors.white54 : AppColors.textSecondary);

    final iconColor = isActive
        ? gold
        : (isDark ? Colors.white38 : AppColors.textSecondary);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 110 : 86,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: isActive ? 1.5 : 1),
        boxShadow: isActive
            ? [BoxShadow(
                color: gold.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon or ring
          if (isActive && ringAnim != null)
            AnimatedBuilder(
              animation: ringAnim!,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      value: ringProgress ?? 0.5,
                      strokeWidth: 3.5,
                      backgroundColor: gold.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        gold.withValues(
                            alpha: 0.55 + (ringAnim!.value) * 0.45),
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Icon(iconOf(key_), size: 18, color: gold),
                ],
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(iconOf(key_), size: 17, color: iconColor),
            ),

          const SizedBox(height: 7),

          // Prayer name
          Text(name,
              style: _f(
                  sz: isActive ? 12 : 11,
                  fw: isActive ? FontWeight.w800 : FontWeight.w600,
                  c: nameColor),
              textAlign: TextAlign.center),

          const SizedBox(height: 3),

          // Time or countdown
          if (isActive && timeLeft != null)
            Text(
              fmtCountdown(timeLeft!),
              style: GoogleFonts.ibmPlexMono(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            )
          else
            Text(fmtTime(time),
                style: _f(sz: 11, fw: FontWeight.w600, c: timeColor),
                textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatefulWidget {
  final bool isDark;
  const _LoadingSkeleton({required this.isDark});
  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = widget.isDark
            ? Colors.white.withValues(alpha: _anim.value * 0.15)
            : Colors.black.withValues(alpha: _anim.value * 0.07);
        return SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => Container(
              width: i == 0 ? 110 : 86,
              decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(18)),
            ),
          ),
        );
      },
    );
  }
}
