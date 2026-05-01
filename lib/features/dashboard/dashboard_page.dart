import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

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

            // --- Stats & Goals Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Stats Row
                    Row(
                      children: [
                        const Expanded(
                          child: _StatCard(
                            label: 'الستريك',
                            value: '١٢ يوم',
                            icon: Icons.local_fire_department,
                            iconColor: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: _StatCard(
                            label: 'الأهداف',
                            value: '٨٥٪',
                            icon: Icons.track_changes,
                            iconColor: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Monthly Goal Progress
                    Text(
                      'الهدف الروحي الشهري',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ختم القرآن الكريم',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '٤٨٠ / ٦٠٠ صفحة',
                                style: GoogleFonts.cairo(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: 0.8,
                            backgroundColor: Colors.grey[200],
                            color: AppColors.lightGreen,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Daily Worship Header
                    Text(
                      'عبادات اليوم',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Worship List ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _WorshipItem(
                    title: 'الصلوات الخمس',
                    subtitle: '٥/٥ صلوات في وقتها',
                    icon: Icons.mosque,
                    isDone: true,
                  ),
                  const _WorshipItem(
                    title: 'قراءة القرآن',
                    subtitle: '٢٠ صفحة من سورة البقرة',
                    icon: Icons.menu_book,
                    isDone: true,
                  ),
                  const _WorshipItem(
                    title: 'أذكار الصباح والمساء',
                    subtitle: 'تمت القراءة بفضل الله',
                    icon: Icons.wb_sunny,
                    isDone: true,
                  ),
                  const _WorshipItem(
                    title: 'قيام الليل',
                    subtitle: 'لم يتم التسجيل بعد',
                    icon: Icons.nightlight_round,
                    isDone: false,
                  ),
                  const _WorshipItem(
                    title: 'الصدقة اليومية',
                    subtitle: 'تصدق بابتسامة على الأقل!',
                    icon: Icons.volunteer_activism,
                    isDone: false,
                  ),
                  const SizedBox(height: 100), // Spacing for FAB
                ]),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: AppColors.darkGreen,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'تسجيل عبادة',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          selectedItemColor: AppColors.darkGreen,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'الخطة'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'المساجد'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.paleGreen),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGreen,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorshipItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDone;

  const _WorshipItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? AppColors.lightGreen.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDone ? AppColors.paleGreen : Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isDone ? AppColors.darkGreen : Colors.grey,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDone ? AppColors.darkGreen : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.cairo(fontSize: 12),
        ),
        trailing: Icon(
          isDone ? Icons.check_circle : Icons.circle_outlined,
          color: isDone ? AppColors.lightGreen : Colors.grey[300],
        ),
      ),
    );
  }
}
