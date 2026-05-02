import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import '../../core/app_colors.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({super.key});
  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> with SingleTickerProviderStateMixin {
  PrayerTimes? _prayerTimes;
  bool _loading = true;
  String? _error;
  String? _nextPrayerName;
  DateTime? _nextPrayerTime;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _fetchPrayerTimes();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_nextPrayerTime != null) {
        setState(() {
          _timeLeft = _nextPrayerTime!.difference(DateTime.now());
          if (_timeLeft.isNegative) _fetchPrayerTimes();
        });
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); _glowCtrl.dispose(); super.dispose(); }

  Future<void> _fetchPrayerTimes() async {
    setState(() { _loading = true; _error = null; });
    try {
      Position pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      final coords = Coordinates(pos.latitude, pos.longitude);
      final params = CalculationMethod.egyptian.getParameters()..madhab = Madhab.shafi;
      final pt = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
      final now = DateTime.now();
      String next = 'الفجر';
      DateTime nextTime = pt.fajr.add(const Duration(days: 1));
      if (now.isBefore(pt.fajr)) { next = 'الفجر'; nextTime = pt.fajr; }
      else if (now.isBefore(pt.sunrise)) { next = 'الشروق'; nextTime = pt.sunrise; }
      else if (now.isBefore(pt.dhuhr)) { next = 'الظهر'; nextTime = pt.dhuhr; }
      else if (now.isBefore(pt.asr)) { next = 'العصر'; nextTime = pt.asr; }
      else if (now.isBefore(pt.maghrib)) { next = 'المغرب'; nextTime = pt.maghrib; }
      else if (now.isBefore(pt.isha)) { next = 'العشاء'; nextTime = pt.isha; }
      setState(() { _prayerTimes = pt; _nextPrayerName = next; _nextPrayerTime = nextTime; _timeLeft = nextTime.difference(now); _loading = false; });
    } catch (e) {
      setState(() { _error = 'تعذر الحصول على أوقات الصلاة'; _loading = false; });
    }
  }

  String _fmtTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'م' : 'ص'}';
  }

  String _fmtCountdown(Duration d) {
    if (d.isNegative) return "00:00:00";
    String p(int n) => n.toString().padLeft(2, "0");
    return "${p(d.inHours)}:${p(d.inMinutes.remainder(60))}:${p(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7F6);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white60 : AppColors.textSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: _loading
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: AppColors.darkGreen),
                const SizedBox(height: 16),
                Text('جاري تحميل أوقات الصلاة...', style: _f(sz: 14, c: subColor)),
              ]))
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
                    const SizedBox(height: 12),
                    Text(_error!, style: _f(sz: 16, c: Colors.red[300])),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: _fetchPrayerTimes,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: Text('إعادة المحاولة', style: _f(c: Colors.white, fw: FontWeight.w600)),
                    ),
                  ]))
                : CustomScrollView(slivers: [
                    // ── Header ──
                    SliverToBoxAdapter(child: Container(
                      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 32, left: 20, right: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: isDark ? [const Color(0xFF0D2818), const Color(0xFF0A3D22)] : [const Color(0xFF145A3A), const Color(0xFF1E8255)]),
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                      ),
                      child: Column(children: [
                        Row(children: [
                          IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                          Expanded(child: Text('أوقات الصلاة', textAlign: TextAlign.center, style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white))),
                          const SizedBox(width: 48),
                        ]),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.2))),
                          child: Text('الصلاة القادمة', style: _f(sz: 12, fw: FontWeight.w600, c: Colors.white70)),
                        ),
                        const SizedBox(height: 12),
                        Text(_nextPrayerName ?? '', style: _f(sz: 34, fw: FontWeight.w900, c: Colors.white)),
                        const SizedBox(height: 6),
                        if (_nextPrayerTime != null)
                          Text(_fmtTime(_nextPrayerTime!), style: GoogleFonts.ibmPlexMono(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.goldLight)),
                        const SizedBox(height: 20),
                        AnimatedBuilder(animation: _glowAnim, builder: (ctx, _) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.gold.withOpacity(_glowAnim.value), width: 1.5),
                            boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(_glowAnim.value * 0.15), blurRadius: 20, spreadRadius: 2)],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.timer_outlined, color: AppColors.goldLight, size: 22),
                            const SizedBox(width: 12),
                            Text(_fmtCountdown(_timeLeft), style: GoogleFonts.ibmPlexMono(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
                          ]),
                        )),
                      ]),
                    )),
                    // ── Prayer List ──
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Text('مواقيت اليوم', style: _f(sz: 18, fw: FontWeight.w800, c: textColor)),
                    )),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(delegate: SliverChildListDelegate([
                        _PrayerRow(name: 'الفجر', time: _prayerTimes!.fajr, icon: Icons.wb_twilight_rounded, isCurrent: _nextPrayerName == 'الفجر', isDark: isDark, fmt: _fmtTime),
                        _PrayerRow(name: 'الشروق', time: _prayerTimes!.sunrise, icon: Icons.wb_sunny_rounded, isCurrent: _nextPrayerName == 'الشروق', isDark: isDark, fmt: _fmtTime),
                        _PrayerRow(name: 'الظهر', time: _prayerTimes!.dhuhr, icon: Icons.light_mode_rounded, isCurrent: _nextPrayerName == 'الظهر', isDark: isDark, fmt: _fmtTime),
                        _PrayerRow(name: 'العصر', time: _prayerTimes!.asr, icon: Icons.cloud_rounded, isCurrent: _nextPrayerName == 'العصر', isDark: isDark, fmt: _fmtTime),
                        _PrayerRow(name: 'المغرب', time: _prayerTimes!.maghrib, icon: Icons.wb_twilight_rounded, isCurrent: _nextPrayerName == 'المغرب', isDark: isDark, fmt: _fmtTime),
                        _PrayerRow(name: 'العشاء', time: _prayerTimes!.isha, icon: Icons.nights_stay_rounded, isCurrent: _nextPrayerName == 'العشاء', isDark: isDark, fmt: _fmtTime),
                        const SizedBox(height: 32),
                      ])),
                    ),
                  ]),
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final String name;
  final DateTime time;
  final IconData icon;
  final bool isCurrent;
  final bool isDark;
  final String Function(DateTime) fmt;
  const _PrayerRow({required this.name, required this.time, required this.icon, required this.isCurrent, required this.isDark, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.darkGreen;
    final cardBg = isCurrent ? (isDark ? accent.withOpacity(0.15) : accent.withOpacity(0.06)) : (isDark ? const Color(0xFF1A1F1C) : Colors.white);
    final textCol = isDark ? Colors.white : AppColors.textPrimary;
    final subCol = isDark ? Colors.white54 : AppColors.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? accent.withOpacity(isDark ? 0.5 : 0.3) : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)), width: isCurrent ? 1.5 : 1),
        boxShadow: isCurrent ? [BoxShadow(color: accent.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: isCurrent ? accent.withOpacity(isDark ? 0.3 : 0.12) : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF0F4F2)), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: isCurrent ? accent : subCol, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: _f(sz: 17, fw: isCurrent ? FontWeight.w800 : FontWeight.w600, c: isCurrent ? accent : textCol)),
          if (isCurrent) Text('الصلاة القادمة', style: _f(sz: 11, fw: FontWeight.w500, c: accent.withOpacity(0.7))),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: isCurrent ? accent.withOpacity(isDark ? 0.25 : 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Text(fmt(time), style: GoogleFonts.ibmPlexMono(fontSize: 15, fontWeight: FontWeight.w700, color: isCurrent ? accent : textCol)),
        ),
        if (isCurrent) ...[
          const SizedBox(width: 8),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: accent.withOpacity(0.5), blurRadius: 6)])),
        ],
      ]),
    );
  }
}
