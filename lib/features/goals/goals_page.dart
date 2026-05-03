import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../../core/app_models.dart';
import '../../models/monthly_goal_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<MonthlyGoal> _goals = [];
  bool _isLoading = true;

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
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading goals: $e');
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
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_goals.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text('لا توجد أهداف مضافة حتى الآن.\nأضف هدفاً جديداً للبدء!', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white54 : AppColors.gray, fontSize: 16)),
                  ),
                ),
              ..._goals.map((g) => _GoalCard(goal: g, isDark: isDark)),
              const SizedBox(height: 16),
              _addGoalButton(context, isDark),
            ]),
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

class _GoalCard extends StatelessWidget {
  final MonthlyGoal goal;
  final bool isDark;
  const _GoalCard({required this.goal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).toInt();
    final daysLeft = goal.endDate.difference(DateTime.now()).inDays.clamp(0, 365);
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.gray;
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;
    
    final icon = GoalCategory.categoryIcons[goal.category] ?? '🎯';

    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(18),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.06)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Text(goal.goalTitle, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: greenColor))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pct >= 100 ? (isDark ? AppColors.darkGreen.withOpacity(0.3) : AppColors.paleGreen) : (isDark ? AppColors.gold.withOpacity(0.15) : AppColors.goldBg),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$pct٪', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, color: pct >= 100 ? greenColor : AppColors.gold)),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: goal.progress, backgroundColor: isDark ? Colors.white12 : Colors.grey[200], color: pct >= 80 ? AppColors.lightGreen : AppColors.gold, minHeight: 10)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${goal.currentValue} / ${goal.targetValue}', style: GoogleFonts.ibmPlexSansArabic(color: subColor, fontSize: 13)),
          Text('تبقى $daysLeft يوم', style: GoogleFonts.ibmPlexSansArabic(color: subColor, fontSize: 13)),
        ]),
      ]),
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
  String _selectedCategory = GoalCategory.quran;
  bool _isLoading = false;

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
      category: _selectedCategory,
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
      debugPrint('Error saving goal: $e');
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
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            dropdownColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
            style: TextStyle(color: textColor, fontFamily: 'IBM Plex Sans Arabic'),
            decoration: InputDecoration(
              labelText: 'التصنيف', labelStyle: GoogleFonts.cairo(color: widget.isDark ? Colors.white54 : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: greenColor)),
            ),
            items: GoalCategory.categoryLabels.entries.map((e) {
              return DropdownMenuItem(value: e.key, child: Text('${GoalCategory.categoryIcons[e.key]} ${e.value}'));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
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


