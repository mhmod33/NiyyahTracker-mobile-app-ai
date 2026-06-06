import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/app_colors.dart';
import 'package:provider/provider.dart';
import '../../core/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../models/worship_model.dart' as db_model;
import 'package:uuid/uuid.dart' as uuid;

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  
  List<double> _prayerData  = List.filled(7, 0);
  List<double> _quranData   = List.filled(7, 0);
  List<double> _dhikrData   = List.filled(7, 0);
  List<double> _wirdData    = List.filled(7, 0);

  int _totalQuranPages = 0;
  int _completedPrayers = 0;
  int _streak = 0;
  int _totalWirdPages = 0;

  // Custom periods (persisted). Month is normalized to the 1st; week start is a
  // date-only anchor for a 7-day window.
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedWeekStart = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day)
      .subtract(const Duration(days: 6));

  static const List<String> _arMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime d) => '${_arMonths[d.month - 1]} ${d.year}';

  String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${start.day} ${_arMonths[start.month - 1]} — ${end.day} ${_arMonths[end.month - 1]}';
  }

  List<String> _weekDayLabels() => List.generate(7, (i) {
        final d = _selectedWeekStart.add(Duration(days: i));
        return '${d.day}';
      });

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _restoreSelection();
    // Defer load to after first frame so setState() inside _loadData is safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  void _restoreSelection() {
    try {
      final box = Hive.box('settings');
      final m = box.get('analytics_month') as String?;
      final w = box.get('analytics_week') as String?;
      if (m != null) {
        final d = DateTime.tryParse(m);
        if (d != null) _selectedMonth = DateTime(d.year, d.month);
      }
      if (w != null) {
        final d = DateTime.tryParse(w);
        if (d != null) _selectedWeekStart = DateTime(d.year, d.month, d.day);
      }
    } catch (_) {}
  }

  void _persistSelection() {
    try {
      final box = Hive.box('settings');
      box.put('analytics_month', _selectedMonth.toIso8601String());
      box.put('analytics_week', _selectedWeekStart.toIso8601String());
    } catch (_) {}
  }

  void _changeMonth(int delta) {
    setState(() => _selectedMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + delta));
    _persistSelection();
    _loadData();
  }

  void _changeWeek(int deltaDays) {
    setState(() =>
        _selectedWeekStart = _selectedWeekStart.add(Duration(days: deltaDays)));
    _persistSelection();
    _loadData();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
      _persistSelection();
      _loadData();
    }
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (picked != null) {
      setState(() =>
          _selectedWeekStart = DateTime(picked.year, picked.month, picked.day));
      _persistSelection();
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // ── Weekly: the selected 7-day window ──
      final weekStart = DateTime(_selectedWeekStart.year,
          _selectedWeekStart.month, _selectedWeekStart.day);
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekWorships =
          await _firebaseService.getWorshipsInRange(userId, weekStart, weekEnd);
      final weekWird = await _firebaseService.getWirdRecordsInRange(
          userId, weekStart, weekEnd);

      final pData = List<double>.filled(7, 0);
      final qData = List<double>.filled(7, 0);
      final dData = List<double>.filled(7, 0);
      final wData = List<double>.filled(7, 0);

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        final dayWorship = weekWorships
            .where((w) =>
                w.date.year == date.year &&
                w.date.month == date.month &&
                w.date.day == date.day)
            .firstOrNull;
        if (dayWorship != null) {
          pData[i] = dayWorship.prayerCount.toDouble();
          qData[i] = dayWorship.quranPages.toDouble();
          dData[i] =
              dayWorship.worships[WorshipType.dhikr.name] == true ? 1.0 : 0.0;
        }
        final key = _dateKey(date);
        final wRec = weekWird.where((w) => w['date'] == key).firstOrNull;
        if (wRec != null) {
          wData[i] = ((wRec['pagesRead'] as int?) ?? 0).toDouble();
        }
      }

      // ── Monthly: the selected month ──
      final monthWorships = await _firebaseService.getMonthlyWorships(
          userId, _selectedMonth.year, _selectedMonth.month);
      final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final monthEnd =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      final monthWird = await _firebaseService.getWirdRecordsInRange(
          userId, monthStart, monthEnd);
      final totalWird = monthWird.fold<int>(
          0, (s, w) => s + ((w['pagesRead'] as int?) ?? 0));

      setState(() {
        _prayerData = pData;
        _quranData = qData;
        _dhikrData = dData;
        _wirdData = wData;
        _totalQuranPages = monthWorships.fold(0, (sum, w) => sum + w.quranPages);
        _completedPrayers = monthWorships.fold(0, (sum, w) => sum + w.prayerCount);
        _streak = monthWorships.length;
        _totalWirdPages = totalWird;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : AppColors.background;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
          title: Text('لوحة التحليلات', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            labelStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.ibmPlexSansArabic(),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [Tab(text: 'أسبوعي'), Tab(text: 'شهري')],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.darkGreen))
          : TabBarView(
          controller: _tabController,
          children: [
            _weeklyView(isDark),
            _monthlyView(isDark),
          ],
        ),
      ),
    );
  }

  Widget _weeklyView(bool isDark) {
    final labels = _weekDayLabels();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _periodSelector(
          label: _weekLabel(_selectedWeekStart),
          onPrev: () => _changeWeek(-7),
          onNext: () => _changeWeek(7),
          onTap: _pickWeek,
          isDark: isDark,
        ),
        _summaryCards(isDark),
        const SizedBox(height: 20),
        _chartCard(
          title: 'الصلوات اليومية (من ٥)',
          titleIcon: Icons.mosque_rounded,
          data: _prayerData,
          maxY: 5,
          color: AppColors.lightGreen,
          isDark: isDark,
          labels: labels,
        ),
        const SizedBox(height: 16),
        _chartCard(
          title: 'صفحات القرآن اليومية',
          titleIcon: Icons.menu_book_rounded,
          data: _quranData,
          maxY: 25,
          color: AppColors.gold,
          isDark: isDark,
          labels: labels,
        ),
        const SizedBox(height: 16),
        _chartCard(
          title: 'صفحات الورد اليومية',
          titleIcon: Icons.auto_stories_rounded,
          data: _wirdData,
          maxY: 25,
          color: AppColors.darkGreen,
          isDark: isDark,
          labels: labels,
        ),
        const SizedBox(height: 16),
        _chartCard(
          title: 'الأذكار (يوم مكتمل = ١)',
          titleIcon: Icons.front_hand_rounded,
          data: _dhikrData,
          maxY: 1,
          color: AppColors.midGreen,
          isDark: isDark,
          labels: labels,
        ),
      ],
    );
  }

  Widget _monthlyView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _periodSelector(
          label: _monthLabel(_selectedMonth),
          onPrev: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
          onTap: _pickMonth,
          isDark: isDark,
        ),
        _pieCard(isDark),
        const SizedBox(height: 16),
        _bestDaysCard(isDark),
      ],
    );
  }

  Widget _periodSelector({
    required String label,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final fg = isDark ? Colors.white : AppColors.darkGreen;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : AppColors.paleGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // RTL: right chevron = previous (earlier), left chevron = next.
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: fg),
            tooltip: 'السابق',
            onPressed: onPrev,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded, color: AppColors.gold, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontWeight: FontWeight.bold, color: fg, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: fg),
            tooltip: 'التالي',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }

  Widget _summaryCards(bool isDark) {
    return Row(
      children: [
        Expanded(child: _miniStat(label: 'إجمالي الصلوات', value: '$_completedPrayers', icon: Icons.mosque_rounded, isDark: isDark)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat(label: 'صفحات القرآن', value: '$_totalQuranPages', icon: Icons.menu_book_rounded, isDark: isDark)),
        const SizedBox(width: 10),
        Expanded(child: _miniStat(label: 'أيام النشاط', value: '$_streak يوم', icon: Icons.local_fire_department_rounded, isDark: isDark)),
      ],
    );
  }

  Widget _miniStat({required String label, required String value, required IconData icon, required bool isDark}) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : AppColors.paleGreen;
    final valueColor = isDark ? Colors.white : AppColors.darkGreen;
    final labelColor = isDark ? Colors.white70 : AppColors.gray;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 14, color: valueColor)),
          Text(label, style: GoogleFonts.ibmPlexSansArabic(fontSize: 10, color: labelColor), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _chartCard({required String title, required IconData titleIcon, required List<double> data, required double maxY, required Color color, required bool isDark, required List<String> labels}) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : AppColors.paleGreen;
    final titleColor = isDark ? Colors.white : AppColors.darkGreen;
    final gridColor = isDark ? Colors.white10 : Colors.grey[200]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(titleIcon, color: titleColor, size: 20),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: titleColor)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                          (v.toInt() >= 0 && v.toInt() < labels.length) ? labels[v.toInt()] : '',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: isDark ? Colors.white70 : AppColors.gray)),
                    ),
                  ),
                ),
                barGroups: List.generate(data.length, (i) {
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: data[i],
                      color: data[i] >= maxY ? color : color.withOpacity(isDark ? 0.3 : 0.5),
                      borderRadius: BorderRadius.circular(6),
                      width: 18,
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pieCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : AppColors.paleGreen;
    final titleColor = isDark ? Colors.white : AppColors.darkGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('توزيع العبادات — ${_monthLabel(_selectedMonth)}',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
              sections: [
                PieChartSectionData(value: _totalQuranPages.toDouble(), title: 'القرآن', color: AppColors.gold, titleStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: _completedPrayers.toDouble() * 10, title: 'الصلاة', color: AppColors.lightGreen, titleStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: _totalWirdPages.toDouble(), title: 'الورد', color: AppColors.darkGreen, titleStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: _streak.toDouble() * 5, title: 'النشاط', color: AppColors.midGreen, titleStyle: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
              centerSpaceRadius: 40,
            )),
          ),
        ],
      ),
    );
  }

  Widget _bestDaysCard(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white12 : AppColors.paleGreen;
    final titleColor = isDark ? Colors.white : AppColors.darkGreen;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏆 أفضل أيامك هذا الشهر',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 12),
          ...(_totalQuranPages > 0 ? ['إنجاز متميز في القرآن 📖', 'مواظبة على الصلوات 🕌'] : ['ابدأ تسجيل عباداتك لتظهر هنا 🌟']).map(
            (d) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.star, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d, style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, color: textColor))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
