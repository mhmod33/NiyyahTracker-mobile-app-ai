import 'dart:io';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('المصحف الشريف', style: _f(fw: FontWeight.w800, sz: 18, c: Colors.white)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.search_rounded, size: 24), onPressed: () => _showSearch(context)),
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
            // Finding the first surah of each Juz (simple approximation for common juz)
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
    // Logic for search sheet
  }
}

class _QuranIndexTile extends StatelessWidget {
  final int index; final String title, subtitle; final bool isDark; final VoidCallback onTap;
  const _QuranIndexTile({required this.index, required this.title, required this.subtitle, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.paleGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text('$index', style: _f(sz: 14, fw: FontWeight.bold, c: isDark ? AppColors.gold : AppColors.darkGreen))),
        ),
        title: Text(title, style: GoogleFonts.amiri(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text(subtitle, style: _f(sz: 12, c: AppColors.gray)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.gray),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Surah Reader — EXACT MUSHAF LAYOUT
// ─────────────────────────────────────────
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
  final ScreenshotController _screenshotController = ScreenshotController();

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
    final isDark = true; // Forcing dark mode as per the user's reference image
    final bg = const Color(0xFF0D0D0D);
    final ayahColor = const Color(0xFFF5E6D3);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            // Top Bar
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 10, left: 16, right: 16),
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
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: Colors.black,
              child: Center(
                child: Text(
                  '${_currentPage + 1}',
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold),
                ),
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
        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70), onPressed: () => Navigator.pop(context)),
        Text(quran.getSurahName(s), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        Text('Juz $j', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        const Icon(Icons.circle_outlined, size: 16, color: Colors.white70),
      ],
    );
  }
}

class _MushafPage extends StatelessWidget {
  final int pageNumber; final Color ayahColor, bg;
  const _MushafPage({required this.pageNumber, required this.ayahColor, required this.bg});

  @override
  Widget build(BuildContext context) {
    final pageData = quran.getPageData(pageNumber);
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          // Adjust font size based on page complexity to ensure no scrolling
          double fontSize = pageNumber <= 2 ? 28 : 22; 
          if (pageData.length > 2) fontSize = 20;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(), // No vertical scroll
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: pageData.map((data) {
                        final surah = data['surah'] as int;
                        final start = data['start'] as int;
                        final end = data['end'] as int;
                        
                        return Column(
                          children: [
                            if (start == 1) _OrnateSurahHeader(surahIndex: surah),
                            if (start == 1 && surah != 1 && surah != 9) _OrnateBasmala(),
                            const SizedBox(height: 10),
                            RichText(
                              textAlign: TextAlign.justify,
                              textDirection: TextDirection.rtl,
                              text: TextSpan(
                                children: List.generate(end - start + 1, (i) => start + i).expand((v) {
                                  return [
                                    TextSpan(
                                      text: quran.getVerse(surah, v, verseEndSymbol: false),
                                      style: TextStyle(
                                        fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                        fontSize: fontSize,
                                        height: 1.8,
                                        color: ayahColor,
                                      ),
                                    ),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: _AyahSymbol(number: v),
                                    ),
                                    const TextSpan(text: ' '),
                                  ];
                                }).toList(),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}

class _OrnateSurahHeader extends StatelessWidget {
  final int surahIndex;
  const _OrnateSurahHeader({required this.surahIndex});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 15),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        image: const DecorationImage(image: AssetImage('assets/surah_frame.png'), fit: BoxFit.fill, opacity: 0.8),
        border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          quran.getSurahNameArabic(surahIndex),
          style: const TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.gold),
        ),
      ),
    );
  }
}

class _OrnateBasmala extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          quran.basmala,
          style: const TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', fontSize: 22, color: AppColors.gold),
        ),
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
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.circle_outlined, size: 28, color: AppColors.gold),
        Text(
          _arabicNumber(number),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'KFGQPC Uthmanic Script Hafs'),
        ),
      ],
    );
  }
}
