import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_colors.dart';

/// Countdown card for Ramadan 1, 1448 AH (Feb 8, 2027).
/// Deep teal → midnight purple gradient with an animated crescent moon
/// and star that pulses with a golden glow.
class RamadanCountdownCard extends StatefulWidget {
  const RamadanCountdownCard({super.key});

  static final DateTime ramadanStart = DateTime(2027, 2, 8);

  @override
  State<RamadanCountdownCard> createState() => _RamadanCountdownCardState();
}

class _RamadanCountdownCardState extends State<RamadanCountdownCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _remaining = RamadanCountdownCard.ramadanStart.difference(DateTime.now());
      if (_remaining.isNegative) _remaining = Duration.zero;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  void _share() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RamadanShareSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24);
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF0E4F5C), // deep teal
            Color(0xFF123B6E),
            Color(0xFF1B1440), // midnight purple
            Color(0xFF0B1030),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E4F5C).withValues(alpha: 0.4),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Ambient glow orbs
            Positioned(
              top: -40,
              left: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gold.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C4DFF).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Animated crescent moon + star with golden glow pulse
                      AnimatedBuilder(
                        animation: _glowCtrl,
                        builder: (_, __) => Transform.scale(
                          scale: 1.0 + _glowCtrl.value * 0.08,
                          child: CustomPaint(
                            size: const Size(64, 64),
                            painter: _CrescentStarPainter(
                              glow: _glowCtrl.value,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رمضان ١٤٤٨ هـ',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'يبدأ بحول الله في ٨ فبراير ٢٠٢٧',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          'قريباً',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.goldLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _share,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.share_rounded,
                            size: 16,
                            color: AppColors.goldLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Countdown units
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _unit(days, 'يوم', _remaining.inDays > 0),
                      _unit(hours, 'ساعة'),
                      _unit(minutes, 'دقيقة'),
                      _unit(seconds, 'ثانية'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 15,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'ترقّبوا مود رمضان بخصائص فريدة وتجربة روحية استثنائية',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stay tuned for a Ramadan theme with unique features and an exceptional spiritual experience.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.65),
                            height: 1.4,
                          ),
                        ),
                      ],
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

  Widget _unit(int value, String label, [bool highlight = false]) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlight
                ? AppColors.gold.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            _two(value),
            style: GoogleFonts.ibmPlexMono(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.goldLight : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

/// Draws a crescent moon with a four-point star and an animated golden glow.
class _CrescentStarPainter extends CustomPainter {
  final double glow;
  _CrescentStarPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // Golden glow halo (pulses with [glow])
    final haloPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.10 + glow * 0.14)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + glow * 8);
    canvas.drawCircle(center, size.width * 0.42, haloPaint);

    // Crescent moon
    final moonR = size.width * 0.30;
    final moonPaint = Paint()..color = const Color(0xFFF6D98A);
    canvas.drawCircle(
      center + Offset(-size.width * 0.03, -size.height * 0.02),
      moonR,
      moonPaint,
    );

    // Cut-out circle creates the crescent shape (matches card teal)
    final cutPaint = Paint()..color = const Color(0xFF0E4F5C);
    canvas.drawCircle(
      center + Offset(size.width * 0.08, -size.height * 0.07),
      moonR * 0.92,
      cutPaint,
    );

    // Soft gold edge on the lit limb
    final shadePaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(
      center + Offset(-size.width * 0.03, -size.height * 0.02),
      moonR,
      shadePaint,
    );

    // Four-point star
    final starCenter = center + Offset(size.width * 0.20, size.height * 0.16);
    final starR = size.width * 0.11;
    final starPaint = Paint()..color = AppColors.gold;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (math.pi / 4) * i - math.pi / 2;
      final r = i.isEven ? starR : starR * 0.38;
      final pt = Offset(
        starCenter.dx + r * math.cos(angle),
        starCenter.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, starPaint);
  }

  @override
  bool shouldRepaint(covariant _CrescentStarPainter old) => old.glow != glow;
}

/// Preview sheet shown before sharing — renders a minimal Ramadan card
/// containing only the prophetic dua and the app name, then shares it
/// as a PNG image.
class _RamadanShareSheet extends StatefulWidget {
  const _RamadanShareSheet();

  @override
  State<_RamadanShareSheet> createState() => _RamadanShareSheetState();
}

class _RamadanShareSheetState extends State<_RamadanShareSheet> {
  final GlobalKey _shareKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final boundary =
          _shareKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/ramadan_dua_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'اللهم بلغنا رمضان في عفو وعافية');
    } catch (_) {
      await Share.share(
        'اللهم بلغنا رمضان في عفو وعافية غير فاقدين ولا مفقودين\n\nتطبيق بصائر',
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _shareKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF0E4F5C),
                      Color(0xFF123B6E),
                      Color(0xFF1B1440),
                      Color(0xFF0B1030),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'اللهم بلغنا رمضان في عفو وعافية\nغير فاقدين ولا مفقودين',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 24,
                        height: 1.9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'تطبيق بصائر',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.goldLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSharing ? null : _share,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.share_rounded, size: 20),
                label: Text(
                  'مشاركة الصورة',
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
      ),
    );
  }
}
