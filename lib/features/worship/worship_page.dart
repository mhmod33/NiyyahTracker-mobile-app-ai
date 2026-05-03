import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../../core/app_models.dart';
import '../../models/worship_model.dart' as db_model;
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/daily_summary_service.dart';

class WorshipPage extends StatefulWidget {
  const WorshipPage({super.key});
  @override
  State<WorshipPage> createState() => _WorshipPageState();
}

class _WorshipPageState extends State<WorshipPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final DailySummaryService _dailySummaryService = DailySummaryService();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasSavedToday = false;
  bool _isEditing = false;
  String _worshipDocId = const Uuid().v4();
  
  final Map<WorshipType, bool> _checked = {
    for (var t in WorshipType.values) t: false,
  };
  int _prayerCount = 0;
  int _quranPages = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayWorship();
  }

  Future<void> _loadTodayWorship() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final worships = await _firebaseService.getDailyWorshipByDate(userId, DateTime.now());
      if (worships.isNotEmpty) {
        final todayWorship = worships.first;
        _worshipDocId = todayWorship.id;
        _prayerCount = todayWorship.prayerCount;
        _quranPages = todayWorship.quranPages;
        
        // Map back the database types to UI types
        for (var t in WorshipType.values) {
          if (todayWorship.worships.containsKey(t.name)) {
            _checked[t] = todayWorship.worships[t.name] ?? false;
          }
        }
        _hasSavedToday = true;
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading worship: $e');
    }
  }

  Future<void> _autoSaveIfNeeded() async {
    if (!_hasSavedToday) return;
    
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) return;

    final worshipsMap = <String, bool>{};
    _checked.forEach((key, value) {
      worshipsMap[key.name] = value;
    });

    final worshipData = db_model.DailyWorship(
      id: _worshipDocId,
      date: DateTime.now(),
      worships: worshipsMap,
      prayerCount: _prayerCount,
      quranPages: _quranPages,
    );

    try {
      await _firebaseService.saveDailyWorship(userId, worshipData);
      debugPrint('Auto-saved worship data successfully');
    } catch (e) {
      debugPrint('Auto-save error: $e');
    }
  }

  Future<void> _saveWorship() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى تسجيل الدخول أولاً', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final worshipsMap = <String, bool>{};
    _checked.forEach((key, value) {
      worshipsMap[key.name] = value;
    });

    final worshipData = db_model.DailyWorship(
      id: _worshipDocId,
      date: DateTime.now(),
      worships: worshipsMap,
      prayerCount: _prayerCount,
      quranPages: _quranPages,
    );

    try {
      await _firebaseService.saveDailyWorship(userId, worshipData);
      setState(() { 
        _isSaving = false; 
        _hasSavedToday = true; 
        _isEditing = false; 
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم حفظ عبادات اليوم بفضل الله 🤍', style: GoogleFonts.cairo(color: Colors.white)),
          backgroundColor: AppColors.darkGreen,
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      debugPrint('Error saving worship: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('حدث خطأ أثناء حفظ العبادات', style: GoogleFonts.cairo()),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

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
          title: Text('عبادات اليوم', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          actions: [
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${today.day}/${today.month}/${today.year}', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 13)),
            )),
          ],
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Column(
              children: [
                Expanded(
                  child: (_hasSavedToday && !_isEditing)
                      ? _buildSummaryCard(isDark, cardBg, textColor, subColor, borderColor)
                      : ListView(
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
                if (_hasSavedToday)
                  _buildQuickSummary(isDark, cardBg, textColor, subColor, borderColor),
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
      child: Text(title, style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _prayerCard(bool isDark, Color cardBg, Color textColor, Color subColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('كم صلاة صليت في وقتها اليوم؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600, color: isDark ? AppColors.lightGreen : AppColors.darkGreen)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(6, (i) {
          final selected = i <= _prayerCount;
          final labels = ['0', 'الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
          return GestureDetector(
            onTap: () {
              setState(() => _prayerCount = i);
              _autoSaveIfNeeded();
            },
            child: Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200), width: 38, height: 38,
                decoration: BoxDecoration(
                  color: selected ? AppColors.darkGreen : (isDark ? Colors.white10 : Colors.grey[100]),
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? AppColors.darkGreen : (isDark ? Colors.white24 : Colors.grey[300]!)),
                ),
                child: Center(child: Text('$i', style: GoogleFonts.ibmPlexSansArabic(color: selected ? Colors.white : (isDark ? Colors.white60 : Colors.grey[600]), fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: GoogleFonts.ibmPlexSansArabic(fontSize: 9, color: subColor)),
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
        Text('كم صفحة قرأت اليوم؟', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600, color: isDark ? AppColors.lightGreen : AppColors.darkGreen)),
        const SizedBox(height: 12),
        Row(children: [
          IconButton(onPressed: () {
            setState(() { if (_quranPages > 0) _quranPages--; });
            _autoSaveIfNeeded();
          }, icon: Icon(Icons.remove_circle_outline, color: isDark ? AppColors.lightGreen : AppColors.midGreen)),
          Expanded(child: Text('$_quranPages صفحة', textAlign: TextAlign.center, style: GoogleFonts.ibmPlexSansArabic(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? AppColors.lightGreen : AppColors.darkGreen))),
          IconButton(onPressed: () {
            setState(() => _quranPages++);
            _autoSaveIfNeeded();
          }, icon: Icon(Icons.add_circle_outline, color: isDark ? AppColors.lightGreen : AppColors.midGreen)),
        ]),
        Wrap(spacing: 8, children: [5, 10, 15, 20].map((p) => ActionChip(
          label: Text('$p صفحات', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: isDark ? Colors.white : null)),
          onPressed: () {
            setState(() => _quranPages = p);
            _autoSaveIfNeeded();
          },
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
        title: Text(type.label, style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w600, color: isDark ? AppColors.lightGreen : AppColors.darkGreen)),
        trailing: GestureDetector(
          onTap: () {
            setState(() => _checked[type] = !done);
            _autoSaveIfNeeded();
          },
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
      onPressed: _isSaving ? null : _saveWorship,
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      icon: _isSaving 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.save, color: Colors.white),
      label: Text('حفظ بطاقة اليوم', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    ));
  }

  Widget _buildSummaryCard(bool isDark, Color cardBg, Color textColor, Color subColor, Color borderColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.darkGreen.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.paleGreen.withOpacity(isDark ? 0.1 : 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: AppColors.darkGreen, size: 64),
              ),
              const SizedBox(height: 16),
              Text('تقبل الله طاعتك!', style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? AppColors.lightGreen : AppColors.darkGreen)),
              const SizedBox(height: 8),
              Text('لقد أتممت تسجيل عبادات اليوم بنجاح 🤍', textAlign: TextAlign.center, style: GoogleFonts.cairo(fontSize: 14, color: subColor)),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _summaryRow('الصلوات', '$_prayerCount', Icons.mosque_rounded, isDark),
              _summaryRow('صفحات القرآن', '$_quranPages', Icons.menu_book_rounded, isDark),
              ...WorshipType.values.where((t) => t != WorshipType.prayer && t != WorshipType.quran && _checked[t] == true)
                  .map((t) => _summaryRow(t.label, 'تم', Icons.check_circle_rounded, isDark)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  label: Text('تعديل', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkGreen,
                    side: const BorderSide(color: AppColors.darkGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSummary(bool isDark, Color cardBg, Color textColor, Color subColor, Color borderColor) {
    final completedWorships = _checked.entries.where((entry) => entry.value == true).length;
    final totalWorships = completedWorships + _prayerCount;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1A4D2E), const Color(0xFF0D2818)]
              : [AppColors.paleGreen, AppColors.lightGreen.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.summarize_rounded, color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ملخص عباداتك اليوم', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.darkGreen)),
                Text('$_prayerCount صلوات • $_quranPages صفحة قرآن • $totalWorships إجمالي', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: isDark ? Colors.white70 : AppColors.gray)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$totalWorships', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String title, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, color: isDark ? Colors.white : AppColors.textPrimary))),
          Text(value, style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkGreen)),
        ],
      ),
    );
  }
}
