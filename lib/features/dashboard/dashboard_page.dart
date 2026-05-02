import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/theme_provider.dart';
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

  String _getArabicDate() {
    final now = DateTime.now();
    final days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${days[now.weekday - 1]}، ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : AppColors.cardBg;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subTextColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 24, left: 20, right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF0D3B26), const Color(0xFF145A3A)]
                        : [AppColors.darkGreen, AppColors.midGreen],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    // Top row: logo + profile
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'السلام عليكم 👋',
                                style: GoogleFonts.cairo(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'النية',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 26),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Slogan card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'وإنما لكل امرئ ما نوى',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getArabicDate(),
                            style: GoogleFonts.cairo(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Section: Quick Access ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  'الوصول السريع',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
            ),

            // Quick access horizontal scroll
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _QuickChip(icon: Icons.access_time_rounded, label: 'الصلاة', color: const Color(0xFF2196F3),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerTimesPage()))),
                    _QuickChip(icon: Icons.explore_rounded, label: 'القبلة', color: const Color(0xFF4CAF50),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QiblaPage()))),
                    _QuickChip(icon: Icons.auto_stories_rounded, label: 'المصحف', color: const Color(0xFF9C27B0),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranPage()))),
                    _QuickChip(icon: Icons.mosque_rounded, label: 'المساجد', color: const Color(0xFF00BCD4),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyMosquesPage()))),
                    _QuickChip(icon: Icons.front_hand_rounded, label: 'الأذكار', color: const Color(0xFFFF9800),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarCounterPage()))),
                  ],
                ),
              ),
            ),

            // ── Section: Features ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'الميزات',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
            ),

            // Feature grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  _FeatureCard(icon: Icons.wb_sunny_rounded, label: 'عبادات اليوم', color: const Color(0xFFFF9800), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorshipPage()))),
                  _FeatureCard(icon: Icons.track_changes_rounded, label: 'أهدافي', color: const Color(0xFFE91E63), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage()))),
                  _FeatureCard(icon: Icons.calendar_today_rounded, label: 'الخطة الذكية', color: const Color(0xFF2196F3), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartPlanPage()))),
                  _FeatureCard(icon: Icons.bar_chart_rounded, label: 'التحليلات', color: const Color(0xFF9C27B0), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsPage()))),
                  _FeatureCard(icon: Icons.description_rounded, label: 'تقرير الروح', color: const Color(0xFF607D8B), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()))),
                  _FeatureCard(icon: Icons.nightlight_round, label: 'مود رمضان', color: const Color(0xFF3F51B5), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RamadanPage()))),
                  _FeatureCard(icon: Icons.landscape_rounded, label: 'مود الحج', color: const Color(0xFF795548), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HajjPage()))),
                  _FeatureCard(icon: Icons.emoji_events_rounded, label: 'التحديات', color: const Color(0xFFFFC107), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengesPage()))),
                  _FeatureCard(icon: Icons.today_rounded, label: 'سنن الجمعة', color: const Color(0xFF00BCD4), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FridayTipsPage()))),
                  _FeatureCard(icon: Icons.menu_book_rounded, label: 'مكتبة الأذكار', color: const Color(0xFF4CAF50), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarLibraryPage()))),
                  _FeatureCard(icon: Icons.front_hand_rounded, label: 'عدّاد الأذكار', color: const Color(0xFFFF5722), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarCounterPage()))),
                  _FeatureCard(icon: Icons.mosque_rounded, label: 'المساجد القريبة', color: const Color(0xFF009688), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyMosquesPage()))),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 65,
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) {
            if (i == 1) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayerTimesPage()));
              return;
            }
            if (i == 2) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranPage()));
              return;
            }
            if (i == 3) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyMosquesPage()));
              return;
            }
            if (i == 4) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
              return;
            }
            setState(() => _currentIndex = i);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.access_time_rounded), label: 'الصلاة'),
            NavigationDestination(icon: Icon(Icons.auto_stories_rounded), label: 'المصحف'),
            NavigationDestination(icon: Icon(Icons.mosque_rounded), label: 'المساجد'),
            NavigationDestination(icon: Icon(Icons.person_rounded), label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}

// ── Quick Access Chip ──
class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature Card (3-column grid) ──
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
