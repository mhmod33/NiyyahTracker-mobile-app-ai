import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/wird_service.dart';
import '../../services/wird_notification_service.dart';
import '../quran/surah_reader_page.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class DailyWirdPage extends StatefulWidget {
  const DailyWirdPage({super.key});
  @override
  State<DailyWirdPage> createState() => _DailyWirdPageState();
}

class _DailyWirdPageState extends State<DailyWirdPage> with TickerProviderStateMixin {
  final WirdService _wirdService = WirdService();
  late AnimationController _streakController;
  late AnimationController _progressController;
  late Animation<double> _streakAnim;
  late Animation<double> _progressAnim;

  WirdDayRecord? _todayRecord;
  int _streak = 0;
  int _longestStreak = 0;
  int _totalDays = 0;
  double _totalJuz = 0;
  double _totalHours = 0;
  List<WirdDayRecord> _last7Days = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _streakController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _streakAnim = CurvedAnimation(parent: _streakController, curve: Curves.elasticOut);
    _progressAnim = CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic);
    _loadData();
  }

  @override
  void dispose() {
    _streakController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _wirdService.init();
    setState(() {
      _todayRecord = _wirdService.getTodayRecord();
      _streak = _wirdService.getCurrentStreak();
      _longestStreak = _wirdService.getLongestStreak();
      _totalDays = _wirdService.getTotalCompletedDays();
      _totalJuz = _wirdService.getTotalJuzRead();
      _totalHours = _wirdService.getTotalHours();
      _last7Days = _wirdService.getLastNDayRecords(7);
      _loading = false;
    });
    _streakController.forward();
    _progressController.forward();
  }

  Future<void> _refresh() async {
    _progressController.reset();
    await _loadData();
  }

  void _openQuranReader() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SurahReaderPage(surahNumber: 1)),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGuest = !context.read<AppAuthProvider>().isAuthenticated;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(isDark),
                  if (isGuest)
                    SliverToBoxAdapter(child: _buildGuestBanner(isDark))
                  else ...[
                    SliverToBoxAdapter(child: _buildStreakHero(isDark)),
                    SliverToBoxAdapter(child: _buildTodayProgress(isDark)),
                    SliverToBoxAdapter(child: _buildSessionsGrid(isDark)),
                    SliverToBoxAdapter(child: _buildWeekChart(isDark)),
                    SliverToBoxAdapter(child: _buildStatsRow(isDark)),
                    SliverToBoxAdapter(child: _buildStartReadingButton(isDark)),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
      title: Text('الورد اليومي', style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: Colors.white70),
          onPressed: () => _showSettingsSheet(isDark),
        ),
      ],
    );
  }

  Widget _buildGuestBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2F23), const Color(0xFF0D2818)]
              : [AppColors.paleGreen, AppColors.lightGreen.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Column(children: [
        const Icon(Icons.menu_book_rounded, color: AppColors.gold, size: 56),
        const SizedBox(height: 16),
        Text('الورد اليومي', style: _f(sz: 22, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
        const SizedBox(height: 8),
        Text('سجل دخولك لتتبع وردك اليومي والحفاظ على streak مواظبتك',
            style: _f(sz: 14, c: isDark ? Colors.white70 : AppColors.gray), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _openQuranReader,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text('ابدأ القراءة الآن', style: _f(sz: 16, fw: FontWeight.bold, c: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _buildStreakHero(bool isDark) {
    final hasStreak = _streak > 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? [const Color(0xFF1A3A28), const Color(0xFF0D2818)]
              : [AppColors.darkGreen, const Color(0xFF145A3A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _streakAnim,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasStreak ? Icons.local_fire_department_rounded : Icons.menu_book_rounded,
                  color: hasStreak ? const Color(0xFFFF6B35) : Colors.white,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ScaleTransition(
                scale: _streakAnim,
                child: Text(
                  '$_streak',
                  style: _f(sz: 56, fw: FontWeight.w900, c: AppColors.gold),
                ),
              ),
              Text('يوم متتالي', style: _f(sz: 16, fw: FontWeight.w600, c: Colors.white70)),
            ]),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            _getStreakMessage(),
            style: _f(sz: 14, fw: FontWeight.w600, c: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _heroStat('أطول streak', '$_longestStreak يوم', Icons.emoji_events_rounded),
            _heroDivider(),
            _heroStat('أيام مكتملة', '$_totalDays يوم', Icons.check_circle_rounded),
            _heroDivider(),
            _heroStat('أجزاء مقروءة', _totalJuz.toStringAsFixed(1), Icons.auto_stories_rounded),
          ],
        ),
      ]),
    );
  }

  Widget _heroStat(String label, String value, IconData icon) {
    return Column(children: [
      Icon(icon, color: AppColors.gold, size: 20),
      const SizedBox(height: 4),
      Text(value, style: _f(sz: 16, fw: FontWeight.w800, c: Colors.white)),
      Text(label, style: _f(sz: 10, c: Colors.white60)),
    ]);
  }

  Widget _heroDivider() {
    return Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2));
  }

  String _getStreakMessage() {
    if (_streak == 0) return 'ابدأ وردك اليوم وحافظ على المواظبة';
    if (_streak < 3) return 'بداية موفقة! واصل المواظبة';
    if (_streak < 7) return 'ماشاء الله! أنت في الطريق الصحيح';
    if (_streak < 14) return 'أسبوع كامل من المواظبة! تقبل الله';
    if (_streak < 30) return 'سبحان الله! مواظبة رائعة على الورد';
    return 'الله أكبر! شهر كامل من المواظبة!';
  }

  Widget _buildTodayProgress(bool isDark) {
    final record = _todayRecord!;
    final progress = record.progress;
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: record.isCompleted
              ? AppColors.lightGreen.withOpacity(0.5)
              : AppColors.gold.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: record.isCompleted
                  ? AppColors.lightGreen.withOpacity(0.2)
                  : AppColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              record.isCompleted ? Icons.check_circle_rounded : Icons.menu_book_rounded,
              color: record.isCompleted ? AppColors.lightGreen : AppColors.gold,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                record.isCompleted ? 'أتممت وردك اليوم!' : 'ورد اليوم',
                style: _f(sz: 16, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen),
              ),
              Text(
                '${record.pagesRead} / ${record.targetPages} صفحة',
                style: _f(sz: 13, c: isDark ? Colors.white60 : AppColors.gray),
              ),
            ]),
          ),
          if (record.totalMinutes > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.darkGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Icon(Icons.timer_rounded, size: 14, color: AppColors.darkGreen),
                const SizedBox(width: 4),
                Text('${record.totalMinutes} د', style: _f(sz: 12, fw: FontWeight.w600, c: AppColors.darkGreen)),
              ]),
            ),
        ]),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _progressAnim,
          builder: (_, __) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress * _progressAnim.value,
                  minHeight: 10,
                  backgroundColor: isDark ? Colors.white12 : AppColors.paleGreen,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    record.isCompleted ? AppColors.lightGreen : AppColors.darkGreen,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(progress * 100).toInt()}% مكتمل',
                style: _f(sz: 11, c: isDark ? Colors.white54 : AppColors.gray),
              ),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _buildSessionsGrid(bool isDark) {
    final record = _todayRecord!;
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('جلسات الورد اليومي', style: _f(sz: 15, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
        Text('5 صفحات لكل جلسة', style: _f(sz: 12, c: isDark ? Colors.white54 : AppColors.gray)),
        const SizedBox(height: 14),
        Row(
          children: WirdSession.all.map((session) {
            final pages = record.sessionPages[session] ?? 0;
            final isDone = pages >= 5;
            final isCurrent = WirdSession.current == session;
            return Expanded(
              child: GestureDetector(
                onTap: _openQuranReader,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: isDone
                        ? LinearGradient(colors: [AppColors.darkGreen, AppColors.midGreen])
                        : isCurrent
                            ? LinearGradient(colors: [AppColors.gold.withOpacity(0.2), AppColors.gold.withOpacity(0.1)])
                            : null,
                    color: isDone || isCurrent ? null : (isDark ? Colors.white.withOpacity(0.05) : AppColors.paleGreen),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDone
                          ? AppColors.darkGreen
                          : isCurrent
                              ? AppColors.gold
                              : Colors.transparent,
                      width: isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDone
                            ? Colors.white.withValues(alpha: 0.2)
                            : WirdSession.iconColor(session).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        WirdSession.iconData(session),
                        size: 22,
                        color: isDone ? Colors.white : WirdSession.iconColor(session),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      WirdSession.label(session),
                      style: _f(
                        sz: 11,
                        fw: FontWeight.w700,
                        c: isDone ? Colors.white : (isDark ? Colors.white70 : AppColors.darkGreen),
                      ),
                    ),
                    const SizedBox(height: 4),
                    isDone
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white70)
                        : Text(
                            '$pages/5',
                            style: _f(
                              sz: 10,
                              fw: FontWeight.w600,
                              c: isCurrent ? AppColors.gold : (isDark ? Colors.white38 : AppColors.gray),
                            ),
                          ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  Widget _buildWeekChart(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final days = ['أحد', 'اثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];
    final now = DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('آخر 7 أيام', style: _f(sz: 15, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final record = _last7Days[i];
              final ratio = record.targetPages > 0
                  ? (record.pagesRead / record.targetPages).clamp(0.0, 1.0)
                  : 0.0;
              final dayDate = now.subtract(Duration(days: 6 - i));
              final dayLabel = days[dayDate.weekday % 7];
              final isToday = i == 6;
              final isCompleted = record.isCompleted;

              return Expanded(
                child: AnimatedBuilder(
                  animation: _progressAnim,
                  builder: (_, __) => Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: (60 * ratio * _progressAnim.value).clamp(4.0, 60.0),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isCompleted
                                ? [AppColors.darkGreen, AppColors.midGreen]
                                : ratio > 0
                                    ? [AppColors.gold.withOpacity(0.7), AppColors.gold]
                                    : [
                                        isDark ? Colors.white12 : AppColors.paleGreen,
                                        isDark ? Colors.white12 : AppColors.paleGreen,
                                      ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: isToday ? Border.all(color: AppColors.gold, width: 2) : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dayLabel,
                        style: _f(
                          sz: 10,
                          fw: isToday ? FontWeight.w800 : FontWeight.w400,
                          c: isToday ? AppColors.gold : (isDark ? Colors.white54 : AppColors.gray),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Expanded(child: _statCard(Icons.timer_rounded, Colors.orange, _totalHours.toStringAsFixed(1), 'ساعة قراءة', isDark, cardBg)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(Icons.auto_stories_rounded, Colors.purple, _totalJuz.toStringAsFixed(1), 'جزء مقروء', isDark, cardBg)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(Icons.calendar_month_rounded, Colors.teal, '$_totalDays', 'يوم مكتمل', isDark, cardBg)),
      ]),
    );
  }

  Widget _statCard(IconData icon, Color iconColor, String value, String label, bool isDark, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: _f(sz: 18, fw: FontWeight.w900, c: isDark ? Colors.white : AppColors.darkGreen)),
        const SizedBox(height: 2),
        Text(label, style: _f(sz: 10, c: isDark ? Colors.white54 : AppColors.gray), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildStartReadingButton(bool isDark) {
    final record = _todayRecord!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton.icon(
          onPressed: _openQuranReader,
          icon: Icon(
            record.isCompleted ? Icons.replay_rounded : Icons.menu_book_rounded,
            color: Colors.white,
            size: 22,
          ),
          label: Text(
            record.isCompleted ? 'قراءة المزيد' : 'ابدأ القراءة الآن',
            style: _f(sz: 17, fw: FontWeight.w800, c: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: record.isCompleted ? AppColors.midGreen : AppColors.darkGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            shadowColor: AppColors.darkGreen.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(bool isDark) {
    final targetOptions = [5, 10, 15, 20, 25, 30];
    int selectedTarget = _wirdService.targetPages;
    bool notifsEnabled = WirdNotificationService().notificationsEnabled;
    final TextEditingController customController = TextEditingController();
    bool showCustomInput = !targetOptions.contains(selectedTarget);
    if (showCustomInput) customController.text = '$selectedTarget';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => StatefulBuilder(
          builder: (ctx, setSheet) => Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(
                left: 24, right: 24, top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('إعدادات الورد اليومي', style: _f(sz: 18, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
              const SizedBox(height: 24),

              // ── Target pages ──
              Row(children: [
                const Icon(Icons.menu_book_rounded, color: AppColors.gold, size: 20),
                const SizedBox(width: 10),
                Text('الهدف اليومي (صفحات)', style: _f(sz: 14, fw: FontWeight.w700, c: isDark ? Colors.white : AppColors.textPrimary)),
              ]),
              const SizedBox(height: 12),

              // Quick-select chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...targetOptions.map((t) => ChoiceChip(
                    label: Text('$t', style: _f(sz: 13, fw: FontWeight.w700, c: selectedTarget == t && !showCustomInput ? Colors.white : null)),
                    selected: selectedTarget == t && !showCustomInput,
                    selectedColor: AppColors.darkGreen,
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.paleGreen,
                    side: BorderSide(color: selectedTarget == t && !showCustomInput ? AppColors.darkGreen : Colors.transparent),
                    onSelected: (_) {
                      setSheet(() {
                        selectedTarget = t;
                        showCustomInput = false;
                        customController.clear();
                      });
                    },
                  )),
                  // "Custom" chip
                  ChoiceChip(
                    avatar: Icon(
                      Icons.edit_rounded,
                      size: 16,
                      color: showCustomInput ? Colors.white : AppColors.darkGreen,
                    ),
                    label: Text('مخصص', style: _f(sz: 13, fw: FontWeight.w700, c: showCustomInput ? Colors.white : null)),
                    selected: showCustomInput,
                    selectedColor: AppColors.gold,
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.paleGreen,
                    side: BorderSide(color: showCustomInput ? AppColors.gold : Colors.transparent),
                    onSelected: (_) => setSheet(() => showCustomInput = true),
                  ),
                ],
              ),

              // Custom number input — shown when "مخصص" is selected
              if (showCustomInput) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: customController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: _f(sz: 20, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen),
                      decoration: InputDecoration(
                        hintText: 'أدخل عدد الصفحات',
                        hintStyle: _f(sz: 14, c: AppColors.gray),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.paleGreen,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.gold, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        suffixText: 'صفحة',
                        suffixStyle: _f(sz: 13, c: AppColors.gray),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed > 0) {
                          setSheet(() => selectedTarget = parsed.clamp(1, 604));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // +/- stepper
                  Column(children: [
                    _stepperBtn(Icons.add_rounded, isDark, () {
                      final next = (selectedTarget + 1).clamp(1, 604);
                      setSheet(() {
                        selectedTarget = next;
                        customController.text = '$next';
                      });
                    }),
                    const SizedBox(height: 6),
                    _stepperBtn(Icons.remove_rounded, isDark, () {
                      final next = (selectedTarget - 1).clamp(1, 604);
                      setSheet(() {
                        selectedTarget = next;
                        customController.text = '$next';
                      });
                    }),
                  ]),
                ]),
                const SizedBox(height: 10),
                // Confirm custom number button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final parsed = int.tryParse(customController.text);
                      if (parsed != null && parsed >= 1) {
                        setSheet(() => selectedTarget = parsed.clamp(1, 604));
                        FocusScope.of(ctx).unfocus();
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      'تأكيد: $selectedTarget صفحة يومياً',
                      style: _f(sz: 14, fw: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkGreen,
                      side: const BorderSide(color: AppColors.darkGreen, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Notifications toggle ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.paleGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.notifications_rounded, color: AppColors.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('تذكيرات الورد اليومي', style: _f(sz: 14, fw: FontWeight.w600, c: isDark ? Colors.white : AppColors.textPrimary)),
                    Text('تذكير بعد كل صلاة', style: _f(sz: 11, c: AppColors.gray)),
                  ])),
                  Switch(
                    value: notifsEnabled,
                    onChanged: (v) => setSheet(() => notifsEnabled = v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.darkGreen,
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              // ── Save button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    // Validate custom input
                    if (showCustomInput) {
                      final parsed = int.tryParse(customController.text);
                      if (parsed == null || parsed < 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('أدخل عدداً صحيحاً من الصفحات', style: _f(c: Colors.white)),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      selectedTarget = parsed.clamp(1, 604);
                    }
                    await _wirdService.setTargetPages(selectedTarget);
                    await WirdNotificationService().setNotificationsEnabled(notifsEnabled);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _refresh();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('حفظ الإعدادات', style: _f(sz: 15, fw: FontWeight.bold, c: Colors.white)),
                ),
              ),
            ]),          // Column
          ),             // SingleChildScrollView
        ),               // Directionality (StatefulBuilder return)
      ),                 // StatefulBuilder (DraggableScrollableSheet builder return)
    ),                   // DraggableScrollableSheet
    );                   // showModalBottomSheet
  }

  Widget _stepperBtn(IconData icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.paleGreen,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: AppColors.darkGreen, size: 20),
      ),
    );
  }
}
