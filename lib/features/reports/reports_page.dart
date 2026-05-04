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
import '../../core/app_models.dart';
import '../../core/directional_icon.dart';
import '../../models/worship_model.dart' hide WorshipType;
import '../../models/monthly_goal_model.dart';
import '../../models/challenge_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Stats for the selected month
  int _totalQuranPages = 0;
  int _totalPrayers = 0;
  int _remembranceDays = 0;
  int _maxStreak = 0;
  
  // Additional dynamic stats
  List<MonthlyGoal> _monthlyGoals = [];
  List<Challenge> _challenges = [];
  int _completedGoals = 0;
  int _activeChallenges = 0;
  double _goalsCompletionRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMonthStats();
  }

  Future<void> _loadMonthStats() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Load all data in parallel
      final futures = await Future.wait([
        _firebaseService.getMonthlyWorships(userId, _selectedDate.year, _selectedDate.month),
        _firebaseService.getAllMonthlyGoals(userId),
        _firebaseService.getChallenges(userId),
      ]);
      
      final worships = futures[0] as List<DailyWorship>;
      final allGoals = futures[1] as List<MonthlyGoal>;
      final challenges = futures[2] as List<Challenge>;
      
      // Filter goals for the selected month
      final goals = allGoals.where((goal) {
        return goal.startDate.year == _selectedDate.year && goal.startDate.month == _selectedDate.month;
      }).toList();
      
      int quran = 0;
      int prayers = 0;
      int remembrance = 0;
      int currentStreak = 0;
      int maxStreak = 0;
      
      // Sort worships by date
      worships.sort((a, b) => a.date.compareTo(b.date));
      
      DateTime? lastDate;

      for (var w in worships) {
        quran += w.quranPages;
        prayers += w.prayerCount;
        
        if (w.worships[WorshipType.dhikr.name] == true) {
          remembrance++;
        }

        // Streak logic: check if w has at least one prayer or quran page
        bool activeDay = w.prayerCount > 0 || w.quranPages > 0 || w.worships.values.any((val) => val);
        if (activeDay) {
          if (lastDate == null || w.date.difference(lastDate).inDays == 1) {
            currentStreak++;
          } else if (w.date.difference(lastDate).inDays > 1) {
            currentStreak = 1;
          }
          if (currentStreak > maxStreak) maxStreak = currentStreak;
          lastDate = w.date;
        }
      }

      setState(() {
        _totalQuranPages = quran;
        _totalPrayers = prayers;
        _remembranceDays = remembrance;
        _maxStreak = maxStreak;
        _monthlyGoals = goals;
        _challenges = challenges;
        
        // Calculate additional stats
        _completedGoals = goals.where((g) => g.isCompleted).length;
        _activeChallenges = challenges.where((c) => c.current > 0).length;
        _goalsCompletionRate = goals.isNotEmpty ? (_completedGoals / goals.length) * 100 : 0.0;
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

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
    if (picked != null && picked.month != _selectedDate.month) {
      setState(() {
        _selectedDate = picked;
      });
      _loadMonthStats();
    }
  }

  Future<void> _generatePdf(BuildContext context, AppAuthProvider authProvider) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();

    final monthStr = DateFormat('MMMM yyyy', 'en').format(_selectedDate);
    final userName = authProvider.displayName ?? 'User';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: font,
          italic: font,
          boldItalic: font,
        ),
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 20),
                pw.Text('Niyyah', style: pw.TextStyle(fontSize: 40, color: PdfColors.green900)),
                pw.SizedBox(height: 10),
                pw.Text('Monthly Worship Report', style: pw.TextStyle(fontSize: 24, color: PdfColors.green700)),
                pw.Divider(color: PdfColors.green300, thickness: 2),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('User Name: $userName', style: const pw.TextStyle(fontSize: 18)),
                    pw.Text('For Month: $monthStr', style: const pw.TextStyle(fontSize: 18)),
                  ],
                ),
                pw.SizedBox(height: 40),
                
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
                      _pdfStatRowEnglish('Quran Pages:', '$_totalQuranPages pages', font),
                      pw.SizedBox(height: 10),
                      _pdfStatRowEnglish('Completed Prayers:', '$_totalPrayers prayers', font),
                      pw.SizedBox(height: 10),
                      _pdfStatRowEnglish('Dhikr Days:', '$_remembranceDays days', font),
                      pw.SizedBox(height: 10),
                      _pdfStatRowEnglish('Longest Streak:', '$_maxStreak days', font),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blue300, width: 2),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                    color: PdfColors.blue50,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Goals & Challenges', style: pw.TextStyle(fontSize: 20, color: PdfColors.blue800, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 15),
                      _pdfStatRowEnglish('Total Monthly Goals:', '${_monthlyGoals.length} goals', font),
                      pw.SizedBox(height: 10),
                      _pdfStatRowEnglish('Completed Goals:', '$_completedGoals goals', font),
                      pw.SizedBox(height: 10),
                      _pdfStatRowEnglish('Goals Completion Rate:', '${_goalsCompletionRate.toStringAsFixed(1)}%', font),
                      pw.SizedBox(height: 10),
                      _pdfStatRowEnglish('Active Challenges:', '$_activeChallenges challenges', font),
                    ],
                  ),
                ),

                pw.Spacer(),
                pw.Text(
                  '"Actions are judged by intentions"',
                  style: const pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return pdf.save();
        },
        name: 'Niyyah_Report_${_selectedDate.month}_${_selectedDate.year}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }

  pw.Widget _pdfStatRowEnglish(String label, String value, pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 18, font: font)),
        pw.Text(value, style: pw.TextStyle(fontSize: 18, color: PdfColors.green800, font: font)),
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
            
            _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.gold)))
                : _previewCard(context, isDark, monthStr, authProvider.displayName),
            const SizedBox(height: 24),
            
            _generateButton(context, authProvider),
            const SizedBox(height: 24),
            
            _analyticsInsights(isDark),
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
              _statRow('📖', 'صفحات القرآن', '$_totalQuranPages صفحة'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)),
              _statRow('🕌', 'الصلوات المكتملة', '$_totalPrayers صلاة'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)),
              _statRow('📿', 'أيام الأذكار', '$_remembranceDays يوم'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)),
              _statRow('🔥', 'أطول ستريك', '$_maxStreak يوم متواصل'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)),
              _statRow('🎯', 'الأهداف المكتملة', '$_completedGoals/${_monthlyGoals.length}'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12, height: 1)),
              _statRow('⚡', 'التحديات النشطة', '$_activeChallenges تحدي'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('"رحلتك الروحية هذا الشهر مميزة يا ${userName?.split(' ').first} — استمر 🤍"',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _generatePdf(context, authProvider),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text(
              'إنشاء تقرير PDF',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.lightGreen : AppColors.darkGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              shadowColor: isDark ? Colors.green.withOpacity(0.3) : Colors.green.withOpacity(0.2),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _testSimplePdf(context),
          icon: const Icon(Icons.bug_report, color: Colors.white),
          label: const Text(
            'Test PDF',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 6,
          ),
        ),
      ],
    );
  }

  Future<void> _testSimplePdf(BuildContext context) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Test PDF', style: const pw.TextStyle(fontSize: 40)),
                pw.SizedBox(height: 20),
                pw.Text('This is a test PDF to verify basic functionality'),
                pw.SizedBox(height: 20),
                pw.Text('Arabic Test: مرحبا بالعالم'),
                pw.SizedBox(height: 20),
                pw.Text('Date: ${DateTime.now()}'),
              ],
            ),
          );
        },
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Test_PDF.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error with test PDF: $e')),
      );
    }
  }

  Widget _analyticsInsights(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final greenColor = isDark ? AppColors.lightGreen : AppColors.darkGreen;
    
    // Calculate insights
    final List<String> insights = [];
    
    if (_totalQuranPages > 100) {
      insights.add('🌟 أداء ممتاز في القرآن هذا الشهر!');
    }
    if (_goalsCompletionRate > 75) {
      insights.add('🎯 نسبة إنجاز أهدافك رائعة!');
    }
    if (_maxStreak > 7) {
      insights.add('🔥 استمرارية مميزة في العبادات!');
    }
    if (_activeChallenges > 2) {
      insights.add('⚡ نشاط ملهم في التحديات!');
    }
    if (_totalPrayers > 100) {
      insights.add('🕌 مواظبة على الصلوات!');
    }
    
    if (insights.isEmpty) {
      insights.add('🌱 استمر في التقدم، كل بداية لها قوة!');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : AppColors.paleGreen),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: greenColor, size: 24),
              const SizedBox(width: 12),
              Text('رؤى تحليلية', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold, fontSize: 16, color: greenColor)),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : AppColors.paleGreen.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      insight,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14, 
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
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
                  _loadMonthStats();
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
                      DirectionalIcon(isBack: false, size: 14, color: AppColors.gray),
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
