import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RamadanPage extends StatelessWidget {
  const RamadanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D22),
        appBar: AppBar(
          backgroundColor: const Color(0xFF10132E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'مود رمضان',
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsetsDirectional.only(end: 18),
              child: Icon(Icons.nights_stay_rounded, color: Color(0xFFFFD98A)),
            ),
          ],
        ),
        body: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF10132E),
                      Color(0xFF17183B),
                      Color(0xFF0A1025),
                    ],
                    stops: [0, 0.52, 1],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _RamadanStarsPainter()),
              ),
            ),
            SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  _buildRamadanHero(context),
                  const SizedBox(height: 18),
                  _buildComingSoonCard(context),
                  const SizedBox(height: 14),
                  _buildDuaCard(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRamadanHero(BuildContext context) {
    return Container(
      height: 350,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF24245B), Color(0xFF3B245F), Color(0xFF151B3E)],
        ),
        border: Border.all(
          color: const Color(0xFFFFD98A).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF08091A).withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _RamadanMotifPainter()),
          ),
          Positioned(
            top: 26,
            right: 24,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD98A).withValues(alpha: 0.32),
                    blurRadius: 38,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const CustomPaint(painter: _CrescentPainter()),
            ),
          ),
          const Positioned(
            top: -4,
            left: 28,
            child: _RamadanLantern(height: 124, width: 66),
          ),
          const Positioned(
            bottom: 10,
            right: 34,
            child: _RamadanLantern(height: 104, width: 54),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 126, 24, 22),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD98A).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'أجواء رمضانية',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: const Color(0xFFFFE6B0),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ليالٍ تُزهر بالقرآن',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'استقبل شهر الرحمة بقلبٍ مطمئن ونيّة صادقة',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFFFD98A),
                        size: 16,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'اللهم بلّغنا رمضان',
                        style: GoogleFonts.amiri(
                          color: const Color(0xFFFFD98A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFFFD98A),
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171B39).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD98A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFFFFD98A),
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'قريبًا في مود رمضان',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFFFFD98A),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'مساحة خاصة تساعدك على عيش أيام الشهر ولياليه بالقرآن والذكر والعبادة.',
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _RamadanTag(icon: Icons.menu_book_rounded, label: 'ورد القرآن'),
              _RamadanTag(icon: Icons.nightlight_round, label: 'قيام الليل'),
              _RamadanTag(icon: Icons.favorite_rounded, label: 'أذكار'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDuaCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF604B76).withValues(alpha: 0.48),
            const Color(0xFF28274D).withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD98A).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.volunteer_activism_rounded,
            color: Color(0xFFFFD98A),
            size: 23,
          ),
          const SizedBox(height: 8),
          Text(
            '«اللهم أعنّا فيه على الصيام والقيام وغضّ البصر وحفظ اللسان»',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              color: Colors.white,
              fontSize: 17,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _RamadanTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RamadanTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFD98A), size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RamadanLantern extends StatelessWidget {
  final double height;
  final double width;

  const _RamadanLantern({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _LanternPainter()),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  const _CrescentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final moon = Path()
      ..addOval(Rect.fromLTWH(8, 8, size.width * 0.76, size.height * 0.76));
    final cutout = Path()
      ..addOval(
        Rect.fromLTWH(
          size.width * 0.42,
          0,
          size.width * 0.68,
          size.height * 0.68,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, moon, cutout);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF1C9), Color(0xFFFFC85A)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;
    canvas.drawPath(crescent, paint);
  }

  @override
  bool shouldRepaint(covariant _CrescentPainter oldDelegate) => false;
}

class _LanternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFA52F).withValues(alpha: 0.32),
              const Color(0xFFFFA52F).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(center, size.height * 0.62),
              radius: size.width * 0.72,
            ),
          );
    canvas.drawCircle(
      Offset(center, size.height * 0.62),
      size.width * 0.72,
      glow,
    );

    final gold = Paint()
      ..color = const Color(0xFFFFD98A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(center, 0), Offset(center, 20), gold);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center, 22), width: 15, height: 8),
      math.pi,
      math.pi,
      false,
      gold,
    );

    final body = Path()
      ..moveTo(size.width * 0.3, size.height * 0.25)
      ..lineTo(size.width * 0.7, size.height * 0.25)
      ..lineTo(size.width * 0.87, size.height * 0.72)
      ..lineTo(size.width * 0.68, size.height * 0.86)
      ..lineTo(size.width * 0.32, size.height * 0.86)
      ..lineTo(size.width * 0.13, size.height * 0.72)
      ..close();
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE3A0), Color(0xFFD58A36), Color(0xFF7C3A45)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(body, bodyPaint);
    canvas.drawPath(body, gold);

    final glass = Path()
      ..moveTo(size.width * 0.38, size.height * 0.32)
      ..lineTo(size.width * 0.62, size.height * 0.32)
      ..lineTo(size.width * 0.75, size.height * 0.69)
      ..lineTo(size.width * 0.25, size.height * 0.69)
      ..close();
    canvas.drawPath(
      glass,
      Paint()..color = const Color(0xFFFFD778).withValues(alpha: 0.62),
    );
    canvas.drawPath(glass, gold);
    canvas.drawLine(
      Offset(center, size.height * 0.31),
      Offset(center, size.height * 0.7),
      Paint()
        ..color = const Color(0xFFFFF0B7).withValues(alpha: 0.8)
        ..strokeWidth = 1.4,
    );
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.74),
      Offset(size.width * 0.78, size.height * 0.74),
      gold,
    );
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.88),
      Offset(size.width * 0.68, size.height * 0.88),
      gold,
    );
    canvas.drawCircle(
      Offset(center, size.height * 0.94),
      2,
      Paint()..color = const Color(0xFFFFD98A),
    );
  }

  @override
  bool shouldRepaint(covariant _LanternPainter oldDelegate) => false;
}

class _RamadanStarsPainter extends CustomPainter {
  const _RamadanStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < 55; index++) {
      final x = ((index * 73 + 19) % 997) / 997 * size.width;
      final y = ((index * 137 + 41) % 991) / 991 * size.height;
      final radius = index % 7 == 0 ? 1.4 : 0.7;
      final alpha = index % 3 == 0 ? 0.65 : 0.32;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = const Color(0xFFFFE6AF).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RamadanStarsPainter oldDelegate) => false;
}

class _RamadanMotifPainter extends CustomPainter {
  const _RamadanMotifPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFE8B7).withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height * 0.48);
    for (var ring = 0; ring < 4; ring++) {
      final radius = 72.0 + ring * 22;
      final path = Path();
      for (var point = 0; point <= 8; point++) {
        final angle = math.pi / 4 * point - math.pi / 2;
        final offset = Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        );
        if (point == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RamadanMotifPainter oldDelegate) => false;
}
