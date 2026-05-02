import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class QiblaPage extends StatelessWidget {
  const QiblaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : AppColors.background;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(children: [
          // ── Header ──
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 20, left: 20, right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: isDark ? [const Color(0xFF0D3B26), const Color(0xFF145A3A)] : [AppColors.darkGreen, AppColors.midGreen]),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
            ),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
              Expanded(child: Text('اتجاه القبلة', textAlign: TextAlign.center, style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white))),
              const SizedBox(width: 48),
            ]),
          ),
          // ── Body ──
          Expanded(
            child: kIsWeb
                ? _buildUnsupported(isDark, textColor, true)
                : _buildCompass(isDark, textColor),
          ),
        ]),
      ),
    );
  }

  Widget _buildUnsupported(bool isDark, Color textColor, bool isWeb) {
    return Center(
      child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(color: (isDark ? Colors.red[900]! : Colors.red[50]!).withOpacity(0.5), shape: BoxShape.circle),
          child: Icon(Icons.sensors_off_rounded, size: 40, color: Colors.red[300])),
        const SizedBox(height: 24),
        Text('البوصلة غير متاحة', textAlign: TextAlign.center, style: _f(sz: 20, fw: FontWeight.w700, c: textColor)),
        const SizedBox(height: 12),
        Text(
          isWeb ? 'اتجاه القبلة غير مدعوم على متصفح الويب.\nيرجى استخدام التطبيق على هاتفك.'
                : 'تأكد أن جهازك يحتوي على بوصلة رقمية\nوأن الأذونات مفعّلة.',
          textAlign: TextAlign.center, style: _f(sz: 14, c: isDark ? Colors.white54 : AppColors.gray, h: 1.8)),
      ])),
    );
  }

  Widget _buildCompass(bool isDark, Color textColor) {
    return StreamBuilder<QiblahDirection>(
      stream: FlutterQiblah.qiblahStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: AppColors.darkGreen),
            const SizedBox(height: 16),
            Text('جاري تحديد الاتجاه...', style: _f(sz: 14, c: isDark ? Colors.white60 : AppColors.gray)),
          ]));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildUnsupported(isDark, textColor, false);
        }

        final q = snapshot.data!;
        final qiblaAngle = q.qiblah * (pi / 180) * -1;
        final compassAngle = q.direction * (pi / 180) * -1;
        final isAligned = (q.qiblah % 360).abs() < 5;

        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: isAligned ? AppColors.darkGreen.withOpacity(0.12) : (isDark ? Colors.white10 : const Color(0xFFF5F5F5)),
              borderRadius: BorderRadius.circular(14),
              border: isAligned ? Border.all(color: AppColors.darkGreen, width: 1.5) : null),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isAligned) Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.check_circle_rounded, color: AppColors.darkGreen, size: 20)),
              Text(isAligned ? 'أنت في اتجاه القبلة' : '${q.direction.toStringAsFixed(0)}°',
                style: _f(sz: isAligned ? 16 : 22, fw: FontWeight.w800, c: isAligned ? AppColors.darkGreen : (isDark ? Colors.white : AppColors.textPrimary))),
            ]),
          ),
          const SizedBox(height: 32),
          SizedBox(width: 280, height: 280, child: Stack(alignment: Alignment.center, children: [
            Transform.rotate(angle: compassAngle, child: CustomPaint(size: const Size(280, 280), painter: _CompassPainter(isDark: isDark))),
            Transform.rotate(angle: qiblaAngle, child: Column(children: [
              Icon(Icons.navigation_rounded, size: 50, color: isAligned ? AppColors.darkGreen : AppColors.gold),
              const SizedBox(height: 90),
            ])),
            Container(width: 56, height: 56,
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
              child: Icon(Icons.mosque_rounded, size: 28, color: isAligned ? AppColors.darkGreen : AppColors.gray)),
          ])),
          const SizedBox(height: 32),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(isAligned ? 'الاتجاه صحيح — توجّه للصلاة' : 'أدر هاتفك حتى يتجه السهم نحو القبلة',
              textAlign: TextAlign.center, style: _f(sz: 15, fw: FontWeight.w600, c: isAligned ? AppColors.darkGreen : (isDark ? Colors.white60 : AppColors.gray)))),
        ]);
      },
    );
  }
}

class _CompassPainter extends CustomPainter {
  final bool isDark;
  _CompassPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    canvas.drawCircle(center, radius - 4, Paint()..color = isDark ? Colors.white24 : Colors.black12..style = PaintingStyle.stroke..strokeWidth = 2);
    for (int i = 0; i < 360; i += 10) {
      final angle = i * pi / 180;
      final isMajor = i % 90 == 0;
      final isMinor = i % 30 == 0;
      final len = isMajor ? 16.0 : (isMinor ? 10.0 : 5.0);
      final tp = Paint()..color = isMajor ? (isDark ? Colors.white70 : Colors.black54) : (isDark ? Colors.white24 : Colors.black12)..strokeWidth = isMajor ? 2.5 : 1;
      canvas.drawLine(
        Offset(center.dx + (radius - 6) * cos(angle - pi / 2), center.dy + (radius - 6) * sin(angle - pi / 2)),
        Offset(center.dx + (radius - 6 - len) * cos(angle - pi / 2), center.dy + (radius - 6 - len) * sin(angle - pi / 2)), tp);
    }
    final labels = {'N': 0, 'E': 90, 'S': 180, 'W': 270};
    final arabic = {'N': 'ش', 'E': 'شر', 'S': 'ج', 'W': 'غ'};
    labels.forEach((key, deg) {
      final angle = deg * pi / 180 - pi / 2;
      final tp = TextPainter(text: TextSpan(text: arabic[key], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
        color: key == 'N' ? Colors.red[400] : (isDark ? Colors.white54 : Colors.black45))), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(center.dx + (radius - 32) * cos(angle) - tp.width / 2, center.dy + (radius - 32) * sin(angle) - tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
