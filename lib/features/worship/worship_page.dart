import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/app_models.dart';

class WorshipPage extends StatefulWidget {
  const WorshipPage({super.key});
  @override
  State<WorshipPage> createState() => _WorshipPageState();
}

class _WorshipPageState extends State<WorshipPage> {
  final Map<WorshipType, bool> _checked = {
    for (var t in WorshipType.values) t: false,
  };
  int _prayerCount = 0;
  int _quranPages = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.gray;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.paleGreen;
    final today = DateTime.now();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          title: Text('عبادات اليوم', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${today.day}/${today.month}/${today.year}', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
            )),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader('🕌 الصلوات الخمس', isDark),
            _prayerCard(isDark, cardBg, textColor, subColor, borderColor),
            const SizedBox(height: 12),
            _sectionHeader('📖 قراءة القرآن الكريم', isDark),
            _quranCard(isDark, cardBg, textColor, subColor, borderColor),
            const SizedBox(height: 12),
            _sectionHeader('📿 العبادات الأخرى', isDark),
            ...WorshipType.values
                .where((t) => t != WorshipType.prayer && t != WorshipType.quran)
                .map((type) => _worshipTile(type, isDark, cardBg, textColor, borderColor)),
            const SizedBox(height: 24),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isDark ? [const Color(0xFF0D3B26), const Color(0xFF145A3A)] : [AppColors.midGreen, AppColors.darkGreen]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(title, style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _prayerCard(bool isDark, Color cardBg, Color textColor, Color subColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('كم صلاة صليت في وقتها اليوم؟', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: isDark ? AppColors.lightGreen : AppColors.darkGreen)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(6, (i) {
          final selected = i <= _prayerCount;
          final labels = ['0', 'الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
          return GestureDetector(
            onTap: () => setState(() => _prayerCount = i),
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200), width: 38, height: 38,
                decoration: BoxDecoration(
                  color: selected ? AppColors.darkGreen : (isDark ? Colors.white10 : Colors.grey[100]),
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? AppColors.darkGreen : (isDark ? Colors.white24 : Colors.grey[300]!)),
                ),
                child: Center(child: Text('$i', style: GoogleFonts.cairo(color: selected ? Colors.white : (isDark ? Colors.white60 : Colors.grey[600]), fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: GoogleFonts.cairo(fontSize: 9, color: subColor)),
            ]),
          );
        })),
      ]),
    );
  }

  Widget _quranCard(bool isDark, Color cardBg, Color textColor, Color subColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('كم صفحة قرأت اليوم؟', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: isDark ? AppColors.lightGreen : AppColors.darkGreen)),
        const SizedBox(height: 12),
        Row(children: [
          IconButton(onPressed: () => setState(() { if (_quranPages > 0) _quranPages--; }), icon: Icon(Icons.remove_circle_outline, color: isDark ? AppColors.lightGreen : AppColors.midGreen)),
          Expanded(child: Text('$_quranPages صفحة', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? AppColors.lightGreen : AppColors.darkGreen))),
          IconButton(onPressed: () => setState(() => _quranPages++), icon: Icon(Icons.add_circle_outline, color: isDark ? AppColors.lightGreen : AppColors.midGreen)),
        ]),
        Wrap(spacing: 8, children: [5, 10, 15, 20].map((p) => ActionChip(
          label: Text('$p صفحات', style: GoogleFonts.cairo(fontSize: 12, color: isDark ? Colors.white : null)),
          onPressed: () => setState(() => _quranPages = p),
          backgroundColor: _quranPages == p ? (isDark ? AppColors.darkGreen.withOpacity(0.3) : AppColors.paleGreen) : (isDark ? Colors.white10 : Colors.grey[100]),
          side: BorderSide(color: _quranPages == p ? (isDark ? AppColors.darkGreen : AppColors.lightGreen) : (isDark ? Colors.white24 : Colors.grey[300]!)),
        )).toList()),
      ]),
    );
  }

  Widget _worshipTile(WorshipType type, bool isDark, Color cardBg, Color textColor, Color borderColor) {
    final done = _checked[type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: done ? AppColors.lightGreen : borderColor),
      ),
      child: ListTile(
        leading: Text(type.emoji, style: const TextStyle(fontSize: 26)),
        title: Text(type.label, style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: isDark ? AppColors.lightGreen : AppColors.darkGreen)),
        trailing: GestureDetector(
          onTap: () => setState(() => _checked[type] = !done),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200), width: 30, height: 30,
            decoration: BoxDecoration(
              color: done ? AppColors.lightGreen : Colors.transparent, shape: BoxShape.circle,
              border: Border.all(color: done ? AppColors.lightGreen : (isDark ? Colors.white24 : Colors.grey[300]!)),
            ),
            child: done ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
          ),
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(height: 56, child: ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم حفظ عبادات اليوم بفضل الله 🤍', style: GoogleFonts.cairo()),
          backgroundColor: AppColors.darkGreen,
        ));
      },
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      icon: const Icon(Icons.save, color: Colors.white),
      label: Text('حفظ بطاقة اليوم', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    ));
  }
}
