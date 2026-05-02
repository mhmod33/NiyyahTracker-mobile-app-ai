import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../../models/weekly_plan_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';

class SmartPlanPage extends StatefulWidget {
  const SmartPlanPage({super.key});

  @override
  State<SmartPlanPage> createState() => _SmartPlanPageState();
}

class _SmartPlanPageState extends State<SmartPlanPage> {
  final FirebaseService _firebaseService = FirebaseService();
  WeeklyPlan? _currentPlan;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrGeneratePlan();
  }

  Future<void> _loadOrGeneratePlan() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      var plan = await _firebaseService.getCurrentWeeklyPlan(userId);
      
      if (plan == null) {
        // Generate a new smart plan based on active goals
        final goals = await _firebaseService.getAllMonthlyGoals(userId);
        final goalId = goals.isNotEmpty ? goals.first.id : 'no_goal_id';
        
        final today = DateTime.now();
        final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
        final dailyPlans = List.generate(7, (i) {
          final date = today.add(Duration(days: i));
          return DailyPlan(
            date: date,
            task: goals.isNotEmpty ? goals.first.goalTitle : 'اقرأ ٢٠ صفحة من القرآن',
            description: 'الورد اليومي للهدف الشهري',
            targetAmount: 20,
            isCompleted: false,
          );
        });

        plan = WeeklyPlan(
          id: const Uuid().v4(),
          userId: userId,
          monthlyGoalId: goalId,
          weekStartDate: today,
          dailyPlans: dailyPlans,
          createdAt: DateTime.now(),
        );

        await _firebaseService.saveWeeklyPlan(userId, plan);
      }

      setState(() {
        _currentPlan = plan;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading weekly plan: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDayCompletion(int index, bool newValue) async {
    if (_currentPlan == null) return;
    
    final userId = context.read<AppAuthProvider>().userId;
    final updatedPlans = List<DailyPlan>.from(_currentPlan!.dailyPlans);
    updatedPlans[index] = updatedPlans[index].copyWith(
      isCompleted: newValue,
      actualAmount: newValue ? updatedPlans[index].targetAmount : 0,
    );

    final newPlan = WeeklyPlan(
      id: _currentPlan!.id,
      userId: _currentPlan!.userId,
      monthlyGoalId: _currentPlan!.monthlyGoalId,
      weekStartDate: _currentPlan!.weekStartDate,
      dailyPlans: updatedPlans,
      createdAt: _currentPlan!.createdAt,
    );

    setState(() => _currentPlan = newPlan);
    await _firebaseService.saveWeeklyPlan(userId, newPlan);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          title: Text('الخطة الأسبوعية الذكية', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _currentPlan == null 
            ? Center(child: Text('لم يتم إنشاء الخطة بعد.', style: TextStyle(color: textColor)))
            : ListView(padding: const EdgeInsets.all(16), children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFDAA520)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    const Text('🎯', style: TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('هدفك النشط', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 12)),
                      Text('الخطة الأسبوعية', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('إنجاز المهام اليومية', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 12)),
                    ])),
                    Column(children: [
                      Text('${((_currentPlan!.totalCompletedDays / 7) * 100).toInt()}٪', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('مكتمل', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 11)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 20),
                Text('خطة هذا الأسبوع', style: GoogleFonts.ibmPlexSansArabic(fontSize: 17, fontWeight: FontWeight.bold, color: greenColor)),
                const SizedBox(height: 12),
                ...List.generate(_currentPlan!.dailyPlans.length, (index) {
                  final plan = _currentPlan!.dailyPlans[index];
                  return _DayCard(
                    plan: plan,
                    isDark: isDark,
                    onToggle: (val) => _toggleDayCompletion(index, val),
                  );
                }),
              ]),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DailyPlan plan;
  final bool isDark;
  final ValueChanged<bool> onToggle;
  
  const _DayCard({required this.plan, required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final bool done = plan.isCompleted;
    final cardBg = done
        ? (isDark ? AppColors.darkGreen.withOpacity(0.15) : AppColors.paleGreen)
        : (isDark ? const Color(0xFF1A1F1C) : Colors.white);
    final borderColor = done
        ? (isDark ? AppColors.darkGreen.withOpacity(0.4) : AppColors.lightGreen)
        : (isDark ? Colors.white.withOpacity(0.06) : AppColors.paleGreen);
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;
    final subColor = isDark ? Colors.white54 : AppColors.gray;

    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final dayName = days[plan.date.weekday % 7];

    return GestureDetector(
      onTap: () => onToggle(!done),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: done ? (isDark ? AppColors.darkGreen.withOpacity(0.3) : AppColors.lightGreen) : (isDark ? Colors.white10 : Colors.grey[200]),
            child: const Text('🎯', style: TextStyle(fontSize: 18)),
          ),
          title: Text('$dayName — ${plan.date.day}/${plan.date.month}', style: GoogleFonts.cairo(fontSize: 12, color: subColor)),
          subtitle: Text(plan.task, style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: greenColor)),
          trailing: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? (isDark ? AppColors.lightGreen : AppColors.lightGreen) : (isDark ? Colors.white24 : Colors.grey[300])),
        ),
      ),
    );
  }
}
