import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../../core/app_models.dart';
import '../../models/monthly_goal_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/goals_statistics_service.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final GoalsStatisticsService _statisticsService = GoalsStatisticsService.instance;
  List<MonthlyGoal> _goals = [];
  bool _isLoading = true;
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      final goals = await _firebaseService.getAllMonthlyGoals(userId);
      final statistics = _statisticsService.calculateGoalsStatistics(goals);
      setState(() {
        _goals = goals;
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          title: Text('الأهداف الروحية الشهرية', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Column(
              children: [
                // Statistics Section
                if (_statistics.isNotEmpty)
                  _buildStatisticsSection(isDark),
                
                // Goals List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_goals.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'لا توجد أهداف مضافة حتى الآن.\nأضف هدفاً جديداً للبدء!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: isDark ? Colors.white54 : AppColors.gray,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ..._goals.map((g) => _GoalCard(
                        goal: g,
                        isDark: isDark,
                        onUpdate: _loadGoals,
                      )),
                      const SizedBox(height: 16),
                      _addGoalButton(context, isDark),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildStatisticsSection(bool isDark) {
    final totalGoals = _statistics['totalGoals'] as int? ?? 0;
    final completedGoals = _statistics['completedGoals'] as int? ?? 0;
    final inProgressGoals = _statistics['inProgressGoals'] as int? ?? 0;
    final completionRate = _statistics['completionRate'] as double? ?? 0.0;
    final averageProgress = _statistics['averageProgress'] as double? ?? 0.0;
    final goalsEndingSoon = _statistics['goalsEndingSoon'] as int? ?? 0;
    final overdueGoals = _statistics['overdueGoals'] as int? ?? 0;
    
    return Container(
      margin: const EdgeInsets.all(16),
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
                child: const Icon(Icons.analytics_rounded, color: AppColors.gold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إحصائيات الأهداف',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      'نظرة عامة على تقدمك الشهري 📊',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : AppColors.gray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'إجمالي الأهداف',
                  '$totalGoals',
                  Icons.track_changes_rounded,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'مكتملة',
                  '$completedGoals',
                  Icons.check_circle_rounded,
                  isDark,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'قيد التنفيذ',
                  '$inProgressGoals',
                  Icons.pending_rounded,
                  isDark,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _progressCard(
                  'معدل الإنجاز',
                  '${(completionRate * 100).toInt()}%',
                  completionRate,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _progressCard(
                  'متوسط التقدم',
                  '${(averageProgress * 100).toInt()}%',
                  averageProgress,
                  isDark,
                ),
              ),
            ],
          ),
          if (goalsEndingSoon > 0 || overdueGoals > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (overdueGoals > 0)
                  Expanded(
                    child: _alertCard(
                      'متأخر',
                      '$overdueGoals أهداف',
                      Icons.warning_rounded,
                      isDark,
                      const Color(0xFFFF5252),
                    ),
                  ),
                if (overdueGoals > 0 && goalsEndingSoon > 0)
                  const SizedBox(width: 12),
                if (goalsEndingSoon > 0)
                  Expanded(
                    child: _alertCard(
                      'ينتهي قريباً',
                      '$goalsEndingSoon أهداف',
                      Icons.schedule_rounded,
                      isDark,
                      AppColors.gold,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, bool isDark, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color ?? AppColors.gold,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10,
              color: isDark ? Colors.white70 : AppColors.gray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(String title, String value, double progress, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10,
              color: isDark ? Colors.white70 : AppColors.gray,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              color: progress >= 0.8 ? const Color(0xFF4CAF50) : AppColors.gold,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertCard(String title, String value, IconData icon, bool isDark, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: isDark ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addGoalButton(BuildContext context, bool isDark) {
    return OutlinedButton.icon(
      onPressed: () => _showAddGoalSheet(context, isDark),
      icon: Icon(Icons.add, color: isDark ? AppColors.lightGreen : AppColors.darkGreen),
      label: Text('إضافة هدف جديد', style: GoogleFonts.ibmPlexSansArabic(color: isDark ? AppColors.lightGreen : AppColors.darkGreen, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        side: BorderSide(color: isDark ? AppColors.lightGreen : AppColors.darkGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddGoalSheet(isDark: isDark, onGoalAdded: _loadGoals),
    );
  }
}

class _GoalCard extends StatefulWidget {
  final MonthlyGoal goal;
  final bool isDark;
  final VoidCallback onUpdate;
  const _GoalCard({required this.goal, required this.isDark, required this.onUpdate});

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _isUpdating = false;

  Future<void> _updateProgress(int newValue) async {
    if (_isUpdating) return;
    
    setState(() => _isUpdating = true);
    
    try {
      final userId = context.read<AppAuthProvider>().userId;
      if (userId.isEmpty) return;
      
      await FirebaseService().updateMonthlyGoalProgress(userId, widget.goal.id, newValue);
      widget.onUpdate();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث التقدم بنجاح', style: GoogleFonts.cairo(color: Colors.white)),
            backgroundColor: AppColors.darkGreen,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التحديث', style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.goal.progress * 100).toInt();
    final daysLeft = widget.goal.endDate.difference(DateTime.now()).inDays.clamp(0, 365);
    final cardBg = widget.isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final textColor = widget.isDark ? Colors.white : AppColors.textPrimary;
    final subColor = widget.isDark ? Colors.white54 : AppColors.gray;
    final greenColor = widget.isDark ? AppColors.lightGreen : AppColors.darkGreen;
    
    final icon = GoalCategory.getCategoryIcon(widget.goal.category);
    final categoryLabel = GoalCategory.getCategoryLabel(
      widget.goal.category,
      customLabel: widget.goal.customCategoryLabel,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(18),
        border: widget.isDark ? Border.all(color: Colors.white.withOpacity(0.06)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.goal.goalTitle,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: greenColor,
                  ),
                ),
                Text(
                  categoryLabel,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pct >= 100 ? (widget.isDark ? AppColors.darkGreen.withOpacity(0.3) : AppColors.paleGreen) : (widget.isDark ? AppColors.gold.withOpacity(0.15) : AppColors.goldBg),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$pct٪', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: pct >= 100 ? greenColor : AppColors.gold)),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: widget.goal.progress,
            backgroundColor: widget.isDark ? Colors.white12 : Colors.grey[200],
            color: pct >= 80 ? AppColors.lightGreen : AppColors.gold,
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  '${widget.goal.currentValue} / ${widget.goal.targetValue}',
                  style: GoogleFonts.ibmPlexSansArabic(color: subColor, fontSize: 13),
                ),
                if (!widget.goal.isCompleted && widget.goal.progress < 1.0) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showProgressUpdateDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            size: 14,
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'تحديث',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text('تبقى $daysLeft يوم', style: GoogleFonts.ibmPlexSansArabic(color: subColor, fontSize: 13)),
          ],
        ),
      ]),
    );
  }

  void _showProgressUpdateDialog() {
    final controller = TextEditingController(text: widget.goal.currentValue.toString());
    
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'تحديث التقدم',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'القيمة الحالية: ${widget.goal.currentValue}',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'القيمة الجديدة',
                  labelStyle: GoogleFonts.ibmPlexSansArabic(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic()),
            ),
            ElevatedButton(
              onPressed: () {
                final newValue = int.tryParse(controller.text) ?? 0;
                if (newValue >= 0 && newValue <= widget.goal.targetValue) {
                  Navigator.pop(ctx);
                  _updateProgress(newValue);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'يرجى إدخال قيمة صحيحة بين 0 و ${widget.goal.targetValue}',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'تحديث',
                style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddGoalSheet extends StatefulWidget {
  final bool isDark;
  final VoidCallback onGoalAdded;
  const _AddGoalSheet({required this.isDark, required this.onGoalAdded});

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _customCategoryController = TextEditingController();
  String _selectedCategory = GoalCategory.quran;
  bool _isLoading = false;
  bool _isCustomCategory = false;

  Future<void> _saveGoal() async {
    final title = _titleController.text.trim();
    final targetStr = _targetController.text.trim();
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إدخال عنوان الهدف', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
      return;
    }

    if (targetStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إدخال القيمة المستهدفة', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
      return;
    }

    final target = int.tryParse(targetStr) ?? 0;
    if (target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إدخال قيمة مستهدفة صحيحة', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى تسجيل الدخول أولاً', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
      return;
    }

    final newGoal = MonthlyGoal(
      id: const Uuid().v4(),
      userId: userId,
      goalTitle: title,
      goalDescription: '',
      targetValue: target,
      currentValue: 0,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 30)),
      category: _isCustomCategory ? GoalCategory.custom : _selectedCategory,
      customCategoryLabel: _isCustomCategory ? _customCategoryController.text.trim() : null,
    );

    try {
      await FirebaseService().saveMonthlyGoal(userId, newGoal);
      widget.onGoalAdded();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة الهدف بنجاح 🎯', style: GoogleFonts.cairo(color: Colors.white)), backgroundColor: AppColors.darkGreen),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حفظ الهدف', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : AppColors.textPrimary;
    final greenColor = widget.isDark ? AppColors.lightGreen : AppColors.darkGreen;
    final borderColor = widget.isDark ? Colors.white24 : Colors.grey[400]!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('هدف جديد', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: greenColor)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'عنوان الهدف', labelStyle: GoogleFonts.cairo(color: widget.isDark ? Colors.white54 : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: greenColor)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'القيمة المستهدفة', labelStyle: GoogleFonts.cairo(color: widget.isDark ? Colors.white54 : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: greenColor)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _isCustomCategory ? 'custom' : _selectedCategory,
                  dropdownColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  style: TextStyle(color: textColor, fontFamily: 'IBM Plex Sans Arabic'),
                  decoration: InputDecoration(
                    labelText: 'التصنيف', labelStyle: GoogleFonts.cairo(color: widget.isDark ? Colors.white54 : null),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: greenColor)),
                  ),
                  items: [
                    ...GoalCategory.allCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text('${GoalCategory.categoryIcons[category]} ${GoalCategory.categoryLabels[category]}'),
                      );
                    }),
                    const DropdownMenuItem(
                      value: 'custom',
                      child: Text('🎯 تصنيف مخصص'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _isCustomCategory = val == 'custom';
                        if (!_isCustomCategory) {
                          _selectedCategory = val;
                        }
                      });
                    }
                  },
                ),
              ),
              if (_isCustomCategory) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _customCategoryController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'اسم التصنيف', labelStyle: GoogleFonts.cairo(color: widget.isDark ? Colors.white54 : null),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: greenColor)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: _isLoading ? null : _saveGoal,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('حفظ الهدف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}


