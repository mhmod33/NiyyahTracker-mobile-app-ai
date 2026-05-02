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

// ─────────────────────────────────────────
// Quran Index Page (Surah list + Juz + Hizb)
// ─────────────────────────────────────────
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          foregroundColor: Colors.white,
          title: Text('المصحف الشريف', style: _f(fw: FontWeight.w800, sz: 18, c: Colors.white)),
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.search_rounded, size: 22), onPressed: () => _showSearch(context)),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelStyle: _f(fw: FontWeight.w700, sz: 13, c: Colors.white),
            unselectedLabelStyle: _f(fw: FontWeight.w500, sz: 13, c: Colors.white70),
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
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 114,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      itemBuilder: (ctx, i) {
        final n = i + 1;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: isDark ? Colors.white10 : AppColors.paleGreen, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text('$n', style: _f(fw: FontWeight.w800, sz: 13, c: isDark ? Colors.white70 : AppColors.darkGreen))),
          ),
          title: Text(quran.getSurahNameArabic(n), style: GoogleFonts.amiri(fontSize: 20, fontWeight: FontWeight.bold)),
          subtitle: Text('${quran.getVerseCount(n)} آية • ${quran.getPlaceOfRevelation(n) == "Makkah" ? "مكية" : "مدنية"}',
            style: _f(sz: 11, c: AppColors.gray)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.gray),
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: n))),
        );
      },
    );
  }

  Widget _buildJuzList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 30,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      itemBuilder: (ctx, i) {
        final juz = i + 1;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: isDark ? Colors.white10 : const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text('$juz', style: _f(fw: FontWeight.w800, sz: 13, c: isDark ? Colors.white70 : const Color(0xFF2196F3)))),
          ),
          title: Text('الجزء $juz', style: _f(sz: 17, fw: FontWeight.w700)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.gray),
          onTap: () {
            for (int s = 1; s <= 114; s++) {
              for (int v = 1; v <= quran.getVerseCount(s); v++) {
                if (quran.getJuzNumber(s, v) == juz) {
                  Navigator.push(ctx, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: s, initialVerse: v)));
                  return;
                }
              }
            }
          },
        );
      },
    );
  }

  Widget _buildHizbList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 60,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 72, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
      itemBuilder: (ctx, i) {
        final hizb = i + 1;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: isDark ? Colors.white10 : const Color(0xFFFDF3D7), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text('$hizb', style: _f(fw: FontWeight.w800, sz: 13, c: isDark ? Colors.white70 : AppColors.gold))),
          ),
          title: Text('الحزب $hizb', style: _f(sz: 17, fw: FontWeight.w700)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.gray),
          onTap: () {},
        );
      },
    );
  }

  void _showSearch(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        final q = ctrl.text;
        final results = <Map<String, dynamic>>[];
        if (q.length >= 2) {
          for (int s = 1; s <= 114; s++) {
            for (int v = 1; v <= quran.getVerseCount(s); v++) {
              if (quran.getVerse(s, v).contains(q)) { results.add({'s': s, 'v': v}); if (results.length >= 30) break; }
            }
            if (results.length >= 30) break;
          }
        }
        return Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
          title: Text('بحث في القرآن', style: _f(fw: FontWeight.w800)),
          content: SizedBox(width: double.maxFinite, height: 400, child: Column(children: [
            TextField(controller: ctrl, decoration: InputDecoration(hintText: 'ابحث عن آية...', prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              onChanged: (_) => ss(() {})),
            const SizedBox(height: 12),
            Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (_, i) {
              final r = results[i];
              return ListTile(
                title: Text('${quran.getSurahNameArabic(r['s'])} : ${r['v']}', style: _f(fw: FontWeight.w700, sz: 13)),
                subtitle: Text(quran.getVerse(r['s'], r['v']), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.amiri(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SurahReaderPage(surahNumber: r['s'], initialVerse: r['v']))); },
              );
            })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إغلاق', style: _f(fw: FontWeight.w700)))],
        ));
      }),
    );
  }
}

// ─────────────────────────────────────────
// Surah Reader — EXACT MUSHAF LAYOUT (604 Pages)
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
  int? _selectedVerse;
  final Set<int> _bookmarks = {};
  final ScreenshotController _screenshotController = ScreenshotController();

  Timer? _readingTimer;
  final Set<int> _readPages = {};

  String _arabicNumber(int number) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String numStr = number.toString();
    for (int i = 0; i < english.length; i++) {
      numStr = numStr.replaceAll(english[i], arabic[i]);
    }
    return numStr;
  }

  @override
  void initState() {
    super.initState();
    // Find which page this verse is on
    int startPage = quran.getPageNumber(widget.surahNumber, widget.initialVerse);
    // PageView is 0-indexed, but quran pages are 1-604
    _currentPage = startPage - 1;
    _pageController = PageController(initialPage: _currentPage);
    _startReadingTimer(_currentPage);
  }

  void _startReadingTimer(int pageIndex) {
    _readingTimer?.cancel();
    if (_readPages.contains(pageIndex)) return;

    _readingTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && !_readPages.contains(pageIndex)) {
        setState(() => _readPages.add(pageIndex));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('تقبل الله.. تم احتساب قراءة هذه الصفحة 🤍', style: _f(c: Colors.white))),
              ],
            ),
            backgroundColor: AppColors.darkGreen,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() { 
    _pageController.dispose(); 
    _readingTimer?.cancel();
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFFCFBF4);
    final textColor = isDark ? const Color(0xFFEAEAEA) : const Color(0xFF1A1A1A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: PageView.builder(
            controller: _pageController,
            itemCount: 604, // Exact number of pages in the Mushaf
            onPageChanged: (i) {
              setState(() => _currentPage = i);
              _startReadingTimer(i);
            },
            itemBuilder: (ctx, index) {
              final pageNumber = index + 1;
              final pageData = quran.getPageData(pageNumber);
              
              // Get Surah, Juz, and Hizb names for the header based on the first verse of the page
              final firstSurah = pageData.first['surah'] as int;
              final firstVerse = pageData.first['start'] as int;
              final surahName = quran.getSurahNameArabic(firstSurah);
              final surahNameEng = quran.getSurahName(firstSurah);
              final juz = quran.getJuzNumber(firstSurah, firstVerse);
              final hizb = ((juz - 1) * 2) + 1; // Calculate hizb from juz (approximate)

              return Column(
                children: [
                  // Header matching the image
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(surahNameEng, style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                        Row(
                          children: [
                            Text('Juz $juz', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                            const SizedBox(width: 8),
                            const Icon(Icons.circle_outlined, size: 8, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('Hizb $hizb', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Mushaf Page Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...pageData.map((data) {
                            final surah = data['surah'] as int;
                            final startVerse = data['start'] as int;
                            final endVerse = data['end'] as int;
                            
                            final isNewSurah = startVerse == 1;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Surah Banner (if start of a new surah on this page)
                                if (isNewSurah)
                                  Container(
                                    margin: const EdgeInsets.symmetric(vertical: 16),
                                    width: double.infinity,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : AppColors.gold.withOpacity(0.1),
                                      border: Border.all(color: isDark ? Colors.white24 : AppColors.gold, width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'سورة ${quran.getSurahNameArabic(surah)}',
                                        style: TextStyle(
                                          fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : AppColors.darkGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                // Basmala
                                if (isNewSurah && surah != 1 && surah != 9)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(
                                      quran.basmala,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                        fontSize: 26,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  
                                // Verses
                                SelectableText.rich(
                                  textAlign: TextAlign.justify,
                                  textDirection: TextDirection.rtl,
                                  TextSpan(
                                    children: List.generate(endVerse - startVerse + 1, (i) => startVerse + i).expand((v) {
                                      final text = quran.getVerse(surah, v, verseEndSymbol: false); // Exclude default symbol
                                      final isSelected = _selectedVerse == v;
                                      final isBookmarked = _bookmarks.contains(v);
                                      
                                      return [
                                        TextSpan(
                                          text: text,
                                          style: TextStyle(
                                            fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                            fontSize: 26, // Large size to fill width
                                            height: 1.8, // Tighter line height like real mushaf
                                            color: isBookmarked ? Colors.red : (isSelected ? AppColors.gold : textColor),
                                            backgroundColor: isSelected ? (isDark ? Colors.white10 : AppColors.darkGreen.withOpacity(0.05)) : Colors.transparent,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              setState(() => _selectedVerse = isSelected ? null : v);
                                              if (!isSelected) _showVerseOptions(context, surah, v, text);
                                            },
                                        ),
                                        // Ornate Ayah Circle
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() => _selectedVerse = isSelected ? null : v);
                                              if (!isSelected) _showVerseOptions(context, surah, v, text);
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 4),
                                              width: 38,
                                              height: 38,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  // Ornate Symbol ۝
                                                  Text(
                                                    '\u06DD',
                                                    style: TextStyle(
                                                      fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                                      fontSize: 34,
                                                      color: isBookmarked ? Colors.red : (isDark ? Colors.white70 : AppColors.darkGreen),
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                  // Arabic Numeral Inside
                                                  Text(
                                                    _arabicNumber(v),
                                                    style: TextStyle(
                                                      fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: isBookmarked ? Colors.red : (isDark ? Colors.white : AppColors.darkGreen),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const TextSpan(text: ' '), // Space between verses
                                      ];
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  // Footer matching the image (just page number)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_rounded, size: 16, color: _currentPage < 603 ? (isDark ? Colors.white54 : Colors.black54) : Colors.transparent),
                          onPressed: _currentPage < 603 ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease) : null,
                        ),
                        Text(
                          '$pageNumber',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                        ),
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _currentPage > 0 ? (isDark ? Colors.white54 : Colors.black54) : Colors.transparent),
                          onPressed: _currentPage > 0 ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease) : null,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showVerseOptions(BuildContext context, int surahNumber, int verse, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surahName = quran.getSurahNameArabic(surahNumber);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: isDark ? Colors.white10 : AppColors.paleGreen, borderRadius: BorderRadius.circular(10)),
                  child: Text('$surahNumber:$verse', style: _f(fw: FontWeight.w800, sz: 14, c: AppColors.darkGreen)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('$surahName - الآية $verse', style: _f(fw: FontWeight.w700, sz: 15))),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            const Divider(height: 24),
            _OptTile(icon: Icons.copy_rounded, label: 'نسخ الآية', onTap: () {
              Clipboard.setData(ClipboardData(text: '$text\n\n[$surahName: $verse]'));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم النسخ', style: _f()), duration: const Duration(seconds: 1)));
            }),
            _OptTile(icon: Icons.text_snippet_rounded, label: 'مشاركة كنص', onTap: () {
              Navigator.pop(ctx);
              Share.share('$text\n\n﴿ $surahName: $verse ﴾');
            }),
            _OptTile(icon: Icons.image_rounded, label: 'مشاركة كصورة', onTap: () {
              Navigator.pop(ctx);
              _shareAsImage(surahName, verse, text, isDark);
            }),
            _OptTile(
              icon: _bookmarks.contains(verse) ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              label: _bookmarks.contains(verse) ? 'إزالة العلامة' : 'إضافة علامة',
              onTap: () { setState(() { _bookmarks.contains(verse) ? _bookmarks.remove(verse) : _bookmarks.add(verse); }); Navigator.pop(ctx); },
            ),
            _OptTile(icon: Icons.menu_book_rounded, label: 'تفسير', onTap: () {
              Navigator.pop(ctx);
              _showTafsir(context, surahNumber, verse, text);
            }),
          ]),
        ),
      ),
    );
  }

  Future<void> _shareAsImage(String surahName, int verse, String text, bool isDark) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );

    try {
      final shareWidget = Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF143023) : const Color(0xFFFDFCF3),
            border: Border.all(color: AppColors.gold, width: 4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$text ﴿${_arabicNumber(verse)}﴾',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'KFGQPC Uthmanic Script Hafs',
                  fontSize: 34,
                  height: 2.2,
                  color: isDark ? const Color(0xFFE8E0D0) : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mosque_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تطبيق النية', style: _f(sz: 18, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
                          Text('NiyyahTracker', style: _f(sz: 12, c: AppColors.gray)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      final imageBytes = await _screenshotController.captureFromWidget(
        shareWidget,
        delay: const Duration(milliseconds: 200),
      );

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/ayah_$verse.png').create();
      await imagePath.writeAsBytes(imageBytes);

      if (mounted) Navigator.pop(context);
      await Share.shareXFiles([XFile(imagePath.path)], text: '﴿ $surahName: $verse ﴾ عبر تطبيق النية');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error sharing image: $e');
    }
  }

  void _showTafsir(BuildContext context, int surahNumber, int verse, String text) {
    final surahName = quran.getSurahNameArabic(surahNumber);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(context: context, builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('تفسير - $surahName: $verse', style: _f(fw: FontWeight.w800, sz: 16)),
        content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : AppColors.paleGreen, borderRadius: BorderRadius.circular(12)),
            child: Text(text, style: TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', fontSize: 20, height: 1.8), textAlign: TextAlign.justify),
          ),
          const SizedBox(height: 16),
          Text('التفسير الميسر', style: _f(fw: FontWeight.w800, sz: 15, c: AppColors.darkGreen)),
          const SizedBox(height: 8),
          Text('يمكنك الاطلاع على التفسير الكامل من مصادر التفسير المعتمدة.', style: _f(sz: 14, h: 1.7)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إغلاق', style: _f(fw: FontWeight.w700)))],
      ),
    ));
  }

  void _searchInSurah(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('بحث في السورة', style: _f(fw: FontWeight.w800)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن آية...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Text(
                    'سيتم عرض نتائج البحث هنا',
                    style: _f(c: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إغلاق', style: _f(fw: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptTile extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _OptTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.darkGreen, size: 22),
      title: Text(label, style: _f(fw: FontWeight.w600, sz: 15)),
      onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
