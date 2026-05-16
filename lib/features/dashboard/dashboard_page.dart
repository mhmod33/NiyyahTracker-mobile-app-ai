import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart' as uuid;
import '../../core/app_colors.dart';
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
import '../settings/notification_settings_page.dart';
import '../azan/azan_settings_page.dart';
import '../auth/login_page.dart';
import '../onboarding/onboarding_page.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/daily_summary_service.dart';
import '../../models/worship_model.dart' as db_model;
import '../../widgets/mini_player.dart';
import '../quran/reciter_library_page.dart';
import '../wird/daily_wird_page.dart';
import '../../services/wird_service.dart';
import '../hajj/hajj_page.dart';
import '../ramadan/ramadan_page.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  static const String _showAzkarPrefKey = 'show_dashboard_azkar';
  int _currentIndex = 0;
  bool _showAzkar = true;
  bool _fajrChecked = false;
  bool _charityChecked = false;
  bool _isLoadingAccountability = true;
  bool _isAccountabilityDone = false;
  bool _isLoadingSummary = true;
  Map<String, dynamic> _todaySummary = {};
  final FirebaseService _firebaseService = FirebaseService();
  final DailySummaryService _dailySummaryService = DailySummaryService();
  final WirdService _wirdService = WirdService();
  WirdDayRecord? _wirdRecord;
  int _wirdStreak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAzkarPref();
    _checkTodayAccountability();
    _loadTodaySummary();
    _loadWirdData();
  }

  Future<void> _loadAzkarPref() async {
    try {
      final box = Hive.isBoxOpen('user_preferences')
          ? Hive.box('user_preferences')
          : await Hive.openBox('user_preferences');
      if (mounted) {
        setState(() {
          _showAzkar = box.get(_showAzkarPrefKey, defaultValue: true) as bool;
        });
      }
    } catch (_) {
      // Fall back to default true if Hive isn't ready
    }
  }

  Future<void> _setShowAzkar(bool value) async {
    setState(() => _showAzkar = value);
    try {
      final box = Hive.isBoxOpen('user_preferences')
          ? Hive.box('user_preferences')
          : await Hive.openBox('user_preferences');
      await box.put(_showAzkarPrefKey, value);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWirdData();
      _loadTodaySummary();
    }
  }

  Future<void> _loadWirdData() async {
    final isGuest = !context.read<AppAuthProvider>().isAuthenticated;
    if (isGuest) {
      setState(() {
        _wirdRecord = null;
        _wirdStreak = 0;
      });
      return;
    }
    await _wirdService.init();
    // Scope wird storage to the current user so reads/writes hit the right keys.
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isNotEmpty) {
      _wirdService.setUserId(userId);
    }
    if (mounted) {
      setState(() {
        _wirdRecord = _wirdService.getTodayRecord();
        _wirdStreak = _wirdService.getCurrentStreak();
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _checkTodayAccountability(),
      _loadTodaySummary(),
      _loadWirdData(),
    ]);
  }

  Future<void> _loadTodaySummary() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _isLoadingSummary = false);
      return;
    }

    try {
      final summary = await _dailySummaryService.getTodaySummary(userId);
      setState(() {
        _todaySummary = summary;
        _isLoadingSummary = false;
      });
    } catch (e) {
      setState(() => _isLoadingSummary = false);
    }
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
      // Reload summary after saving accountability
      _loadTodaySummary();
    } catch (e) {
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
    final isGuest = !authProvider.isAuthenticated;
    final userName = isGuest ? 'ضيف' : authProvider.displayName;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: RefreshIndicator(
          onRefresh: _refreshAll,
          color: AppColors.darkGreen,
          backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                        if (isGuest)
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
                              child: Text('تسجيل الدخول', style: _f(sz: 12, fw: FontWeight.bold, c: Colors.white)),
                            ),
                          )
                        else
                          _IconButton(icon: Icons.notifications_none_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsPage()))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _HeaderQuote(date: _getArabicDate()),
                  ],
                ),
              ),
            ),

            // ── Rotating Azkar Section ──
            if (_showAzkar) ...[
              SliverToBoxAdapter(child: _SectionTitle(title: 'ذكر اليوم', icon: Icons.auto_awesome_rounded)),
              SliverToBoxAdapter(child: _buildRotatingAzkar(isDark)),
            ] else
              SliverToBoxAdapter(child: _buildAzkarSettingsButton(isDark)),

            // ── Today's Focus Section (only for logged-in users) ──
            if (!isGuest) ...[
              SliverToBoxAdapter(child: _SectionTitle(title: 'محاسبة اليوم', icon: Icons.auto_awesome_rounded)),
              SliverToBoxAdapter(child: _buildDailyAccountability(isDark)),
            ],

            // ── Daily Summary Section ──
            if (!isGuest && _todaySummary['hasData'] == true) ...[
              SliverToBoxAdapter(child: _SectionTitle(title: 'ملخص عبادات اليوم', icon: Icons.summarize_rounded)),
              SliverToBoxAdapter(child: _buildDailySummaryCard(isDark)),
            ],

            // ── Daily Wird Section ──
            SliverToBoxAdapter(child: _SectionTitle(title: 'الورد اليومي', icon: Icons.auto_stories_rounded)),
            SliverToBoxAdapter(child: _buildWirdCard(isDark, isGuest: isGuest)),

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
                    _QuickChip(icon: Icons.volume_up_rounded, label: 'الأذان', color: Colors.teal, onTap: () => _to(const AzanSettingsPage())),
                    _QuickChip(icon: Icons.explore_rounded, label: 'اتجاة القبلة', color: Colors.green, onTap: () => _to(const QiblaPage())),
                    _QuickChip(icon: Icons.menu_book_rounded, label: 'المصحف الشريف', color: Colors.purple, onTap: () => _to(const QuranPage())),
                    _QuickChip(icon: Icons.headphones_rounded, label: 'مكتبة القراء', color: const Color(0xFF1B7A4E), onTap: () => _to(const ReciterLibraryPage())),
                    _QuickChip(icon: Icons.location_on_rounded, label: 'المساجد', color: Colors.cyan, onTap: () => _to(const NearbyMosquesPage())),
                    _QuickChip(icon: Icons.front_hand_rounded, label: 'الأذكار اليومية', color: Colors.orange, onTap: () => _to(const AzkarCounterPage())),
                  ],
                ),
              ),
            ),

            // ── Features Sections (protected for guests) ──
            SliverToBoxAdapter(child: _SectionTitle(title: 'أدوات العبادة', icon: Icons.stars_rounded)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                children: [
                  _FeatureCard(icon: Icons.wb_sunny_rounded, label: 'عباداتي', color: Colors.amber, isDark: isDark, onTap: () => _toProtected(const WorshipPage())),
                  _FeatureCard(icon: Icons.track_changes_rounded, label: 'الأهداف', color: Colors.pink, isDark: isDark, onTap: () => _toProtected(const GoalsPage())),
                  _FeatureCard(icon: Icons.calendar_today_rounded, label: 'الخطة', color: Colors.indigo, isDark: isDark, onTap: () => _toProtected(const SmartPlanPage())),
                  _FeatureCard(icon: Icons.analytics_rounded, label: 'التحليلات', color: Colors.deepPurple, isDark: isDark, onTap: () => _toProtected(const AnalyticsPage())),
                  _FeatureCard(icon: Icons.emoji_events_rounded, label: 'التحديات', color: Colors.orange, isDark: isDark, onTap: () => _toProtected(const ChallengesPage())),
                  _FeatureCard(icon: Icons.description_rounded, label: 'التقارير', color: Colors.blueGrey, isDark: isDark, onTap: () => _toProtected(const ReportsPage())),
                  _FeatureCard(icon: Icons.nights_stay_rounded, label: 'مود رمضان', color: Colors.indigo, isDark: isDark, onTap: () => _to(const RamadanPage())),
                  _FeatureCard(icon: Icons.mosque_rounded, label: 'مود الحج', color: const Color(0xFF8D6E00), isDark: isDark, onTap: () => _to(const HajjPage())),
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
                  _FeatureCard(icon: Icons.import_contacts_rounded, label: 'مكتبة الأذكار', color: Colors.green, isDark: isDark, onTap: () => _to(const AzkarLibraryPage())),
                  _FeatureCard(icon: Icons.mosque_rounded, label: 'المساجد', color: Colors.blueAccent, isDark: isDark, onTap: () => _to(const NearbyMosquesPage())),
                  _FeatureCard(icon: Icons.headphones_rounded, label: 'مكتبة القراء', color: const Color(0xFF1B5E20), isDark: isDark, onTap: () => _to(const ReciterLibraryPage())),
                  _FeatureCard(icon: Icons.wb_sunny_outlined, label: 'الأذكار اليومية', color: Colors.amber.shade700, isDark: isDark, onTap: () => _to(const AzkarLibraryPage())),
                  _FeatureCard(icon: Icons.volume_up_rounded, label: 'إعدادات الأذان', color: Colors.indigo, isDark: isDark, onTap: () => _to(const AzanSettingsPage())),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
        ),
        extendBody: true,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            _ModernNavBar(currentIndex: _currentIndex, onTap: (i) => setState(() => _currentIndex = i)),
          ],
        ),
      ),
    );
  }

  void _to(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// Navigate with login check — guest users get a login prompt for protected pages
  void _toProtected(Widget page) {
    final auth = context.read<AppAuthProvider>();
    if (auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    } else {
      _showLoginPrompt();
    }
  }

  void _showLoginPrompt() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.gold),
            const SizedBox(height: 16),
            Text('يجب تسجيل الدخول', style: _f(sz: 20, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
            const SizedBox(height: 8),
            Text('سجل دخولك للوصول إلى جميع الميزات', style: _f(sz: 14, c: AppColors.gray), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text('تسجيل الدخول', style: _f(sz: 16, fw: FontWeight.bold, c: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage()));
              },
              child: Text('إنشاء حساب جديد', style: _f(sz: 14, fw: FontWeight.w700, c: AppColors.midGreen)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAzkarSettingsButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.paleGreen.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ذكر اليوم مخفي',
                    style: _f(
                        sz: 14,
                        fw: FontWeight.w800,
                        c: isDark ? Colors.white : AppColors.darkGreen)),
                Text('يمكنك إظهار الأذكار المقترحة في الصفحة الرئيسية',
                    style: _f(
                        sz: 11,
                        c: isDark ? Colors.white60 : AppColors.gray)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _setShowAzkar(true),
            icon: const Icon(Icons.visibility_rounded, size: 16),
            label: Text('إظهار',
                style:
                    _f(sz: 13, fw: FontWeight.w700, c: AppColors.darkGreen)),
            style: TextButton.styleFrom(foregroundColor: AppColors.darkGreen),
          ),
        ]),
      ),
    );
  }

  Widget _buildRotatingAzkar(bool isDark) {
    // Pick random azkar that change on each app open
    final allAzkar = <Dhikr>[
      ...azkarCategories['أذكار الصباح']!.items.take(10),
      ...azkarCategories['أذكار المساء']!.items.take(10),
      ...azkarCategories['أدعية نبوية']!.items,
    ];
    final random = Random(DateTime.now().day * 100 + DateTime.now().hour ~/ 6);
    final shuffled = List<Dhikr>.from(allAzkar)..shuffle(random);
    final selected = shuffled.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A2F23), const Color(0xFF0D2818)]
                : [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10), // spacing for the close button
                ...selected.map((dhikr) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dhikr.text.length > 120 ? '${dhikr.text.substring(0, 120)}...' : dhikr.text,
                        style: _f(sz: 15, fw: FontWeight.w700, c: isDark ? Colors.white : AppColors.darkGreen, h: 1.8),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(dhikr.reward, style: _f(sz: 11, c: AppColors.gold, fw: FontWeight.w600)),
                      if (selected.last != dhikr) Divider(height: 20, color: AppColors.gold.withOpacity(0.2)),
                    ],
                  ),
                )),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _to(const AzkarLibraryPage()),
                    icon: const Icon(Icons.import_contacts_rounded, size: 18),
                    label: Text('مكتبة الأذكار', style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: -10,
              left: -10,
              child: IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white54 : AppColors.darkGreen.withOpacity(0.5)),
                onPressed: () => _setShowAzkar(false),
                splashRadius: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWirdCard(bool isDark, {bool isGuest = false}) {
    final record = _wirdRecord;
    final streak = _wirdStreak;

    // For guests: show a teaser card with a lock overlay
    if (isGuest) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () => _showLoginPrompt(),
          child: Stack(
            children: [
              // Teaser card (blurred content)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: isDark
                        ? [const Color(0xFF1A3A28), const Color(0xFF0D2818)]
                        : [AppColors.darkGreen, const Color(0xFF145A3A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('الورد اليومي', style: _f(sz: 17, fw: FontWeight.w800, c: Colors.white)),
                      Text('تابع تقدمك اليومي في القرآن', style: _f(sz: 12, c: Colors.white70)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('7', style: _f(sz: 13, fw: FontWeight.w900, c: Colors.white)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: 0.6,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('12 / 20 صفحة', style: _f(sz: 12, c: Colors.white70)),
                    Row(children: WirdSession.all.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(WirdSession.iconData(s), size: 16, color: Colors.white.withValues(alpha: 0.5)),
                    )).toList()),
                  ]),
                ]),
              ),
              // Lock overlay
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 12)],
                          ),
                          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 10),
                        Text('سجل دخولك لتفعيل الورد اليومي',
                            style: _f(sz: 13, fw: FontWeight.w700, c: Colors.white)),
                        const SizedBox(height: 4),
                        Text('تتبع تقدمك وحافظ على streak مواظبتك',
                            style: _f(sz: 11, c: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show shimmer-like placeholder while loading
    if (record == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyWirdPage()));
            _loadWirdData();
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: isDark
                    ? [const Color(0xFF1A3A28), const Color(0xFF0D2818)]
                    : [AppColors.darkGreen, const Color(0xFF145A3A)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الورد اليومي', style: _f(sz: 17, fw: FontWeight.w800, c: Colors.white)),
                Text('اضغط لبدء وردك اليومي', style: _f(sz: 12, c: Colors.white70)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyWirdPage()));
          _loadWirdData();
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? [const Color(0xFF1A3A28), const Color(0xFF0D2818)]
                  : [AppColors.darkGreen, const Color(0xFF145A3A)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkGreen.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الورد اليومي', style: _f(sz: 17, fw: FontWeight.w800, c: Colors.white)),
                  Text(
                    record.isCompleted
                        ? 'أتممت وردك اليوم! تقبل الله'
                        : 'اقرأ وردك اليومي من القرآن الكريم',
                    style: _f(sz: 12, c: Colors.white70),
                  ),
                ]),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('$streak', style: _f(sz: 14, fw: FontWeight.w900, c: Colors.white)),
                  ]),
                ),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: record.progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  record.isCompleted ? AppColors.gold : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                '${record.pagesRead} / ${record.targetPages} صفحة',
                style: _f(sz: 12, c: Colors.white70),
              ),
              Row(children: WirdSession.all.map((s) {
                final done = (record.sessionPages[s] ?? 0) >= record.pagesPerSession;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    WirdSession.iconData(s),
                    size: 18,
                    color: done ? WirdSession.iconColor(s) : Colors.white.withValues(alpha: 0.3),
                  ),
                );
              }).toList()),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildDailySummaryCard(bool isDark) {
    if (_isLoadingSummary) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final prayerCount = _todaySummary['prayerCount'] ?? 0;
    final quranPages = _todaySummary['quranPages'] ?? 0;
    final completedWorships = (_todaySummary['completedWorships'] as List<dynamic>?)?.cast<String>() ?? [];
    final totalWorships = _todaySummary['totalWorships'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF1A4D2E), const Color(0xFF0D2818)]
                : [AppColors.paleGreen, AppColors.lightGreen.withOpacity(0.3)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkGreen.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.summarize_rounded, color: AppColors.gold, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ملخص عبادات اليوم', style: _f(sz: 16, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
                      Text('إنجازاتك الروحية لهذا اليوم 🤍', style: _f(sz: 12, c: isDark ? Colors.white70 : AppColors.gray)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$totalWorships', style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _summaryItem('الصلوات', '$prayerCount/5', Icons.mosque_rounded, isDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryItem('صفحات القرآن', '$quranPages', Icons.menu_book_rounded, isDark),
                ),
              ],
            ),
            if (completedWorships.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('العبادات الأخرى:', style: _f(sz: 12, fw: FontWeight.w600, c: isDark ? Colors.white70 : AppColors.gray)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: completedWorships.take(4).map((worship) {
                  final displayName = _getWorshipDisplayName(worship);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      displayName,
                      style: _f(sz: 10, fw: FontWeight.w600, c: Colors.white),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String title, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _f(sz: 11, c: isDark ? Colors.white70 : AppColors.gray)),
                Text(value, style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWorshipDisplayName(String key) {
    switch (key) {
      case 'morningRemembrance':
        return 'أذكار الصباح';
      case 'eveningRemembrance':
        return 'أذكار المساء';
      case 'quranRecitation':
        return 'قراءة القرآن';
      case 'charity':
        return 'الصدقة';
      case 'nightPrayer':
        return 'قيام الليل';
      case 'fasting':
        return 'الصيام';
      case 'taraweeh':
        return 'التراويح';
      default:
        return key;
    }
  }

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
    final isGuest = !context.watch<AppAuthProvider>().isAuthenticated;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
            _NavButton(icon: Icons.mosque_rounded, label: 'المساجد', selected: currentIndex == 1, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NearbyMosquesPage()))),
            _NavButton(icon: Icons.auto_stories_rounded, label: 'المصحف', selected: currentIndex == 2, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranPage()))),
            _NavButton(
              icon: isGuest ? Icons.login_rounded : Icons.person_rounded,
              label: isGuest ? 'تسجيل الدخول' : 'حسابي',
              selected: currentIndex == 3,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => isGuest ? const LoginPage() : const ProfilePage())),
            ),
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
