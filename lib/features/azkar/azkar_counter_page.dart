import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class _Dhikr {
  final String text, reward;
  final int targetCount;
  const _Dhikr({required this.text, required this.reward, required this.targetCount});
}

const List<_Dhikr> _azkar = [
  _Dhikr(text: 'سبحان الله', reward: 'يغرس لك نخلة في الجنة', targetCount: 33),
  _Dhikr(text: 'الحمد لله', reward: 'تملأ الميزان', targetCount: 33),
  _Dhikr(text: 'الله أكبر', reward: 'تملأ ما بين السماء والأرض', targetCount: 34),
  _Dhikr(text: 'لا إله إلا الله', reward: 'أفضل ما قلت أنا والنبيون من قبلي', targetCount: 100),
  _Dhikr(text: 'سبحان الله وبحمده', reward: 'حُطّت خطاياه وإن كانت مثل زبد البحر', targetCount: 100),
  _Dhikr(text: 'لا حول ولا قوة إلا بالله', reward: 'كنز من كنوز الجنة', targetCount: 100),
  _Dhikr(text: 'أستغفر الله', reward: 'من لزم الاستغفار جعل الله له من كل همّ فرجاً', targetCount: 100),
  _Dhikr(text: 'اللهم صلّ وسلم على نبينا محمد', reward: 'من صلّى عليّ صلاة صلّى الله عليه بها عشراً', targetCount: 100),
  _Dhikr(text: 'سبحان الله وبحمده سبحان الله العظيم', reward: 'كلمتان حبيبتان إلى الرحمن ثقيلتان في الميزان', targetCount: 100),
];

class AzkarCounterPage extends StatefulWidget {
  const AzkarCounterPage({super.key});
  @override
  State<AzkarCounterPage> createState() => _AzkarCounterPageState();
}

class _AzkarCounterPageState extends State<AzkarCounterPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<int> _counts;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _counts = List.filled(_azkar.length, 0);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseController.dispose(); super.dispose(); }

  _Dhikr get _current => _azkar[_selectedIndex];
  int get _currentCount => _counts[_selectedIndex];
  double get _progress => (_currentCount / _current.targetCount).clamp(0.0, 1.0);
  bool get _completed => _currentCount >= _current.targetCount;

  void _increment() {
    if (_completed) return;
    HapticFeedback.lightImpact();
    _pulseController.forward().then((_) => _pulseController.reverse());
    setState(() { _counts[_selectedIndex]++; });
    if (_counts[_selectedIndex] >= _current.targetCount) HapticFeedback.heavyImpact();
  }

  void _reset() => setState(() => _counts[_selectedIndex] = 0);
  void _resetAll() => setState(() { _counts = List.filled(_azkar.length, 0); });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;
    final cardBg = isDark ? const Color(0xFF1A1F1C) : AppColors.cardBg;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.gray;
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cardBg, elevation: 0, scrolledUnderElevation: 1,
          leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textColor), onPressed: () => Navigator.pop(context)),
          title: Text('📿 عدّاد الأذكار', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 20, color: textColor)),
          actions: [IconButton(icon: Icon(Icons.restart_alt, color: subColor), tooltip: 'إعادة ضبط الكل', onPressed: _resetAll)],
        ),
        body: Column(children: [
          // ── Azkar selector ──
          SizedBox(height: 52, child: ListView.builder(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _azkar.length,
            itemBuilder: (_, i) {
              final selected = i == _selectedIndex;
              final done = _counts[i] >= _azkar[i].targetCount;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.darkGreen : done ? (isDark ? AppColors.darkGreen.withOpacity(0.2) : AppColors.paleGreen) : (isDark ? Colors.white10 : cardBg),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppColors.darkGreen : (isDark ? Colors.white24 : AppColors.grayLight)),
                  ),
                  child: Center(child: Row(children: [
                    if (done) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.check_circle, size: 14, color: isDark ? AppColors.lightGreen : AppColors.darkGreen)),
                    Text('${i + 1}', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? Colors.white : textColor)),
                  ])),
                ),
              );
            },
          )),
          // ── Main counter ──
          Expanded(child: GestureDetector(
            onTap: _increment, behavior: HitTestBehavior.opaque,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_current.text, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.w900, color: greenColor, height: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: isDark ? AppColors.gold.withOpacity(0.15) : AppColors.goldLight, borderRadius: BorderRadius.circular(12)),
                  child: Text(_current.reward, textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.goldLight : AppColors.dark)),
                ),
                const SizedBox(height: 36),
                ScaleTransition(scale: _pulseAnim, child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: cardBg,
                    boxShadow: [BoxShadow(color: (_completed ? AppColors.lightGreen : AppColors.darkGreen).withOpacity(0.15), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(width: 170, height: 170, child: CircularProgressIndicator(
                      value: _progress, strokeWidth: 6,
                      backgroundColor: isDark ? Colors.white12 : AppColors.grayLight,
                      color: _completed ? AppColors.lightGreen : AppColors.darkGreen, strokeCap: StrokeCap.round)),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      if (_completed)
                        const Text('✅', style: TextStyle(fontSize: 28))
                      else
                        Text('$_currentCount', style: GoogleFonts.cairo(fontSize: 52, fontWeight: FontWeight.w900, color: greenColor)),
                      Text('/ ${_current.targetCount}', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600, color: subColor)),
                    ]),
                  ]),
                )),
                const SizedBox(height: 24),
                Text(_completed ? 'أحسنت! أكملت هذا الذكر ✨' : 'اضغط في أي مكان للعدّ',
                  style: GoogleFonts.cairo(fontSize: 14, color: _completed ? greenColor : subColor, fontWeight: FontWeight.w600)),
              ],
            )),
          )),
          // ── Bottom controls ──
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: cardBg,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _reset,
                icon: Icon(Icons.refresh, size: 18, color: subColor),
                label: Text('إعادة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: subColor)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: subColor,
                  side: BorderSide(color: isDark ? Colors.white24 : AppColors.grayLight),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: _selectedIndex > 0 ? () => setState(() => _selectedIndex--) : null,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text('السابق', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : AppColors.surfaceLight,
                  foregroundColor: greenColor, disabledForegroundColor: subColor,
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: _selectedIndex < _azkar.length - 1 ? () => setState(() => _selectedIndex++) : null,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text('التالي', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGreen, foregroundColor: Colors.white,
                  elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}
