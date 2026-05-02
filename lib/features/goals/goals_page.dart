import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/app_models.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});
  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final List<SpiritualGoal> _goals = [
    SpiritualGoal(title: 'ختم القرآن الكريم', type: WorshipType.quran, targetValue: 604, currentValue: 480, startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31)),
    SpiritualGoal(title: 'صلاة الفجر يومياً', type: WorshipType.prayer, targetValue: 30, currentValue: 22, startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31)),
    SpiritualGoal(title: '١٠٠ صدقة', type: WorshipType.charity, targetValue: 100, currentValue: 63, startDate: DateTime(2026, 5, 1), endDate: DateTime(2026, 5, 31)),
  ];

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
          title: Text('الأهداف الروحية الشهرية', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
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
      label: Text('إضافة هدف جديد', style: GoogleFonts.cairo(color: isDark ? AppColors.lightGreen : AppColors.darkGreen, fontWeight: FontWeight.bold)),
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
      builder: (_) => _AddGoalSheet(isDark: isDark),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SpiritualGoal goal;
  final bool isDark;
  const _GoalCard({required this.goal, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).toInt();
    final daysLeft = goal.endDate.difference(DateTime.now()).inDays;
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.gray;
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(18),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.06)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(goal.type.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Text(goal.title, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: greenColor))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pct >= 100 ? (isDark ? AppColors.darkGreen.withOpacity(0.3) : AppColors.paleGreen) : (isDark ? AppColors.gold.withOpacity(0.15) : AppColors.goldBg),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$pct٪', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: pct >= 100 ? greenColor : AppColors.gold)),
          ),
        ]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: goal.progress, backgroundColor: isDark ? Colors.white12 : Colors.grey[200], color: pct >= 80 ? AppColors.lightGreen : AppColors.gold, minHeight: 10)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${goal.currentValue} / ${goal.targetValue}', style: GoogleFonts.cairo(color: subColor, fontSize: 13)),
          Text('تبقى $daysLeft يوم', style: GoogleFonts.cairo(color: subColor, fontSize: 13)),
        ]),
      ]),
    );
  }
}

class _AddGoalSheet extends StatelessWidget {
  final bool isDark;
  const _AddGoalSheet({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;
    final borderColor = isDark ? Colors.white24 : Colors.grey[400]!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('هدف جديد', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: greenColor)),
          const SizedBox(height: 16),
          TextField(
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'عنوان الهدف', labelStyle: GoogleFonts.cairo(color: isDark ? Colors.white54 : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: greenColor)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            keyboardType: TextInputType.number,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'القيمة المستهدفة', labelStyle: GoogleFonts.cairo(color: isDark ? Colors.white54 : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: greenColor)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('حفظ الهدف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
