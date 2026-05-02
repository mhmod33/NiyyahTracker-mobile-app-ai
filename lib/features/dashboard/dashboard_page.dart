import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../worship/worship_page.dart';
import '../goals/goals_page.dart';
import '../plan/smart_plan_page.dart';
import '../analytics/analytics_page.dart';
import '../reports/reports_page.dart';
import '../ramadan/ramadan_page.dart';
import '../hajj/hajj_page.dart';
import '../map/nearby_mosques_page.dart';
import '../profile/profile_page.dart';
import '../friday/friday_tips_page.dart';
import '../azkar/azkar_counter_page.dart';
import '../prayer_times/prayer_times_page.dart';
import '../qibla/qibla_page.dart';
import '../challenges/challenges_page.dart';
import '../quran/quran_page.dart';
import '../azkar/azkar_library_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  void _onNavTap(int index) {
    if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyMosquesPage()));
      return;
    }
    if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
      return;
    }
    setState(() => _currentIndex = index);
  }

  String _getArabicDate() {
    final now = DateTime.now();
    final days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${days[now.weekday - 1]}، ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: AppColors.cardBg,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'النية',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    color: AppColors.darkGreen,
                    fontSize: 20,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.paleGreen,
                        AppColors.background,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.darkGreen.withOpacity(0.1),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Slogan
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.darkGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'وإنما لكل امرئ ما نوى',
                            style: GoogleFonts.cairo(
                              color: AppColors.darkGreen,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getArabicDate(),
                          style: GoogleFonts.cairo(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Menu Grid ──
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.1,
                children: [
                  _MenuCard(
                    title: 'عبادات اليوم',
                    icon: '📿',
                    color: const Color(0xFFE8F8EF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorshipPage())),
                  ),
                  _MenuCard(
                    title: 'أهدافي',
                    icon: '🎯',
                    color: const Color(0xFFFFFBF0),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage())),
                  ),
                  _MenuCard(
                    title: 'الخطة الذكية',
                    icon: '📅',
                    color: const Color(0xFFEFF6FF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartPlanPage())),
                  ),
                  _MenuCard(
                    title: 'التحليلات',
                    icon: '📊',
                    color: const Color(0xFFF5F3FF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsPage())),
                  ),
                  _MenuCard(
                    title: 'تقرير الروح',
                    icon: '📄',
                    color: const Color(0xFFFFF7ED),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage())),
                  ),
                  _MenuCard(
                    title: 'مود رمضان',
                    icon: '🌙',
                    color: const Color(0xFFEEF2FF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RamadanPage())),
                  ),
                  _MenuCard(
                    title: 'مود الحج',
                    icon: '🕋',
                    color: const Color(0xFFF8FAFC),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HajjPage())),
                  ),
                  _MenuCard(
                    title: 'المساجد القريبة',
                    icon: '🕌',
                    color: const Color(0xFFE8F8EF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyMosquesPage())),
                  ),
                  // ── New features ──
                  _MenuCard(
                    title: 'عدّاد الأذكار',
                    icon: '📿',
                    color: const Color(0xFFFDF3D7),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarCounterPage())),
                  ),
                  _MenuCard(
                    title: 'سنن الجمعة',
                    icon: '🌟',
                    color: const Color(0xFFEFF6FF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FridayTipsPage())),
                  ),
                  _MenuCard(
                    title: 'أوقات الصلاة',
                    icon: '🕌',
                    color: const Color(0xFFE0F2FE),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerTimesPage())),
                  ),
                  _MenuCard(
                    title: 'القبلة',
                    icon: '🧭',
                    color: const Color(0xFFF1F5F9),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QiblaPage())),
                  ),
                  _MenuCard(
                    title: 'التحديات',
                    icon: '🏆',
                    color: const Color(0xFFFEF3C7),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengesPage())),
                  ),
                  _MenuCard(
                    title: 'المصحف',
                    icon: '📖',
                    color: const Color(0xFFECFDF5),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranPage())),
                  ),
                  _MenuCard(
                    title: 'مكتبة الأذكار',
                    icon: '🤲',
                    color: const Color(0xFFFDF2F8),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarLibraryPage())),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex.clamp(0, 1),
            onTap: _onNavTap,
            selectedItemColor: AppColors.darkGreen,
            unselectedItemColor: AppColors.gray,
            backgroundColor: Colors.transparent,
            elevation: 0,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 12),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'الخطة'),
              BottomNavigationBarItem(icon: Icon(Icons.mosque_outlined), label: 'المساجد'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu Card (light theme) ──
class _MenuCard extends StatelessWidget {
  final String title;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 38)),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
