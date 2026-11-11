import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import '../../core/hijri_utils.dart';
import '../../services/azan_service.dart';
import '../qibla/qibla_page.dart';
import '../azan/azan_settings_page.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({super.key});
  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> with SingleTickerProviderStateMixin {
  PrayerTimes? _prayerTimes;
  String _nextPrayerName = 'الفجر';
  String _nextPrayerKey = 'fajr';
  DateTime? _nextPrayerTime;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  Duration _totalDuration = const Duration(hours: 1);
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    // Load immediately from sync cache (zero waiting)
    _applyPrayerTimes(AzanService().prayerTimesSync);
    // Refresh with GPS in background
    _refreshPrayerTimes();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_nextPrayerTime != null && mounted) {
        final diff = _nextPrayerTime!.difference(DateTime.now());
        if (diff.isNegative) {
          _applyPrayerTimes(AzanService().prayerTimesSync);
        } else {
          setState(() => _timeLeft = diff);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _applyPrayerTimes(PrayerTimes pt) {
    final now = DateTime.now();
    String next = 'الفجر';
    String key = 'fajr';
    DateTime nextTime = pt.fajr.add(const Duration(days: 1));
    DateTime prevTime = pt.isha;

    if (now.isBefore(pt.fajr)) {
      next = 'الفجر';
      key = 'fajr';
      nextTime = pt.fajr;
      prevTime = pt.isha.subtract(const Duration(days: 1));
    } else if (now.isBefore(pt.sunrise)) {
      next = 'الشروق';
      key = 'sunrise';
      nextTime = pt.sunrise;
      prevTime = pt.fajr;
    } else if (now.isBefore(pt.dhuhr)) {
      next = 'الظهر';
      key = 'dhuhr';
      nextTime = pt.dhuhr;
      prevTime = pt.sunrise;
    } else if (now.isBefore(pt.asr)) {
      next = 'العصر';
      key = 'asr';
      nextTime = pt.asr;
      prevTime = pt.dhuhr;
    } else if (now.isBefore(pt.maghrib)) {
      next = 'المغرب';
      key = 'maghrib';
      nextTime = pt.maghrib;
      prevTime = pt.asr;
    } else if (now.isBefore(pt.isha)) {
      next = 'العشاء';
      key = 'isha';
      nextTime = pt.isha;
      prevTime = pt.maghrib;
    }

    var total = nextTime.difference(prevTime);
    if (total.inSeconds <= 0) total = const Duration(hours: 2);

    if (mounted) {
      setState(() {
        _prayerTimes = pt;
        _nextPrayerName = next;
        _nextPrayerKey = key;
        _nextPrayerTime = nextTime;
        _timeLeft = nextTime.difference(now);
        _totalDuration = total;
      });
    }
  }

  Future<void> _refreshPrayerTimes() async {
    try {
      final pt = await AzanService().preloadPrayerTimes();
      _applyPrayerTimes(pt);
    } catch (_) {}
  }

  String _fmtTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'م' : 'ص'}';
  }

  String _fmtCountdown(Duration d) {
    if (d.isNegative) return '00:00:00';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inHours)}:${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}';
  }

  String _spiritualTagline(String key) {
    switch (key) {
      case 'fajr':
        return 'مع نسيم الفجر 🌅، أقبِل على صلاتك في خشوع';
      case 'sunrise':
        return 'أشرقت الشمس ☀️، وقت صلاة الضحى وذكر الله';
      case 'dhuhr':
        return 'في منتصف النهار 🌤️، استرح بصلاتك مع الله';
      case 'asr':
        return 'حين تمتد الظلال ⛅، حافظوا على الصلاة الوسطى';
      case 'maghrib':
        return 'مع غروب الشمس 🌇، اختم نهارك بطاعة الله';
      case 'isha':
        return 'في سكون الليل 🌙، نورٌ وطمأنينة لقلبك';
      default:
        return 'حيّ على الصلاة، حيّ على الفلاح';
    }
  }

  List<Color> _skyColors(String key, bool isDark) {
    switch (key) {
      case 'fajr':
        return [const Color(0xFF1F3B64), const Color(0xFF5A5D8D), const Color(0xFFD68A6C)];
      case 'sunrise':
        return [const Color(0xFF2E5984), const Color(0xFF9C7A65), const Color(0xFFE7A95B)];
      case 'dhuhr':
        return [const Color(0xFF28587B), const Color(0xFF5386A6), const Color(0xFFD9A66C)];
      case 'asr':
        // Exact Nusuk-inspired warm dusk blue -> amber -> terracotta -> golden sand
        return [const Color(0xFF33597E), const Color(0xFF90745A), const Color(0xFFD77A49), const Color(0xFFC8995B)];
      case 'maghrib':
        return [const Color(0xFF282E54), const Color(0xFF8C495C), const Color(0xFFD97248)];
      case 'isha':
        return [const Color(0xFF0E1B2E), const Color(0xFF1C354D), const Color(0xFF3B4D5E)];
      default:
        return [const Color(0xFF33597E), const Color(0xFFD77A49), const Color(0xFFC8995B)];
    }
  }

  static String _hijriStr(DateTime g) {
    final h = HijriDate.fromGregorian(g);
    const m = [
      'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
      'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
    ];
    return '${h.day} ${(h.month >= 1 && h.month <= 12) ? m[h.month - 1] : m[0]} ${h.year}هـ';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0D0B) : const Color(0xFFF6F7F8);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final pt = _prayerTimes!;

    final elapsed = _totalDuration - _timeLeft;
    final progress = (_totalDuration.inSeconds > 0
            ? elapsed.inSeconds / _totalDuration.inSeconds
            : 0.5)
        .clamp(0.05, 0.95);

    final skyGradient = _skyColors(_nextPrayerKey, isDark);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Nusuk-Inspired Atmospheric Hero Header ──
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: skyGradient,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: skyGradient.last.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Subtle glowing radial orb in background
                    Positioned(
                      right: -40,
                      bottom: 20,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFFA756).withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 12,
                        bottom: 24,
                        left: 20,
                        right: 20,
                      ),
                      child: Column(
                        children: [
                          // Top App Bar Row
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: const DirectionalIcon(
                                    isBack: true,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      _hijriStr(DateTime.now()),
                                      style: _f(sz: 12, fw: FontWeight.w700, c: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _refreshPrayerTimes,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: const Icon(Icons.my_location_rounded, size: 18, color: Colors.white),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Quick Action Navigation Bar (Qibla, Azan, Prayer Info)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _HeroQuickNav(
                                  icon: Icons.explore_outlined,
                                  label: 'اتجاه القبلة',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const QiblaPage()),
                                  ),
                                ),
                                Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.15)),
                                _HeroQuickNav(
                                  icon: Icons.volume_up_outlined,
                                  label: 'إعدادات الأذان',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AzanSettingsPage()),
                                  ),
                                ),
                                Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.15)),
                                _HeroQuickNav(
                                  icon: Icons.mosque_outlined,
                                  label: 'مواقيت اليوم',
                                  onTap: _refreshPrayerTimes,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 26),

                          // Nusuk-Style Celestial Horizon Arc with Kaaba Emblem & Sun Indicator
                          SizedBox(
                            height: 220,
                            width: double.infinity,
                            child: AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (context, _) {
                                return Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Custom Painted Semi-Circle Arc + Sun Position Dot
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _CelestialArcPainter(
                                          progress: progress,
                                          glowValue: _pulseCtrl.value,
                                        ),
                                      ),
                                    ),
                                    // Top Center Kaaba Emblem Badge on the Arc Crest
                                    Positioned(
                                      top: 0,
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.18),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: _KaabaVectorIcon(size: 28, color: Color(0xFF1E293B)),
                                        ),
                                      ),
                                    ),
                                    // Center Prayer Name, Time & Spiritual Subtitle inside the Arc
                                    Positioned(
                                      top: 76,
                                      left: 24,
                                      right: 24,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '$_nextPrayerName  ${_nextPrayerTime != null ? _fmtTime(_nextPrayerTime!) : ''}',
                                            style: _f(
                                              sz: 27,
                                              fw: FontWeight.w800,
                                              c: Colors.white,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _spiritualTagline(_nextPrayerKey),
                                            style: _f(
                                              sz: 13,
                                              fw: FontWeight.w500,
                                              c: Colors.white.withValues(alpha: 0.90),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 14),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.22),
                                              borderRadius: BorderRadius.circular(24),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.timer_outlined, color: Color(0xFFFFD580), size: 16),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'متبقي ${_fmtCountdown(_timeLeft)}',
                                                  style: GoogleFonts.ibmPlexSansArabic(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 8),
                          // Handle bar indicator like Nusuk card bottom
                          Container(
                            width: 44,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Horizontal Iconic Strip (Nusuk-style white rounded icon cards) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151C18) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NusukActionCard(
                        icon: Icons.explore_rounded,
                        label: 'بوصلة القبلة',
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QiblaPage()),
                        ),
                      ),
                      _NusukActionCard(
                        icon: Icons.notifications_active_outlined,
                        label: 'صوت الأذان',
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AzanSettingsPage()),
                        ),
                      ),
                      _NusukActionCard(
                        icon: Icons.my_location_rounded,
                        label: 'تحديث الموقع',
                        isDark: isDark,
                        onTap: _refreshPrayerTimes,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Prayer Times List Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    Text('مواقيت الصلاة اليوم', style: _f(sz: 18, fw: FontWeight.w800, c: textColor)),
                    const Spacer(),
                    Text(
                      'حسب توقيتك المحلي',
                      style: _f(sz: 12, c: isDark ? Colors.white54 : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),

            // ── Prayer Times Rows ──
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _PrayerRow(
                    name: 'الفجر',
                    time: pt.fajr,
                    icon: Icons.wb_twilight_rounded,
                    isCurrent: _nextPrayerName == 'الفجر',
                    isDark: isDark,
                    fmt: _fmtTime,
                  ),
                  _PrayerRow(
                    name: 'الشروق',
                    time: pt.sunrise,
                    icon: Icons.wb_sunny_outlined,
                    isCurrent: _nextPrayerName == 'الشروق',
                    isDark: isDark,
                    fmt: _fmtTime,
                  ),
                  _PrayerRow(
                    name: 'الظهر',
                    time: pt.dhuhr,
                    icon: Icons.light_mode_rounded,
                    isCurrent: _nextPrayerName == 'الظهر',
                    isDark: isDark,
                    fmt: _fmtTime,
                  ),
                  _PrayerRow(
                    name: 'العصر',
                    time: pt.asr,
                    icon: Icons.wb_cloudy_outlined,
                    isCurrent: _nextPrayerName == 'العصر',
                    isDark: isDark,
                    fmt: _fmtTime,
                  ),
                  _PrayerRow(
                    name: 'المغرب',
                    time: pt.maghrib,
                    icon: Icons.wb_twilight_rounded,
                    isCurrent: _nextPrayerName == 'المغرب',
                    isDark: isDark,
                    fmt: _fmtTime,
                  ),
                  _PrayerRow(
                    name: 'العشاء',
                    time: pt.isha,
                    icon: Icons.nights_stay_rounded,
                    isCurrent: _nextPrayerName == 'العشاء',
                    isDark: isDark,
                    fmt: _fmtTime,
                  ),
                  const SizedBox(height: 36),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroQuickNav extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroQuickNav({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: _f(sz: 12, fw: FontWeight.w600, c: Colors.white.withValues(alpha: 0.92)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NusukActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _NusukActionCard({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2822) : const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Icon(
              icon,
              size: 26,
              color: isDark ? const Color(0xFFD4A843) : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: _f(
              sz: 12,
              fw: FontWeight.w700,
              c: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter that draws the Nusuk-style celestial horizon arc and glowing sun orb.
class _CelestialArcPainter extends CustomPainter {
  final double progress;
  final double glowValue;

  _CelestialArcPainter({required this.progress, required this.glowValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 16);
    final radius = min(size.width * 0.43, size.height - 44);

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Subtle background track arc (from pi to 2*pi, i.e., upper semi-circle)
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, pi, pi, false, trackPaint);

    // Highlighted progress arc from left (pi) to current progress
    final activePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final sweepAngle = pi * progress;
    canvas.drawArc(rect, pi, sweepAngle, false, activePaint);

    // Calculate Sun/Indicator position on the arc
    final sunAngle = pi + sweepAngle;
    final sunPos = Offset(
      center.dx + radius * cos(sunAngle),
      center.dy + radius * sin(sunAngle),
    );

    // Outer soft glow on sun dot
    final glowPaint = Paint()
      ..color = const Color(0xFFFFB347).withValues(alpha: 0.35 + 0.25 * glowValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(sunPos, 12, glowPaint);

    // White border circle + warm amber fill (matching Nusuk image)
    final sunFill = Paint()
      ..color = const Color(0xFFE58C3A)
      ..style = PaintingStyle.fill;
    final sunBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawCircle(sunPos, 9, sunFill);
    canvas.drawCircle(sunPos, 9, sunBorder);
  }

  @override
  bool shouldRepaint(covariant _CelestialArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.glowValue != glowValue;
}

/// Custom vector icon of the Kaaba matching the geometric emblem in the reference image.
class _KaabaVectorIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _KaabaVectorIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _KaabaEmblemPainter(color: color),
    );
  }
}

class _KaabaEmblemPainter extends CustomPainter {
  final Color color;
  _KaabaEmblemPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    // Top diamond roof of cube
    final topPath = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.88, h * 0.26)
      ..lineTo(w * 0.5, h * 0.44)
      ..lineTo(w * 0.12, h * 0.26)
      ..close();
    canvas.drawPath(topPath, paint);

    // Left face
    final leftPath = Path()
      ..moveTo(w * 0.12, h * 0.26)
      ..lineTo(w * 0.5, h * 0.44)
      ..lineTo(w * 0.5, h * 0.90)
      ..lineTo(w * 0.12, h * 0.72)
      ..close();
    canvas.drawPath(leftPath, paint);

    // Right face
    final rightPath = Path()
      ..moveTo(w * 0.88, h * 0.26)
      ..lineTo(w * 0.5, h * 0.44)
      ..lineTo(w * 0.5, h * 0.90)
      ..lineTo(w * 0.88, h * 0.72)
      ..close();
    canvas.drawPath(rightPath, paint);

    // Ornamental horizontal bands (Kiswah belt)
    final bandPaint = Paint()
      ..color = const Color(0xFFD4A843)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(w * 0.12, h * 0.42), Offset(w * 0.5, h * 0.60), bandPaint);
    canvas.drawLine(Offset(w * 0.5, h * 0.60), Offset(w * 0.88, h * 0.42), bandPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrayerRow extends StatelessWidget {
  final String name;
  final DateTime time;
  final IconData icon;
  final bool isCurrent;
  final bool isDark;
  final String Function(DateTime) fmt;
  const _PrayerRow({
    required this.name,
    required this.time,
    required this.icon,
    required this.isCurrent,
    required this.isDark,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD9883D);
    final cardBg = isCurrent
        ? (isDark ? const Color(0xFF282015) : const Color(0xFFFFF8F0))
        : (isDark ? const Color(0xFF151C18) : Colors.white);
    final textCol = isDark ? Colors.white : AppColors.textPrimary;
    final subCol = isDark ? Colors.white54 : AppColors.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? gold.withValues(alpha: 0.55)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          width: isCurrent ? 1.6 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: gold.withValues(alpha: 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCurrent
                  ? gold.withValues(alpha: 0.18)
                  : (isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF2F5F4)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: isCurrent ? gold : subCol, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: _f(
                    sz: 17,
                    fw: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    c: isCurrent ? (isDark ? Colors.white : const Color(0xFF9C5414)) : textCol,
                  ),
                ),
                if (isCurrent)
                  Text(
                    'الصلاة القادمة',
                    style: _f(sz: 11, fw: FontWeight.w600, c: gold),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isCurrent ? gold.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              fmt(time),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isCurrent ? gold : textCol,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
