import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          title: Text('تقرير الروح الشهري', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _previewCard(context, isDark),
          const SizedBox(height: 20),
          _generateButton(context),
          const SizedBox(height: 20),
          _pastReports(isDark),
        ]),
      ),
    );
  }

  Widget _previewCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft,
          colors: isDark ? [const Color(0xFF0D3B26), const Color(0xFF145A3A)] : [AppColors.darkGreen, AppColors.midGreen],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.darkGreen.withOpacity(isDark ? 0.2 : 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.picture_as_pdf, color: AppColors.goldLight, size: 32),
          const SizedBox(width: 12),
          Text('تقرير أبريل ٢٠٢٦', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 20),
        _statRow('📖', 'صفحات القرآن', '٤٨٠ صفحة'),
        _statRow('🕌', 'الصلوات المكتملة', '١٤٢ / ١٥٠'),
        _statRow('📿', 'أيام الأذكار', '٢٥ / ٣٠ يوم'),
        _statRow('💚', 'الصدقات', '٦٣ صدقة'),
        _statRow('🔥', 'أطول ستريك', '١٢ يوم متواصل'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('"رحلتك الروحية هذا الشهر كانت مميزة — استمر، فالثبات أفضل من الاندفاع المؤقت 🤍"',
            style: GoogleFonts.ibmPlexSansArabic(color: AppColors.goldLight, fontSize: 13, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _statRow(String icon, String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 13))),
      Text(value, style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
    ]));
  }

  Widget _generateButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🎉 جارٍ إنشاء التقرير... سيتم التنزيل تلقائياً', style: GoogleFonts.ibmPlexSansArabic()),
          backgroundColor: AppColors.darkGreen,
        ));
      },
      icon: const Icon(Icons.download, color: Colors.white),
      label: Text('تنزيل تقرير الروح (PDF)', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold, minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _pastReports(bool isDark) {
    final reports = ['مارس ٢٠٢٦', 'فبراير ٢٠٢٦', 'يناير ٢٠٢٦'];
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : AppColors.paleGreen),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('التقارير السابقة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: greenColor)),
        const SizedBox(height: 12),
        ...reports.map((r) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? AppColors.darkGreen.withOpacity(0.2) : AppColors.paleGreen, shape: BoxShape.circle),
            child: Icon(Icons.picture_as_pdf, color: greenColor, size: 20),
          ),
          title: Text('تقرير $r', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: textColor)),
          trailing: IconButton(icon: Icon(Icons.download, color: isDark ? AppColors.lightGreen : AppColors.midGreen), onPressed: () {}),
        )),
      ]),
    );
  }
}
