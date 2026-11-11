import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/directional_icon.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> with SingleTickerProviderStateMixin {
  Future<bool>? _permissionFuture;
  bool _wasAligned = false;
  DateTime? _lastVibrateTime;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _permissionFuture = _checkLocationPermission();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<bool> _checkLocationPermission() async {
    if (kIsWeb) return false;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  void _triggerAlignmentHaptic(bool isAligned) {
    if (isAligned && !_wasAligned) {
      final now = DateTime.now();
      if (_lastVibrateTime == null ||
          now.difference(_lastVibrateTime!).inMilliseconds > 1200) {
        _lastVibrateTime = now;
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 120), () {
          HapticFeedback.vibrate();
        });
      }
    }
    _wasAligned = isAligned;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            // Atmospheric Nusuk-inspired gradient (Dusk Sky Blue -> Warm Amber -> Golden Sand)
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2B4D70),
                Color(0xFF7B6452),
                Color(0xFFCB7848),
                Color(0xFFC39457),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Atmospheric glowing sun/horizon backdrop
              Positioned(
                top: 120,
                right: -50,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFB259).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // ── Top Bar ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
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
                          Expanded(
                            child: Text(
                              'بوصلة القبلة',
                              textAlign: TextAlign.center,
                              style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.vibration_rounded, size: 18, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    // ── Main Content ──
                    Expanded(
                      child: kIsWeb
                          ? _buildUnsupported(isDark, true)
                          : FutureBuilder<bool>(
                              future: _permissionFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(color: Colors.white),
                                        const SizedBox(height: 16),
                                        Text(
                                          'جاري فحص أذونات الموقع...',
                                          style: _f(sz: 14, c: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                if (snapshot.hasError || !snapshot.hasData || snapshot.data == false) {
                                  return _buildUnsupported(isDark, false);
                                }
                                return _buildCompass(isDark);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnsupported(bool isDark, bool isWeb) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sensors_off_rounded, size: 38, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                'البوصلة غير متاحة',
                textAlign: TextAlign.center,
                style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                isWeb
                    ? 'اتجاه القبلة غير مدعوم على متصفح الويب.\nيرجى استخدام التطبيق على هاتفك.'
                    : 'تأكد أن جهازك يحتوي على بوصلة رقمية\nوأن أذونات الموقع مفعّلة.',
                textAlign: TextAlign.center,
                style: _f(sz: 14, c: Colors.white70, h: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompass(bool isDark) {
    return StreamBuilder<QiblahDirection>(
      stream: FlutterQiblah.qiblahStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Text('جاري تحديد اتجاه القبلة...', style: _f(sz: 14, c: Colors.white70)),
              ],
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildUnsupported(isDark, false);
        }

        final q = snapshot.data!;
        // Normalize angle difference to [-180, 180]
        double diff = (q.qiblah % 360);
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;
        final isAligned = diff.abs() <= 5.0;

        // Trigger vibration / haptic feedback when aligned toward Qibla
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _triggerAlignmentHaptic(isAligned);
        });

        final qiblaAngle = q.qiblah * (pi / 180) * -1;
        final compassAngle = q.direction * (pi / 180) * -1;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top Kaaba Badge & Status Pill
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: isAligned
                    ? const Color(0xFF1B7A4E).withValues(alpha: 0.90)
                    : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isAligned
                      ? const Color(0xFF6FCF97)
                      : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: isAligned
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1B7A4E).withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAligned ? Icons.check_circle_rounded : Icons.explore_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAligned
                        ? 'أنت الآن في اتجاه القبلة الصحيح 🕋'
                        : 'زاوية القبلة ${q.offset.toStringAsFixed(0)}° • اتجاهك ${q.direction.toStringAsFixed(0)}°',
                    style: _f(sz: 14, fw: FontWeight.w800, c: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Nusuk-Style Celestial Dial & Qibla Arc ──
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (context, _) {
                return SizedBox(
                  width: 310,
                  height: 310,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glowing aura when aligned
                      if (isAligned)
                        Container(
                          width: 295,
                          height: 295,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6FCF97)
                                    .withValues(alpha: 0.35 + 0.25 * _glowCtrl.value),
                                blurRadius: 36,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),

                      // Frosted glass dial backdrop
                      Container(
                        width: 284,
                        height: 284,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.18),
                          border: Border.all(
                            color: isAligned
                                ? const Color(0xFF6FCF97)
                                : Colors.white.withValues(alpha: 0.35),
                            width: isAligned ? 2.5 : 1.5,
                          ),
                        ),
                      ),

                      // Rotating Compass Rose ticks & Arabic cardinal directions
                      Transform.rotate(
                        angle: compassAngle,
                        child: CustomPaint(
                          size: const Size(270, 270),
                          painter: _NusukCompassPainter(isAligned: isAligned),
                        ),
                      ),

                      // Rotating Qibla Pointer with Kaaba Emblem on the rim (like Nusuk arc)
                      Transform.rotate(
                        angle: qiblaAngle,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Kaaba circle badge at the tip of the Qibla needle
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isAligned
                                      ? const Color(0xFF1B7A4E)
                                      : const Color(0xFFE58C3A),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: CustomPaint(
                                  size: const Size(26, 26),
                                  painter: _QiblaKaabaPainter(
                                    color: isAligned
                                        ? const Color(0xFF1B7A4E)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ),
                            // Golden / Green needle beam pointing from center to Kaaba
                            Container(
                              width: 3.5,
                              height: 68,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    isAligned
                                        ? const Color(0xFF6FCF97)
                                        : const Color(0xFFFFB347),
                                    Colors.white.withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),

                      // Center pivot hub
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${q.direction.toStringAsFixed(0)}°',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // Instruction card at bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAligned ? Icons.vibration_rounded : Icons.screen_rotation_rounded,
                      color: isAligned ? const Color(0xFF6FCF97) : const Color(0xFFFFD580),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        isAligned
                            ? 'اهتز الهاتف تأكيداً لمحاذاتك للقبلة الشريفة'
                            : 'أدر هاتفك بشكل مسطح حتى تتطابق أيقونة الكعبة مع الأعلى',
                        textAlign: TextAlign.center,
                        style: _f(sz: 13, fw: FontWeight.w600, c: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NusukCompassPainter extends CustomPainter {
  final bool isAligned;
  _NusukCompassPainter({required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 360; i += 6) {
      final angle = i * pi / 180;
      final isMajor = i % 90 == 0;
      final isMinor = i % 30 == 0;
      final len = isMajor ? 16.0 : (isMinor ? 10.0 : 5.0);
      final tp = Paint()
        ..color = isMajor
            ? Colors.white
            : (isMinor
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.25))
        ..strokeWidth = isMajor ? 2.5 : (isMinor ? 1.5 : 1.0)
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(
          center.dx + (radius - 8) * cos(angle - pi / 2),
          center.dy + (radius - 8) * sin(angle - pi / 2),
        ),
        Offset(
          center.dx + (radius - 8 - len) * cos(angle - pi / 2),
          center.dy + (radius - 8 - len) * sin(angle - pi / 2),
        ),
        tp,
      );
    }

    final labels = {'N': 0, 'E': 90, 'S': 180, 'W': 270};
    final arabic = {'N': 'ش', 'E': 'شر', 'S': 'ج', 'W': 'غ'};
    labels.forEach((key, deg) {
      final angle = deg * pi / 180 - pi / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: arabic[key],
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: key == 'N' ? const Color(0xFFFFB347) : Colors.white70,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          center.dx + (radius - 36) * cos(angle) - tp.width / 2,
          center.dy + (radius - 36) * sin(angle) - tp.height / 2,
        ),
      );
    });
  }

  @override
  bool shouldRepaint(covariant _NusukCompassPainter oldDelegate) =>
      oldDelegate.isAligned != isAligned;
}

class _QiblaKaabaPainter extends CustomPainter {
  final Color color;
  _QiblaKaabaPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    final topPath = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.88, h * 0.26)
      ..lineTo(w * 0.5, h * 0.44)
      ..lineTo(w * 0.12, h * 0.26)
      ..close();
    canvas.drawPath(topPath, paint);

    final leftPath = Path()
      ..moveTo(w * 0.12, h * 0.26)
      ..lineTo(w * 0.5, h * 0.44)
      ..lineTo(w * 0.5, h * 0.90)
      ..lineTo(w * 0.12, h * 0.72)
      ..close();
    canvas.drawPath(leftPath, paint);

    final rightPath = Path()
      ..moveTo(w * 0.88, h * 0.26)
      ..lineTo(w * 0.5, h * 0.44)
      ..lineTo(w * 0.5, h * 0.90)
      ..lineTo(w * 0.88, h * 0.72)
      ..close();
    canvas.drawPath(rightPath, paint);

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
