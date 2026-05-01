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
    SpiritualGoal(
      title: 'ختم القرآن الكريم',
      type: WorshipType.quran,
      targetValue: 604,
      currentValue: 480,
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 31),
    ),
    SpiritualGoal(
      title: 'صلاة الفجر يومياً',
      type: WorshipType.prayer,
      targetValue: 30,
      currentValue: 22,
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 31),
    ),
    SpiritualGoal(
      title: '١٠٠ صدقة',
      type: WorshipType.charity,
      targetValue: 100,
      currentValue: 63,
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 31),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.darkGreen,
          title: Text('الأهداف الروحية الشهرية', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ..._goals.map((g) => _GoalCard(goal: g)),
            const SizedBox(height: 16),
            _addGoalButton(context),
          ],
        ),
      ),
    );
  }

  Widget _addGoalButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showAddGoalSheet(context),
      icon: const Icon(Icons.add, color: AppColors.darkGreen),
      label: Text('إضافة هدف جديد', style: GoogleFonts.cairo(color: AppColors.darkGreen, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        side: const BorderSide(color: AppColors.darkGreen),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddGoalSheet(),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SpiritualGoal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final pct = (goal.progress * 100).toInt();
    final daysLeft = goal.endDate.difference(DateTime.now()).inDays;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.type.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(goal.title,
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.darkGreen)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: pct >= 100 ? AppColors.paleGreen : AppColors.goldBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$pct٪', style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: pct >= 100 ? AppColors.darkGreen : AppColors.gold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: goal.progress,
              backgroundColor: Colors.grey[200],
              color: pct >= 80 ? AppColors.lightGreen : AppColors.gold,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${goal.currentValue} / ${goal.targetValue}',
                  style: GoogleFonts.cairo(color: AppColors.gray, fontSize: 13)),
              Text('تبقى $daysLeft يوم',
                  style: GoogleFonts.cairo(color: AppColors.gray, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddGoalSheet extends StatelessWidget {
  const _AddGoalSheet();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هدف جديد', style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkGreen)),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'عنوان الهدف',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.darkGreen)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'القيمة المستهدفة',
                labelStyle: GoogleFonts.cairo(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.darkGreen)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('حفظ الهدف', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
