import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  final List<_Challenge> _challenges = [
    _Challenge(title: 'صيام الاثنين والخميس', desc: 'سنة مؤكدة عن النبي ﷺ', icon: Icons.nights_stay_rounded, gradient: [const Color(0xFF1A237E), const Color(0xFF3949AB)], target: 8, current: 5),
    _Challenge(title: 'قراءة سورة الكهف', desc: 'نور ما بين الجمعتين', icon: Icons.auto_stories_rounded, gradient: [const Color(0xFF4A148C), const Color(0xFF7B1FA2)], target: 4, current: 3),
    _Challenge(title: 'قيام الليل', desc: 'شرف المؤمن', icon: Icons.star_rounded, gradient: [const Color(0xFF0D47A1), const Color(0xFF1976D2)], target: 30, current: 18),
    _Challenge(title: 'صلاة الضحى', desc: 'صلاة الأوابين', icon: Icons.wb_sunny_rounded, gradient: [const Color(0xFFE65100), const Color(0xFFFF8F00)], target: 30, current: 22),
    _Challenge(title: 'أذكار الصباح والمساء', desc: 'حصن المسلم', icon: Icons.shield_rounded, gradient: [const Color(0xFF1B5E20), const Color(0xFF388E3C)], target: 30, current: 27),
    _Challenge(title: 'صدقة يومية', desc: 'الصدقة تطفئ الخطيئة', icon: Icons.favorite_rounded, gradient: [const Color(0xFFB71C1C), const Color(0xFFE53935)], target: 30, current: 12),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7F6);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    final completed = _challenges.where((c) => c.current >= c.target).length;
    final totalProgress = _challenges.fold<double>(0, (s, c) => s + (c.current / c.target).clamp(0, 1)) / _challenges.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(slivers: [
          // ── Header ──
          SliverToBoxAdapter(child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 28, left: 20, right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: isDark ? [const Color(0xFF0D2818), const Color(0xFF0A3D22)] : [const Color(0xFF145A3A), const Color(0xFF1E8255)]),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
            ),
            child: Column(children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                Expanded(child: Text('التحديات الروحية', textAlign: TextAlign.center, style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white))),
                const SizedBox(width: 48),
              ]),
              const SizedBox(height: 20),
              // Progress overview
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: Row(children: [
                  SizedBox(width: 60, height: 60, child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(value: totalProgress, strokeWidth: 5, backgroundColor: Colors.white24, color: AppColors.goldLight, strokeCap: StrokeCap.round),
                    Text('${(totalProgress * 100).toInt()}٪', style: _f(sz: 14, fw: FontWeight.w800, c: Colors.white)),
                  ])),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('التقدم الإجمالي', style: _f(sz: 14, fw: FontWeight.w700, c: Colors.white)),
                    const SizedBox(height: 4),
                    Text('$completed من ${_challenges.length} تحديات مكتملة', style: _f(sz: 12, c: Colors.white60)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text('🔥 ${_challenges.fold<int>(0, (s, c) => s + c.current)}', style: _f(sz: 13, fw: FontWeight.w700, c: AppColors.goldLight)),
                  ),
                ]),
              ),
            ]),
          )),

          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('تحدياتك', style: _f(sz: 18, fw: FontWeight.w800, c: textColor)),
          )),

          // ── Challenge Cards ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
              final c = _challenges[i];
              final pct = (c.current / c.target).clamp(0.0, 1.0);
              final done = c.current >= c.target;
              final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cardBg, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                  boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  // Icon with gradient
                  Container(width: 56, height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: done ? [AppColors.darkGreen, AppColors.midGreen] : c.gradient),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: c.gradient[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Icon(done ? Icons.check_rounded : c.icon, color: Colors.white, size: 28)),
                  const SizedBox(width: 14),
                  // Info
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.title, style: _f(sz: 15, fw: FontWeight.w700, c: textColor)),
                    const SizedBox(height: 4),
                    Text(c.desc, style: _f(sz: 12, c: isDark ? Colors.white54 : AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: pct, minHeight: 6,
                        backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                        color: done ? AppColors.lightGreen : Color.lerp(c.gradient[0], c.gradient[1], 0.5))),
                  ])),
                  const SizedBox(width: 12),
                  // Count
                  Column(children: [
                    Text('${c.current}', style: _f(sz: 22, fw: FontWeight.w800, c: done ? AppColors.darkGreen : Color.lerp(c.gradient[0], c.gradient[1], 0.5))),
                    Text('/ ${c.target}', style: _f(sz: 11, c: isDark ? Colors.white38 : AppColors.gray)),
                  ]),
                ])),
              );
            }, childCount: _challenges.length)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ]),
      ),
    );
  }
}

class _Challenge {
  final String title, desc;
  final IconData icon;
  final List<Color> gradient;
  final int target, current;
  _Challenge({required this.title, required this.desc, required this.icon, required this.gradient, required this.target, required this.current});
}
