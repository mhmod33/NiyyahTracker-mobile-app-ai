import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class SmartPlanPage extends StatelessWidget {
  const SmartPlanPage({super.key});

  // Mock weekly plan based on "complete Quran in May" goal
  static const List<Map<String, dynamic>> _plan = [
    {'day': 'السبت',    'date': '3/5',  'task': 'اقرأ ٢٠ صفحة من القرآن',  'type': '📖', 'done': true},
    {'day': 'الأحد',    'date': '4/5',  'task': 'اقرأ ٢٠ صفحة + أذكار الصباح', 'type': '📿', 'done': true},
    {'day': 'الاثنين',  'date': '5/5',  'task': 'اقرأ ٢٠ صفحة + صدقة', 'type': '💚', 'done': false},
    {'day': 'الثلاثاء', 'date': '6/5',  'task': 'اقرأ ٢٠ صفحة', 'type': '📖', 'done': false},
    {'day': 'الأربعاء', 'date': '7/5',  'task': 'اقرأ ٢٠ صفحة + قيام الليل', 'type': '⭐', 'done': false},
    {'day': 'الخميس',  'date': '8/5',  'task': 'اقرأ ٢٠ صفحة', 'type': '📖', 'done': false},
    {'day': 'الجمعة',   'date': '9/5',  'task': 'سورة الكهف + اقرأ ٢٠ صفحة', 'type': '🕌', 'done': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.darkGreen,
          title: Text('الخطة الأسبوعية الذكية', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Goal summary banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFDAA520)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('هدفك الشهري', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
                        Text('ختم القرآن الكريم في مايو', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('المطلوب يومياً: ٢٠ صفحة', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text('٧٩٪', style: GoogleFonts.cairo(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      Text('مكتمل', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('خطة هذا الأسبوع',
                style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.darkGreen)),
            const SizedBox(height: 12),
            ..._plan.map((item) => _DayCard(item: item)),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _DayCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final bool done = item['done'] as bool;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: done ? AppColors.paleGreen : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: done ? AppColors.lightGreen : AppColors.paleGreen),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: done ? AppColors.lightGreen : Colors.grey[200],
          child: Text(item['type'] as String, style: const TextStyle(fontSize: 18)),
        ),
        title: Text('${item['day']} — ${item['date']}',
            style: GoogleFonts.cairo(fontSize: 12, color: AppColors.gray)),
        subtitle: Text(item['task'] as String,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: AppColors.darkGreen)),
        trailing: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? AppColors.lightGreen : Colors.grey[300]),
      ),
    );
  }
}
