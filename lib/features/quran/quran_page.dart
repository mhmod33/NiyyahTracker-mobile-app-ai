import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/app_colors.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

String _removeDiacritics(String text) {
  return text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
}

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});
  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5);
    final primaryColor = isDark ? AppColors.darkGreen : AppColors.darkGreen;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('المصحف الشريف', style: _f(fw: FontWeight.w800, sz: 18, c: Colors.white)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded, size: 24), 
              onPressed: () => _showSearch(context),
              style: IconButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelStyle: _f(fw: FontWeight.w700, sz: 14, c: Colors.white),
            unselectedLabelStyle: _f(fw: FontWeight.w500, sz: 14, c: Colors.white70),
            tabs: const [Tab(text: 'السور'), Tab(text: 'الأجزاء'), Tab(text: 'الأحزاب')],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildSurahList(isDark), _buildJuzList(isDark), _buildHizbList(isDark)],
        ),
      ),
    );
  }

  Widget _buildSurahList(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 114,
      itemBuilder: (ctx, i) {
        final n = i + 1;
        return _QuranIndexTile(
          index: n,
          title: quran.getSurahNameArabic(n),
          subtitle: '${quran.getVerseCount(n)} آية • ${quran.getPlaceOfRevelation(n) == "Makkah" ? "مكية" : "مدنية"}',
          isDark: isDark,
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: n))),
        );
      },
    );
  }

  Widget _buildJuzList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 30,
      itemBuilder: (ctx, i) {
        final juz = i + 1;
        return _QuranIndexTile(
          index: juz,
          title: 'الجزء $juz',
          subtitle: 'الجزء رقم $juz في المصحف الشريف',
          isDark: isDark,
          onTap: () {
            final startSurahs = {1:1, 2:2, 3:2, 4:3, 5:4, 6:4, 7:5, 8:6, 9:7, 10:8, 11:9, 12:11, 13:12, 14:15, 15:17, 16:18, 17:21, 18:23, 19:25, 20:27, 21:29, 22:33, 23:36, 24:39, 25:41, 26:46, 27:51, 28:58, 29:67, 30:78};
            Navigator.push(ctx, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: startSurahs[juz] ?? 1)));
          },
        );
      },
    );
  }

  Widget _buildHizbList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 60,
      itemBuilder: (ctx, i) {
        final hizb = i + 1;
        return _QuranIndexTile(
          index: hizb,
          title: 'الحزب $hizb',
          subtitle: 'الحزب رقم $hizb من القرآن الكريم',
          isDark: isDark,
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: 1))),
        );
      },
    );
  }

  void _showSearch(BuildContext context) {
    debugPrint('Opening search sheet...');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        debugPrint('Building search sheet...');
        return _QuranSearchSheet();
      },
    );
  }
}

class _QuranIndexTile extends StatelessWidget {
  final int index; final String title, subtitle; final bool isDark; final VoidCallback onTap;
  const _QuranIndexTile({required this.index, required this.title, required this.subtitle, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final primaryColor = AppColors.darkGreen;
    final accentColor = AppColors.gold;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44, 
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              '$index', 
              style: _f(sz: 14, fw: FontWeight.bold, c: primaryColor)
            ),
          ),
        ),
        title: Text(
          title, 
          style: GoogleFonts.amiri(
            fontSize: 20, 
            fontWeight: FontWeight.bold, 
            color: textColor
          )
        ),
        subtitle: Text(
          subtitle, 
          style: _f(sz: 12, c: subtitleColor)
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded, 
          size: 14, 
          color: isDark ? Colors.white60 : Colors.black38
        ),
      ),
    );
  }
}

class SurahReaderPage extends StatefulWidget {
  final int surahNumber;
  final int initialVerse;
  const SurahReaderPage({super.key, required this.surahNumber, this.initialVerse = 1});
  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    int startPage = quran.getPageNumber(widget.surahNumber, widget.initialVerse);
    _currentPage = startPage - 1;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() { _pageController.dispose(); super.dispose(); }

  
  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0D0D0D);
    final ayahColor = const Color(0xFFF5E6D3);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            // Top Bar - Minimal Margin
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top - 10, bottom: 1, left: 16, right: 16),
              color: Colors.black,
              child: _buildReaderHeader(_currentPage + 1),
            ),
            // Quran Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 604,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (ctx, index) {
                  return _MushafPage(pageNumber: index + 1, ayahColor: ayahColor, bg: bg);
                },
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              color: Colors.black,
              child: Text(
                '${_currentPage + 1}',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderHeader(int page) {
    final data = quran.getPageData(page).first;
    final s = data['surah'] as int;
    final j = quran.getJuzNumber(s, data['start']);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18), onPressed: () => Navigator.pop(context)),
        Text(quran.getSurahName(s), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text('Juz $j', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        const Icon(Icons.circle_outlined, size: 14, color: Colors.white70),
      ],
    );
  }
}

class _MushafPage extends StatelessWidget {
  final int pageNumber; final Color ayahColor, bg;
  const _MushafPage({required this.pageNumber, required this.ayahColor, required this.bg});

  void _showAyahOptions(BuildContext context, int surah, int start, int end) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('خيارات الآيات', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.copy_all, color: AppColors.gold),
                title: Text('نسخ الآيات', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyVerses(ctx, surah, start, end);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: AppColors.gold),
                title: Text('مشاركة الآيات', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareVerses(surah, start, end);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border, color: AppColors.gold),
                title: Text('إضافة مرجع', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _addBookmark(ctx, surah, start, end);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVerseActions(BuildContext context, int surah, int verse) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('آية رقم $verse', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.copy, color: AppColors.gold),
                title: Text('نسخ الآية', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyVerse(ctx, surah, verse);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: AppColors.gold),
                title: Text('مشاركة الآية', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareVerse(surah, verse);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: AppColors.gold),
                title: Text('مشاركة كصورة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareVerseAsImage(context, surah, verse);
                },
              ),
              ListTile(
                leading: const Icon(Icons.book, color: AppColors.gold),
                title: Text('تفسير الآية', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTafseer(context, surah, verse);
                },
              ),
              ListTile(
                leading: const Icon(Icons.play_arrow, color: AppColors.gold),
                title: Text('استماع للتلاوة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _playAudio(ctx, surah, verse);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyVerse(BuildContext context, int surah, int verse) {
    final verseText = quran.getVerse(surah, verse);
    Clipboard.setData(ClipboardData(text: verseText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ الآية', style: GoogleFonts.cairo()), backgroundColor: AppColors.darkGreen),
    );
  }

  void _copyVerses(BuildContext context, int surah, int start, int end) {
    String versesText = '';
    for (int i = start; i <= end; i++) {
      versesText += '﴿${i}﴾ ${quran.getVerse(surah, i)} ';
    }
    Clipboard.setData(ClipboardData(text: versesText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ الآيات', style: GoogleFonts.cairo()), backgroundColor: AppColors.darkGreen),
    );
  }

  void _shareVerse(int surah, int verse) {
    final verseText = quran.getVerse(surah, verse);
    final surahName = quran.getSurahNameArabic(surah);
    Share.share('﴿${verse}﴾ $verseText\n\n- سورة $surahName -');
  }

  void _shareVerses(int surah, int start, int end) {
    String versesText = '';
    for (int i = start; i <= end; i++) {
      versesText += '﴿${i}﴾ ${quran.getVerse(surah, i)}\n';
    }
    final surahName = quran.getSurahNameArabic(surah);
    Share.share('$versesText\n- سورة $surahName -');
  }

  void _addBookmark(BuildContext context, int surah, int start, int end) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إضافة المرجع', style: GoogleFonts.cairo()), backgroundColor: AppColors.darkGreen),
    );
  }

  void _playAudio(BuildContext context, int surah, int verse) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('سيتم تشغيل التلاوة قريباً', style: GoogleFonts.cairo()), backgroundColor: AppColors.gold),
    );
  }

  void _showTafseer(BuildContext context, int surah, int verse) {
    final verseText = quran.getVerse(surah, verse);
    final surahName = quran.getSurahNameArabic(surah);
    
    // Simple tafseer data (in a real app, this would come from a proper tafseer API/database)
    final tafseerData = _getSimpleTafseer(surah, verse);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'تفسير الآية',
                    style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$surahName - آية $verse',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      verseText,
                      style: const TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', color: Colors.white, fontSize: 18, height: 1.8),
                      textAlign: TextAlign.justify,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    tafseerData,
                    style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 16, height: 1.8),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSimpleTafseer(int surah, int verse) {
    // This is a very basic tafseer implementation
    // In a real app, you would use a proper tafseer source
    final Map<String, String> tafseerMap = {
      '1:1': 'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ: أبتدئ قراءة متعوذاً بالله، والرحمن الرحيم اسمان من أسماء الله تعالى.',
      '1:2': 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ: الثناء الكامل لله وحده، فهو سبحانه وتعالى المربي لجميع الخلائق.',
      '1:3': 'الرَّحْمَنِ الرَّحِيمِ: تكرار للتأكيد على رحمة الله الواسعة.',
      '1:4': 'مَالِكِ يَوْمِ الدِّينِ: الله هو المتصرف في يوم الجزاء والحساب.',
      '1:5': 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ: نخصك وحدك بالعبادة والاستعانة.',
      '1:6': 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ: دلنا وأرشدنا إلى الطريق المستقيم.',
      '1:7': 'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِمْ: طريق الذين أنعمت عليهم من النبيين والصديقين.',
    };
    
    final key = '$surah:$verse';
    return tafseerMap[key] ?? 'التفسير غير متوفر حالياً. هذه ميزة تجريبية وسيتم إضافة التفسير الكامل قريباً.';
  }

  Future<void> _shareVerseAsImage(BuildContext context, int surah, int verse) async {
    final verseText = quran.getVerse(surah, verse);
    final surahName = quran.getSurahNameArabic(surah);
    
    // Create a simple image representation
    final GlobalKey repaintBoundaryKey = GlobalKey();
    
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text('مشاركة كصورة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
          content: RepaintBoundary(
            key: repaintBoundaryKey,
            child: Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.darkGreen, AppColors.gold.withOpacity(0.3)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '﴿$verse﴾',
                    style: GoogleFonts.ibmPlexSansArabic(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    verseText,
                    style: const TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', color: Colors.white, fontSize: 20, height: 1.8),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$surahName - آية $verse',
                    style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70, fontSize: 14),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Niyyah Tracker',
                      style: GoogleFonts.ibmPlexSansArabic(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  // This is a simplified version - in a real app you'd use screenshot package
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('سيتم حفظ الصورة ومشاركتها قريباً', style: GoogleFonts.cairo()), backgroundColor: AppColors.gold),
                  );
                  Navigator.pop(ctx);
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ', style: GoogleFonts.cairo()), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text('مشاركة', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.gold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageData = quran.getPageData(pageNumber);
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: pageData.map((data) {
              final surah = data['surah'] as int;
              final start = data['start'] as int;
              final end = data['end'] as int;
              
              return Column(
                children: [
                  if (start == 1) _OrnateSurahHeader(surahIndex: surah),
                  // Professional Basmala - Only show if it's the START of a surah (except Fatiha and Tawbah)
                  if (start == 1 && surah != 1 && surah != 9) _OrnateBasmala(),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      // Show ayah options when tapped
                      _showAyahOptions(context, surah, start, end);
                    },
                    child: RichText(
                      textAlign: TextAlign.justify,
                      textDirection: TextDirection.rtl,
                      text: TextSpan(
                        children: List.generate(end - start + 1, (i) => start + i).expand((v) {
                          String verseText = quran.getVerse(surah, v, verseEndSymbol: false);
                          // Remove Basmala from first verse of any surah (except Fatiha and Tawbah)
                          if (v == 1 && surah != 1 && surah != 9) {
                            // Remove Basmala in all possible forms
                            verseText = verseText
                                .replaceFirst(RegExp(r'^بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ\s*'), '')
                                .replaceFirst(RegExp(r'^بسم الله الرحمن الرحيم\s*'), '')
                                .replaceFirst(RegExp(r'^بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\s*'), '')
                                .replaceFirst(RegExp(r'^بسم الله\s*[\u064B-\u065F\u0670\u06D6-\u06ED]*الرحمن[\u064B-\u065F\u0670\u06D6-\u06ED]*الرحيم\s*'), '')
                                .trim();
                          }

                          return [
                            TextSpan(
                              text: verseText,
                              style: TextStyle(
                                fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                fontSize: pageNumber <= 2 ? 26 : 20,
                                height: 1.8,
                                color: ayahColor,
                              ),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: GestureDetector(
                                onTap: () => _showVerseActions(context, surah, v),
                                child: _AyahSymbol(number: v),
                              ),
                            ),
                            const TextSpan(text: ' '),
                          ];
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _OrnateSurahHeader extends StatelessWidget {
  final int surahIndex;
  const _OrnateSurahHeader({required this.surahIndex});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surahInfo = '${quran.getVerseCount(surahIndex)} آية • ${quran.getPlaceOfRevelation(surahIndex) == "Makkah" ? "مكية" : "مدنية"}';
    final primaryColor = AppColors.darkGreen;
    final accentColor = AppColors.gold;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [
            const Color(0xFF1A1A1A).withOpacity(0.9),
            const Color(0xFF2A2A2A).withOpacity(0.9),
          ] : [
            primaryColor.withOpacity(0.08),
            accentColor.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          if (!isDark)
            BoxShadow(
              color: primaryColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          // Top decorative elements
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.2),
                      accentColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
                ),
                child: Icon(
                  Icons.brightness_7_outlined,
                  color: accentColor,
                  size: 20,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.2),
                      primaryColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.2),
                      accentColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
                ),
                child: Icon(
                  Icons.brightness_7_outlined,
                  color: accentColor,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Surah name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? accentColor.withOpacity(0.2) : primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              quran.getSurahNameArabic(surahIndex),
              style: TextStyle(
                fontFamily: 'KFGQPC Uthmanic Script Hafs',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? accentColor : primaryColor,
                height: 1.5,
                shadows: [
                  Shadow(
                    color: (isDark ? accentColor : primaryColor).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          // Surah info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : accentColor.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              surahInfo,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrnateBasmala extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [
            AppColors.gold.withOpacity(0.1),
            AppColors.gold.withOpacity(0.05),
          ] : [
            AppColors.darkGreen.withOpacity(0.1),
            AppColors.gold.withOpacity(0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.gold.withOpacity(0.3) : AppColors.darkGreen.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? AppColors.gold : AppColors.darkGreen).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.gold : AppColors.darkGreen).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.brightness_7_outlined,
              color: isDark ? AppColors.gold : AppColors.darkGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            quran.basmala,
            style: TextStyle(
              fontFamily: 'KFGQPC Uthmanic Script Hafs',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.gold : AppColors.darkGreen,
              height: 1.5,
              shadows: [
                Shadow(
                  color: (isDark ? AppColors.gold : AppColors.darkGreen).withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(width: 16),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.gold : AppColors.darkGreen).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.brightness_7_outlined,
              color: isDark ? AppColors.gold : AppColors.darkGreen,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _AyahSymbol extends StatelessWidget {
  final int number;
  const _AyahSymbol({required this.number});
  String _arabicNumber(int n) {
    const ar = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    return n.toString().split('').map((e) => ar[int.parse(e)]).join('');
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.brightness_7_outlined, size: 24, color: AppColors.gold),
          Text(
            _arabicNumber(number),
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _QuranSearchSheet extends StatefulWidget {
  @override
  State<_QuranSearchSheet> createState() => _QuranSearchSheetState();
}

class _QuranSearchSheetState extends State<_QuranSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];

  void _search(String q) {
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    
    final normalizedQ = _removeDiacritics(q.toLowerCase().trim());
    final List<Map<String, dynamic>> res = [];
    
    // Search through all 114 surahs but limit results
    for (int s = 1; s <= 114; s++) {
      try {
        final verseCount = quran.getVerseCount(s);
        for (int v = 1; v <= verseCount; v++) {
          try {
            final verse = quran.getVerse(s, v);
            final normalizedVerse = _removeDiacritics(verse.toLowerCase());
            
            // Check if the search term is in the verse
            if (normalizedVerse.contains(normalizedQ)) {
              res.add({'s': s, 'v': v});
              if (res.length >= 50) break; // Increased result limit
            }
          } catch (e) {
            continue; // Skip problematic verses
          }
        }
        if (res.length >= 50) break;
      } catch (e) {
        continue; // Skip problematic surahs
      }
    }
    
    // Sort results by relevance (shorter verses first for more precise matches)
    res.sort((a, b) {
      final verseA = quran.getVerse(a['s'], a['v']);
      final verseB = quran.getVerse(b['s'], b['v']);
      return verseA.length.compareTo(verseB.length);
    });
    
    setState(() => _results = res.take(30).toList()); // Take top 30 results
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building search sheet UI...');
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _ctrl,
            onChanged: (value) {
              debugPrint('Search input changed: $value');
              _search(value);
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث عن آية...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: AppColors.gold),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final r = _results[i];
                return ListTile(
                  title: Text(quran.getVerse(r['s'], r['v']), style: const TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', color: Colors.white, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${quran.getSurahNameArabic(r['s'])} - آية ${r['v']}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: r['s'], initialVerse: r['v'])));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
