import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart' as uuid;
import '../../core/app_colors.dart';
import '../../core/theme_provider.dart';
import '../../core/app_models.dart';
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
import '../../services/firebase_service.dart';
import '../../models/worship_model.dart' as db_model;

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
  bool _isLoadingAccountability = true;
  bool _isAccountabilityDone = false;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _checkTodayAccountability();
  }

  Future<void> _checkTodayAccountability() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) return;

    try {
      final worships = await _firebaseService.getDailyWorshipByDate(userId, DateTime.now());
      if (worships.isNotEmpty) {
        final today = worships.first;
        setState(() {
          _fajrChecked = today.prayerCount > 0;
          _charityChecked = today.worships['charity'] == true;
          _isAccountabilityDone = _fajrChecked && _charityChecked;
          _isLoadingAccountability = false;
        });
      } else {
        setState(() => _isLoadingAccountability = false);
      }
    } catch (e) {
      debugPrint('Error checking accountability: $e');
      setState(() => _isLoadingAccountability = false);
    }
  }

  Future<void> _saveQuickAccountability() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) return;

    setState(() => _isLoadingAccountability = true);

    try {
      final worships = await _firebaseService.getDailyWorshipByDate(userId, DateTime.now());
      String docId = worships.isNotEmpty ? worships.first.id : const uuid.Uuid().v4();
      
      final data = db_model.DailyWorship(
        id: docId,
        date: DateTime.now(),
        prayerCount: _fajrChecked ? 1 : 0,
        quranPages: worships.isNotEmpty ? worships.first.quranPages : 0,
        worships: {
          ...?worships.firstOrNull?.worships,
          'charity': _charityChecked,
        },
      );

      await _firebaseService.saveDailyWorship(userId, data);
      setState(() {
        _isAccountabilityDone = true;
        _isLoadingAccountability = false;
      });
    } catch (e) {
      debugPrint('Error saving accountability: $e');
      setState(() => _isLoadingAccountability = false);
    }
  }

  String _getArabicDate() {
    final now = DateTime.now();
    final days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${days[now.weekday - 1]}، ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9);
    final authProvider = context.watch<AppAuthProvider>();
    final userName = authProvider.displayName;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Modern Header ──
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 28, left: 20, right: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF0D2818), const Color(0xFF051109)]
                        : [const Color(0xFF145A3A), const Color(0xFF1E8255)],
                  ),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '؟', style: _f(sz: 20, fw: FontWeight.bold, c: Colors.white)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('السلام عليكم، ${userName.split(' ').first}', style: _f(sz: 13, c: Colors.white70)),
                              Text('مرحباً بك في النية', style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white)),
                            ],
                          ),
                        ),
                        _IconButton(icon: Icons.notifications_none_rounded, onTap: () {}),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _HeaderQuote(date: _getArabicDate()),
                  ],
                ),
              ),
            ),

            // ── Today's Focus Section ──
            SliverToBoxAdapter(child: _SectionTitle(title: 'محاسبة اليوم', icon: Icons.auto_awesome_rounded)),
            SliverToBoxAdapter(child: _buildDailyAccountability(isDark)),

            // ── Quick Access Section ──
            SliverToBoxAdapter(child: _SectionTitle(title: 'الوصول السريع', icon: Icons.grid_view_rounded)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _QuickChip(icon: Icons.access_time_filled_rounded, label: 'مواقيت الصلاة', color: Colors.blue, onTap: () => _to(const PrayerTimesPage())),
                    _QuickChip(icon: Icons.explore_rounded, label: 'اتجاة القبلة', color: Colors.green, onTap: () => _to(const QiblaPage())),
                    _QuickChip(icon: Icons.menu_book_rounded, label: 'المصحف الشريف', color: Colors.purple, onTap: () => _to(const QuranPage())),
                    _QuickChip(icon: Icons.location_on_rounded, label: 'المساجد', color: Colors.cyan, onTap: () => _to(const NearbyMosquesPage())),
                    _QuickChip(icon: Icons.front_hand_rounded, label: 'الأذكار اليومية', color: Colors.orange, onTap: () => _to(const AzkarCounterPage())),
                  ],
                ),
              ),
            ),

            // ── Features Sections ──
            SliverToBoxAdapter(child: _SectionTitle(title: 'أدوات العبادة', icon: Icons.stars_rounded)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                children: [
                  _FeatureCard(icon: Icons.wb_sunny_rounded, label: 'عباداتي', color: Colors.amber, isDark: isDark, onTap: () => _to(const WorshipPage())),
                  _FeatureCard(icon: Icons.track_changes_rounded, label: 'الأهداف', color: Colors.pink, isDark: isDark, onTap: () => _to(const GoalsPage())),
                  _FeatureCard(icon: Icons.calendar_today_rounded, label: 'الخطة', color: Colors.indigo, isDark: isDark, onTap: () => _to(const SmartPlanPage())),
                  _FeatureCard(icon: Icons.analytics_rounded, label: 'التحليلات', color: Colors.deepPurple, isDark: isDark, onTap: () => _to(const AnalyticsPage())),
                  _FeatureCard(icon: Icons.emoji_events_rounded, label: 'التحديات', color: Colors.orange, isDark: isDark, onTap: () => _to(const ChallengesPage())),
                  _FeatureCard(icon: Icons.description_rounded, label: 'التقارير', color: Colors.blueGrey, isDark: isDark, onTap: () => _to(const ReportsPage())),
                ],
              ),
            ),

            SliverToBoxAdapter(child: _SectionTitle(title: 'المزيد', icon: Icons.add_circle_outline_rounded)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                children: [
                  _FeatureCard(icon: Icons.today_rounded, label: 'سنن الجمعة', color: Colors.teal, isDark: isDark, onTap: () => _to(const FridayTipsPage())),
                  _FeatureCard(icon: Icons.import_contacts_rounded, label: 'المكتبة', color: Colors.green, isDark: isDark, onTap: () => _to(const AzkarLibraryPage())),
                  _FeatureCard(icon: Icons.mosque_rounded, label: 'المساجد', color: Colors.blueAccent, isDark: isDark, onTap: () => _to(const NearbyMosquesPage())),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: _ModernNavBar(currentIndex: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
      ),
    );
  }

  void _to(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _buildDailyAccountability(bool isDark) {
    if (_isLoadingAccountability) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)));

    if (_isAccountabilityDone) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _SuccessCard(isDark: isDark),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _AccountabilityCard(isDark: isDark, onAdd: () => _showAccountabilityDialog(isDark)),
    );
  }

  void _showAccountabilityDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('المحاسبة اليومية', style: _f(sz: 18, fw: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CheckItem(title: 'صلاة الفجر', subtitle: 'في وقتها', icon: Icons.wb_twilight_rounded, value: _fajrChecked, onChanged: (v) {
                  setDialogState(() => _fajrChecked = v ?? false);
                  setState(() {});
                }),
                const SizedBox(height: 12),
                _CheckItem(title: 'الصدقة', subtitle: 'ولو بالقليل', icon: Icons.volunteer_activism_rounded, value: _charityChecked, onChanged: (v) {
                  setDialogState(() => _charityChecked = v ?? false);
                  setState(() {});
                }),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: _f(c: Colors.grey))),
              ElevatedButton(
                onPressed: () { Navigator.pop(context); _saveQuickAccountability(); },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('حفظ الإنجاز', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small Support Widgets ──

class _IconButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _IconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}

class _HeaderQuote extends StatelessWidget {
  final String date;
  const _HeaderQuote({required this.date});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.2)),
    ),
    child: Row(children: [
      const Icon(Icons.format_quote_rounded, color: AppColors.gold, size: 28),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('وإنما لكل امرئ ما نوى', style: _f(sz: 18, fw: FontWeight.w700, c: Colors.white)),
        Text(date, style: _f(sz: 11, c: Colors.white60)),
      ])),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionTitle({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
    child: Row(children: [
      Icon(icon, color: AppColors.gold, size: 20),
      const SizedBox(width: 10),
      Text(title, style: _f(sz: 18, fw: FontWeight.w800, c: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.darkGreen)),
    ]),
  );
}

class _SuccessCard extends StatelessWidget {
  final bool isDark;
  const _SuccessCard({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.lightGreen.withOpacity(0.3)),
      boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: AppColors.paleGreen, shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: AppColors.darkGreen, size: 24)),
      const SizedBox(width: 14),
      Expanded(child: Text('تقبل الله طاعتك! أتممت محاسبة اليوم بنجاح 🤍', style: _f(sz: 14, fw: FontWeight.w700, c: isDark ? Colors.white : AppColors.darkGreen))),
    ]),
  );
}

class _AccountabilityCard extends StatelessWidget {
  final bool isDark; final VoidCallback onAdd;
  const _AccountabilityCard({required this.isDark, required this.onAdd});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
      boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ابدأ محاسبتك اليومية', style: _f(sz: 16, fw: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('سجل إنجازاتك الروحية لليوم', style: _f(sz: 12, c: AppColors.gray)),
      ])),
      ElevatedButton(
        onPressed: onAdd,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20)),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    ]),
  );
}

class _CheckItem extends StatelessWidget {
  final String title, subtitle; final IconData icon; final bool value; final ValueChanged<bool?> onChanged;
  const _CheckItem({required this.title, required this.subtitle, required this.icon, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
    child: CheckboxListTile(
      value: value, onChanged: onChanged,
      title: Text(title, style: _f(fw: FontWeight.w700, sz: 14)),
      subtitle: Text(subtitle, style: _f(sz: 11)),
      secondary: Icon(icon, color: AppColors.darkGreen),
      activeColor: AppColors.darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class _QuickChip extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickChip({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 90, margin: const EdgeInsets.only(right: 12),
      child: Column(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.1))),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: _f(sz: 11, fw: FontWeight.w700)),
      ]),
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final bool isDark; final VoidCallback onTap;
  const _FeatureCard({required this.icon, required this.label, required this.color, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: _f(sz: 12, fw: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

class _ModernNavBar extends StatelessWidget {
  final int currentIndex; final ValueChanged<int> onTap;
  const _ModernNavBar({required this.currentIndex, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.9) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _NavButton(icon: Icons.dashboard_rounded, label: 'الرئيسية', selected: currentIndex == 0, onTap: () => onTap(0)),
            _NavButton(icon: Icons.auto_stories_rounded, label: 'المصحف', selected: currentIndex == 1, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranPage()))),
            _NavButton(icon: Icons.person_rounded, label: 'حسابي', selected: currentIndex == 2, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()))),
          ]),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon; final String label; final bool selected; final VoidCallback onTap;
  const _NavButton({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: selected ? AppColors.darkGreen.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Icon(icon, color: selected ? AppColors.darkGreen : AppColors.gray, size: 24),
        if (selected) ...[const SizedBox(width: 8), Text(label, style: _f(sz: 13, fw: FontWeight.w700, c: AppColors.darkGreen))],
      ]),
    ),
  );
}
