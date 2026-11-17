import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

/// Rawdah (الروضة) — the green area around the Kaaba in Masjid al-Haram,
/// where the Prophet ﷺ said prayer there is better than a thousand prayers
/// elsewhere. Feature is under active development.
class RawdahPage extends StatelessWidget {
  const RawdahPage({super.key});

  static const List<Map<String, String>> _virtues = [
    {
      'title': 'فضل الروضة',
      'body':
          'قال النبي ﷺ: «ما بين بيتي ومنبري روضة من رياض الجنة» — رواه البخاري. الصلاة فيها تعادل ألف صلاة فيما سواها.',
    },
    {
      'title': 'دعاء في الروضة',
      'body':
          '«اللهم إن بيتك عظيم ووجهك كريم وإنك حليم كريم تحب العفو فاعف عنا» — من أدعية السلف في الروضة.',
    },
    {
      'title': 'عمرة وذكر',
      'body':
          'تُسنّ العمرة والصلاة في الروضة خاصة، مع الإكثار من الصلاة على النبي ﷺ.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D2818),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D2818),
          foregroundColor: Colors.white,
          title: Text(
            '🌿 الروضة',
            style: GoogleFonts.ibmPlexSansArabic(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.darkGreen.withValues(alpha: 0.9),
                    const Color(0xFF0D2818),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                children: [
                  const Text('🕋', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 10),
                  Text(
                    'الروضة الشريفة',
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'بين مقام إبراهيم والحجر الأسود\nفي المسجد الحرام بمكة المكرمة',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.ibmPlexSansArabic(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'ميزة تفاعلية قيد التطوير 🌙',
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.goldLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ..._virtues.map(
              (v) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v['title']!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: AppColors.goldLight,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      v['body']!,
                      style: GoogleFonts.ibmPlexSansArabic(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
