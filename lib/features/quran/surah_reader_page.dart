import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/app_colors.dart';

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(_currentPage + 1),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 604,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (ctx, index) => _MushafPageWidget(pageNumber: index + 1),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int page) {
    final data = quran.getPageData(page).first;
    final s = data['surah'] as int;
    final j = quran.getJuzNumber(s, data['start']);
    final h = ((j - 1) * 2 + 1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
          ),
          Text(quran.getSurahNameArabic(s), style: GoogleFonts.amiri(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text('Juz $j', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          Text('Hizb $h', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.black,
      child: Center(
        child: Text('${_currentPage + 1}', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─── Mushaf Page Widget ───
class _MushafPageWidget extends StatelessWidget {
  final int pageNumber;
  const _MushafPageWidget({required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    final pageData = quran.getPageData(pageNumber);
    final screenH = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom - 80;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: pageData.map((data) {
                    final surah = data['surah'] as int;
                    final start = data['start'] as int;
                    final end = data['end'] as int;
                    return Column(
                      children: [
                        if (start == 1) _buildSurahHeader(context, surah),
                        if (start == 1 && surah != 1 && surah != 9) _buildBasmala(),
                        const SizedBox(height: 8),
                        _buildVersesBlock(context, surah, start, end),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSurahHeader(BuildContext context, int surah) {
    final verseCount = quran.getVerseCount(surah);
    final place = quran.getPlaceOfRevelation(surah) == "Makkah" ? "مكية" : "مدنية";
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen.withOpacity(0.25), AppColors.darkGreen.withOpacity(0.10)],
          begin: Alignment.centerRight, end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkGreen.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$place • $verseCount آية', style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11)),
          Text(
            'سورة ${quran.getSurahNameArabic(surah)}',
            style: const TextStyle(
              fontFamily: 'KFGQPC Uthmanic Script Hafs', fontSize: 22,
              color: Colors.white, fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildBasmala() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.darkGreen.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.darkGreen.withOpacity(0.3), width: 1),
          top: BorderSide(color: AppColors.darkGreen.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined, color: AppColors.darkGreen.withOpacity(0.8), size: 18),
          const SizedBox(width: 12),
          Text(
            quran.basmala,
            style: const TextStyle(
              fontFamily: 'KFGQPC Uthmanic Script Hafs', 
              fontSize: 24,
              color: Colors.white, 
              shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(width: 12),
          Icon(Icons.auto_awesome_outlined, color: AppColors.darkGreen.withOpacity(0.8), size: 18),
        ],
      ),
    );
  }

  Widget _buildVersesBlock(BuildContext context, int surah, int start, int end) {
    return RichText(
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
      text: TextSpan(
        children: List.generate(end - start + 1, (i) => start + i).expand((v) {
          String verseText = quran.getVerse(surah, v, verseEndSymbol: false);
          // Remove Basmala from first verse (except Fatiha & Tawbah)
          if (v == 1 && surah != 1 && surah != 9) {
            verseText = verseText.replaceFirst('${quran.basmala} ', '');
            verseText = verseText.replaceFirst(quran.basmala, '');
            verseText = verseText
                .replaceFirst(RegExp(r'^بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ\s*'), '')
                .replaceFirst(RegExp(r'^بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\s*'), '')
                .replaceFirst(RegExp(r'^بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ\s*'), '')
                .replaceFirst(RegExp(r'^بسم الله الرحمن الرحيم\s*'), '')
                .trim();
          }
          final tapHandler = TapGestureRecognizer()..onTap = () => _showVerseActions(context, surah, v);
          return [
            TextSpan(
              text: verseText,
              style: TextStyle(
                fontFamily: 'KFGQPC Uthmanic Script Hafs',
                fontSize: pageNumber <= 2 ? 26 : 20,
                height: 1.85, color: const Color(0xFFF5F0E8),
              ),
              recognizer: tapHandler,
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: GestureDetector(
                onTap: () => _showVerseActions(context, surah, v),
                child: _AyahEndMark(number: v),
              ),
            ),
            const TextSpan(text: ' '),
          ];
        }).toList(),
      ),
    );
  }

  void _showVerseActions(BuildContext context, int surah, int verse) {
    final verseText = quran.getVerse(surah, verse);
    final surahName = quran.getSurahNameArabic(surah);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111611),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.darkGreen.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.darkGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.darkGreen.withOpacity(0.2)),
              ),
              child: Text(verseText, style: const TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', color: Colors.white, fontSize: 18, height: 1.8), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 6),
            Text('سورة $surahName - آية $verse', style: GoogleFonts.cairo(color: AppColors.darkGreen, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _actionTile(Icons.copy_rounded, 'نسخ الآية', () { Navigator.pop(ctx); Clipboard.setData(ClipboardData(text: verseText)); _snack(context, 'تم نسخ الآية'); }),
            _actionTile(Icons.menu_book_rounded, 'التفسير الميسر', () { Navigator.pop(ctx); _showTafseer(context, surah, verse, 'ar.muyassar', 'التفسير الميسر'); }),
            _actionTile(Icons.auto_stories_rounded, 'تفسير الجلالين', () { Navigator.pop(ctx); _showTafseer(context, surah, verse, 'ar.jalalayn', 'تفسير الجلالين'); }),
            _actionTile(Icons.share_rounded, 'مشاركة نص', () { Navigator.pop(ctx); Share.share('﴿$verse﴾ $verseText\n\n- سورة $surahName -\n\nNiyyah Tracker'); }),
            _actionTile(Icons.image_rounded, 'مشاركة كصورة', () { Navigator.pop(ctx); _shareAsImage(context, surah, verse); }),
            _actionTile(Icons.bookmark_border_rounded, 'إضافة علامة', () { Navigator.pop(ctx); _snack(context, 'تم إضافة العلامة'); }),
            const SizedBox(height: 8),
          ]),
        ),
      ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      leading: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: AppColors.darkGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.darkGreen, size: 18),
      ),
      title: Text(label, style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.cairo()), backgroundColor: AppColors.darkGreen));
  }

  Future<void> _showTafseer(BuildContext context, int surah, int verse, String edition, String title) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: AppColors.darkGreen)),
    );

    try {
      final response = await http.get(Uri.parse('https://api.alquran.cloud/v1/ayah/$surah:$verse/$edition')).timeout(const Duration(seconds: 10));
      Navigator.pop(context); 
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tafseerText = data['data']['text'];
        _showTafseerDialog(context, surah, verse, tafseerText, title);
      } else {
        _snack(context, 'تعذر جلب التفسير. حاول مرة أخرى.');
      }
    } catch (e) {
      Navigator.pop(context);
      _snack(context, 'لا يوجد اتصال بالإنترنت أو الخادم لا يستجيب.');
    }
  }

  void _showTafseerDialog(BuildContext context, int surah, int verse, String text, String title) {
    final surahName = quran.getSurahNameArabic(surah);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111611),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.darkGreen.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.cairo(color: AppColors.lightGreen, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('سورة $surahName - آية $verse', style: GoogleFonts.cairo(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: SingleChildScrollView(
                  child: Text(text, style: const TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', color: Colors.white, fontSize: 20, height: 1.8), textAlign: TextAlign.justify),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareAsImage(BuildContext context, int surah, int verse) async {
    final verseText = quran.getVerse(surah, verse);
    final surahName = quran.getSurahNameArabic(surah);
    final key = GlobalKey();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF111611),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            RepaintBoundary(
              key: key,
              child: Container(
                width: 340, padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0D2818), Color(0xFF1B4332), Color(0xFF0D2818)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.darkGreen.withOpacity(0.5)), borderRadius: BorderRadius.circular(20)),
                    child: Text('سورة $surahName', style: GoogleFonts.amiri(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  Text(verseText, style: const TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', color: Colors.white, fontSize: 22, height: 1.9), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text('﴿ $verse ﴾', style: GoogleFonts.amiri(color: AppColors.lightGreen, fontSize: 18)),
                  const SizedBox(height: 20),
                  Container(height: 1, color: AppColors.darkGreen.withOpacity(0.3)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.eco_rounded, color: AppColors.lightGreen.withOpacity(0.7), size: 16),
                    const SizedBox(width: 6),
                    Text('Niyyah Tracker', style: GoogleFonts.inter(color: AppColors.lightGreen.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white60))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.darkGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      try {
                        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
                        final image = await boundary.toImage(pixelRatio: 3.0);
                        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                        final bytes = byteData!.buffer.asUint8List();
                        final dir = await getTemporaryDirectory();
                        final file = File('${dir.path}/ayah_${surah}_$verse.png');
                        await file.writeAsBytes(bytes);
                        Navigator.pop(ctx);
                        await Share.shareXFiles([XFile(file.path)], text: 'سورة $surahName - آية $verse\nNiyyah Tracker');
                      } catch (e) {
                        Navigator.pop(ctx);
                        _snack(context, 'حدث خطأ في المشاركة');
                      }
                    },
                    child: Text('مشاركة', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Ayah End Mark ───
class _AyahEndMark extends StatelessWidget {
  final int number;
  const _AyahEndMark({required this.number});
  String _toArabic(int n) {
    const ar = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    return n.toString().split('').map((e) => ar[int.parse(e)]).join('');
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 28, height: 28,
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.circle_outlined, size: 26, color: AppColors.darkGreen.withOpacity(0.7)),
        Text(_toArabic(number), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
      ]),
    );
  }
}
