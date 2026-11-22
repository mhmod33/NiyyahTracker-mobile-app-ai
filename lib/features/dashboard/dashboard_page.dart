import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart' as uuid;
import '../../core/app_colors.dart';
import '../worship/worship_page.dart';
import '../goals/goals_page.dart';
import '../plan/smart_plan_page.dart';
import '../analytics/analytics_page.dart';
import '../reports/reports_page.dart';
import '../map/nearby_mosques_page.dart';
import '../profile/profile_page.dart';
import '../friday/friday_tips_page.dart';
import '../prayer_times/prayer_times_page.dart';
import '../qibla/qibla_page.dart';
import '../challenges/challenges_page.dart';
import '../quran/quran_page.dart';
import '../quran/reading_stops_page.dart';
import '../azkar/azkar_library_page.dart';
import '../azkar/azkar_counter_page.dart';
import '../settings/notification_settings_page.dart';
import '../azan/azan_settings_page.dart';
import '../auth/login_page.dart';
import '../onboarding/onboarding_page.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/daily_summary_service.dart';
import '../../models/worship_model.dart' as db_model;
import '../../widgets/mini_player.dart';
import '../../widgets/prayer_times_card.dart';
import '../../widgets/fajr_tree_widget.dart';
import '../fajr/fajr_streak_page.dart';
import '../quran/reciter_library_page.dart';
import '../wird/daily_wird_page.dart';
import '../../services/wird_service.dart';
import '../../services/wird_notification_service.dart';
import '../../services/azan_service.dart';
import '../dawri/dawri_page.dart';
import '../dawri/dawri_detail_page.dart';
import '../../services/dawri_service.dart';
import '../../models/dawri_model.dart';
import '../study_tracker/study_tracker_page.dart';
import '../../models/study_track_model.dart';
import '../../services/study_track_service.dart';
import '../badges/badges_page.dart';
import '../../widgets/closest_badge_widget.dart';
import '../../widgets/ramadan_countdown_card.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) => GoogleFonts.ibmPlexSansArabic(
  fontSize: sz,
  fontWeight: fw,
  color: c,
  height: h,
);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _fajrChecked = false;
  bool _charityChecked = false;
  bool _quranChecked = false;
  bool _azkarChecked = false;
  bool _istighfarChecked = false;
  bool _isLoadingAccountability = true;
  bool _isAccountabilityDone = false;
  bool _isLoadingSummary = true;
  Map<String, dynamic> _todaySummary = {};
  final FirebaseService _firebaseService = FirebaseService();
  final DailySummaryService _dailySummaryService = DailySummaryService();
  final WirdService _wirdService = WirdService();
  WirdDayRecord? _wirdRecord;
  int _wirdStreak = 0;
  final StudyTrackService _studyService = StudyTrackService();
  List<StudyPlaylist> _studyPlaylists = [];
  // Dawri (leagues) dashboard state
  final DawriService _dawriService = DawriService();
  Dawri? _featuredDawri;
  List<DawriMemberWeekStats> _featuredLeaderboard = [];
  bool _loadingDawri = false;
  // Next prayer state
  String _nextPrayerName = '';
  String _nextPrayerKey = '';
  DateTime? _nextPrayerTime;
  String _afterPrayerName = '';
  DateTime? _afterPrayerTime;
  List<Map<String, dynamic>> _allPrayerTimes = [];
  bool _loadingPrayer = false;
  // Fajr tree state
  int _fajrStreak = 0;
  List<bool> _fajrWeekDays = List.filled(7, false);
  DateTime _fajrWeekStart = DateTime.now().subtract(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _preloadPrayerTimesSync();
    _checkTodayAccountability();
    _loadTodaySummary();
    _loadWirdData();
    _loadStudyData();
    _loadDawriWidget();
    _loadNextPrayer();
    _loadFajrWeekly();
  }

  void _preloadPrayerTimesSync() {
    try {
      final twoInfo = AzanService().getNextTwoPrayersInfoSync();
      final allTimes = AzanService().getAllPrayerTimesSync();
      final next = twoInfo['next']!;
      final after = twoInfo['after']!;
      _nextPrayerName = next['name'] as String? ?? '';
      _nextPrayerKey = next['key'] as String? ?? '';
      _nextPrayerTime = next['time'] as DateTime?;
      _afterPrayerName = after['name'] as String? ?? '';
      _afterPrayerTime = after['time'] as DateTime?;
      _allPrayerTimes = allTimes;
      _loadingPrayer = false;
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
      _loadNextPrayer();
      _loadFajrWeekly();
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
    _loadStudyData();
    _loadDawriWidget();
    _loadNextPrayer();
    _loadFajrWeekly();
  }

  Future<void> _loadStudyData() async {
    await _studyService.init();
    if (mounted) {
      setState(() => _studyPlaylists = _studyService.getAllPlaylists());
    }
  }

  Future<void> _loadDawriWidget() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) return;
    setState(() => _loadingDawri = true);
    try {
      final list = await _dawriService.getUserDawriList(userId);
      if (list.isEmpty) {
        if (mounted)
          setState(() {
            _featuredDawri = null;
            _loadingDawri = false;
          });
        return;
      }
      // Pick first active league as featured
      final dawri = list.firstWhere(
        (d) => d.isActive,
        orElse: () => list.first,
      );
      final board = await _dawriService.getLeaderboard(
        dawri: dawri,
        period: 'today',
      );
      if (mounted)
        setState(() {
          _featuredDawri = dawri;
          _featuredLeaderboard = board;
          _loadingDawri = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingDawri = false);
    }
  }

  Future<void> _loadNextPrayer() async {
    if (_allPrayerTimes.isEmpty) {
      setState(() => _loadingPrayer = true);
    }
    try {
      final results = await Future.wait([
        AzanService().getNextTwoPrayersInfo(),
        AzanService().getAllPrayerTimes(),
      ]);
      if (mounted) {
        final twoInfo = results[0] as Map<String, Map<String, dynamic>>;
        final allTimes = results[1] as List<Map<String, dynamic>>;
        final next = twoInfo['next']!;
        final after = twoInfo['after']!;
        setState(() {
          _nextPrayerName = next['name'] as String? ?? '';
          _nextPrayerKey = next['key'] as String? ?? '';
          _nextPrayerTime = next['time'] as DateTime?;
          _afterPrayerName = after['name'] as String? ?? '';
          _afterPrayerTime = after['time'] as DateTime?;
          _allPrayerTimes = allTimes;
          _loadingPrayer = false;
        });
      }
      // Refresh dynamic wird notifications with latest prayer times
      WirdNotificationService().scheduleAll().catchError((_) {});
    } catch (_) {
      if (mounted) setState(() => _loadingPrayer = false);
    }
  }

  Future<void> _loadFajrWeekly() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) return;

    final today = DateTime.now();
    // Week starts on Saturday (weekday == 6 in Dart, Mon=1…Sun=7)
    // We show 7 days ending today
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6));

    try {
      // One query covers the week view and a streak that crosses months.
      final records = await _firebaseService.getWorshipsInRange(
        userId,
        today.subtract(const Duration(days: 400)),
        today,
      );
      final prayedKeys = <String>{
        for (final r in records)
          if (r.fajrPrayed) fajrDayKey(r.date),
      };

      final days = List.generate(
        7,
        (i) =>
            prayedKeys.contains(fajrDayKey(weekStart.add(Duration(days: i)))),
      );

      if (mounted) {
        setState(() {
          _fajrWeekDays = days;
          _fajrWeekStart = weekStart;
          _fajrStreak = fajrStreakFromDays(prayedKeys, today);
        });
      }
    } catch (_) {}
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
      final worships = await _firebaseService.getDailyWorshipByDate(
        userId,
        DateTime.now(),
      );
      if (worships.isNotEmpty) {
        final today = worships.first;
        setState(() {
          _fajrChecked = today.fajrPrayed;
          _charityChecked = today.worships['charity'] == true;
          _quranChecked = today.worships['quran_read'] == true;
          _azkarChecked = today.worships['azkar_done'] == true;
          _istighfarChecked = today.worships['istighfar_done'] == true;
          _isAccountabilityDone =
              _fajrChecked &&
              _charityChecked &&
              _quranChecked &&
              _azkarChecked &&
              _istighfarChecked;
          _isLoadingAccountability = false;
        });
      } else {
        setState(() => _isLoadingAccountability = false);
      }
    } catch (e) {
      setState(() => _isLoadingAccountability = false);
    }
  }

  Future<void> _persistAccountability() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) return;

    try {
      final worships = await _firebaseService.getDailyWorshipByDate(
        userId,
        DateTime.now(),
      );
      String docId = worships.isNotEmpty
          ? worships.first.id
          : const uuid.Uuid().v4();

      final data = db_model.DailyWorship(
        id: docId,
        date: DateTime.now(),
        prayerCount: db_model.DailyWorship.prayerCountAfterFajr(
          worships.firstOrNull,
          _fajrChecked,
        ),
        quranPages: worships.isNotEmpty ? worships.first.quranPages : 0,
        notes: worships.firstOrNull?.notes ?? '',
        worships: {
          ...?worships.firstOrNull?.worships,
          db_model.DailyWorship.fajrPrayedKey: _fajrChecked,
          'charity': _charityChecked,
          'quran_read': _quranChecked,
          'azkar_done': _azkarChecked,
          'istighfar_done': _istighfarChecked,
        },
      );

      await _firebaseService.saveDailyWorship(userId, data);
      setState(() {
        _isAccountabilityDone =
            _fajrChecked &&
            _charityChecked &&
            _quranChecked &&
            _azkarChecked &&
            _istighfarChecked;
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
    final days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
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
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── Modern Enhanced Header ──
              // ── Glass Prayer Arch Header ──
              SliverToBoxAdapter(
                child: _buildArchHeader(isDark, userName, isGuest),
              ),

              // ── Last Read Quran Progress Card (متابعة القراءة) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                  child: _buildLastReadQuranCard(isDark),
                ),
              ),

              // ── Interactive Home Dhikr Counter (مسبحة الرئيسية) ──
              SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'مسبحة الذكر السريع',
                  icon: Icons.touch_app_rounded,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _HomeDhikrCounterCard(
                    isDark: isDark,
                    onOpenFullCounter: () => _to(const AzkarCounterPage()),
                  ),
                ),
              ),

              // ── Today's Focus Section (only for logged-in users) ──
              if (!isGuest) ...[
                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: 'محاسبة اليوم',
                    icon: Icons.auto_awesome_rounded,
                  ),
                ),
                SliverToBoxAdapter(child: _buildDailyAccountability(isDark)),
              ],

              // ── Ramadan Coming Soon ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: const RamadanCountdownCard(),
                ),
              ),

              // ── Daily Summary Section ──
              if (!isGuest && _todaySummary['hasData'] == true) ...[
                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: 'ملخص عبادات اليوم',
                    icon: Icons.summarize_rounded,
                  ),
                ),
                SliverToBoxAdapter(child: _buildDailySummaryCard(isDark)),
              ],

              // ── Prayer Times Card ──
              SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'مواقيت الصلاة',
                  icon: Icons.access_time_filled_rounded,
                ),
              ),
              SliverToBoxAdapter(
                child: PrayerTimesCard(
                  allPrayers: _allPrayerTimes,
                  nextPrayerName: _nextPrayerName,
                  nextPrayerTime: _nextPrayerTime,
                  afterPrayerTime: _afterPrayerTime,
                  loading: _loadingPrayer,
                  isDark: isDark,
                  onTap: () => _to(const PrayerTimesPage()),
                ),
              ),

              // ── Fajr Tree Section ──
              SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'شجرتك تنمو باستيقاظك للفجر',
                  icon: Icons.park_rounded,
                ),
              ),
              SliverToBoxAdapter(
                child: FajrTreeWidget(
                  streak: _fajrStreak,
                  weekDays: _fajrWeekDays,
                  weekStart: _fajrWeekStart,
                  isDark: isDark,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FajrStreakPage()),
                    );
                    // Refresh fajr data when returning
                    _loadFajrWeekly();
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── Closest Badge Widget ──
              if (!isGuest) ...[
                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: 'أقرب وسام',
                    icon: Icons.military_tech_rounded,
                  ),
                ),
                SliverToBoxAdapter(child: ClosestBadgeWidget(isDark: isDark)),
              ],

              // ── Daily Wird Section ──
              SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'الورد اليومي',
                  icon: Icons.auto_stories_rounded,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildWirdCard(isDark, isGuest: isGuest),
              ),

              // ── Study Tracker Section ──
              SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'متابعة الدراسة',
                  icon: Icons.school_rounded,
                ),
              ),
              SliverToBoxAdapter(child: _buildStudyTrackerSection(isDark)),

              // ── Leagues (Dawri) Widget ──
              if (!isGuest) ...[
                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: 'الأصدقاء',
                    icon: Icons.emoji_events_rounded,
                  ),
                ),
                SliverToBoxAdapter(child: _buildDawriWidget(isDark)),
              ],

              // ── Quick Access Section ──
              SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'الوصول السريع',
                  icon: Icons.grid_view_rounded,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _QuickChip(
                        icon: Icons.access_time_filled_rounded,
                        label: 'مواقيت الصلاة',
                        color: Colors.blue,
                        onTap: () => _to(const PrayerTimesPage()),
                      ),
                      _QuickChip(
                        icon: Icons.volume_up_rounded,
                        label: 'الأذان',
                        color: Colors.teal,
                        onTap: () => _to(const AzanSettingsPage()),
                      ),
                      _QuickChip(
                        icon: Icons.explore_rounded,
                        label: 'اتجاة القبلة',
                        color: Colors.green,
                        onTap: () => _to(const QiblaPage()),
                      ),
                      _QuickChip(
                        icon: Icons.menu_book_rounded,
                        label: 'المصحف الشريف',
                        color: Colors.purple,
                        onTap: () => _to(const QuranPage()),
                      ),
                      _QuickChip(
                        icon: Icons.headphones_rounded,
                        label: 'مزامير القرآن',
                        color: const Color(0xFF1B7A4E),
                        onTap: () => _to(const ReciterLibraryPage()),
                      ),
                      _QuickChip(
                        icon: Icons.location_on_rounded,
                        label: 'المساجد',
                        color: Colors.cyan,
                        onTap: () => NearbyMosquesPage.show(context),
                      ),
                      _QuickChip(
                        icon: Icons.import_contacts_rounded,
                        label: 'مكتبة الأذكار',
                        color: Colors.orange,
                        onTap: () => _to(const AzkarLibraryPage()),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Features Sections (protected for guests) ──
              SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'أدوات العبادة',
                  icon: Icons.stars_rounded,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  children: [
                    _FeatureCard(
                      icon: Icons.wb_sunny_rounded,
                      label: 'عباداتي',
                      color: Colors.amber,
                      isDark: isDark,
                      onTap: () => _toProtected(const WorshipPage()),
                    ),
                    _FeatureCard(
                      icon: Icons.track_changes_rounded,
                      label: 'الأهداف',
                      color: Colors.pink,
                      isDark: isDark,
                      onTap: () => _toProtected(const GoalsPage()),
                    ),
                    _FeatureCard(
                      icon: Icons.calendar_today_rounded,
                      label: 'الخطة',
                      color: Colors.indigo,
                      isDark: isDark,
                      onTap: () => _toProtected(const SmartPlanPage()),
                    ),
                    _FeatureCard(
                      icon: Icons.analytics_rounded,
                      label: 'التحليلات',
                      color: Colors.deepPurple,
                      isDark: isDark,
                      onTap: () => _toProtected(const AnalyticsPage()),
                    ),
                    _FeatureCard(
                      icon: Icons.emoji_events_rounded,
                      label: 'التحديات',
                      color: Colors.orange,
                      isDark: isDark,
                      onTap: () => _toProtected(const ChallengesPage()),
                    ),
                    _FeatureCard(
                      icon: Icons.description_rounded,
                      label: 'التقارير',
                      color: Colors.blueGrey,
                      isDark: isDark,
                      onTap: () => _toProtected(const ReportsPage()),
                    ),
                    _FeatureCard(
                      icon: Icons.military_tech_rounded,
                      label: 'الأوسمة',
                      color: AppColors.gold,
                      isDark: isDark,
                      onTap: () => _toProtected(const BadgesPage()),
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: _SectionTitle(
                  title: 'المزيد',
                  icon: Icons.add_circle_outline_rounded,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  children: [
                    _FeatureCard(
                      icon: Icons.today_rounded,
                      label: 'سنن الجمعة',
                      color: Colors.teal,
                      isDark: isDark,
                      onTap: () => _to(const FridayTipsPage()),
                    ),
                    _FeatureCard(
                      icon: Icons.import_contacts_rounded,
                      label: 'مكتبة الأذكار',
                      color: Colors.green,
                      isDark: isDark,
                      onTap: () => _to(const AzkarLibraryPage()),
                    ),
                    _FeatureCard(
                      icon: Icons.mosque_rounded,
                      label: 'المساجد',
                      color: Colors.blueAccent,
                      isDark: isDark,
                      onTap: () => NearbyMosquesPage.show(context),
                    ),
                    _FeatureCard(
                      icon: Icons.headphones_rounded,
                      label: 'مزامير القرآن',
                      color: const Color(0xFF1B5E20),
                      isDark: isDark,
                      onTap: () => _to(const ReciterLibraryPage()),
                    ),
                    _FeatureCard(
                      icon: Icons.volume_up_rounded,
                      label: 'إعدادات الأذان',
                      color: Colors.indigo,
                      isDark: isDark,
                      onTap: () => _to(const AzanSettingsPage()),
                    ),
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
            _ModernNavBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
          ],
        ),
      ),
    );
  }

  void _to(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Icon(Icons.lock_outline_rounded, size: 56, color: AppColors.gold),
              const SizedBox(height: 16),
              Text(
                'يجب تسجيل الدخول',
                style: _f(
                  sz: 20,
                  fw: FontWeight.w800,
                  c: isDark ? Colors.white : AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سجل دخولك للوصول إلى جميع الميزات',
                style: _f(sz: 14, c: AppColors.gray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'تسجيل الدخول',
                    style: _f(sz: 16, fw: FontWeight.bold, c: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingPage()),
                  );
                },
                child: Text(
                  'إنشاء حساب جديد',
                  style: _f(sz: 14, fw: FontWeight.w700, c: AppColors.midGreen),
                ),
              ),
            ],
          ),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الورد اليومي',
                                style: _f(
                                  sz: 17,
                                  fw: FontWeight.w800,
                                  c: Colors.white,
                                ),
                              ),
                              Text(
                                'تابع تقدمك اليومي في القرآن',
                                style: _f(sz: 12, c: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '7',
                                style: _f(
                                  sz: 13,
                                  fw: FontWeight.w900,
                                  c: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: 0.6,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '12 / 20 صفحة',
                          style: _f(sz: 12, c: Colors.white70),
                        ),
                        Row(
                          children: WirdSession.all
                              .map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    WirdSession.iconData(s),
                                    size: 16,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ],
                ),
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
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'سجل دخولك لتفعيل الورد اليومي',
                          style: _f(
                            sz: 13,
                            fw: FontWeight.w700,
                            c: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تتبع تقدمك وحافظ على streak مواظبتك',
                          style: _f(sz: 11, c: Colors.white70),
                        ),
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
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyWirdPage()),
            );
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الورد اليومي',
                        style: _f(sz: 17, fw: FontWeight.w800, c: Colors.white),
                      ),
                      Text(
                        'اضغط لبدء وردك اليومي',
                        style: _f(sz: 12, c: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DailyWirdPage()),
          );
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
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الورد اليومي',
                          style: _f(
                            sz: 17,
                            fw: FontWeight.w800,
                            c: Colors.white,
                          ),
                        ),
                        Text(
                          record.isCompleted
                              ? 'أتممت وردك اليوم! تقبل الله'
                              : 'اقرأ وردك اليومي من القرآن الكريم',
                          style: _f(sz: 12, c: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$streak',
                            style: _f(
                              sz: 14,
                              fw: FontWeight.w900,
                              c: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${record.pagesRead} / ${record.targetPages} صفحة',
                    style: _f(sz: 12, c: Colors.white70),
                  ),
                  Row(
                    children: WirdSession.all.map((s) {
                      final done =
                          (record.sessionPages[s] ?? 0) >=
                          record.pagesPerSession;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          WirdSession.iconData(s),
                          size: 18,
                          color: done
                              ? WirdSession.iconColor(s)
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudyTrackerSection(bool isDark) {
    if (_studyPlaylists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudyTrackerPage()),
            );
            _loadStudyData();
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C17) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.darkGreen.withValues(
                  alpha: isDark ? 0.3 : 0.15,
                ),
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: AppColors.darkGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ابدأ متابعة دراستك',
                        style: _f(
                          sz: 15,
                          fw: FontWeight.w800,
                          c: isDark ? Colors.white : AppColors.darkGreen,
                        ),
                      ),
                      Text(
                        'أضف سلسلة علمية أو يوتيوب لتتابع تقدمك',
                        style: _f(sz: 12, c: AppColors.gray),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _studyPlaylists.length > 4
                ? 5
                : _studyPlaylists.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              if (i ==
                  (_studyPlaylists.length > 4 ? 4 : _studyPlaylists.length)) {
                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudyTrackerPage(),
                      ),
                    );
                    _loadStudyData();
                  },
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151C17) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.darkGreen.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.darkGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: AppColors.darkGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'عرض الكل',
                          style: _f(
                            sz: 11,
                            fw: FontWeight.w700,
                            c: AppColors.darkGreen,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              final p = _studyPlaylists[i];
              final isYt = p.type == StudySourceType.youtube;
              return GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudyTrackerPage()),
                  );
                  _loadStudyData();
                },
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: isYt
                          ? [const Color(0xFFB71C1C), const Color(0xFFE53935)]
                          : isDark
                          ? [const Color(0xFF1A3A28), const Color(0xFF0D2818)]
                          : [AppColors.darkGreen, const Color(0xFF145A3A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isYt
                                ? Icons.smart_display_rounded
                                : Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.title,
                              style: _f(
                                sz: 11,
                                fw: FontWeight.w800,
                                c: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p.progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        p.totalCount == 0
                            ? 'لا توجد حلقات'
                            : '${p.watchedCount}/${p.totalCount} • ${(p.progress * 100).round()}%',
                        style: _f(sz: 10, c: Colors.white70),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Dawri (Leagues) Dashboard Widget ──────────────────────────────────────
  Widget _buildDawriWidget(bool isDark) {
    final cardBg = isDark ? const Color(0xFF151C17) : Colors.white;

    // Loading state
    if (_loadingDawri) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.darkGreen,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    // No leagues yet
    if (_featuredDawri == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DawriPage()),
            );
            _loadDawriWidget();
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.gold,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ابدأ دورياً مع أصدقائك',
                        style: _f(
                          sz: 15,
                          fw: FontWeight.w800,
                          c: isDark ? Colors.white : AppColors.darkGreen,
                        ),
                      ),
                      Text(
                        'تنافسوا على الصلوات والعبادات',
                        style: _f(sz: 12, c: AppColors.gray),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Featured league card
    final dawri = _featuredDawri!;
    final board = _featuredLeaderboard;
    final me = context.read<AppAuthProvider>().userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DawriDetailPage(dawriId: dawri.id),
            ),
          );
          _loadDawriWidget();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.darkGreen.withOpacity(isDark ? 0.3 : 0.12),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: league name + "عرض الدوري المفضل"
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'عرض الدوري المفضل',
                      style: _f(
                        sz: 13,
                        c: isDark ? Colors.white54 : AppColors.gray,
                      ),
                    ),
                  ),
                  Text(
                    dawri.name,
                    style: _f(
                      sz: 15,
                      fw: FontWeight.w800,
                      c: isDark ? Colors.white : AppColors.darkGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Member avatars with rank numbers and points
              board.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد أعضاء بعد',
                        style: _f(sz: 13, c: AppColors.gray),
                      ),
                    )
                  : SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: board.length > 6 ? 6 : board.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (ctx, i) {
                          final stat = board[i];
                          final isMe = stat.userId == me;
                          final avatarColors = [
                            AppColors.darkGreen,
                            AppColors.midGreen,
                            Colors.purple,
                            Colors.blue,
                            Colors.orange,
                            Colors.pink,
                          ];
                          final color =
                              avatarColors[stat.name.codeUnits.fold(
                                    0,
                                    (a, b) => a + b,
                                  ) %
                                  avatarColors.length];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Avatar circle
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isMe
                                            ? AppColors.gold
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withOpacity(0.35),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        stat.name.isNotEmpty
                                            ? stat.name[0].toUpperCase()
                                            : '؟',
                                        style: _f(
                                          sz: 16,
                                          fw: FontWeight.bold,
                                          c: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Rank badge
                                  if (i < 3)
                                    Positioned(
                                      top: -6,
                                      right: -6,
                                      child: Text(
                                        i == 0
                                            ? '🥇'
                                            : i == 1
                                            ? '🥈'
                                            : '🥉',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    )
                                  else
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: AppColors.gray,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: cardBg,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${i + 1}',
                                            style: _f(
                                              sz: 9,
                                              fw: FontWeight.w900,
                                              c: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              // Name
                              SizedBox(
                                width: 48,
                                child: Text(
                                  isMe ? 'أنت' : stat.name.split(' ').first,
                                  style: _f(
                                    sz: 10,
                                    fw: FontWeight.w700,
                                    c: isMe
                                        ? AppColors.gold
                                        : isDark
                                        ? Colors.white70
                                        : AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Points
                              Text(
                                '${stat.weekPoints}',
                                style: _f(
                                  sz: 11,
                                  fw: FontWeight.w900,
                                  c: isDark ? Colors.white54 : AppColors.gray,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

              const SizedBox(height: 12),

              // Footer: today's date label
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: AppColors.gray.withOpacity(0.6),
                  ),
                  const SizedBox(width: 5),
                  Text(_getArabicDate(), style: _f(sz: 11, c: AppColors.gray)),
                  const Spacer(),
                  Text(
                    'اليوم • بالنقاط',
                    style: _f(
                      sz: 11,
                      fw: FontWeight.w700,
                      c: isDark ? Colors.white54 : AppColors.darkGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailySummaryCard(bool isDark) {
    if (_isLoadingSummary) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final prayerCount = _todaySummary['prayerCount'] ?? 0;
    final quranPages = _todaySummary['quranPages'] ?? 0;
    final completedWorships =
        (_todaySummary['completedWorships'] as List<dynamic>?)
            ?.cast<String>() ??
        [];
    final totalWorships = _todaySummary['totalWorships'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: isDark
                ? [const Color(0xFF1A4D2E), const Color(0xFF0D2818)]
                : [AppColors.darkGreen, AppColors.midGreen],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.gold.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkGreen.withOpacity(isDark ? 0.2 : 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
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
                  child: const Icon(
                    Icons.summarize_rounded,
                    color: AppColors.gold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملخص عبادات اليوم',
                        style: _f(sz: 16, fw: FontWeight.w800, c: Colors.white),
                      ),
                      Text(
                        'إنجازاتك الروحية لهذا اليوم 🤍',
                        style: _f(sz: 12, c: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalWorships',
                    style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _summaryItem(
                    'الصلوات',
                    '$prayerCount/5',
                    Icons.mosque_rounded,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryItem(
                    'صفحات القرآن',
                    '$quranPages',
                    Icons.menu_book_rounded,
                    isDark,
                  ),
                ),
              ],
            ),
            if (completedWorships.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'العبادات الأخرى:',
                style: _f(sz: 12, fw: FontWeight.w600, c: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: completedWorships.take(4).map((worship) {
                  final displayName = _getWorshipDisplayName(worship);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
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
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _f(sz: 11, c: Colors.white70)),
                Text(
                  value,
                  style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white),
                ),
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
      case 'morning_azkar':
        return 'أذكار الصباح';
      case 'eveningRemembrance':
      case 'evening_azkar_done':
        return 'أذكار المساء';
      case 'quranRecitation':
      case 'quran_read':
      case 'quran':
        return 'قراءة القرآن';
      case 'charity':
        return 'الصدقة';
      case 'nightPrayer':
      case 'qiyam':
        return 'قيام الليل';
      case 'fasting':
        return 'الصيام';
      case 'fasting_ayyam_beed':
        return 'صيام الأيام البيض';
      case 'taraweeh':
        return 'التراويح';
      case 'dhikr':
      case 'azkar_done':
        return 'الأذكار';
      case 'istighfar_done':
        return 'الاستغفار';
      case 'fajr_prayed':
        return 'صلاة الفجر';
      case 'fajr_woke_alarm':
        return 'الاستيقاظ لصلاة الفجر';
      case 'prayer':
        return 'الصلوات';
      default:
        return key;
    }
  }

  Widget _buildDailyAccountability(bool isDark) {
    if (_isLoadingAccountability) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final items = <_AccountabilityChipData>[
      _AccountabilityChipData(
        label: 'الفجر',
        icon: Icons.wb_twilight_rounded,
        checked: _fajrChecked,
        color: const Color(0xFF1A237E),
        onTap: () => _toggleAccountabilityItem('fajr'),
      ),
      _AccountabilityChipData(
        label: 'الورد',
        icon: Icons.menu_book_rounded,
        checked: _quranChecked,
        color: AppColors.darkGreen,
        onTap: () => _toggleAccountabilityItem('quran'),
      ),
      _AccountabilityChipData(
        label: 'الأذكار',
        icon: Icons.spa_rounded,
        checked: _azkarChecked,
        color: const Color(0xFF6A1B9A),
        onTap: () => _toggleAccountabilityItem('azkar'),
      ),
      _AccountabilityChipData(
        label: 'الاستغفار',
        icon: Icons.favorite_rounded,
        checked: _istighfarChecked,
        color: const Color(0xFFE65100),
        onTap: () => _toggleAccountabilityItem('istighfar'),
      ),
      _AccountabilityChipData(
        label: 'الصدقة',
        icon: Icons.volunteer_activism_rounded,
        checked: _charityChecked,
        color: const Color(0xFFF9A825),
        onTap: () => _toggleAccountabilityItem('charity'),
      ),
    ];

    final doneCount = [
      _fajrChecked,
      _quranChecked,
      _azkarChecked,
      _istighfarChecked,
      _charityChecked,
    ].where((e) => e).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '$doneCount/5',
                style: _f(sz: 11, fw: FontWeight.w800, c: AppColors.gold),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: doneCount / 5,
                    minHeight: 4,
                    backgroundColor: isDark
                        ? Colors.white12
                        : AppColors.paleGreen,
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) =>
                _AccountabilityChip(data: items[i], isDark: isDark),
          ),
        ),
      ],
    );
  }

  void _toggleAccountabilityItem(String key) {
    setState(() {
      switch (key) {
        case 'fajr':
          _fajrChecked = !_fajrChecked;
          break;
        case 'quran':
          _quranChecked = !_quranChecked;
          break;
        case 'azkar':
          _azkarChecked = !_azkarChecked;
          break;
        case 'istighfar':
          _istighfarChecked = !_istighfarChecked;
          break;
        case 'charity':
          _charityChecked = !_charityChecked;
          break;
      }
      _isAccountabilityDone =
          _fajrChecked &&
          _charityChecked &&
          _quranChecked &&
          _azkarChecked &&
          _istighfarChecked;
    });
    _persistAccountability();
  }

  Widget _buildLastReadQuranCard(bool isDark) {
    if (!Hive.isBoxOpen('quran_progress')) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<Box>(
      valueListenable: Hive.box(
        'quran_progress',
      ).listenable(keys: ['last_read']),
      builder: (context, box, _) {
        final raw = box.get('last_read');
        final hasSaved = raw is Map;
        final int surahNumber = hasSaved
            ? ((raw['surahNumber'] as int?) ?? 1)
            : 1;
        final String surahName = hasSaved
            ? ((raw['surahName'] as String?) ?? 'الفاتحة')
            : 'الفاتحة';
        final int page = hasSaved ? ((raw['page'] as int?) ?? 1) : 1;
        final int juz = hasSaved ? ((raw['juz'] as int?) ?? 1) : 1;
        final int verse = hasSaved ? ((raw['verse'] as int?) ?? 1) : 1;
        final double progress = (page / 604.0).clamp(0.0, 1.0);
        final int percent = (progress * 100).round();

        final scheme = Theme.of(context).colorScheme;
        final primary = scheme.primary;
        final titleColor = scheme.onSurface;
        final muted = scheme.onSurface.withValues(alpha: isDark ? 0.64 : 0.58);
        final line = scheme.outline.withValues(alpha: isDark ? 0.28 : 0.16);
        final track = primary.withValues(alpha: isDark ? 0.16 : 0.12);
        final cardGradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.dashboardGreenTop, AppColors.dashboardGreenBottom]
              : [AppColors.dashboardMintTop, AppColors.dashboardMintBottom],
        );

        Future<void> openReader() async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SurahReaderPage(
                surahNumber: surahNumber,
                initialPage: page,
              ),
            ),
          );
          if (mounted) _loadWirdData();
        }

        return Container(
          decoration: BoxDecoration(
            gradient: cardGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: line),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      hasSaved ? 'آخر موضع' : 'ابدأ ختمتك',
                      style: _f(sz: 12, fw: FontWeight.w700, c: primary),
                    ),
                    const Spacer(),
                    Text(
                      'الجزء $juz',
                      style: _f(sz: 12, fw: FontWeight.w600, c: muted),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      style: _f(sz: 12, fw: FontWeight.w800, c: primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: track,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سورة $surahName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.amiri(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasSaved
                                ? 'صفحة $page من 604  ·  الآية $verse'
                                : 'افتح المصحف وسيُحفظ مكان توقفك',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _f(sz: 12, fw: FontWeight.w500, c: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: track,
                    valueColor: AlwaysStoppedAnimation(primary),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: openReader,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    hasSaved ? 'متابعة القراءة' : 'ابدأ القراءة',
                    style: _f(
                      sz: 14,
                      fw: FontWeight.w700,
                      c: scheme.onPrimary,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: scheme.onPrimary,
                    minimumSize: const Size.fromHeight(44),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _to(const QuranPage()),
                        icon: Icon(Icons.list_alt_rounded, size: 16, color: muted),
                        label: Text(
                          'الفهرس',
                          style: _f(sz: 12.5, fw: FontWeight.w700, c: muted),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Container(width: 1, height: 14, color: line),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReadingStopsPage(),
                          ),
                        ),
                        icon: Icon(
                          Icons.bookmark_rounded,
                          size: 16,
                          color: muted,
                        ),
                        label: Text(
                          'المواضع',
                          style: _f(sz: 12.5, fw: FontWeight.w700, c: muted),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Interactive Home Screen Dhikr Counter ──

class _HomeDhikrCounterCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback onOpenFullCounter;

  const _HomeDhikrCounterCard({
    required this.isDark,
    required this.onOpenFullCounter,
  });

  @override
  State<_HomeDhikrCounterCard> createState() => _HomeDhikrCounterCardState();
}

class _HomeDhikrCounterCardState extends State<_HomeDhikrCounterCard> {
  static const List<Map<String, dynamic>> _dhikrOptions = [
    {
      'text': 'سبحان الله وبحمده',
      'target': 33,
      'reward': 'حُطَّت خطاياه وإن كانت مثل زبد البحر',
    },
    {
      'text': 'أستغفر الله وأتوب إليه',
      'target': 100,
      'reward': 'من لزم الاستغفار جعل الله له من كل هم فرجاً',
    },
    {'text': 'سبحان الله', 'target': 33, 'reward': 'تملأ ميزان الحسنات'},
    {'text': 'الحمد لله', 'target': 33, 'reward': 'الحمد لله تملأ الميزان'},
    {
      'text': 'لا إله إلا الله',
      'target': 100,
      'reward': 'أفضل الذكر لا إله إلا الله',
    },
    {'text': 'الله أكبر', 'target': 34, 'reward': 'تملأ ما بين السماء والأرض'},
    {
      'text': 'اللهم صلِّ وسلم على نبينا محمد',
      'target': 10,
      'reward': 'من صلى عليّ صلاة صلى الله عليه بها عشراً',
    },
  ];

  int _selectedIndex = 0;
  int _count = 0;
  int _dailyTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void _loadState() {
    try {
      if (!Hive.isBoxOpen('home_dhikr')) return;
      final box = Hive.box('home_dhikr');
      final savedDay = box.get('daily_date') as String?;
      final today = _todayKey();
      setState(() {
        _selectedIndex = ((box.get('selected_index') as int?) ?? 0).clamp(
          0,
          _dhikrOptions.length - 1,
        );
        _count = (box.get('count_$_selectedIndex') as int?) ?? 0;
        _dailyTotal = (savedDay == today)
            ? ((box.get('daily_total') as int?) ?? 0)
            : 0;
      });
    } catch (_) {}
  }

  Future<void> _saveState() async {
    try {
      if (!Hive.isBoxOpen('home_dhikr')) return;
      final box = Hive.box('home_dhikr');
      await box.put('selected_index', _selectedIndex);
      await box.put('count_$_selectedIndex', _count);
      await box.put('daily_date', _todayKey());
      await box.put('daily_total', _dailyTotal);
    } catch (_) {}
  }

  void _increment() {
    final target = _dhikrOptions[_selectedIndex]['target'] as int;
    final nextCount = _count + 1;
    if (nextCount % target == 0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _count = nextCount;
      _dailyTotal += 1;
    });
    _saveState();
  }

  void _resetCurrent() {
    HapticFeedback.selectionClick();
    setState(() {
      _count = 0;
    });
    _saveState();
  }

  void _selectPhrase(int index) {
    HapticFeedback.selectionClick();
    int savedForPhrase = 0;
    try {
      if (Hive.isBoxOpen('home_dhikr')) {
        savedForPhrase =
            (Hive.box('home_dhikr').get('count_$index') as int?) ?? 0;
      }
    } catch (_) {}
    setState(() {
      _selectedIndex = index;
      _count = savedForPhrase;
    });
    _saveState();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final item = _dhikrOptions[_selectedIndex];
    final String phrase = item['text'] as String;
    final int target = item['target'] as int;
    final String reward = item['reward'] as String;
    final int cycleCount = _count % target;
    final double progress = _count > 0 && cycleCount == 0
        ? 1.0
        : (cycleCount / target);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16211C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.gold.withValues(alpha: 0.25)
              : AppColors.darkGreen.withValues(alpha: 0.12),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phrase selector chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _dhikrOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = i == _selectedIndex;
                return GestureDetector(
                  onTap: () => _selectPhrase(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.darkGreen
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF0F6F3)),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? AppColors.gold.withValues(alpha: 0.6)
                            : Colors.transparent,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _dhikrOptions[i]['text'] as String,
                      style: _f(
                        sz: 12,
                        fw: selected ? FontWeight.w800 : FontWeight.w600,
                        c: selected
                            ? Colors.white
                            : (isDark ? Colors.white70 : AppColors.darkGreen),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Interactive Counter Ring Button
              GestureDetector(
                onTap: _increment,
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: isDark
                              ? Colors.white12
                              : const Color(0xFFE4EFEA),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.gold,
                          ),
                        ),
                      ),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF145A3A), Color(0xFF1E8255)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF145A3A,
                              ).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_count',
                              style: _f(
                                sz: 22,
                                fw: FontWeight.w900,
                                c: Colors.white,
                              ),
                            ),
                            Text(
                              'اضغط للتسبيح',
                              style: _f(
                                sz: 9,
                                fw: FontWeight.w600,
                                c: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Active Dhikr Details & Actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phrase,
                      style: GoogleFonts.amiri(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reward,
                      style: _f(
                        sz: 11.5,
                        fw: FontWeight.w600,
                        c: isDark ? Colors.white60 : AppColors.gray,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'مجموع اليوم: $_dailyTotal',
                            style: _f(
                              sz: 11,
                              fw: FontWeight.w800,
                              c: isDark
                                  ? AppColors.gold
                                  : const Color(0xFF8C6218),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _resetCurrent,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 15,
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.gray,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'تصفير',
                                  style: _f(
                                    sz: 11,
                                    fw: FontWeight.w600,
                                    c: isDark ? Colors.white54 : AppColors.gray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: widget.onOpenFullCounter,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 14,
                                  color: AppColors.midGreen,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'المسبحة الكاملة',
                                  style: _f(
                                    sz: 11,
                                    fw: FontWeight.w700,
                                    c: AppColors.midGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Small Support Widgets ──

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}

/// Auto-rotating, swipeable carousel of religious quotes ("نورٌ وبصيرة")
/// updated throughout the week with options to copy text, share text, or
/// share as a styled image.
class _QuoteCarousel extends StatefulWidget {
  final String date;
  const _QuoteCarousel({required this.date});

  @override
  State<_QuoteCarousel> createState() => _QuoteCarouselState();
}

class _QuoteCarouselState extends State<_QuoteCarousel> {
  // Curated sets updated throughout the 7 days of the week
  static const Map<int, List<Map<String, String>>> _weeklyQuotesByWeekday = {
    // Monday (1)
    1: [
      {
        'text':
            'تُعْرَضُ الأَعْمَالُ يَوْمَ الاِثْنَيْنِ وَالْخَمِيسِ فَأُحِبُّ أَنْ يُعْرَضَ عَمَلِي وَأَنَا صَائِمٌ',
        'source': 'حديث شريف',
      },
      {
        'text':
            'وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا وَيَرْزُقْهُ مِنْ حَيْثُ لَا يَحْتَسِبُ',
        'source': 'سورة الطلاق',
      },
      {
        'text': 'إنّما الأعمالُ بالنيّات وإنّما لكلِّ امرئٍ ما نوى',
        'source': 'حديث شريف',
      },
      {'text': 'وقُل ربِّ زِدني عِلمًا', 'source': 'سورة طه'},
    ],
    // Tuesday (2)
    2: [
      {
        'text': 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
        'source': 'سورة البقرة',
      },
      {
        'text': 'أَحَبُّ الأعمالِ إلى اللهِ أدْوَمُها وإنْ قَلَّ',
        'source': 'حديث شريف',
      },
      {'text': 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ', 'source': 'سورة البقرة'},
      {
        'text': 'ما نقصت صدقة من مال، وما زاد الله عبداً بعفو إلا عزاً',
        'source': 'حديث شريف',
      },
    ],
    // Wednesday (3)
    3: [
      {
        'text': 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
        'source': 'سورة الرعد',
      },
      {
        'text':
            'وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ وَاللَّهُ بِمَا تَعْمَلُونَ بَصِيرٌ',
        'source': 'سورة الحديد',
      },
      {'text': 'الكلمةُ الطيبةُ صدقة', 'source': 'حديث شريف'},
      {
        'text':
            'رَبَّنَا آتِنَا مِن لَّدُنكَ رَحْمَةً وَهَيِّئْ لَنَا مِنْ أَمْرِنَا رَشَدًا',
        'source': 'سورة الكهف',
      },
    ],
    // Thursday (4)
    4: [
      {
        'text':
            'وَإِذَا سَأَلَكَ عِبَادِي عَنِّي فَإِنِّي قَرِيبٌ أُجِيبُ دَعْوَةَ الدَّاعِ إِذَا دَعَانِ',
        'source': 'سورة البقرة',
      },
      {
        'text': 'اقرؤوا القرآن فإنه يأتي يوم القيامة شفيعاً لأصحابه',
        'source': 'حديث شريف',
      },
      {
        'text': 'وَلَسَوْفَ يُعْطِيكَ رَبُّكَ فَتَرْضَىٰ',
        'source': 'سورة الضحى',
      },
      {'text': 'الدعاءُ هو العبادة', 'source': 'حديث شريف'},
    ],
    // Friday (5)
    5: [
      {
        'text':
            'إِنَّ اللَّهَ وَمَلَائِكَتَهُ يُصَلُّونَ عَلَى النَّبِيِّ يَا أَيُّهَا الَّذِينَ آمَنُوا صَلُّوا عَلَيْهِ وَسَلِّمُوا تَسْلِيمًا',
        'source': 'سورة الأحزاب',
      },
      {
        'text':
            'من قرأ سورة الكهف في يوم الجمعة أضاء له من النور ما بين الجمعتين',
        'source': 'حديث شريف',
      },
      {
        'text':
            'في يوم الجمعة ساعة لا يوافقها عبد مسلم يسأل الله خيراً إلا أعطاه إياه',
        'source': 'حديث شريف',
      },
      {'text': 'ربِّ اشرح لي صدري ويسِّر لي أمري', 'source': 'سورة طه'},
    ],
    // Saturday (6)
    6: [
      {
        'text': 'فَمَنْ أَبْصَرَ فَلِنَفْسِهِ وَمَنْ عَمِيَ فَعَلَيْهَا',
        'source': 'سورة الأنعام',
      },
      {
        'text': 'إنّ مع العُسرِ يُسراً • فإنّ مع العُسرِ يُسراً',
        'source': 'سورة الشرح',
      },
      {'text': 'خيرُكم من تعلّم القرآن وعلّمه', 'source': 'حديث شريف'},
      {
        'text':
            'وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ عَلَيْهِ تَوَكَّلْتُ وَإِلَيْهِ أُنِيبُ',
        'source': 'سورة هود',
      },
    ],
    // Sunday (7)
    7: [
      {
        'text':
            'وَسَارِعُوا إِلَىٰ مَغْفِرَةٍ مِّن رَّبِّكُمْ وَجَنَّةٍ عَرْضُهَا السَّمَاوَاتُ وَالْأَرْضُ',
        'source': 'سورة آل عمران',
      },
      {
        'text':
            'من سلك طريقاً يلتمس فيه علماً سهّل الله له به طريقاً إلى الجنة',
        'source': 'حديث شريف',
      },
      {
        'text': 'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا',
        'source': 'سورة البقرة',
      },
      {
        'text': 'الطهور شطر الإيمان، والحمد لله تملأ الميزان',
        'source': 'حديث شريف',
      },
    ],
  };

  late final List<Map<String, String>> _activeQuotes;
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _activeQuotes = _buildWeeklyRotatedQuotes();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % _activeQuotes.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  List<Map<String, String>> _buildWeeklyRotatedQuotes() {
    final now = DateTime.now();
    final dayQuotes = List<Map<String, String>>.from(
      _weeklyQuotesByWeekday[now.weekday] ?? _weeklyQuotesByWeekday[1]!,
    );
    // Add rotating selections from adjacent days based on week of year so it updates weekly
    final weekOfYear = (now.difference(DateTime(now.year, 1, 1)).inDays ~/ 7);
    final nextWeekday = ((now.weekday + weekOfYear) % 7) + 1;
    final bonusQuotes = _weeklyQuotesByWeekday[nextWeekday] ?? [];
    for (final q in bonusQuotes.take(2)) {
      if (!dayQuotes.any((item) => item['text'] == q['text'])) {
        dayQuotes.add(q);
      }
    }
    return dayQuotes;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Map<String, String> get _currentQuote =>
      _activeQuotes[_index.clamp(0, _activeQuotes.length - 1)];

  String _formattedText(Map<String, String> q) =>
      '«${q['text']}»\n— ${q['source']}\n\nمن تطبيق بصائر 🌿';

  Future<void> _copyQuoteText() async {
    final q = _currentQuote;
    await Clipboard.setData(ClipboardData(text: _formattedText(q)));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ محتوى "نورٌ وبصيرة" إلى الحافظة',
          style: _f(sz: 13, fw: FontWeight.w700, c: Colors.white),
        ),
        backgroundColor: AppColors.darkGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareQuoteText() async {
    final q = _currentQuote;
    HapticFeedback.selectionClick();
    await Share.share(_formattedText(q));
  }

  Future<void> _shareQuoteAsImage() async {
    final quote = _currentQuote;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = GlobalKey();
    HapticFeedback.mediumImpact();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  key: key,
                  child: _buildQuoteShareCard(quote, isDark),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('\u0625\u063a\u0644\u0627\u0642'),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          _captureAndShareQuote(dialogContext, key, quote),
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('\u0645\u0634\u0627\u0631\u0643\u0629'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteShareCard(Map<String, String> quote, bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final title = scheme.onSurface;
    final muted = scheme.onSurface.withValues(alpha: isDark ? 0.64 : 0.58);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [AppColors.dashboardGreenTop, AppColors.dashboardGreenBottom]
          : [AppColors.dashboardMintTop, AppColors.dashboardMintBottom],
    );

    return Container(
      width: (MediaQuery.sizeOf(context).width - 72)
          .clamp(220.0, 380.0)
          .toDouble(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.24 : 0.14),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                '\u0646\u0648\u0631\u064c \u0648\u0628\u0635\u064a\u0631\u0629',
                style: _f(sz: 12.5, fw: FontWeight.w700, c: accent),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            quote['text']!,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: _f(sz: 17, fw: FontWeight.w700, c: title, h: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            quote['source']!,
            style: _f(sz: 12, fw: FontWeight.w600, c: muted),
          ),
          const SizedBox(height: 16),
          Divider(color: accent.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '\u062a\u0637\u0628\u064a\u0642 \u0628\u0635\u0627\u0626\u0631 - \u0642\u0631\u0622\u0646 \u0648\u0639\u0628\u0627\u062f\u0627\u062a',
              style: _f(sz: 11, fw: FontWeight.w700, c: accent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndShareQuote(
    BuildContext dialogContext,
    GlobalKey key,
    Map<String, String> quote,
  ) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('The quote card is not ready to capture');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) throw StateError('Unable to encode quote card');
        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}/nur_wa_basirah_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
        if (!dialogContext.mounted) return;
        Navigator.pop(dialogContext);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: _formattedText(quote));
      } finally {
        image.dispose();
      }
    } catch (error) {
      debugPrint('Error sharing quote card: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u062a\u0639\u0630\u0631 \u0625\u0646\u0634\u0627\u0621 \u0635\u0648\u0631\u0629 \u0648\u0645\u0634\u0627\u0631\u0643\u0629 \u0627\u0644\u0628\u0637\u0627\u0642\u0629',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final title = scheme.onSurface;
    final muted = scheme.onSurface.withValues(alpha: isDark ? 0.64 : 0.58);
    final accent = scheme.primary;
    final iconBg = accent.withValues(alpha: isDark ? 0.16 : 0.08);
    final cardGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [AppColors.dashboardGreenTop, AppColors.dashboardGreenBottom]
          : [AppColors.dashboardMintTop, AppColors.dashboardMintBottom],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.24 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                'نورٌ وبصيرة',
                style: _f(sz: 12.5, fw: FontWeight.w700, c: accent),
              ),
              const Spacer(),
              _QuoteActionIcon(
                icon: Icons.copy_rounded,
                tooltip: 'نسخ النص',
                color: muted,
                background: iconBg,
                onTap: _copyQuoteText,
              ),
              const SizedBox(width: 6),
              _QuoteActionIcon(
                icon: Icons.share_rounded,
                tooltip: 'مشاركة كنص',
                color: muted,
                background: iconBg,
                onTap: _shareQuoteText,
              ),
              const SizedBox(width: 6),
              _QuoteActionIcon(
                icon: Icons.image_outlined,
                tooltip: 'مشاركة كصورة',
                color: muted,
                background: iconBg,
                onTap: _shareQuoteAsImage,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: _activeQuotes.length,
              itemBuilder: (_, i) {
                final q = _activeQuotes[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      q['text']!,
                      style: _f(sz: 15, fw: FontWeight.w700, c: title, h: 1.45),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      q['source']!,
                      style: _f(sz: 11, fw: FontWeight.w600, c: muted),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Row(
                children: List.generate(_activeQuotes.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? accent
                          : muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _shareQuoteAsImage,
                child: Text(
                  'مشاركة كبطاقة',
                  style: _f(sz: 11, fw: FontWeight.w700, c: accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuoteActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final Color background;

  const _QuoteActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
    child: Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: _f(
            sz: 18,
            fw: FontWeight.w800,
            c: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : AppColors.darkGreen,
          ),
        ),
      ],
    ),
  );
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _f(sz: 11, fw: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => Material(
    color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: _f(sz: 12, fw: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModernNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _ModernNavBar({required this.currentIndex, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGuest = !context.watch<AppAuthProvider>().isAuthenticated;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      height: 70,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E1E).withOpacity(0.9)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavButton(
                icon: Icons.home_rounded,
                label: '',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavButton(
                icon: Icons.emoji_events_rounded,
                label: 'الدوريات',
                selected: currentIndex == 1,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DawriPage()),
                ),
              ),
              _NavButton(
                icon: Icons.auto_stories_rounded,
                label: 'المصحف',
                selected: currentIndex == 2,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuranPage()),
                ),
              ),
              _NavButton(
                icon: Icons.explore_rounded,
                label: 'القبلة',
                selected: currentIndex == 3,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QiblaPage()),
                ),
              ),
              _NavButton(
                icon: Icons.mosque_rounded,
                label: 'المساجد',
                selected: false,
                onTap: () => NearbyMosquesPage.show(context),
              ),
              _NavButton(
                icon: isGuest ? Icons.login_rounded : Icons.person_rounded,
                label: isGuest ? 'تسجيل الدخول' : 'المزيد',
                selected: currentIndex == 4,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        isGuest ? const LoginPage() : const ProfilePage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.darkGreen.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: selected ? AppColors.darkGreen : AppColors.gray,
            size: 24,
          ),
          if (selected && label.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: _f(sz: 13, fw: FontWeight.w700, c: AppColors.darkGreen),
            ),
          ],
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
//  Glass Prayer Arch Header — added as extension of page state
// ════════════════════════════════════════════════════════════════

extension _ArchHeader on _DashboardPageState {
  Widget _buildArchHeader(bool isDark, String userName, bool isGuest) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onSurface;
    final fgDim = scheme.onSurface.withValues(alpha: isDark ? 0.68 : 0.62);
    final headerColors = isDark
        ? [
            AppColors.dashboardGreenTop,
            AppColors.dashboardGreenBottom,
          ]
        : [
            AppColors.dashboardMintTop,
            AppColors.dashboardMintBottom,
          ];
    final glassBg = isDark
        ? scheme.surface.withValues(alpha: 0.48)
        : Color.lerp(Colors.white, AppColors.midGreen, 0.04)!;
    final glassBorder = scheme.outline.withValues(alpha: isDark ? 0.28 : 0.14);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: headerColors,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, -0.8),
                  radius: 1.15,
                  colors: [
                    scheme.secondary.withValues(alpha: isDark ? 0.12 : 0.13),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 26,
                left: 20,
                right: 20,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: glassBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: glassBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.18 : 0.05,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(
                              alpha: isDark ? 0.22 : 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : '؟',
                            style: _f(
                              sz: 18,
                              fw: FontWeight.w800,
                              c: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'السلام عليكم، ${userName.split(' ').first}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _f(
                                        sz: 12.5,
                                        fw: FontWeight.w600,
                                        c: fgDim,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 14,
                                    color: scheme.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'مرحباً بك في بصائر',
                                style: _f(sz: 19, fw: FontWeight.w900, c: fg),
                              ),
                            ],
                          ),
                        ),
                        if (isGuest)
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'دخول',
                                style: _f(
                                  sz: 12,
                                  fw: FontWeight.bold,
                                  c: Colors.white,
                                ),
                              ),
                            ),
                          )
                        else
                          _GlassIconButton(
                            icon: Icons.notifications_none_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const NotificationSettingsPage(),
                              ),
                            ),
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _QuoteCarousel(date: _getArabicDate()),
                  const SizedBox(height: 16),
                  _buildPrayerArch(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerArch(bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    final progress = _archProgress();
    final nextTime = _nextPrayerTime;
    final timeDigits = nextTime != null ? _fmtDigits(nextTime) : '--:--';
    final timePeriod = nextTime != null ? _fmtPeriod(nextTime) : '';
    final left = nextTime != null
        ? nextTime.difference(DateTime.now())
        : Duration.zero;
    final countdown = left.isNegative
        ? 'حان الآن'
        : 'متبقي ${_fmtCountdown(left)}';
    final accent = scheme.primary;
    final title = scheme.onSurface;
    final muted = scheme.onSurface.withValues(alpha: isDark ? 0.64 : 0.58);
    final cardGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [AppColors.dashboardGreenTop, AppColors.dashboardGreenBottom]
          : [AppColors.dashboardMintTop, AppColors.dashboardMintBottom],
    );
    final dialGradient = RadialGradient(
      center: const Alignment(0, -0.35),
      radius: 0.95,
      colors: isDark
          ? [
              AppColors.midGreen,
              AppColors.dashboardGreenBottom,
              AppColors.dashboardGreenTop,
            ]
          : [
              AppColors.dashboardMintTop,
              AppColors.dashboardMintBottom,
              scheme.surface,
            ],
    );
    final hairline = Color.lerp(
      scheme.outline,
      scheme.secondary,
      isDark ? 0.20 : 0.10,
    )!.withValues(alpha: isDark ? 0.32 : 0.20);

    return GestureDetector(
      onTap: () => _to(const PrayerTimesPage()),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: cardGradient,
          border: Border.all(color: hairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                top: -72,
                left: -44,
                child: Container(
                  width: 184,
                  height: 184,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.secondary.withValues(
                          alpha: isDark ? 0.14 : 0.12,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'الصلاة القادمة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _getArabicDate(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 208,
                      height: 208,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: dialGradient,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.28 : 0.06,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _DialRingPainter(
                                progress: progress,
                                accent: accent,
                                isDark: isDark,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 34),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _nextPrayerName.isEmpty
                                      ? '—'
                                      : _nextPrayerName,
                                  style: GoogleFonts.amiri(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: title,
                                    height: 1.05,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      timeDigits,
                                      style: GoogleFonts.cormorantGaramond(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                        color: title,
                                        height: 1,
                                      ),
                                    ),
                                    if (timePeriod.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        timePeriod,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: accent,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    countdown,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ibmPlexSansArabic(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _spiritualTagline(_nextPrayerKey),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: muted,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'مواقيت الصلاة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
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
  }

  String _fmtDigits(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtPeriod(DateTime t) => t.hour >= 12 ? 'م' : 'ص';

  String _fmtCountdown(Duration d) {
    if (d.inSeconds <= 0) return 'حان الآن';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}س ${m}د';
    if (m > 0) return '${m}د ${s}ث';
    return '${s}ث';
  }

  double _archProgress() {
    final next = _nextPrayerTime;
    if (next == null || _allPrayerTimes.isEmpty) return 0.5;
    final idx = _allPrayerTimes.indexWhere((e) => e['name'] == _nextPrayerName);
    DateTime prev;
    if (idx > 0) {
      prev =
          _allPrayerTimes[idx - 1]['time'] as DateTime? ??
          next.subtract(const Duration(hours: 1));
    } else {
      final last = _allPrayerTimes.last['time'] as DateTime?;
      prev = last != null
          ? last.subtract(const Duration(days: 1))
          : next.subtract(const Duration(hours: 1));
    }
    final total = next.difference(prev).inSeconds;
    if (total <= 0) return 0.5;
    final elapsed = DateTime.now().difference(prev).inSeconds;
    return (elapsed / total).clamp(0.05, 0.95);
  }

  String _spiritualTagline(String key) {
    switch (key) {
      case 'fajr':
        return 'مع نسيم الفجر، أقبِل على صلاتك في خشوع';
      case 'sunrise':
        return 'أشرقت الشمس، وقتُ الضحى وذكر الله';
      case 'dhuhr':
        return 'في سكون الظهيرة، استرح بصلاتك مع الله';
      case 'asr':
        return 'حين تمتد الظلال، حافظوا على الصلاة الوسطى';
      case 'maghrib':
        return 'مع غروب الشمس، اختم نهارك بطاعة الله';
      case 'isha':
        return 'في سكون الليل، نورٌ وطمأنينة لقلبك';
      default:
        return 'حيّ على الصلاة، حيّ على الفلاح';
    }
  }
}

/// Luxury watch-dial painter for the upcoming-prayer card.
/// Gold bezel, minute ticks, soft track and a glowing accent progress arc.
class _DialRingPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final bool isDark;

  _DialRingPainter({
    required this.progress,
    required this.accent,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    if (radius <= 0) return;

    // ── Theme bezel ──
    final bezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = accent.withValues(alpha: isDark ? 0.55 : 0.38);
    canvas.drawCircle(center, radius - 3, bezelPaint);

    final hairline = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.22 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius - 9, hairline);

    // ── Hour ticks, with finer marks between them ──
    final tickPaint = Paint()..strokeCap = StrokeCap.round;
    for (int i = 0; i < 60; i++) {
      final angle = -math.pi / 2 + i * (math.pi * 2 / 60);
      final major = i % 5 == 0;
      final inner = radius - (major ? 22 : 16);
      final outer = radius - 13;
      tickPaint
        ..color = major
            ? accent.withValues(alpha: isDark ? 0.8 : 0.55)
            : accent.withValues(alpha: isDark ? 0.28 : 0.2)
        ..strokeWidth = major ? 1.7 : 0.7;
      canvas.drawLine(
        Offset(
          center.dx + inner * math.cos(angle),
          center.dy + inner * math.sin(angle),
        ),
        Offset(
          center.dx + outer * math.cos(angle),
          center.dy + outer * math.sin(angle),
        ),
        tickPaint,
      );
    }

    final sepPaint = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.2 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    canvas.drawCircle(center, radius - 48, sepPaint);

    // ── Track + progress arc ──
    final trackRadius = radius - 38;
    final trackPaint = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.16 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, trackRadius, trackPaint);

    final arcRect = Rect.fromCircle(center: center, radius: trackRadius);
    final glowPaint = Paint()
      ..color = accent.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, glowPaint);

    final arcPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, arcPaint);

    // ── Tip marker on the arc ──
    final tipAngle = -math.pi / 2 + math.pi * 2 * progress;
    final tip = Offset(
      center.dx + trackRadius * math.cos(tipAngle),
      center.dy + trackRadius * math.sin(tipAngle),
    );
    final tipGlow = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(tip, 7, tipGlow);
    final tipFill = Paint()..color = accent;
    final tipRing = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(tip, 4.5, tipFill);
    canvas.drawCircle(tip, 4.5, tipRing);
  }

  @override
  bool shouldRepaint(covariant _DialRingPainter old) =>
      old.progress != progress || old.accent != accent || old.isDark != isDark;
}

class _AccountabilityChipData {
  final String label;
  final IconData icon;
  final bool checked;
  final Color color;
  final VoidCallback onTap;

  const _AccountabilityChipData({
    required this.label,
    required this.icon,
    required this.checked,
    required this.color,
    required this.onTap,
  });
}

class _AccountabilityChip extends StatelessWidget {
  final _AccountabilityChipData data;
  final bool isDark;

  const _AccountabilityChip({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: data.checked
              ? data.color.withValues(alpha: 0.16)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: data.checked
                ? data.color.withValues(alpha: 0.55)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
            width: data.checked ? 1.6 : 1,
          ),
          boxShadow: data.checked
              ? [
                  BoxShadow(
                    color: data.color.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: data.checked
                    ? data.color
                    : data.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                data.checked ? Icons.check_rounded : data.icon,
                size: 15,
                color: data.checked ? Colors.white : data.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: _f(
                sz: 10.5,
                fw: FontWeight.w800,
                c: data.checked
                    ? data.color
                    : (isDark ? Colors.white70 : AppColors.darkGreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle film-grain / noise overlay painted once per theme.
class _FilmGrainPainter extends CustomPainter {
  final bool isDark;
  _FilmGrainPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(7);
    final specks = (size.width * size.height / 900).round().clamp(300, 1400);
    final alpha = isDark ? 0.05 : 0.07;
    for (var i = 0; i < specks; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final w = rng.nextDouble() < 0.85 ? 1.0 : 1.6;
      paint.color = (rng.nextBool() ? Colors.white : Colors.black).withValues(
        alpha: alpha * rng.nextDouble() * 1.6,
      );
      canvas.drawRect(Rect.fromLTWH(x, y, w, w), paint);
    }
    // A few slightly larger soft dust motes for a filmic feel
    for (var i = 0; i < 14; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      paint.color = Colors.white.withValues(alpha: alpha * 0.7);
      canvas.drawCircle(Offset(x, y), 1.2 + rng.nextDouble() * 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FilmGrainPainter old) => old.isDark != isDark;
}

/// Frosted-glass icon button matching the new header style.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(
              alpha: isDark ? 0.35 : 0.2,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 22,
        ),
      ),
    );
  }
}
