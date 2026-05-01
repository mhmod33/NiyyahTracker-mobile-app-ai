import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class HajjPage extends StatelessWidget {
  const HajjPage({super.key});

  static const List<Map<String, dynamic>> _rituals = [
    {'day': 'اليوم الأول',   'date': '٨ ذو الحجة', 'title': 'الإحرام والتوجه إلى منى',    'dua': 'لبيك اللهم لبيك، لبيك لا شريك لك لبيك', 'done': false},
    {'day': 'اليوم الثاني',  'date': '٩ ذو الحجة', 'title': 'الوقوف بعرفة',               'dua': 'اللهم اجعلني من الذين وقفوا بعرفة خاشعين', 'done': false},
    {'day': 'اليوم الثالث',  'date': '١٠ ذو الحجة','title': 'النحر ورمي جمرة العقبة',    'dua': 'الله أكبر اللهم اجعله حجاً مبروراً', 'done': false},
    {'day': 'اليوم الرابع',  'date': '١١ ذو الحجة','title': 'رمي الجمرات الثلاث',         'dua': 'رب اغفر وارحم وتجاوز عما تعلم', 'done': false},
    {'day': 'اليوم الخامس',  'date': '١٢ ذو الحجة','title': 'رمي الجمرات + طواف الوداع', 'dua': 'اللهم لا تجعله آخر العهد ببيتك الحرام', 'done': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1200),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1200),
          title: Text('🕋 مود الحج', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _countdownCard(),
            const SizedBox(height: 16),
            _mapPlaceholder(context),
            const SizedBox(height: 16),
            Text('خطوات المناسك يوماً بيوم',
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._rituals.map((r) => _RitualCard(ritual: r)),
          ],
        ),
      ),
    );
  }

  Widget _countdownCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D2B00), Color(0xFF5C4200)],
          begin: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text('🕋', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('العد التنازلي لموسم الحج', style: GoogleFonts.cairo(color: AppColors.goldLight, fontSize: 14)),
          const SizedBox(height: 4),
          Text('٦٠ يوماً', style: GoogleFonts.cairo(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          Text('حتى ٨ ذو الحجة ١٤٤٧', style: GoogleFonts.cairo(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _mapPlaceholder(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F00),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map, color: AppColors.gold, size: 40),
          const SizedBox(height: 8),
          Text('خريطة المشاعر المقدسة', style: GoogleFonts.cairo(color: Colors.white70, fontWeight: FontWeight.bold)),
          Text('مكة المكرمة · منى · عرفات · مزدلفة', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RitualCard extends StatefulWidget {
  final Map<String, dynamic> ritual;
  const _RitualCard({required this.ritual});

  @override
  State<_RitualCard> createState() => _RitualCardState();
}

class _RitualCardState extends State<_RitualCard> {
  bool _done = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _done ? const Color(0xFF1A3300) : const Color(0xFF241A00),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _done ? AppColors.lightGreen.withOpacity(0.4) : AppColors.gold.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: _done ? AppColors.lightGreen : AppColors.gold.withOpacity(0.2),
              child: Text(widget.ritual['day'].toString().substring(0, 1),
                  style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(widget.ritual['title'] as String,
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${widget.ritual['day']} — ${widget.ritual['date']}',
                style: GoogleFonts.cairo(color: Colors.white54, fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.goldLight),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
                GestureDetector(
                  onTap: () => setState(() => _done = !_done),
                  child: Icon(_done ? Icons.check_circle : Icons.circle_outlined,
                      color: _done ? AppColors.lightGreen : Colors.white30),
                ),
              ],
            ),
          ),
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '🤲 ${widget.ritual['dua']}',
                  style: GoogleFonts.cairo(color: AppColors.goldLight, fontSize: 13, height: 1.6),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
