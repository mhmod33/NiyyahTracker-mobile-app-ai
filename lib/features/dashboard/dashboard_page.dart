import 'dart:ui';
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
import '../map/nearby_mosques_page.dart';
import '../profile/profile_page.dart';
import '../friday/friday_tips_page.dart';
import '../azkar/azkar_counter_page.dart';
import '../prayer_times/prayer_times_page.dart';
import '../qibla/qibla_page.dart';
import '../challenges/challenges_page.dart';
import '../quran/quran_page.dart';
import '../azkar/azkar_library_page.dart';
import '../../providers/auth_provider.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  bool _fajrChecked = false;
  bool _charityChecked = false;

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
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final authProvider = context.watch<AppAuthProvider>();
    final userName = authProvider.displayName;

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
                        ? [const Color(0xFF0A1912), const Color(0xFF143023)]
                        : [const Color(0xFF145A3A), const Color(0xFF1E8255)], // A bit deeper green
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Stack(
                  children: [
                    // Background Pattern
                    Positioned.fill(
                      child: Opacity(
                        opacity: isDark ? 0.05 : 0.08,
                        child: CustomPaint(painter: _IslamicPatternPainter()),
                      ),
                    ),
                    Column(
                      children: [
                    Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
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
                              Text('السلام عليكم، ${userName.split(' ').first}', style: _f(sz: 13, c: Colors.white70)),
                              Text('النية', style: _f(sz: 22, fw: FontWeight.w800, c: Colors.white)),
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
                          Text('وإنما لكل امرئ ما نوى', style: _f(sz: 18, fw: FontWeight.w700, c: Colors.white)),
                          const SizedBox(height: 4),
                          Text(_getArabicDate(), style: _f(sz: 12, c: Colors.white60)),
                        ],
                      ),
                    ),
                  ],
                ), // Column
              ],
            ), // Stack
          ), // Container
        ), // SliverToBoxAdapter

            // ── Daily Accountability (المحاسبة اليومية) ──
            SliverToBoxAdapter(
              child: _buildDailyAccountability(isDark, textColor),
            ),

            // ── Quick Access ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text('الوصول السريع', style: _f(sz: 18, fw: FontWeight.w800, c: textColor)),
              ),
            ),

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

            // ── Features Grid ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text('الميزات', style: _f(sz: 18, fw: FontWeight.w800, c: textColor)),
              ),
            ),

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
                  _FeatureCard(icon: Icons.description_rounded, label: 'تقرير الروح', color: const Color(0xFF607D8B), isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()))),
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

            const SliverToBoxAdapter(child: SizedBox(height: 120)), // Added padding for floating navbar
          ],
        ),
        extendBody: true,
        bottomNavigationBar: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.8) : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Right Side (RTL context)
                    _NavBarItem(icon: Icons.dashboard_rounded, label: 'الرئيسية', isSelected: _currentIndex == 0, onTap: () => setState(() => _currentIndex = 0)),
                    _NavBarItem(icon: Icons.auto_stories_rounded, label: 'المصحف', isSelected: _currentIndex == 3, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranPage()))),
                    
                    // Center Logo
                    GestureDetector(
                      onTap: () => setState(() => _currentIndex = 0), // Just goes to home
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.5), blurRadius: 10)],
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.darkGreen,
                          backgroundImage: const AssetImage('assets/logo.png'),
                        ),
                      ),
                    ),

                    // Left Side
                    _NavBarItem(icon: Icons.mosque_rounded, label: 'المساجد', isSelected: _currentIndex == 1, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyMosquesPage()))),
                    _NavBarItem(icon: Icons.person_rounded, label: 'حسابي', isSelected: _currentIndex == 4, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyAccountability(bool isDark, Color textColor) {
    if (_fajrChecked && _charityChecked) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.paleGreen.withOpacity(isDark ? 0.1 : 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.midGreen.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.darkGreen, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text('تقبل الله! أتممت محاسبة اليوم بنجاح 🤍', style: _f(sz: 14, fw: FontWeight.w700, c: AppColors.darkGreen)),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Text('المحاسبة اليومية', style: _f(sz: 18, fw: FontWeight.w800, c: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              boxShadow: [
                if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                _buildChecklistItem('هل صليت الفجر اليوم؟', 'الصلاة خير من النوم', Icons.wb_twilight_rounded, _fajrChecked, (val) {
                  setState(() => _fajrChecked = val ?? false);
                }, isDark),
                Divider(height: 1, indent: 56, endIndent: 16, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                _buildChecklistItem('هل تصدقت اليوم؟', 'ولو بشق تمرة', Icons.volunteer_activism_rounded, _charityChecked, (val) {
                  setState(() => _charityChecked = val ?? false);
                }, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, String subtitle, IconData icon, bool value, ValueChanged<bool?> onChanged, bool isDark) {
    return Theme(
      data: ThemeData(
        unselectedWidgetColor: isDark ? Colors.white54 : Colors.grey[400],
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.darkGreen,
        checkColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title, style: _f(sz: 15, fw: FontWeight.w700, c: isDark ? Colors.white : AppColors.textPrimary)),
        subtitle: Text(subtitle, style: _f(sz: 12, c: AppColors.gray)),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value ? AppColors.darkGreen.withOpacity(0.1) : (isDark ? Colors.white10 : AppColors.paleGreen),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: value ? AppColors.darkGreen : (isDark ? Colors.white70 : AppColors.midGreen), size: 20),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.darkGreen.withOpacity(isDark ? 0.3 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.darkGreen : (isDark ? Colors.white54 : AppColors.gray),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: _f(
                  sz: 13,
                  fw: FontWeight.w700,
                  c: AppColors.darkGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: _f(sz: 11, fw: FontWeight.w700, c: isDark ? Colors.white70 : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  const _FeatureCard({required this.icon, required this.label, required this.color, required this.isDark, required this.onTap});

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
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: _f(sz: 12, fw: FontWeight.w700, c: isDark ? Colors.white : AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final double step = 60.0;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        canvas.drawLine(Offset(x - 10, y), Offset(x + 10, y), paint);
        canvas.drawLine(Offset(x, y - 10), Offset(x, y + 10), paint);
        canvas.drawLine(Offset(x - 7, y - 7), Offset(x + 7, y + 7), paint);
        canvas.drawLine(Offset(x - 7, y + 7), Offset(x + 7, y - 7), paint);
        canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: step, height: step), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
