import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
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
  
  int _totalQuranPages = 0;
  int _completedPrayers = 0;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) return;

    try {
      final now = DateTime.now();
      final worships = await _firebaseService.getMonthlyWorships(userId, now.year, now.month);
      
      final last7Days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
      
      final List<double> pData = List.filled(7, 0);
      final List<double> qData = List.filled(7, 0);
      final List<double> dData = List.filled(7, 0);

      for (int i = 0; i < 7; i++) {
        final date = last7Days[i];
        final dayWorship = worships.where((w) => w.date.day == date.day && w.date.month == date.month).firstOrNull;
        
        if (dayWorship != null) {
          pData[i] = dayWorship.prayerCount.toDouble();
          qData[i] = dayWorship.quranPages.toDouble();
          dData[i] = dayWorship.worships[WorshipType.dhikr.name] == true ? 1.0 : 0.0;
        }
      }

      setState(() {
        _prayerData = pData;
        _quranData = qData;
        _dhikrData = dData;
        _totalQuranPages = worships.fold(0, (sum, w) => sum + w.quranPages);
        _completedPrayers = worships.fold(0, (sum, w) => sum + w.prayerCount);
        _streak = worships.length; 
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.darkGreen,
          title: Text('لوحة التحليلات', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.cairo(),
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
            _weeklyView(),
            _monthlyView(),
          ],
        ),
      ),
    );
  }

  Widget _weeklyView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCards(),
        const SizedBox(height: 20),
        _chartCard(
          title: '🕌 الصلوات اليومية (من ٥)',
          data: _prayerData,
          maxY: 5,
          color: AppColors.lightGreen,
        ),
        const SizedBox(height: 16),
        _chartCard(
          title: '📖 صفحات القرآن اليومية',
          data: _quranData,
          maxY: 25,
          color: AppColors.gold,
        ),
        const SizedBox(height: 16),
        _chartCard(
          title: '📿 الأذكار (يوم مكتمل = ١)',
          data: _dhikrData,
          maxY: 1,
          color: AppColors.midGreen,
        ),
      ],
    );
  }

  Widget _monthlyView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _pieCard(),
        const SizedBox(height: 16),
        _bestDaysCard(),
      ],
    );
  }

  Widget _summaryCards() {
    return Row(
      children: [
        Expanded(child: _miniStat(label: 'إجمالي الصلوات', value: '$_completedPrayers', icon: '🕌')),
        const SizedBox(width: 10),
        Expanded(child: _miniStat(label: 'صفحات القرآن', value: '$_totalQuranPages', icon: '📖')),
        const SizedBox(width: 10),
        Expanded(child: _miniStat(label: 'أيام النشاط', value: '$_streak يوم', icon: '🔥')),
      ],
    );
  }

  Widget _miniStat({required String label, required String value, required String icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.paleGreen),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.darkGreen)),
          Text(label, style: GoogleFonts.cairo(fontSize: 10, color: AppColors.gray), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _chartCard({required String title, required List<double> data, required double maxY, required Color color}) {
    const days = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.paleGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.darkGreen)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(days[v.toInt()],
                          style: GoogleFonts.cairo(fontSize: 11, color: AppColors.gray)),
                    ),
                  ),
                ),
                barGroups: List.generate(data.length, (i) {
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: data[i],
                      color: data[i] >= maxY ? color : color.withOpacity(0.5),
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

  Widget _pieCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.paleGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('توزيع العبادات هذا الشهر',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.darkGreen)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
              sections: [
                PieChartSectionData(value: _totalQuranPages.toDouble(), title: 'القرآن', color: AppColors.gold, titleStyle: GoogleFonts.cairo(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: _completedPrayers.toDouble() * 10, title: 'الصلاة', color: AppColors.lightGreen, titleStyle: GoogleFonts.cairo(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                PieChartSectionData(value: _streak.toDouble() * 5, title: 'النشاط', color: AppColors.midGreen, titleStyle: GoogleFonts.cairo(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
              centerSpaceRadius: 40,
            )),
          ),
        ],
      ),
    );
  }

  Widget _bestDaysCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.paleGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🏆 أفضل أيامك هذا الشهر',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppColors.darkGreen)),
          const SizedBox(height: 12),
          ...(_totalQuranPages > 0 ? ['إنجاز متميز في القرآن 📖', 'مواظبة على الصلوات 🕌'] : ['ابدأ تسجيل عباداتك لتظهر هنا 🌟']).map(
            (d) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.star, color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d, style: GoogleFonts.cairo(fontSize: 13))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
