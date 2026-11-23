import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import '../core/app_colors.dart';
import '../features/azkar/azkar_counter_page.dart';

class AzkarReminderService {
  static final AzkarReminderService _instance = AzkarReminderService._internal();
  factory AzkarReminderService() => _instance;
  AzkarReminderService._internal();

  static GlobalKey<NavigatorState>? navigatorKey;

  bool _isShowing = false;

  /// Checks if a reminder should be shown right now.
  /// Morning: 7am - 12pm (7 <= hour < 12)
  /// Evening: 3pm - 7pm (15 <= hour < 19)
  Future<void> checkAndShowReminder() async {
    if (_isShowing) return;

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hour = now.hour;

    final isMorningTime = hour >= 7 && hour < 12;
    final isEveningTime = hour >= 15 && hour < 19;

    if (!isMorningTime && !isEveningTime) return;

    try {
      final box = Hive.isBoxOpen('settings') ? Hive.box('settings') : await Hive.openBox('settings');

      if (isMorningTime) {
        final lastMorning = box.get('last_morning_reminder_date');
        if (lastMorning == todayKey) return;

        await box.put('last_morning_reminder_date', todayKey);
        _showReminderBottomSheet(isMorning: true);
      } else if (isEveningTime) {
        final lastEvening = box.get('last_evening_reminder_date');
        if (lastEvening == todayKey) return;

        await box.put('last_evening_reminder_date', todayKey);
        _showReminderBottomSheet(isMorning: false);
      }
    } catch (_) {}
  }

  void _showReminderBottomSheet({
    required bool isMorning,
  }) {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;

    _isShowing = true;

    final title = isMorning ? 'أذكار الصباح' : 'أذكار المساء';
    final subtitle = isMorning
        ? 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ\nابدأ يومك ببركة وحفظ وأجر عظيم'
        : 'حان وقت أذكار المساء وراحة النفس\nحصّن نفسك وبارك ليلتك بذكر الله';
    final categoryKey = isMorning ? 'أذكار الصباح' : 'أذكار المساء';
    final icon = isMorning ? '☀️' : '🌙';

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B221E) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Green Gradient Header ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D2818), Color(0xFF165B33), Color(0xFF1B4332)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: Center(
                            child: Text(icon, style: const TextStyle(fontSize: 30)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Body content ──
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 15,
                            height: 1.7,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // ── Open Azkar Button ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.darkGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.menu_book_rounded, color: AppColors.gold),
                            label: Text(
                              'فتح الأذكار',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => AzkarCounterPage(categoryKey: categoryKey),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: Text(
                            'تذكير لاحقاً',
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: isDark ? Colors.white54 : AppColors.gray,
                              fontSize: 13,
                            ),
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
      },
    ).whenComplete(() {
      _isShowing = false;
    });
  }
}
