import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/directional_icon.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) =>
    GoogleFonts.ibmPlexSansArabic(
      fontSize: sz,
      fontWeight: fw,
      color: c,
      height: h,
    );

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage>
    with TickerProviderStateMixin {
  Future<bool>? _permissionFuture;
  bool _wasAligned = false;
  DateTime? _lastVibrateTime;
  late AnimationController _glowCtrl;
  late AnimationController _tiltCtrl;
  late AnimationController _needleCtrl;
  late Animation<double> _needleAnim;
  double _lastTurns = 0.0;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _tiltCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _needleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _needleAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _needleCtrl, curve: Curves.easeOutCubic),
    );

    _permissionFuture = _checkLocationPermission();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _tiltCtrl.dispose();
    _needleCtrl.dispose();
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

  void _updateNeedleAngle(double targetAngleDeg) {
    // targetAngle in degrees -> turns = angle / 360
    final targetTurns = (-targetAngleDeg / 360.0);
    double diff = (targetTurns - _lastTurns) % 1.0;
    if (diff > 0.5) diff -= 1.0;
    if (diff < -0.5) diff += 1.0;
    final newTurns = _lastTurns + diff;

    if ((newTurns - _lastTurns).abs() > 0.001) {
      _needleAnim = Tween<double>(begin: _lastTurns, end: newTurns).animate(
        CurvedAnimation(parent: _needleCtrl, curve: Curves.easeOutCubic),
      );
      _lastTurns = newTurns;
      _needleCtrl.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            // ── Feature 12: Sleek Modern Dark Gradient Background ──
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF060D17), // Deep midnight navy
                      Color(0xFF091C27), // Dark ocean teal
                      Color(0xFF07241A), // Deep emerald
                      Color(0xFF030A0E), // Obsidian base
                    ],
                  ),
                ),
              ),
            ),

            // ── Feature 12: Subtle Islamic Star & Geometric Pattern ──
            Positioned.fill(
              child: CustomPaint(
                painter: _GeometricStarBackdropPainter(),
              ),
            ),

            // Atmospheric glowing radial highlight behind the compass
            Positioned(
              top: MediaQuery.of(context).size.height * 0.28,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _glowCtrl,
                  builder: (context, _) {
                    return Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF1B7A4E).withOpacity(
                              0.20 + 0.10 * _glowCtrl.value,
                            ),
                            const Color(0xFFD4A843).withOpacity(0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Foreground UI ──
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
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.20),
                              ),
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
                            'بوصلة القبلة ثلاثية الأبعاد',
                            textAlign: TextAlign.center,
                            style: _f(
                              sz: 19,
                              fw: FontWeight.w800,
                              c: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.20),
                            ),
                          ),
                          child: const Icon(
                            Icons.vibration_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Main Compass Body ──
                  Expanded(
                    child: kIsWeb
                        ? _buildUnsupported(isDark, true)
                        : FutureBuilder<bool>(
                            future: _permissionFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        color: Color(0xFF6FCF97),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'جاري فحص أذونات الموقع...',
                                        style: _f(sz: 14, c: Colors.white70),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              if (snapshot.hasError ||
                                  !snapshot.hasData ||
                                  snapshot.data == false) {
                                return _buildUnsupported(isDark, false);
                              }
                              return _build3DCompass(isDark);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
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
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sensors_off_rounded,
                  size: 38,
                  color: Colors.white,
                ),
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
                    ? 'اتجاه القبلة غير مدعوم على متصفح الويب.\nيرجى استخدام التطبيق على هاتفك المحمول.'
                    : 'تأكد أن جهازك يحتوي على مستشعر البوصلة الرقمية\nوأن أذونات الموقع مفعّلة.',
                textAlign: TextAlign.center,
                style: _f(sz: 14, c: Colors.white70, h: 1.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DCompass(bool isDark) {
    return StreamBuilder<QiblahDirection>(
      stream: FlutterQiblah.qiblahStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF6FCF97)),
                const SizedBox(height: 16),
                Text(
                  'جاري تحديد اتجاه القبلة...',
                  style: _f(sz: 14, c: Colors.white70),
                ),
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

        // Animate needle turns
        _updateNeedleAngle(q.qiblah);

        // Alignment haptic trigger
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _triggerAlignmentHaptic(isAligned);
        });

        final compassAngle = q.direction * (pi / 180) * -1;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Alignment Status Pill ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: isAligned
                    ? const Color(0xFF1B7A4E).withOpacity(0.92)
                    : Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isAligned
                      ? const Color(0xFF6FCF97)
                      : Colors.white.withOpacity(0.22),
                  width: isAligned ? 1.8 : 1.2,
                ),
                boxShadow: isAligned
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1B7A4E).withOpacity(0.6),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAligned
                        ? Icons.check_circle_rounded
                        : Icons.explore_rounded,
                    color: isAligned
                        ? const Color(0xFF6FCF97)
                        : const Color(0xFFFFD580),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAligned
                        ? 'أنت الآن في اتجاه القبلة الشريفة 🕋'
                        : 'زاوية القبلة ${q.offset.toStringAsFixed(0)}° • اتجاهك ${q.direction.toStringAsFixed(0)}°',
                    style: _f(
                      sz: 14,
                      fw: FontWeight.w800,
                      c: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Feature 12: 3D Compass Housing & 3D Needle ──
            AnimatedBuilder(
              animation: Listenable.merge([_glowCtrl, _tiltCtrl, _needleAnim]),
              builder: (context, _) {
                // Dynamic tilt calculation for 3D perspective
                final tiltX = 0.22 + 0.04 * sin(_tiltCtrl.value * pi);
                final tiltY = 0.03 * cos(_tiltCtrl.value * pi);

                return SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer 3D glow aura when aligned
                      if (isAligned)
                        Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6FCF97).withOpacity(
                                  0.35 + 0.25 * _glowCtrl.value,
                                ),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),

                      // 3D Bevelled Dial Housing (applied perspective tilt)
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0018) // perspective
                          ..rotateX(tiltX)
                          ..rotateY(tiltY),
                        child: Container(
                          width: 290,
                          height: 290,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFF0E1A16),
                                Color(0xFF091410),
                                Color(0xFF040A07),
                              ],
                            ),
                            border: Border.all(
                              color: isAligned
                                  ? const Color(0xFF6FCF97)
                                  : const Color(0xFFD4A843).withOpacity(0.65),
                              width: isAligned ? 3.0 : 2.0,
                            ),
                            boxShadow: [
                              // 3D depth shadows
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 28,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: (isAligned
                                        ? const Color(0xFF6FCF97)
                                        : const Color(0xFFD4A843))
                                    .withOpacity(0.18),
                                blurRadius: 16,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Rotating Compass Rose (applied perspective tilt)
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0018)
                          ..rotateX(tiltX)
                          ..rotateY(tiltY),
                        child: Transform.rotate(
                          angle: compassAngle,
                          child: CustomPaint(
                            size: const Size(276, 276),
                            painter: _3DCompassRosePainter(
                              isAligned: isAligned,
                            ),
                          ),
                        ),
                      ),

                      // ── Feature 12: 3D Needle using Transform.perspective + RotationTransition ──
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0022) // perspective depth
                          ..rotateX(tiltX + 0.04) // distinct 3D tilt on needle
                          ..rotateY(tiltY),
                        child: RotationTransition(
                          turns: _needleAnim,
                          child: _3DNeedleWidget(isAligned: isAligned),
                        ),
                      ),

                      // Center 3D Pivot Hub
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0018)
                          ..rotateX(tiltX)
                          ..rotateY(tiltY),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF3A5A4A),
                                Color(0xFF132A1F),
                                Color(0xFF09140E),
                              ],
                            ),
                            border: Border.all(
                              color: isAligned
                                  ? const Color(0xFF6FCF97)
                                  : const Color(0xFFD4A843),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
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
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Instruction card at bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAligned
                          ? Icons.vibration_rounded
                          : Icons.screen_rotation_rounded,
                      color: isAligned
                          ? const Color(0xFF6FCF97)
                          : const Color(0xFFFFD580),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        isAligned
                            ? 'اهتز الهاتف تأكيداً لمحاذاتك للقبلة المشرفة'
                            : 'أدر هاتفك بشكل مسطح حتى تطابق أيقونة الكعبة مع السهم الأخضر',
                        textAlign: TextAlign.center,
                        style: _f(
                          sz: 13,
                          fw: FontWeight.w600,
                          c: Colors.white,
                        ),
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

/// 3D Needle widget with dual-tone shading, shadow, and Kaaba badge.
class _3DNeedleWidget extends StatelessWidget {
  final bool isAligned;

  const _3DNeedleWidget({required this.isAligned});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kaaba badge on needle crest with 3D elevation
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
                color: Colors.black.withOpacity(0.40),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              if (isAligned)
                BoxShadow(
                  color: const Color(0xFF6FCF97).withOpacity(0.5),
                  blurRadius: 12,
                ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(26, 26),
              painter: _QiblaKaaba3DPainter(
                color: isAligned
                    ? const Color(0xFF1B7A4E)
                    : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),

        // 3D Bevelled Needle Spine (Dual Tone Light/Dark to create 3D ridge)
        SizedBox(
          width: 20,
          height: 74,
          child: CustomPaint(
            painter: _3DNeedleSpinePainter(isAligned: isAligned),
          ),
        ),

        const SizedBox(height: 110),
      ],
    );
  }
}

/// Painter for the 3D-bevelled dual-tone needle spine.
class _3DNeedleSpinePainter extends CustomPainter {
  final bool isAligned;

  _3DNeedleSpinePainter({required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Shadow under the needle
    final shadowPath = Path()
      ..moveTo(cx + 2, 4)
      ..lineTo(w - 2, h - 2)
      ..lineTo(2, h - 2)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Left facet (highlighted / lighter side of 3D needle)
    final leftPath = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx, h)
      ..lineTo(2, h)
      ..close();
    final leftPaint = Paint()
      ..color = isAligned ? const Color(0xFF86E3A8) : const Color(0xFFFFD580)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leftPath, leftPaint);

    // Right facet (shadowed / darker side of 3D needle)
    final rightPath = Path()
      ..moveTo(cx, 0)
      ..lineTo(w - 2, h)
      ..lineTo(cx, h)
      ..close();
    final rightPaint = Paint()
      ..color = isAligned ? const Color(0xFF2E9A60) : const Color(0xFFE58C3A)
      ..style = PaintingStyle.fill;
    canvas.drawPath(rightPath, rightPaint);

    // Center ridge line
    final ridgePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx, 0), Offset(cx, h), ridgePaint);
  }

  @override
  bool shouldRepaint(covariant _3DNeedleSpinePainter oldDelegate) =>
      oldDelegate.isAligned != isAligned;
}

/// Custom painter for the 3D compass rose (ticks and cardinal letters).
class _3DCompassRosePainter extends CustomPainter {
  final bool isAligned;

  _3DCompassRosePainter({required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 360; i += 6) {
      final angle = i * pi / 180;
      final isMajor = i % 90 == 0;
      final isMinor = i % 30 == 0;
      final len = isMajor ? 16.0 : (isMinor ? 10.0 : 5.0);

      final p = Paint()
        ..color = isMajor
            ? (isAligned ? const Color(0xFF6FCF97) : const Color(0xFFD4A843))
            : (isMinor
                ? Colors.white.withOpacity(0.55)
                : Colors.white.withOpacity(0.20))
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
        p,
      );
    }

    final arabicLabels = {'N': 'ش', 'E': 'شر', 'S': 'ج', 'W': 'غ'};
    final angles = {'N': 0, 'E': 90, 'S': 180, 'W': 270};

    angles.forEach((key, deg) {
      final angle = deg * pi / 180 - pi / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: arabicLabels[key],
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: key == 'N'
                ? (isAligned
                    ? const Color(0xFF6FCF97)
                    : const Color(0xFFFFB347))
                : Colors.white.withOpacity(0.70),
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
  bool shouldRepaint(covariant _3DCompassRosePainter oldDelegate) =>
      oldDelegate.isAligned != isAligned;
}

/// Custom Kaaba vector icon painter with golden Kiswah belt.
class _QiblaKaaba3DPainter extends CustomPainter {
  final Color color;

  _QiblaKaaba3DPainter({required this.color});

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

    // Kiswah golden band
    final bandPaint = Paint()
      ..color = const Color(0xFFD4A843)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(w * 0.12, h * 0.42),
      Offset(w * 0.5, h * 0.60),
      bandPaint,
    );
    canvas.drawLine(
      Offset(w * 0.5, h * 0.60),
      Offset(w * 0.88, h * 0.42),
      bandPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Feature 12: Subtle Islamic Star & Geometric Lattice Backdrop CustomPainter.
class _GeometricStarBackdropPainter extends CustomPainter {
  static final _rng = Random(77);
  static final List<Offset> _stars = List.generate(
    45,
    (_) => Offset(_rng.nextDouble(), _rng.nextDouble()),
  );
  static final List<double> _radii = List.generate(
    45,
    (_) => _rng.nextDouble() * 1.8 + 0.5,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle night stars
    final starPaint = Paint()..color = Colors.white.withOpacity(0.22);
    for (int i = 0; i < _stars.length; i++) {
      canvas.drawCircle(
        Offset(_stars[i].dx * size.width, _stars[i].dy * size.height),
        _radii[i],
        starPaint,
      );
    }

    // 2. Draw subtle Islamic 8-point geometric rosette patterns
    final geomPaint = Paint()
      ..color = const Color(0xFFD4A843).withOpacity(0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height * 0.48);
    _drawIslamicStar(canvas, center, 140, geomPaint);
    _drawIslamicStar(canvas, center, 220, geomPaint);
    _drawIslamicStar(canvas, center, 300, geomPaint);
  }

  void _drawIslamicStar(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const points = 8;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.70;
      final angle = i * pi / points - pi / 2;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
