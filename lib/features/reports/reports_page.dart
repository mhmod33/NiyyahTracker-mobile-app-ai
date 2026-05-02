import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectMonth(BuildContext context) async {
    // Simple month picker using standard date picker
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.darkGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.darkGreen,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _generatePdf(BuildContext context, AppAuthProvider authProvider) async {
    final pdf = pw.Document();

    // Try to load Arabic font for PDF
    pw.Font? arabicFont;
    try {
      final fontData = await rootBundle.load('assets/fonts/KFGQPC Uthmanic Script HAFS.otf');
      arabicFont = pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Could not load font for PDF: $e');
    }

    final monthStr = DateFormat('MMMM yyyy', 'ar').format(_selectedDate);
    final userName = authProvider.displayName;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
        ),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 20),
                pw.Text('النية', style: pw.TextStyle(fontSize: 40, color: PdfColors.green900)),
                pw.SizedBox(height: 10),
                pw.Text('تقرير العبادات الشهري', style: pw.TextStyle(fontSize: 24, color: PdfColors.green700)),
                pw.Divider(color: PdfColors.green300, thickness: 2),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('اسم المستخدم: $userName', style: const pw.TextStyle(fontSize: 18)),
                    pw.Text('عن شهر: $monthStr', style: const pw.TextStyle(fontSize: 18)),
                  ],
                ),
                pw.SizedBox(height: 40),
                
                // Stats Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.green300, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    color: PdfColors.green50,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfStatRow('صفحات القرآن:', '١٥٠ صفحة'),
                      pw.SizedBox(height: 10),
                      _pdfStatRow('الصلوات المكتملة:', '١٣٠ / ١٥٠'),
                      pw.SizedBox(height: 10),
                      _pdfStatRow('أيام الأذكار:', '٢٥ / ٣٠ يوم'),
                      pw.SizedBox(height: 10),
                      _pdfStatRow('أطول فترة استمرار (ستريك):', '١٢ يوم'),
                    ],
                  ),
                ),

                pw.Spacer(),
                pw.Text(
                  '"إنما الأعمال بالنيات"',
                  style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Niyyah_Report_${_selectedDate.month}_${_selectedDate.year}.pdf',
    );
  }

  pw.Widget _pdfStatRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 18)),
        pw.Text(value, style: pw.TextStyle(fontSize: 18, color: PdfColors.green800)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;
    final authProvider = context.watch<AppAuthProvider>();

    final monthStr = DateFormat('MMMM yyyy', 'ar').format(_selectedDate);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          title: Text('تقارير', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16), 
          children: [
            // Month Selector
            GestureDetector(
              onTap: () => _selectMonth(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : AppColors.paleGreen),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: AppColors.midGreen, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'تقرير شهر $monthStr',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.darkGreen,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_drop_down_rounded, color: AppColors.gray),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            _previewCard(context, isDark, monthStr, authProvider.displayName),
            const SizedBox(height: 24),
            
            _generateButton(context, authProvider),
            const SizedBox(height: 24),
            
            _pastReports(isDark),
          ],
        ),
      ),
    );
  }

  Widget _previewCard(BuildContext context, bool isDark, String monthStr, String userName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft,
          colors: isDark ? [const Color(0xFF0D3B26), const Color(0xFF145A3A)] : [AppColors.darkGreen, AppColors.midGreen],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.darkGreen.withOpacity(isDark ? 0.2 : 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.picture_as_pdf, color: AppColors.goldLight, size: 28),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تقرير العبادات', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 12)),
                  Text(monthStr, style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ]),
            Icon(Icons.check_circle_outline_rounded, color: AppColors.goldLight, size: 24),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _statRow('📖', 'صفحات القرآن', '١٥٠ صفحة'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)),
              _statRow('🕌', 'الصلوات المكتملة', '١٣٠ / ١٥٠'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)),
              _statRow('📿', 'أيام الأذكار', '٢٥ / ٣٠ يوم'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)),
              _statRow('🔥', 'أطول ستريك', '١٢ يوم متواصل'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('"رحلتك الروحية هذا الشهر مميزة يا ${userName.split(' ').first} — استمر 🤍"',
              style: GoogleFonts.ibmPlexSansArabic(color: AppColors.goldLight, fontSize: 13, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
          ),
        ),
      ]),
    );
  }

  Widget _statRow(String icon, String label, String value) {
    return Row(children: [
      Text(icon, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 14))),
      Text(value, style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  Widget _generateButton(BuildContext context, AppAuthProvider authProvider) {
    return ElevatedButton.icon(
      onPressed: () => _generatePdf(context, authProvider),
      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
      label: Text('تنزيل التقرير بصيغة PDF', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold, 
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: AppColors.gold.withOpacity(0.4),
      ),
    );
  }

  Widget _pastReports(bool isDark) {
    final now = DateTime.now();
    final reports = [
      DateTime(now.year, now.month - 1, 1),
      DateTime(now.year, now.month - 2, 1),
      DateTime(now.year, now.month - 3, 1),
    ];
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : AppColors.paleGreen),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('سجل التقارير السابقة', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: greenColor)),
        const SizedBox(height: 16),
        ...reports.map((date) {
          final monthStr = DateFormat('MMMM yyyy', 'ar').format(date);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: isDark ? AppColors.darkGreen.withOpacity(0.2) : AppColors.paleGreen, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.description_rounded, color: greenColor, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تقرير شهر', style: GoogleFonts.ibmPlexSansArabic(fontSize: 11, color: AppColors.gray)),
                            Text(monthStr, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.gray, size: 14),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }
}
