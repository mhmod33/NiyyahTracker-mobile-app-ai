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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  void _onNavTap(int index) {
    if (index == 2) {
      // Mosques tab → push as a full page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NearbyMosquesPage()),
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // --- Custom Header ---
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppColors.darkGreen,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  '🤍 NiyyahTracker',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.darkGreen, AppColors.midGreen],
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '"ارسم رحلتك الروحية — يوماً بيوم"',
                            style: GoogleFonts.cairo(
                              color: AppColors.goldLight,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'الجمعة، 1 مايو 2026',
                            style: GoogleFonts.cairo(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- Menu Grid ---
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _MenuCard(
                    title: 'عبادات اليوم',
                    icon: '📿',
                    color: AppColors.paleGreen,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorshipPage())),
                  ),
                  _MenuCard(
                    title: 'أهدافي',
                    icon: '🎯',
                    color: AppColors.goldBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage())),
                  ),
                  _MenuCard(
                    title: 'الخطة الذكية',
                    icon: '📅',
                    color: const Color(0xFFE0F2FE),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartPlanPage())),
                  ),
                  _MenuCard(
                    title: 'التحليلات',
                    icon: '📊',
                    color: const Color(0xFFF3E8FF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsPage())),
                  ),
                  _MenuCard(
                    title: 'تقرير الروح',
                    icon: '📄',
                    color: const Color(0xFFFFEDD5),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage())),
                  ),
                  _MenuCard(
                    title: 'مود رمضان',
                    icon: '🌙',
                    color: const Color(0xFFE0E7FF),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RamadanPage())),
                  ),
                  _MenuCard(
                    title: 'مود الحج',
                    icon: '🕋',
                    color: const Color(0xFFF1F5F9),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HajjPage())),
                  ),
                  // ── New: Nearby Mosques card ──
                  _MenuCard(
                    title: 'المساجد القريبة',
                    icon: '🕌',
                    color: const Color(0xFFD1FAE5),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NearbyMosquesPage()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex == 2 ? 0 : _currentIndex,
          onTap: _onNavTap,
          selectedItemColor: AppColors.darkGreen,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'الخطة'),
            BottomNavigationBarItem(icon: Icon(Icons.mosque_outlined), label: 'المساجد'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.darkGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
