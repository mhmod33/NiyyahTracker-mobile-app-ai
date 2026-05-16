import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import '../../providers/auth_provider.dart';
import '../../services/quran_audio_service.dart';
import '../../services/wird_service.dart';
import '../../services/wird_notification_service.dart';
import 'reciter_library_page.dart';

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
  int? _highlightSurah;
  int? _highlightVerse;
  Timer? _highlightTimer;
  final WirdService _wirdService = WirdService();

  @override
  void initState() {
    super.initState();
    int startPage = quran.getPageNumber(widget.surahNumber, widget.initialVerse);
    _currentPage = startPage - 1;
    _pageController = PageController(initialPage: _currentPage);
    
    // Setup temporary highlight
    if (widget.initialVerse != 1) {
      _highlightSurah = widget.surahNumber;
      _highlightVerse = widget.initialVerse;
      _highlightTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _highlightSurah = null;
            _highlightVerse = null;
          });
        }
      });
    }

    // Start wird session tracking
    _startWirdSession();
  }

  Future<void> _startWirdSession() async {
    await _wirdService.init();
    // Make sure the wird service is scoped to the current authenticated user
    // before starting a session — otherwise pages won't be saved.
    if (mounted) {
      final userId = context.read<AppAuthProvider>().userId;
      if (userId.isNotEmpty) {
        _wirdService.setUserId(userId);
      }
    }
    if (_wirdService.hasUser) {
      await _wirdService.startReadingSession(_currentPage + 1);
    }
  }

  /// Manual wird log — shows a bottom sheet to record pages read.
  void _showWirdLogSheet() {
    if (!_wirdService.hasUser) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = _wirdService.getTodayRecord();
    int pagesToAdd = 1;
    String selectedSession = WirdSession.current;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_stories_rounded,
                      color: AppColors.darkGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('تسجيل الورد اليومي',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.darkGreen)),
                  Text('قرأت ${today.pagesRead}/${today.targetPages} صفحة اليوم',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : AppColors.gray)),
                ])),
              ]),
              const SizedBox(height: 20),
              Text('كم صفحة قرأت الآن؟',
                  style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary)),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _stepBtn(Icons.remove_rounded, isDark, () {
                  if (pagesToAdd > 1) setSheet(() => pagesToAdd--);
                }),
                const SizedBox(width: 20),
                Text('$pagesToAdd',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 36, fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.darkGreen)),
                const SizedBox(width: 20),
                _stepBtn(Icons.add_rounded, isDark, () {
                  setSheet(() => pagesToAdd++);
                }),
              ]),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [1, 2, 3, 5, 10].map((n) => ActionChip(
                  label: Text('$n',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: pagesToAdd == n ? Colors.white : null)),
                  backgroundColor: pagesToAdd == n
                      ? AppColors.darkGreen
                      : (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.paleGreen),
                  onPressed: () => setSheet(() => pagesToAdd = n),
                )).toList(),
              ),
              const SizedBox(height: 20),
              // ── Session picker ──
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('في أي فترة قرأت؟',
                    style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textPrimary)),
              ),
              const SizedBox(height: 10),
              Row(
                children: WirdSession.all.map((s) {
                  final selected = s == selectedSession;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => selectedSession = s),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.darkGreen
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : AppColors.paleGreen),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.darkGreen
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(children: [
                          Icon(
                            WirdSession.iconData(s),
                            size: 20,
                            color: selected
                                ? Colors.white
                                : WirdSession.iconColor(s),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            WirdSession.label(s),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white70
                                      : AppColors.darkGreen),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'سيُحسب الوقت تلقائياً (${(pagesToAdd * 0.5).ceil()} دقيقة)',
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11, color: AppColors.gold,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _wirdService.addPages(
                      pagesToAdd,
                      session: selectedSession,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                          'تم تسجيل $pagesToAdd صفحة في فترة ${WirdSession.label(selectedSession)}',
                          style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
                        ),
                        backgroundColor: AppColors.darkGreen,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  },
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: Text('تسجيل $pagesToAdd صفحة',
                      style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.paleGreen,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkGreen.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: AppColors.darkGreen, size: 22),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _highlightTimer?.cancel();
    // End wird session and check for session completion
    _endWirdSession();
    super.dispose();
  }

  void _endWirdSession() {
    if (!_wirdService.hasUser) return;
    _wirdService.endReadingSession(_currentPage + 1).then((pagesRead) async {
      if (pagesRead >= _wirdService.getTodayRecord().pagesPerSession) {
        final session = WirdSession.current;
        final wasAlreadyDone = _wirdService.isSessionDoneToday(session);
        if (!wasAlreadyDone) {
          await WirdNotificationService().showSessionCompletedNotification(session);
        }
        final streak = _wirdService.getCurrentStreak();
        await WirdNotificationService().showStreakMilestone(streak);
      }
    });
  }

  /// Marks the current page as completed (reading rate: 30 sec/page).
  /// Updates the wird record live, restarts the session anchor at the next
  /// page so subsequent swipes don't double-count, and shows a confirmation.
  Future<void> _markCurrentPageComplete() async {
    if (!_wirdService.hasUser) return;
    final pageNumber = _currentPage + 1;
    await _wirdService.markPageRead();
    // Re-anchor the session so the dispose() crediting won't count this page
    // again. Keep the same session key by resetting start info.
    await _wirdService.startReadingSession(pageNumber + 1);

    final today = _wirdService.getTodayRecord();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.darkGreen,
        duration: const Duration(seconds: 2),
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تم احتساب صفحة $pageNumber في الورد · ${today.pagesRead}/${today.targetPages}',
              style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0D0D) : AppColors.background;
    final headerFooterColor = isDark ? Colors.black : AppColors.cardBg;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top),
            _buildHeader(_currentPage + 1, isDark, headerFooterColor, textColor, subtextColor),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 604,
                physics: const _SinglePagePhysics(),
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                },
                itemBuilder: (ctx, index) => _MushafPageWidget(
                  pageNumber: index + 1,
                  highlightSurah: _highlightSurah,
                  highlightVerse: _highlightVerse,
                  isDark: isDark,
                ),
              ),
            ),
            _buildFooter(isDark, headerFooterColor, subtextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int page, bool isDark, Color bgColor, Color textColor, Color subtextColor) {
    final data = quran.getPageData(page).first;
    final s = data['surah'] as int;
    final j = quran.getJuzNumber(s, data['start']);
    final h = ((j - 1) * 2 + 1);
    final audioService = QuranAudioService();
    final isPlayingThisSurah = audioService.state.currentSurah == s &&
        audioService.state.isPlaying;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: DirectionalIcon(isBack: true, size: 18, color: isDark ? Colors.white70 : AppColors.textSecondary),
          ),
          Text(quran.getSurahNameArabic(s), style: GoogleFonts.amiri(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
          Text('Juz $j', style: GoogleFonts.inter(color: subtextColor, fontSize: 12)),
          Text('Hizb $h', style: GoogleFonts.inter(color: subtextColor, fontSize: 12)),
          // Audio button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReciterLibraryPage(surahToPlay: s),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isPlayingThisSurah
                    ? AppColors.darkGreen
                    : AppColors.darkGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPlayingThisSurah
                    ? Icons.graphic_eq_rounded
                    : Icons.headphones_rounded,
                color: isPlayingThisSurah ? Colors.white : AppColors.darkGreen,
                size: 18,
              ),
            ),
          ),
          // Wird log button — only for logged-in users
          if (_wirdService.hasUser) ...[
            GestureDetector(
              onTap: _markCurrentPageComplete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppColors.darkGreen,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _showWirdLogSheet,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.gold,
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark, Color bgColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: bgColor,
      child: Center(
        child: Text('${_currentPage + 1}', style: GoogleFonts.inter(fontSize: 14, color: subtextColor, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─── Mushaf Page Widget ───
class _MushafPageWidget extends StatefulWidget {
  final int pageNumber;
  final int? highlightSurah;
  final int? highlightVerse;
  final bool isDark;
  const _MushafPageWidget({required this.pageNumber, this.highlightSurah, this.highlightVerse, required this.isDark});

  @override
  State<_MushafPageWidget> createState() => _MushafPageWidgetState();
}

class _MushafPageWidgetState extends State<_MushafPageWidget> with AutomaticKeepAliveClientMixin {
  // Cache the computed font size so it doesn't recompute during swipe animation
  double? _cachedFontSize;
  double? _cachedWidth;
  double? _cachedHeight;

  // Constants used in both rendering and measurement — must match exactly.
  static const double _hPad = 10.0;
  static const double _vPad = 6.0;
  static const double _lineHeight = 1.85;

  @override
  bool get wantKeepAlive => true;

  int get pageNumber => widget.pageNumber;
  int? get highlightSurah => widget.highlightSurah;
  int? get highlightVerse => widget.highlightVerse;
  bool get isDark => widget.isDark;

  double _computeFontSize(List pageData, double availableW, double availableH) {
    // Return cached if dimensions haven't changed
    if (_cachedFontSize != null && _cachedWidth == availableW && _cachedHeight == availableH) {
      return _cachedFontSize!;
    }

    double lo = 12.0, hi = 30.0;
    for (int i = 0; i < 15; i++) {
      final mid = (lo + hi) / 2;
      final measured = _measurePage(pageData, mid, availableW);
      if (measured <= availableH) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    _cachedFontSize = lo;
    _cachedWidth = availableW;
    _cachedHeight = availableH;
    return lo;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
    final pageData = quran.getPageData(pageNumber);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: _DecoratedMushafFrame(
        isDark: isDark,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableW = constraints.maxWidth;
            final availableH = constraints.maxHeight;
            final fontSize = _computeFontSize(pageData, availableW, availableH);

            return SizedBox(
              width: availableW,
              height: availableH,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: _hPad, vertical: _vPad),
                child: Column(
                  mainAxisAlignment: pageData.length > 1
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: pageData.map((data) {
                    final surah = data['surah'] as int;
                    final start = data['start'] as int;
                    final end = data['end'] as int;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (start == 1) _buildSurahHeader(context, surah, fontSize),
                        if (start == 1 && surah != 1 && surah != 9) _buildBasmala(fontSize),
                        _buildVersesBlock(context, surah, start, end, fontSize),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Accurate page-height measurement ──
  // Replicates the exact rendering math for every component on the page.
  double _measurePage(List pageData, double fontSize, double totalWidth) {
    final innerWidth = totalWidth - _hPad * 2;
    double total = _vPad * 2;

    for (final data in pageData) {
      final surah = data['surah'] as int;
      final start = data['start'] as int;
      final end   = data['end']   as int;

      if (start == 1) {
        total += _measureHeaderHeight(fontSize);
        if (surah != 1 && surah != 9) {
          total += _measureBasmalaHeight(fontSize);
        }
      }
      total += _measureVersesHeight(surah, start, end, fontSize, innerWidth);
    }
    return total;
  }

  double _measureHeaderHeight(double fontSize) {
    final marginV  = fontSize * 0.15 * 2;
    final paddingV = fontSize * 0.4  * 2;
    const border   = 3.0; // 1.5 * 2
    final titleFS  = (fontSize * 1.4).clamp(16.0, 28.0);
    // Line height for Arabic display font is ~1.35 of em.
    final contentH = titleFS * 1.35;
    return marginV + paddingV + border + contentH;
  }

  double _measureBasmalaHeight(double fontSize) {
    final marginV  = fontSize * 0.3 + fontSize * 0.1;
    final paddingV = fontSize * 0.2 * 2;
    const border   = 2.0;
    final textFS   = (fontSize * 1.3).clamp(14.0, 30.0);
    final contentH = textFS * 1.35;
    return marginV + paddingV + border + contentH;
  }

  double _measureVersesHeight(int surah, int start, int end, double fontSize, double width) {
    // Build the same inline spans used in the real render, so TextPainter
    // produces the same line count and height.
    final spans = <InlineSpan>[];
    final markSize = (fontSize * 1.5).clamp(24.0, 38.0);
    final markBoxW = markSize + markSize * 0.16; // includes symmetric margin

    for (int v = start; v <= end; v++) {
      String t = quran.getVerse(surah, v, verseEndSymbol: false);
      if (v == 1 && surah != 1 && surah != 9) {
        final trimmed = t.trim();
        if (trimmed.startsWith(quran.basmala)) {
          t = trimmed.substring(quran.basmala.length).trim();
        } else {
          final words = trimmed.split(' ');
          if (words.length > 4) t = words.skip(4).join(' ').trim();
        }
      }
      spans.add(TextSpan(
        text: t,
        style: TextStyle(
          fontFamily: 'KFGQPC Uthmanic Script Hafs',
          fontSize: fontSize,
          height: _lineHeight,
        ),
      ));
      spans.add(const WidgetSpan(child: SizedBox())); // placeholder (dims set below)
      spans.add(TextSpan(
        text: ' ',
        style: TextStyle(
          fontFamily: 'KFGQPC Uthmanic Script Hafs',
          fontSize: fontSize,
          height: _lineHeight,
        ),
      ));
    }

    final verseCount = end - start + 1;
    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.justify,
    );
    tp.setPlaceholderDimensions(List.generate(
      verseCount,
      (_) => PlaceholderDimensions(
        size: Size(markBoxW, markSize),
        alignment: PlaceholderAlignment.middle,
      ),
    ));
    tp.layout(maxWidth: width);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  Widget _buildSurahHeader(BuildContext context, int surah, double fontSize) {
    final verseCount = quran.getVerseCount(surah);
    final place = quran.getPlaceOfRevelation(surah) == "Makkah" ? "مكية" : "مدنية";
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: fontSize * 0.15),
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.8, vertical: fontSize * 0.4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen.withValues(alpha: 0.25), AppColors.darkGreen.withValues(alpha: 0.10)],
          begin: Alignment.centerRight, end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.darkGreen.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$place • $verseCount آية',
              style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                  fontSize: (fontSize * 0.6).clamp(9.0, 13.0))),
          Text(
            'سورة ${quran.getSurahNameArabic(surah)}',
            style: TextStyle(
              fontFamily: 'KFGQPC Uthmanic Script Hafs',
              fontSize: (fontSize * 1.4).clamp(16.0, 28.0),
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: fontSize * 3),
        ],
      ),
    );
  }

  Widget _buildBasmala(double fontSize) {
    return Container(
      margin: EdgeInsets.only(bottom: fontSize * 0.3, top: fontSize * 0.1),
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.5, vertical: fontSize * 0.2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, AppColors.darkGreen.withValues(alpha: 0.15), Colors.transparent],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.darkGreen.withValues(alpha: 0.3), width: 1),
          top: BorderSide(color: AppColors.darkGreen.withValues(alpha: 0.3), width: 1),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, color: AppColors.darkGreen.withValues(alpha: 0.8), size: fontSize * 0.9),
            SizedBox(width: fontSize * 0.4),
            Text(
              quran.basmala,
              style: TextStyle(
                fontFamily: 'KFGQPC Uthmanic Script Hafs',
                fontSize: (fontSize * 1.3).clamp(14.0, 30.0),
                color: isDark ? Colors.white : AppColors.textPrimary,
                shadows: isDark ? [const Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))] : null,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(width: fontSize * 0.4),
            Icon(Icons.auto_awesome_outlined, color: AppColors.darkGreen.withValues(alpha: 0.8), size: fontSize * 0.9),
          ],
        ),
      ),
    );
  }

  Widget _buildVersesBlock(BuildContext context, int surah, int start, int end, double fontSize) {
    // Build verse ranges to map character offsets to verse numbers
    final List<_VerseRange> verseRanges = [];
    final spans = <InlineSpan>[];
    int charOffset = 0;

    for (int v = start; v <= end; v++) {
      String verseText = quran.getVerse(surah, v, verseEndSymbol: false);
      if (v == 1 && surah != 1 && surah != 9) {
        final trimmed = verseText.trim();
        if (trimmed.startsWith(quran.basmala)) {
          verseText = trimmed.substring(quran.basmala.length).trim();
        } else {
          final words = trimmed.split(' ');
          if (words.length > 4) verseText = words.skip(4).join(' ').trim();
        }
      }

      final startOffset = charOffset;
      charOffset += verseText.length;

      final bool isHighlighted = (highlightSurah != null && highlightVerse != null &&
          highlightSurah == surah && highlightVerse == v);

      spans.add(TextSpan(
        text: verseText,
        style: TextStyle(
          fontFamily: 'KFGQPC Uthmanic Script Hafs',
          fontSize: fontSize,
          height: 1.8,
          color: isHighlighted ? Colors.black : (isDark ? const Color(0xFFF5F0E8) : AppColors.textPrimary),
          backgroundColor: isHighlighted ? Colors.yellow.withValues(alpha: 0.18) : null,
        ),
      ));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _AyahEndMark(number: v, isDark: isDark, size: (fontSize * 1.5).clamp(24.0, 38.0)),
      ));
      // Space character after mark
      spans.add(TextSpan(
        text: ' ',
        style: TextStyle(
          fontFamily: 'KFGQPC Uthmanic Script Hafs',
          fontSize: fontSize,
          height: 1.8,
        ),
      ));
      charOffset += 1; // for the space

      verseRanges.add(_VerseRange(startOffset, charOffset, v));
    }

    final textSpan = TextSpan(children: spans);

    return _TappableRichText(
      textSpan: textSpan,
      verseRanges: verseRanges,
      surah: surah,
      onVerseTap: (verse) => _showVerseActions(context, surah, verse),
    );
  }

  void _showVerseActions(BuildContext context, int surah, int verse) {
    final verseText = quran.getVerse(surah, verse);
    final surahName = quran.getSurahNameArabic(surah);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111611) : AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.darkGreen.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.darkGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.darkGreen.withValues(alpha: 0.2)),
              ),
              child: Text(verseText, style: TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 18, height: 1.8), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 6),
            Text('سورة $surahName - آية $verse', style: GoogleFonts.ibmPlexSansArabic(color: AppColors.darkGreen, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _actionTile(Icons.copy_rounded, 'نسخ الآية', () { Navigator.pop(ctx); Clipboard.setData(ClipboardData(text: verseText)); _snack(context, 'تم نسخ الآية'); }),
            _actionTile(Icons.menu_book_rounded, 'التفسير الميسر', () { Navigator.pop(ctx); _showTafseer(context, surah, verse, 'ar.muyassar', 'التفسير الميسر'); }),
            _actionTile(Icons.auto_stories_rounded, 'تفسير الجلالين', () { Navigator.pop(ctx); _showTafseer(context, surah, verse, 'ar.jalalayn', 'تفسير الجلالين'); }),
            _actionTile(Icons.share_rounded, 'مشاركة نص', () { Navigator.pop(ctx); Share.share('﴿$verse﴾ $verseText\n\n- سورة $surahName -\n\nNiyyah Tracker'); }),
            _actionTile(Icons.image_rounded, 'مشاركة كصورة', () { Navigator.pop(ctx); _shareAsImage(context, surah, verse); }),
            _actionTile(Icons.bookmark_border_rounded, 'إضافة علامة', () async { 
              Navigator.pop(ctx); 
              final box = await Hive.openBox('quran_bookmarks');
              final key = '$surah-$verse';
              if (box.containsKey(key)) {
                if (context.mounted) _snack(context, 'الآية موجودة بالفعل في المحفوظات');
              } else {
                await box.put(key, {
                  'surah': surah,
                  'verse': verse,
                  'surahName': surahName,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                });
                if (context.mounted) _snack(context, 'تم إضافة العلامة للمحفوظات');
              }
            }),
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
        decoration: BoxDecoration(color: AppColors.darkGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.darkGreen, size: 18),
      ),
      title: Text(label, style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: DirectionalIcon(isBack: false, size: 12, color: isDark ? Colors.white24 : AppColors.gray),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.ibmPlexSansArabic()), backgroundColor: AppColors.darkGreen));
  }

  Future<void> _showTafseer(BuildContext context, int surah, int verse, String edition, String title) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: AppColors.darkGreen)),
    );

    try {
      final response = await http.get(Uri.parse('https://api.alquran.cloud/v1/ayah/$surah:$verse/$edition')).timeout(const Duration(seconds: 10));
      if (!context.mounted) return;
      Navigator.pop(context); 
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tafseerText = data['data']['text'];
        _showTafseerDialog(context, surah, verse, tafseerText, title);
      } else {
        _snack(context, 'تعذر جلب التفسير. حاول مرة أخرى.');
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _snack(context, 'لا يوجد اتصال بالإنترنت أو الخادم لا يستجيب.');
    }
  }

  void _showTafseerDialog(BuildContext context, int surah, int verse, String text, String title) {
    final surahName = quran.getSurahNameArabic(surah);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111611) : AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.darkGreen.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.ibmPlexSansArabic(color: AppColors.lightGreen, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('سورة $surahName - آية $verse', style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: SingleChildScrollView(
                  child: Text(text, style: TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', color: isDark ? Colors.white : AppColors.textPrimary, fontSize: 20, height: 1.8), textAlign: TextAlign.justify),
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
          backgroundColor: isDark ? const Color(0xFF111611) : AppColors.cardBg,
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
                    decoration: BoxDecoration(border: Border.all(color: AppColors.darkGreen.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(20)),
                    child: Text('سورة $surahName', style: GoogleFonts.amiri(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  Text(verseText, style: const TextStyle(fontFamily: 'KFGQPC Uthmanic Script Hafs', color: Colors.white, fontSize: 22, height: 1.9), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text('﴿ $verse ﴾', style: GoogleFonts.amiri(color: AppColors.lightGreen, fontSize: 18)),
                  const SizedBox(height: 20),
                  Container(height: 1, color: AppColors.darkGreen.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.eco_rounded, color: AppColors.lightGreen.withValues(alpha: 0.7), size: 16),
                    const SizedBox(width: 6),
                    Text('Niyyah Tracker', style: GoogleFonts.inter(color: AppColors.lightGreen.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white60 : AppColors.textSecondary))),
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
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await Share.shareXFiles([XFile(file.path)], text: 'سورة $surahName - آية $verse\nNiyyah Tracker');
                      } catch (e) {
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _snack(context, 'حدث خطأ في المشاركة');
                      }
                    },
                    child: Text('مشاركة', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.bold)),
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
  final bool isDark;
  final double size;
  const _AyahEndMark({required this.number, required this.isDark, this.size = 32});
  String _toArabic(int n) {
    const ar = ['٠','١','٢','٣','٤','٥','٦','٧','٨','٩'];
    return n.toString().split('').map((e) => ar[int.parse(e)]).join('');
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: size * 0.08),
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.circle_outlined, size: size, color: AppColors.darkGreen.withValues(alpha: 0.7)),
        Text(_toArabic(number), style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimary,
        )),
      ]),
    );
  }
}



// ─── Decorated Mushaf Frame ──────────────────────────────────────────────────
// Provides an ornamental double-border around each mushaf page,
// reminiscent of classic printed Qur'an pages.
class _DecoratedMushafFrame extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _DecoratedMushafFrame({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    final outerColor = isDark
        ? AppColors.gold.withValues(alpha: 0.55)
        : AppColors.darkGreen.withValues(alpha: 0.55);
    final innerColor = isDark
        ? AppColors.gold.withValues(alpha: 0.95)
        : AppColors.darkGreen.withValues(alpha: 0.85);
    final cornerColor = isDark ? AppColors.gold : AppColors.darkGreen;
    final fillStart = isDark
        ? const Color(0xFF11150F)
        : const Color(0xFFFAF6EC);
    final fillEnd = isDark
        ? const Color(0xFF0A0D08)
        : const Color(0xFFF1EAD6);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [fillStart, fillEnd],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outerColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: innerColor, width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Inner content
            Padding(padding: const EdgeInsets.all(2), child: child),
            // Decorative corners
            Positioned(
              top: 4, right: 4,
              child: _Corner(color: cornerColor, alignment: Alignment.topRight),
            ),
            Positioned(
              top: 4, left: 4,
              child: _Corner(color: cornerColor, alignment: Alignment.topLeft),
            ),
            Positioned(
              bottom: 4, right: 4,
              child: _Corner(color: cornerColor, alignment: Alignment.bottomRight),
            ),
            Positioned(
              bottom: 4, left: 4,
              child: _Corner(color: cornerColor, alignment: Alignment.bottomLeft),
            ),
          ],
        ),
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final Color color;
  final Alignment alignment;
  const _Corner({required this.color, required this.alignment});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(
        painter: _CornerPainter(color: color, alignment: alignment),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final Alignment alignment;
  _CornerPainter({required this.color, required this.alignment});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final path = Path();

    final isLeft = alignment.x < 0;
    final isTop = alignment.y < 0;
    final dx = isLeft ? 0.0 : size.width;
    final dy = isTop ? 0.0 : size.height;

    // Two short strokes meeting at the corner with a small ornamental dot
    path.moveTo(dx, isTop ? size.height : 0);
    path.lineTo(dx, dy);
    path.lineTo(isLeft ? size.width : 0, dy);

    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(dx, dy), 1.6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.color != color || old.alignment != alignment;
}

// ─── Verse Range helper ───
class _VerseRange {
  final int startOffset;
  final int endOffset;
  final int verse;
  const _VerseRange(this.startOffset, this.endOffset, this.verse);
}

// ─── Single Page Physics ─────────────────────────────────────────────────────
// Restricts every fling/swipe to exactly one page advance.
// Without this, a fast horizontal flick can carry the simulation
// far enough to skip a page (the "double-swipe" problem).
class _SinglePagePhysics extends ScrollPhysics {
  const _SinglePagePhysics({super.parent});

  @override
  _SinglePagePhysics applyTo(ScrollPhysics? ancestor) =>
      _SinglePagePhysics(parent: buildParent(ancestor));

  double _page(ScrollPosition position) =>
      position.pixels / position.viewportDimension;

  double _targetPixels(ScrollPosition position, double velocity) {
    final current = _page(position);
    // Determine which page to settle on based on direction + small threshold.
    final base = current.floor().toDouble();
    double target;
    if (velocity.abs() < 200) {
      // Slow drag: snap to nearest page.
      target = current.roundToDouble();
    } else if (velocity > 0) {
      target = base + 1;
    } else {
      target = base;
    }
    final maxIndex =
        (position.maxScrollExtent / position.viewportDimension).round();
    target = target.clamp(0.0, maxIndex.toDouble());
    return target * position.viewportDimension;
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if (position is! ScrollPosition) return super.createBallisticSimulation(position, velocity);
    final tolerance = toleranceFor(position);

    final target = _targetPixels(position, velocity);
    if ((target - position.pixels).abs() < tolerance.distance) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      // Cap velocity so the spring never overshoots into the next page.
      velocity.clamp(-2000.0, 2000.0),
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

// ─── Tappable RichText ───
// Uses onTapUp instead of TapGestureRecognizer on TextSpans.
// This way the gesture arena is NOT blocked — horizontal drags
// pass through to PageView immediately on first swipe.
class _TappableRichText extends StatelessWidget {
  final TextSpan textSpan;
  final List<_VerseRange> verseRanges;
  final int surah;
  final void Function(int verse) onVerseTap;

  const _TappableRichText({
    required this.textSpan,
    required this.verseRanges,
    required this.surah,
    required this.onVerseTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapUp: (details) {
        // Find which verse was tapped using TextPainter hit-testing
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localPos = details.localPosition;

        // Each verse produces exactly one WidgetSpan (_AyahEndMark).
        // We must supply PlaceholderDimensions for every WidgetSpan before
        // calling layout(), otherwise Flutter asserts 'dimensions != null'.
        final verseCount = verseRanges.length;

        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
        );

        if (verseCount > 0) {
          tp.setPlaceholderDimensions(
            List.generate(
              verseCount,
              (_) => const PlaceholderDimensions(
                size: Size(32, 32),
                alignment: PlaceholderAlignment.middle,
              ),
            ),
          );
        }

        tp.layout(maxWidth: renderBox.size.width);
        final offset = tp.getPositionForOffset(localPos).offset;
        tp.dispose();

        // Find which verse this offset belongs to
        for (final range in verseRanges) {
          if (offset >= range.startOffset && offset < range.endOffset) {
            onVerseTap(range.verse);
            return;
          }
        }
        // If tapped between ranges (on a mark), find nearest
        if (verseRanges.isNotEmpty) {
          onVerseTap(verseRanges.last.verse);
        }
      },
      child: RichText(
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        text: textSpan,
      ),
    );
  }
}
