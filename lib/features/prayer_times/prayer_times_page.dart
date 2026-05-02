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

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  PrayerTimes? _prayerTimes;
  bool _loading = true;
  String? _error;
  String? _currentPrayerName;
  DateTime? _nextPrayerTime;
  String? _nextPrayerName;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchPrayerTimes();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_nextPrayerTime != null) {
        setState(() {
          _timeLeft = _nextPrayerTime!.difference(DateTime.now());
          if (_timeLeft.isNegative) {
            _fetchPrayerTimes(); // Refresh if time passed
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPrayerTimes() async {
    setState(() { _loading = true; _error = null; });

    try {
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));

      final coordinates = Coordinates(position.latitude, position.longitude);
      final params = CalculationMethod.egyptian.getParameters();
      params.madhab = Madhab.shafi;

      final date = DateComponents.from(DateTime.now());
      final prayerTimes = PrayerTimes(coordinates, date, params);

      // Determine current and next prayer
      final now = DateTime.now();
      String current = 'العشاء';
      String next = 'الفجر';
      DateTime nextTime = prayerTimes.fajr.add(const Duration(days: 1)); // Default to tomorrow's fajr
      
      if (now.isBefore(prayerTimes.fajr)) {
        current = 'العشاء'; next = 'الفجر'; nextTime = prayerTimes.fajr;
      } else if (now.isBefore(prayerTimes.sunrise)) {
        current = 'الفجر'; next = 'الشروق'; nextTime = prayerTimes.sunrise;
      } else if (now.isBefore(prayerTimes.dhuhr)) {
        current = 'الشروق'; next = 'الظهر'; nextTime = prayerTimes.dhuhr;
      } else if (now.isBefore(prayerTimes.asr)) {
        current = 'الظهر'; next = 'العصر'; nextTime = prayerTimes.asr;
      } else if (now.isBefore(prayerTimes.maghrib)) {
        current = 'العصر'; next = 'المغرب'; nextTime = prayerTimes.maghrib;
      } else if (now.isBefore(prayerTimes.isha)) {
        current = 'المغرب'; next = 'العشاء'; nextTime = prayerTimes.isha;
      }

      setState(() {
        _prayerTimes = prayerTimes;
        _currentPrayerName = next; // The design highlights the NEXT prayer usually, or current. We'll highlight 'next' as the one we are waiting for.
        _nextPrayerName = next;
        _nextPrayerTime = nextTime;
        _timeLeft = nextTime.difference(now);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذر الحصول على أوقات الصلاة';
        _loading = false;
      });
    }
  }

  String _formatTime(DateTime time, {bool withAmPm = true}) {
    final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final m = time.minute.toString().padLeft(2, '0');
    final p = time.hour >= 12 ? 'PM' : 'AM';
    return withAmPm ? '$h:$m $p' : '$h:$m';
  }

  String _formatCountdown(Duration duration) {
    if (duration.isNegative) return "00:00:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String h = twoDigits(duration.inHours);
    String m = twoDigits(duration.inMinutes.remainder(60));
    String s = twoDigits(duration.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('أوقات الصلاة', style: _f(sz: 18, fw: FontWeight.w800, c: textColor)),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.darkGreen))
            : _error != null
                ? Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 12),
                      Text(_error!, style: _f(sz: 16, c: Colors.red[300])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen),
                        onPressed: _fetchPrayerTimes,
                        child: Text('إعادة المحاولة', style: _f(c: Colors.white)),
                      ),
                    ],
                  ))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Top Header
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left: Countdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('بعد', style: _f(sz: 16, fw: FontWeight.w600, c: isDark ? Colors.white70 : AppColors.gray)),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCountdown(_timeLeft),
                                      style: GoogleFonts.ibmPlexMono(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                  ],
                                ),
                                // Right: Next Prayer Info
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_nextPrayerName ?? '', style: _f(sz: 28, fw: FontWeight.bold, c: const Color(0xFF8B1538))), // Deep red/burgundy color
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(_nextPrayerTime!.hour >= 12 ? 'مساءً' : 'صباحاً', style: _f(sz: 20, fw: FontWeight.bold, c: textColor)),
                                        const SizedBox(width: 8),
                                        Text(_formatTime(_nextPrayerTime!, withAmPm: false), style: GoogleFonts.ibmPlexMono(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12, indent: 24, endIndent: 24),
                          
                          // Date
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text('التاريخ الهجري اليوم', style: _f(sz: 16, fw: FontWeight.w600, c: textColor)),
                            ),
                          ),
                          
                          // Horizontal Prayers List
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _PrayerColumn(name: 'الفجر', time: _prayerTimes!.fajr, icon: Icons.wb_twilight_rounded, isCurrent: _nextPrayerName == 'الفجر', isDark: isDark, formatTime: _formatTime),
                                  _PrayerColumn(name: 'الشروق', time: _prayerTimes!.sunrise, icon: Icons.wb_sunny_rounded, isCurrent: _nextPrayerName == 'الشروق', isDark: isDark, formatTime: _formatTime),
                                  _PrayerColumn(name: 'الظهر', time: _prayerTimes!.dhuhr, icon: Icons.light_mode_rounded, isCurrent: _nextPrayerName == 'الظهر', isDark: isDark, formatTime: _formatTime),
                                  _PrayerColumn(name: 'العصر', time: _prayerTimes!.asr, icon: Icons.cloud_rounded, isCurrent: _nextPrayerName == 'العصر', isDark: isDark, formatTime: _formatTime),
                                  _PrayerColumn(name: 'المغرب', time: _prayerTimes!.maghrib, icon: Icons.wb_twilight_rounded, isCurrent: _nextPrayerName == 'المغرب', isDark: isDark, formatTime: _formatTime),
                                  _PrayerColumn(name: 'العشاء', time: _prayerTimes!.isha, icon: Icons.nights_stay_rounded, isCurrent: _nextPrayerName == 'العشاء', isDark: isDark, formatTime: _formatTime),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Bottom Button
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0EBE1),
                              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.arrow_back_ios_rounded, size: 14),
                                const SizedBox(width: 8),
                                Text('المزيد من أوقات الصلاة', style: _f(sz: 16, fw: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _PrayerColumn extends StatelessWidget {
  final String name;
  final DateTime time;
  final IconData icon;
  final bool isCurrent;
  final bool isDark;
  final String Function(DateTime, {bool withAmPm}) formatTime;

  const _PrayerColumn({
    required this.name,
    required this.time,
    required this.icon,
    required this.isCurrent,
    required this.isDark,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF8B1538); // Deep red/burgundy matching the image
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent ? (isDark ? activeColor.withOpacity(0.1) : activeColor.withOpacity(0.05)) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? activeColor.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(name, style: _f(sz: 15, fw: isCurrent ? FontWeight.w800 : FontWeight.w600, c: isCurrent ? activeColor : textColor)),
          const SizedBox(height: 12),
          Icon(icon, color: isCurrent ? activeColor : textColor, size: 28),
          const SizedBox(height: 16),
          Text(
            formatTime(time),
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isCurrent ? activeColor : textColor,
            ),
          ),
        ],
      ),
    );
  }
}

