import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class FridayTipsPage extends StatelessWidget {
  const FridayTipsPage({super.key});

  static const List<_SunnahCategory> _categories = [
    _SunnahCategory(title: 'سنن الغُسل', icon: '🚿', color: Color(0xFFE0F2FE), darkColor: Color(0xFF0D3B54), items: ['الاغتسال يوم الجمعة واجب على كل محتلم', 'التبكير إلى المسجد بعد الغسل', 'التطيب والتسوك قبل الذهاب', 'لبس أحسن الثياب']),
    _SunnahCategory(title: 'سنن الصلاة', icon: '🕌', color: Color(0xFFE8F8EF), darkColor: Color(0xFF0D2818), items: ['الإكثار من الصلاة على النبي ﷺ', 'قراءة سورة الكهف', 'التبكير إلى صلاة الجمعة', 'الإنصات للخطبة وعدم اللغو', 'صلاة ركعتين تحية المسجد']),
    _SunnahCategory(title: 'سنن الدعاء', icon: '🤲', color: Color(0xFFFDF3D7), darkColor: Color(0xFF3D2E0A), items: ['تحرّي ساعة الإجابة يوم الجمعة', 'الدعاء بين الأذان والإقامة', 'الدعاء في آخر ساعة بعد العصر', 'الإكثار من الاستغفار']),
    _SunnahCategory(title: 'سنن أخرى', icon: '✨', color: Color(0xFFF3E8FF), darkColor: Color(0xFF2D1A47), items: ['قص الأظافر وإزالة الشعر', 'الصدقة يوم الجمعة', 'زيارة المقابر والدعاء للأموات', 'المشي إلى المسجد وعدم الركوب إن أمكن', 'عدم تخطي رقاب الناس في المسجد']),
  ];

  static const List<_HadithItem> _hadiths = [
    _HadithItem(text: 'من غسّل يوم الجمعة واغتسل، وبكّر وابتكر، ومشى ولم يركب، ودنا من الإمام فاستمع ولم يلغُ، كان له بكل خطوة عمل سنة أجر صيامها وقيامها', source: 'رواه أبو داود والترمذي'),
    _HadithItem(text: 'إن من أفضل أيامكم يوم الجمعة فأكثروا عليّ من الصلاة فيه', source: 'رواه أبو داود'),
    _HadithItem(text: 'من قرأ سورة الكهف في يوم الجمعة أضاء له من النور ما بين الجمعتين', source: 'رواه الحاكم'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.textSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 180, pinned: true,
            backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
            flexibleSpace: FlexibleSpaceBar(
              title: Text('سنن الجمعة', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
              background: Container(
                decoration: BoxDecoration(gradient: LinearGradient(
                  colors: isDark ? [const Color(0xFF0D2818), const Color(0xFF145A3A)] : [AppColors.darkGreen, AppColors.midGreen],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🌟', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 8),
                  Text('خير يوم طلعت عليه الشمس', style: GoogleFonts.cairo(color: AppColors.goldLight, fontSize: 15, fontWeight: FontWeight.w600)),
                ])),
              ),
            ),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('📜 أحاديث عن فضل الجمعة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          )),
          SliverToBoxAdapter(child: SizedBox(height: 180, child: ListView.builder(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _hadiths.length, itemBuilder: (_, i) => _HadithCard(hadith: _hadiths[i], isDark: isDark),
          ))),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('📋 سنن يوم الجمعة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          )),
          SliverList(delegate: SliverChildBuilderDelegate((_, i) => _SunnahCategoryCard(category: _categories[i], isDark: isDark), childCount: _categories.length)),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('اللهم صلِّ وسلم على نبينا محمد ﷺ', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppColors.lightGreen : AppColors.darkGreen))),
          )),
        ]),
      ),
    );
  }
}

class _SunnahCategory {
  final String title, icon;
  final Color color, darkColor;
  final List<String> items;
  const _SunnahCategory({required this.title, required this.icon, required this.color, required this.darkColor, required this.items});
}

class _HadithItem {
  final String text, source;
  const _HadithItem({required this.text, required this.source});
}

class _HadithCard extends StatelessWidget {
  final _HadithItem hadith;
  final bool isDark;
  const _HadithCard({required this.hadith, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [const Color(0xFF1A2E1F), const Color(0xFF1A1F1C)] : [AppColors.paleGreen, AppColors.cardBg],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(18),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.06)) : null,
        boxShadow: [BoxShadow(color: (isDark ? Colors.black : AppColors.darkGreen).withOpacity(isDark ? 0.3 : 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(hadith.text, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimary, height: 1.6), maxLines: 5, overflow: TextOverflow.ellipsis)),
        const SizedBox(height: 8),
        Text(hadith.source, style: GoogleFonts.cairo(fontSize: 11, color: isDark ? AppColors.lightGreen : AppColors.darkGreen, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SunnahCategoryCard extends StatelessWidget {
  final _SunnahCategory category;
  final bool isDark;
  const _SunnahCategoryCard({required this.category, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A1F1C) : AppColors.cardBg;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final catColor = isDark ? category.darkColor : category.color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(18),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.06)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          leading: Container(width: 44, height: 44,
            decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(category.icon, style: const TextStyle(fontSize: 22)))),
          title: Text(category.title, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 16, color: textColor)),
          subtitle: Text('${category.items.length} سنن', style: GoogleFonts.cairo(fontSize: 12, color: isDark ? Colors.white54 : AppColors.textSecondary)),
          iconColor: isDark ? Colors.white54 : null,
          collapsedIconColor: isDark ? Colors.white38 : null,
          children: category.items.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 28, height: 28,
                decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('${entry.key + 1}', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 12, color: isDark ? Colors.white : AppColors.darkGreen)))),
              const SizedBox(width: 12),
              Expanded(child: Text(entry.value, style: GoogleFonts.cairo(fontSize: 14, color: textColor, fontWeight: FontWeight.w600, height: 1.5))),
            ]),
          )).toList(),
        ),
      ),
    );
  }
}
