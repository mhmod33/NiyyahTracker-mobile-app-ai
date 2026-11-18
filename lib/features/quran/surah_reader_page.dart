import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:wakelock_plus/wakelock_plus.dart';
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
import 'package:mushaf/mushaf.dart';

class SurahReaderPage extends StatefulWidget {
  final int surahNumber;
  final int initialVerse;
  final int? initialPage;
  const SurahReaderPage({
    super.key,
    required this.surahNumber,
    this.initialVerse = 1,
    this.initialPage,
  });
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

  // ── Feature 10: Reader settings ──
  double _fontSize = 22.0;
  bool _boldFont = false;
  bool _verticalScroll = false; // false = horizontal (default)
  bool _useQcfFont = true; // Ottoman script (QCF) 604 page fonts

  // ── Feature 1: Multi-verse selection ──
  final Set<int> _selectedVerses = {};
  int? _selectedSurah; // surah context for the current selection

  @override
  void initState() {
    super.initState();
    // Keep the screen on while reading.
    WakelockPlus.enable();
    final int startPage =
        (widget.initialPage != null &&
            widget.initialPage! >= 1 &&
            widget.initialPage! <= 604)
        ? widget.initialPage!
        : quran.getPageNumber(widget.surahNumber, widget.initialVerse);
    _currentPage = startPage - 1;
    _pageController = PageController(initialPage: _currentPage);
    _loadSettings();

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

    // Save reading progress immediately & track Al-Kahf on Fridays
    _saveReadingProgress(_currentPage);
    _maybeTrackKahf(_currentPage);

    // Start wird session tracking
    _startWirdSession();
  }

  // ── Feature 10: Load/Save settings ──
  Future<void> _loadSettings() async {
    try {
      final box = Hive.isBoxOpen('quran_settings')
          ? Hive.box('quran_settings')
          : await Hive.openBox('quran_settings');
      if (mounted) {
        setState(() {
          _fontSize = (box.get('fontSize', defaultValue: 22.0) as num)
              .toDouble();
          _boldFont = box.get('boldFont', defaultValue: false) as bool;
          _verticalScroll =
              box.get('verticalScroll', defaultValue: false) as bool;
          _useQcfFont = box.get('useQcfFont', defaultValue: true) as bool;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      final box = Hive.isBoxOpen('quran_settings')
          ? Hive.box('quran_settings')
          : await Hive.openBox('quran_settings');
      await box.put('fontSize', _fontSize);
      await box.put('boldFont', _boldFont);
      await box.put('verticalScroll', _verticalScroll);
      await box.put('useQcfFont', _useQcfFont);
    } catch (_) {}
  }

  Future<void> _saveReadingProgress(int pageIndex) async {
    try {
      final pageNum = (pageIndex + 1).clamp(1, 604);
      final pageData = quran.getPageData(pageNum).first;
      final surahNum = pageData['surah'] as int;
      final startVerse = pageData['start'] as int;
      final surahName = quran.getSurahNameArabic(surahNum);
      final juzNum = quran.getJuzNumber(surahNum, startVerse);

      final box = Hive.isBoxOpen('quran_progress')
          ? Hive.box('quran_progress')
          : await Hive.openBox('quran_progress');

      await box.put('last_read', {
        'page': pageNum,
        'surahNumber': surahNum,
        'surahName': surahName,
        'verse': startVerse,
        'juz': juzNum,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Smart progression: track the furthest page ever reached.
      final existing = box.get('max_page');
      final existingMax = existing is Map
          ? ((existing['page'] as int?) ?? 0)
          : 0;
      if (pageNum > existingMax) {
        await box.put('max_page', {
          'page': pageNum,
          'surahNumber': surahNum,
          'surahName': surahName,
          'verse': startVerse,
          'juz': juzNum,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      // Record reading history of visited surahs with timestamps
      final rawHistory = box.get('visited_surahs');
      final visitedList = rawHistory is List
          ? List<dynamic>.from(rawHistory)
          : <dynamic>[];
      visitedList.add({
        'surahNumber': surahNum,
        'surahName': surahName,
        'page': pageNum,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      // Keep last 100 history entries
      if (visitedList.length > 100) {
        visitedList.removeRange(0, visitedList.length - 100);
      }
      await box.put('visited_surahs', visitedList);

      // Record reading "stops": each contiguous run of pages inside one surah
      // becomes a segment, so partial reads of a surah are preserved even when
      // the user jumps to another surah before finishing it.
      final rawStops = box.get('reading_stops');
      final stops = rawStops is List
          ? List<dynamic>.from(rawStops)
          : <dynamic>[];
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (stops.isNotEmpty && stops.last is Map) {
        final last = stops.last as Map;
        if ((last['surahNumber'] as int?) == surahNum) {
          last['endPage'] = pageNum;
          last['lastTimestamp'] = nowMs;
          await box.put('reading_stops', stops);
          return;
        }
      }
      stops.add({
        'surahNumber': surahNum,
        'surahName': surahName,
        'startPage': pageNum,
        'endPage': pageNum,
        'firstTimestamp': nowMs,
        'lastTimestamp': nowMs,
      });
      // Keep last 200 stop segments
      if (stops.length > 200) {
        stops.removeRange(0, stops.length - 200);
      }
      await box.put('reading_stops', stops);
    } catch (_) {}
  }

  Future<void> _startWirdSession() async {
    await _wirdService.init();
    // Make sure the wird service is scoped to the current authenticated user
    // before starting a session — otherwise pages won't be saved.
    if (mounted) {
      final userId = context.read<AppAuthProvider>().userId;
      if (userId.isNotEmpty) {
        _wirdService.setUserId(userId);
        setState(() {});
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.darkGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: AppColors.darkGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تسجيل الورد اليومي',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.darkGreen,
                            ),
                          ),
                          Text(
                            'قرأت ${today.pagesRead}/${today.targetPages} صفحة اليوم',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : AppColors.gray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'كم صفحة قرأت الآن؟',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stepBtn(Icons.remove_rounded, isDark, () {
                      if (pagesToAdd > 1) setSheet(() => pagesToAdd--);
                    }),
                    const SizedBox(width: 20),
                    Text(
                      '$pagesToAdd',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(width: 20),
                    _stepBtn(Icons.add_rounded, isDark, () {
                      setSheet(() => pagesToAdd++);
                    }),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [1, 2, 3, 5, 10]
                      .map(
                        (n) => ActionChip(
                          label: Text(
                            '$n',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: pagesToAdd == n ? Colors.white : null,
                            ),
                          ),
                          backgroundColor: pagesToAdd == n
                              ? AppColors.darkGreen
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : AppColors.paleGreen),
                          onPressed: () => setSheet(() => pagesToAdd = n),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                // ── Session picker ──
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'في أي فترة قرأت؟',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
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
                          child: Column(
                            children: [
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
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'سيُحسب الوقت تلقائياً (${(pagesToAdd * 0.5).ceil()} دقيقة)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم تسجيل $pagesToAdd صفحة في فترة ${WirdSession.label(selectedSession)}',
                              style: GoogleFonts.ibmPlexSansArabic(
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: AppColors.darkGreen,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: Text(
                      'تسجيل $pagesToAdd صفحة',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.paleGreen,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkGreen.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: AppColors.darkGreen, size: 22),
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
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
          await WirdNotificationService().showSessionCompletedNotification(
            session,
          );
        }
        final streak = _wirdService.getCurrentStreak();
        await WirdNotificationService().showStreakMilestone(streak);
      }
    });
  }

  // ─── Al-Kahf Friday tracking ───
  void _maybeTrackKahf(int pageIndex) {
    final pageNum = pageIndex + 1;
    try {
      final pageData = quran.getPageData(pageNum);
      if (pageData.any((d) => d['surah'] == 18)) {
        _trackKahfFridayReading();
      }
    } catch (_) {}
  }

  Future<void> _trackKahfFridayReading() async {
    final now = DateTime.now();
    if (now.weekday != DateTime.friday) return;
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final box = await Hive.openBox('kahf_tracker');
    if (!box.containsKey(dayKey)) {
      await box.put(dayKey, {'timestamp': now.millisecondsSinceEpoch});
    }
  }

  /// Marks the current page as completed.
  /// Updates the wird record live, restarts the session anchor at the next
  /// page so subsequent swipes don't double-count, and shows a confirmation.
  Future<void> _markCurrentPageComplete() async {
    final pageNumber = _currentPage + 1;
    if (_wirdService.hasUser) {
      await _wirdService.markPageRead();
      await _wirdService.startReadingSession(pageNumber + 1);
    }
    // Also record page in local reading progress
    final progressBox = Hive.isBoxOpen('quran_progress')
        ? Hive.box('quran_progress')
        : await Hive.openBox('quran_progress');
    final todayKey =
        'read_pages_${DateTime.now().toIso8601String().substring(0, 10)}';
    final List readToday = List.from(
      progressBox.get(todayKey, defaultValue: []) as List,
    );
    if (!readToday.contains(pageNumber)) {
      readToday.add(pageNumber);
      await progressBox.put(todayKey, readToday);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.darkGreen,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تم احتساب صفحة $pageNumber في قراءتك اليوم (${readToday.length} صفحة)',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B120D) : AppColors.background;
    final headerFooterColor = isDark
        ? const Color(0xFF0B120D)
        : AppColors.cardBg;

    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtextColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top),
            _buildHeader(
              _currentPage + 1,
              isDark,
              headerFooterColor,
              textColor,
              subtextColor,
            ),
            Expanded(
              // LTR paging so the next page sits to the right and pages
              // advance rightward; each page keeps its own RTL content.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: PageView.builder(
                controller: _pageController,
                scrollDirection: _verticalScroll
                    ? Axis.vertical
                    : Axis.horizontal,
                itemCount: 604,
                physics: const _SinglePagePhysics(),
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  _saveReadingProgress(i);
                  _maybeTrackKahf(i);
                },
                itemBuilder: (ctx, index) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: _MushafPageWidget(
                  pageNumber: index + 1,
                  highlightSurah: _highlightSurah,
                  highlightVerse: _highlightVerse,
                  isDark: isDark,
                  selectedVerses: _selectedSurah == null
                      ? const {}
                      : _selectedVerses,
                  selectedSurah: _selectedSurah,
                  readerFontSize: _fontSize,
                  boldFont: _boldFont,
                  verticalScroll: _verticalScroll,
                  useQcfFont: _useQcfFont,
                  onVerseTap: (surah, verse) {
                    if (_selectedVerses.isNotEmpty) {
                      setState(() {
                        if (_selectedSurah != surah) {
                          _selectedVerses.clear();
                          _selectedSurah = surah;
                        }
                        if (_selectedVerses.contains(verse)) {
                          _selectedVerses.remove(verse);
                          if (_selectedVerses.isEmpty) _selectedSurah = null;
                        } else {
                          _selectedVerses.add(verse);
                        }
                      });
                    } else {
                      _showVerseActions(context, surah, verse);
                    }
                  },
                  onVerseLongPress: (surah, verse) {
                    _showVerseActions(context, surah, verse);
                  },
                  ),
                ),
                ),
              ),
            ),
            if (_selectedVerses.isNotEmpty) _buildSelectionBar(isDark),
            _buildFooter(isDark, headerFooterColor, subtextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar(bool isDark) {
    final count = _selectedVerses.length;
    final surah = _selectedSurah;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1B2A20)
            : AppColors.goldLight.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: AppColors.gold.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: AppColors.gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count آية محددة',
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? Colors.white : AppColors.darkGreen,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {
              if (surah == null) return;
              final verses = _selectedVerses.toList()..sort();
              final surahName = quran.getSurahNameArabic(surah);
              final combined = verses
                  .map((v) => '﴿$v﴾ ${quran.getVerse(surah, v)}')
                  .join('\n');
              Clipboard.setData(
                ClipboardData(text: '$combined\n\n- سورة $surahName -'),
              );
              _snack(context, 'تم نسخ $count آية');
              setState(() {
                _selectedVerses.clear();
                _selectedSurah = null;
              });
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 16,
              color: AppColors.darkGreen,
            ),
            label: Text(
              'نسخ',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.darkGreen,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              if (surah == null) return;
              final verses = _selectedVerses.toList()..sort();
              _shareVersesAsImage(context, surah, verses);
              setState(() {
                _selectedVerses.clear();
                _selectedSurah = null;
              });
            },
            icon: const Icon(
              Icons.image_rounded,
              size: 16,
              color: AppColors.gold,
            ),
            label: Text(
              'مشاركة كصورة',
              style: GoogleFonts.ibmPlexSansArabic(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
            onPressed: () => setState(() {
              _selectedVerses.clear();
              _selectedSurah = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    int page,
    bool isDark,
    Color bgColor,
    Color textColor,
    Color subtextColor,
  ) {
    final data = quran.getPageData(page).first;
    final s = data['surah'] as int;
    final startVerse = data['start'] as int;
    final j = quran.getJuzNumber(s, startVerse);
    final h = ((j - 1) * 2 + 1);
    final audioService = QuranAudioService();
    final isPlayingThisSurah =
        audioService.state.currentSurah == s && audioService.state.isPlaying;

    // Use Muhaf font for surah name on regular pages;
    // skip for Al-Fatihah (s==1) and pages that start a new surah (startVerse==1)
    final bool useMushafFont = !(s == 1 || startVerse == 1);
    const double mushafHeaderFontSize = 14.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: DirectionalIcon(
              isBack: true,
              size: 18,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              quran.getSurahNameArabic(s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: useMushafFont
                  ? TextStyle(
                      fontFamily: 'Al Mushaf',
                      fontSize: mushafHeaderFontSize,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    )
                  : GoogleFonts.amiri(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: mushafHeaderFontSize,
                    ),
            ),
          ),
          Text(
            'J$j · H$h',
            style: GoogleFonts.inter(color: subtextColor, fontSize: 11),
          ),
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
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.paleGreen),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPlayingThisSurah
                    ? Icons.graphic_eq_rounded
                    : Icons.headphones_rounded,
                color: isPlayingThisSurah
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.darkGreen),
                size: 18,
              ),
            ),
          ),
          // Button to count the page (احتساب الصفحة)
          GestureDetector(
            onTap: _markCurrentPageComplete,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkGreen.withValues(alpha: 0.25)
                    : AppColors.paleGreen,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.darkGreen.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.darkGreen,
                size: 18,
              ),
            ),
          ),
          if (_wirdService.hasUser) ...[
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
          // Page Bookmark button (Allows saving multiple pages in browser/reader)
          const SizedBox(width: 4),
          FutureBuilder<Box>(
            future: Hive.openBox('quran_page_bookmarks'),
            builder: (ctx, snap) {
              final box = snap.data;
              final isPageBookmarked = box?.containsKey('page_$page') ?? false;
              return GestureDetector(
                onTap: () async {
                  final b = box ?? await Hive.openBox('quran_page_bookmarks');
                  final key = 'page_$page';
                  if (b.containsKey(key)) {
                    await b.delete(key);
                    if (mounted)
                      _snack(context, 'تمت إزالة صفحة $page من المحفوظات');
                  } else {
                    await b.put(key, {
                      'page': page,
                      'surah': s,
                      'surahName': quran.getSurahNameArabic(s),
                      'juz': j,
                      'timestamp': DateTime.now().millisecondsSinceEpoch,
                    });
                    if (mounted)
                      _snack(context, 'تم حفظ صفحة $page في المحفوظات');
                  }
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isPageBookmarked
                        ? AppColors.gold.withValues(alpha: 0.25)
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.grayLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPageBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isPageBookmarked
                        ? AppColors.gold
                        : (isDark ? Colors.white60 : AppColors.textSecondary),
                    size: 18,
                  ),
                ),
              );
            },
          ),
          // Settings button
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _showSettingsSheet(context, isDark),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.grayLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Feature 10: Settings bottom sheet ──
  void _showSettingsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.darkGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: AppColors.darkGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'إعدادات القارئ',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.darkGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // QCF 604 Ottoman Script toggle
                SwitchListTile(
                  value: _useQcfFont,
                  activeColor: AppColors.darkGreen,
                  contentPadding: EdgeInsets.zero,
                  secondary: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'الخط العثماني لمصحف المدينة (QCF)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'خط مجمع الملك فهد (604 خط لكل صفحة خط مخصص يطابق المصحف المطبوع)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                    ),
                  ),
                  onChanged: (v) {
                    setSheet(() => _useQcfFont = v);
                    setState(() => _useQcfFont = v);
                    _saveSettings();
                  },
                ),
                Divider(color: isDark ? Colors.white12 : AppColors.grayLight),
                const SizedBox(height: 4),
                // Scroll direction toggle
                SwitchListTile(
                  value: _verticalScroll,
                  activeColor: AppColors.darkGreen,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'تمرير رأسي (العرض الديناميكي)',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'يتيح التحكم في حجم الخط والخط العريض',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                    ),
                  ),
                  onChanged: (v) {
                    setSheet(() => _verticalScroll = v);
                    setState(() {
                      _verticalScroll = v;
                      // Rebuild PageController to reset scroll direction
                      final page = _currentPage;
                      _pageController.dispose();
                      _pageController = PageController(initialPage: page);
                    });
                    _saveSettings();
                  },
                ),
                const SizedBox(height: 8),
                // Font size & bold (active only in vertical scroll mode)
                AnimatedOpacity(
                  opacity: _verticalScroll ? 1.0 : 0.45,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_verticalScroll,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_size_rounded,
                              color: AppColors.darkGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'حجم الخط: ${_fontSize.round()}',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (!_verticalScroll) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(متاح في العرض الرأسي فقط)',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 11,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Slider(
                          value: _fontSize,
                          min: 16,
                          max: 36,
                          divisions: 20,
                          activeColor: AppColors.darkGreen,
                          inactiveColor: AppColors.darkGreen.withValues(
                            alpha: 0.2,
                          ),
                          onChanged: (v) {
                            setSheet(() => _fontSize = v);
                            setState(() => _fontSize = v);
                            _saveSettings();
                          },
                        ),
                        SwitchListTile(
                          value: _boldFont,
                          activeColor: AppColors.darkGreen,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'خط عريض (Bold)',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          onChanged: (v) {
                            setSheet(() => _boldFont = v);
                            setState(() => _boldFont = v);
                            _saveSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Feature 9: Instructions section ──
                Divider(color: isDark ? Colors.white12 : AppColors.grayLight),
                const SizedBox(height: 8),
                Text(
                  'ميزات المصحف',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _featureTile(
                  Icons.navigation_rounded,
                  'ميزة التنقل السريع',
                  'اضغط على رقم الصفحة في الأسفل للانتقال إلى أي صفحة',
                  isDark,
                ),
                _featureTile(
                  Icons.share_rounded,
                  'مشاركة وتفسير الآيات',
                  'اضغط على أي آية لعرض خيارات النسخ والمشاركة والتفسير',
                  isDark,
                ),
                _featureTile(
                  Icons.menu_book_rounded,
                  'المصحف الديناميكي',
                  'اضغط مطولاً لتحديد آيات متعددة ومشاركتها كصورة',
                  isDark,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _featureTile(IconData icon, String title, String desc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.darkGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.darkGreen, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark, Color bgColor, Color subtextColor) {
    final canPrev = _currentPage > 0;
    final canNext = _currentPage < 603;
    // Determine if this page starts a new surah or is Al-Fatihah
    final pageData = quran.getPageData(_currentPage + 1).first;
    final s = pageData['surah'] as int;
    final startVerse = pageData['start'] as int;
    final bool useMushafFont = !(s == 1 || startVerse == 1);
    const double mushafFooterFontSize = 14.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Right side in RTL: step back toward the start of the mushaf.
          _navBtn(Icons.arrow_forward_rounded, canPrev, isDark, () {
            _pageController.animateToPage(
              _currentPage - 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }),
          // Feature 9: Tap page number to reveal quick navigation slider
          GestureDetector(
            onTap: () => _showQuickNavPanel(context, isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.darkGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.explore_rounded,
                    size: 14,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_currentPage + 1}',
                    style: useMushafFont
                        ? const TextStyle(
                            fontFamily: 'Al Mushaf',
                            fontSize: mushafFooterFontSize,
                            color: AppColors.darkGreen,
                            fontWeight: FontWeight.bold,
                          )
                        : GoogleFonts.inter(
                            fontSize: mushafFooterFontSize,
                            color: isDark ? Colors.white : AppColors.darkGreen,
                            fontWeight: FontWeight.bold,
                          ),
                  ),
                ],
              ),
            ),
          ),
          // Left side in RTL: advance toward the later pages.
          _navBtn(Icons.arrow_back_rounded, canNext, isDark, () {
            _pageController.animateToPage(
              _currentPage + 1,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }),
        ],
      ),
    );
  }

  // ── Feature 9: Quick Navigation panel ──
  void _showQuickNavPanel(BuildContext context, bool isDark) {
    int selectedPage = _currentPage + 1;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141D17) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setNav) {
          final data = quran.getPageData(selectedPage).first;
          final s = data['surah'] as int;
          final startV = data['start'] as int;
          final j = quran.getJuzNumber(s, startV);
          final surahName = quran.getSurahNameArabic(s);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'السورة السابقة',
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: AppColors.darkGreen,
                          size: 28,
                        ),
                        onPressed: s > 1
                            ? () {
                                final targetPage = quran.getPageNumber(
                                  s - 1,
                                  1,
                                );
                                setNav(() => selectedPage = targetPage);
                                _pageController.jumpToPage(targetPage - 1);
                              }
                            : null,
                      ),
                      Column(
                        children: [
                          Text(
                            '$selectedPage',
                            style: GoogleFonts.amiri(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'سورة $surahName • آية $startV • الجزء $j',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'السورة التالية',
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: AppColors.darkGreen,
                          size: 28,
                        ),
                        onPressed: s < 114
                            ? () {
                                final targetPage = quran.getPageNumber(
                                  s + 1,
                                  1,
                                );
                                setNav(() => selectedPage = targetPage);
                                _pageController.jumpToPage(targetPage - 1);
                              }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(ctx).copyWith(
                      activeTrackColor: AppColors.gold,
                      inactiveTrackColor: AppColors.darkGreen.withValues(
                        alpha: 0.18,
                      ),
                      thumbColor: AppColors.gold,
                      overlayColor: AppColors.gold.withValues(alpha: 0.2),
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 9,
                      ),
                    ),
                    child: Slider(
                      value: selectedPage.toDouble(),
                      min: 1,
                      max: 604,
                      divisions: 603,
                      label: '$selectedPage',
                      onChanged: (v) {
                        final p = v.round();
                        setNav(() => selectedPage = p);
                        _pageController.jumpToPage(p - 1);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 30,
                      itemBuilder: (c, idx) {
                        final juzNum = idx + 1;
                        const juzPages = [
                          1,
                          22,
                          42,
                          62,
                          82,
                          102,
                          122,
                          142,
                          162,
                          182,
                          202,
                          222,
                          242,
                          262,
                          282,
                          302,
                          322,
                          342,
                          362,
                          382,
                          402,
                          422,
                          442,
                          462,
                          482,
                          502,
                          522,
                          542,
                          562,
                          582,
                        ];
                        final isCurJuz = j == juzNum;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ActionChip(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            backgroundColor: isCurJuz
                                ? AppColors.darkGreen
                                : (isDark
                                      ? Colors.white10
                                      : AppColors.paleGreen),
                            label: Text(
                              'جزء $juzNum',
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCurJuz
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white70
                                          : AppColors.darkGreen),
                              ),
                            ),
                            onPressed: () {
                              final p = juzPages[idx];
                              setNav(() => selectedPage = p);
                              _pageController.jumpToPage(p - 1);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Feature 1: Verse Actions sheet with copy, partial copy, share as image, multi-select ──
  void _showVerseActions(BuildContext context, int surah, int verse) {
    final verseText = quran.getVerse(surah, verse);
    final surahName = quran.getSurahNameArabic(surah);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111611) : AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    verseText,
                    style: TextStyle(
                      fontFamily: 'KFGQPC Uthmanic Script Hafs',
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 18,
                      height: 1.8,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'سورة $surahName - آية $verse',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _actionTile(Icons.copy_rounded, 'نسخ الآية كاملة', () {
                  Navigator.pop(ctx);
                  Clipboard.setData(
                    ClipboardData(
                      text: '﴿$verse﴾ $verseText\n- سورة $surahName -',
                    ),
                  );
                  _snack(context, 'تم نسخ الآية');
                }, isDark),
                _actionTile(Icons.content_cut_rounded, 'نسخ جزء من الآية', () {
                  Navigator.pop(ctx);
                  _showPartialCopyDialog(context, surah, verse, isDark);
                }, isDark),
                _actionTile(Icons.image_rounded, 'مشاركة كصورة', () {
                  Navigator.pop(ctx);
                  _shareVersesAsImage(context, surah, [verse]);
                }, isDark),
                _actionTile(Icons.checklist_rounded, 'تحديد آيات متعددة', () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedSurah = surah;
                    _selectedVerses.clear();
                    _selectedVerses.add(verse);
                  });
                  _snack(
                    context,
                    'تم تفعيل التحديد. اضغط على الآيات لإضافتها.',
                  );
                }, isDark),
                _actionTile(Icons.menu_book_rounded, 'التفسير الميسر', () {
                  Navigator.pop(ctx);
                  _showTafseer(
                    context,
                    surah,
                    verse,
                    'ar.muyassar',
                    'التفسير الميسر',
                    isDark,
                  );
                }, isDark),
                _actionTile(Icons.auto_stories_rounded, 'تفسير الجلالين', () {
                  Navigator.pop(ctx);
                  _showTafseer(
                    context,
                    surah,
                    verse,
                    'ar.jalalayn',
                    'تفسير الجلالين',
                    isDark,
                  );
                }, isDark),
                _actionTile(Icons.share_rounded, 'مشاركة نص الآية', () {
                  Navigator.pop(ctx);
                  Share.share(
                    '﴿$verse﴾ $verseText\n\n- سورة $surahName -\n\nبصائر',
                  );
                }, isDark),
                _actionTile(
                  Icons.bookmark_border_rounded,
                  'إضافة علامة',
                  () async {
                    Navigator.pop(ctx);
                    final box = await Hive.openBox('quran_bookmarks');
                    final key = '$surah-$verse';
                    if (box.containsKey(key)) {
                      if (context.mounted)
                        _snack(context, 'الآية موجودة بالفعل في المحفوظات');
                    } else {
                      await box.put(key, {
                        'surah': surah,
                        'verse': verse,
                        'surahName': surahName,
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                      });
                      if (context.mounted)
                        _snack(context, 'تم إضافة العلامة للمحفوظات');
                    }
                  },
                  isDark,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Feature 1: Partial copy & share dialog with SelectableText & dots highlight ──
  void _showPartialCopyDialog(
    BuildContext context,
    int surah,
    int verse,
    bool isDark,
  ) {
    final verseText = quran.getVerse(surah, verse);
    final surahName = quran.getSurahNameArabic(surah);
    final textCtrl = TextEditingController(text: verseText);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF16241D) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.content_cut_rounded,
                  color: AppColors.gold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'اقتطاع جزء من الآية ($surahName - $verse)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.darkGreen,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'يمكنك تحديد أو تعديل النص المراد نسخه ومشاركته (يتم تمييزه بنقاط الاقتباس ···):',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : AppColors.paleGreen,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TextField(
                      controller: textCtrl,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'KFGQPC Uthmanic Script Hafs',
                        fontSize: 18,
                        height: 1.8,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  final portion = textCtrl.text.trim();
                  if (portion.isEmpty) return;
                  final highlighted = '··· $portion ···';
                  Clipboard.setData(
                    ClipboardData(
                      text:
                          '$highlighted\n\n- جزء من آية $verse سورة $surahName -\nتطبيق بصائر',
                    ),
                  );
                  Navigator.pop(ctx);
                  _snack(context, 'تم نسخ الجزء مع نقاط التمييز (···)');
                },
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: AppColors.darkGreen,
                ),
                label: Text(
                  'نسخ مع نقاط (···)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final portion = textCtrl.text.trim();
                  if (portion.isEmpty) return;
                  Navigator.pop(ctx);
                  _sharePartialAsImage(context, surah, verse, portion);
                },
                icon: const Icon(
                  Icons.image_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  'مشاركة كصورة (···)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Feature 1: Share partial verse with ornamental dots highlight ──
  Future<void> _sharePartialAsImage(
    BuildContext context,
    int surah,
    int verse,
    String partialText,
  ) async {
    final surahName = quran.getSurahNameArabic(surah);
    final key = GlobalKey();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111611) : AppColors.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: key,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Base frosted green gradient layer
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF091610),
                                Color(0xFF132B1F),
                                Color(0xFF08120D),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // Frosted glass: blur the green layer beneath, translucent white tint
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      // Content with gold frame on a transparent top container
                      Container(
                        width: 340,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gold, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gold.withValues(alpha: 0.25),
                                    AppColors.darkGreen.withValues(alpha: 0.35),
                                  ],
                                ),
                                border: Border.all(
                                  color: AppColors.gold,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                'سورة $surahName • آية $verse',
                                style: GoogleFonts.amiri(
                                  color: AppColors.gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            // Partial text with decorative quotation dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.more_horiz_rounded,
                                  color: AppColors.gold,
                                  size: 24,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '«',
                                  style: GoogleFonts.amiri(
                                    fontSize: 22,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Text(
                                partialText,
                                style: const TextStyle(
                                  fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                  color: Colors.white,
                                  fontSize: 20,
                                  height: 1.85,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '»',
                                  style: GoogleFonts.amiri(
                                    fontSize: 22,
                                    color: AppColors.gold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.more_horiz_rounded,
                                  color: AppColors.gold,
                                  size: 24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              height: 1,
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_stories_rounded,
                                  color: AppColors.gold.withValues(alpha: 0.8),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'اقتباس قرآني • بصائر',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final ro = key.currentContext?.findRenderObject();
                          if (ro is! RenderRepaintBoundary) return;
                          final img = await ro.toImage(pixelRatio: 3.0);
                          final bd = await img.toByteData(
                            format: ui.ImageByteFormat.png,
                          );
                          if (bd == null) return;
                          final tempDir = await getTemporaryDirectory();
                          final file = File(
                            '${tempDir.path}/verse_partial_${surah}_$verse.png',
                          );
                          await file.writeAsBytes(bd.buffer.asUint8List());
                          if (context.mounted) Navigator.pop(ctx);
                          await Share.shareXFiles(
                            [XFile(file.path)],
                            text: '﴿ $partialText ﴾ - سورة $surahName ($verse)',
                          );
                        } catch (e) {
                          debugPrint('Share partial error: $e');
                        }
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('مشاركة الآن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Feature 1: Sleek multi-verse share as image ──
  Future<void> _shareVersesAsImage(
    BuildContext context,
    int surah,
    List<int> verses,
  ) async {
    final sortedVerses = verses.toList()..sort();
    final surahName = quran.getSurahNameArabic(surah);
    final key = GlobalKey();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-aware card colors
    final cardBg = isDark ? const Color(0xFF06100A) : const Color(0xFFFAF8F2);
    final verseTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtleTextColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF1E293B).withValues(alpha: 0.45);
    final glowColor = isDark
        ? const Color(0xFFD4A843)
        : AppColors.gold.withValues(alpha: 0.18);
    final cardBorderColor =
        AppColors.gold.withValues(alpha: isDark ? 0.4 : 0.55);
    final backdropTint = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.01);
    final dividerColor = AppColors.gold.withValues(alpha: isDark ? 0.2 : 0.4);
    final dialogBg = isDark ? const Color(0xFF111611) : AppColors.cardBg;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: key,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: cardBorderColor,
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Gold glow top-right
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: const Alignment(0.8, -0.8),
                                radius: 1.2,
                                colors: [glowColor, Colors.transparent],
                                stops: const [0.0, 0.55],
                              ),
                            ),
                          ),
                        ),
                        // Frosted glass
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: 14,
                              sigmaY: 14,
                            ),
                            child: Container(
                              color: backdropTint,
                            ),
                          ),
                        ),
                        // Inner content
                        Container(
                          width: 360,
                          padding: const EdgeInsets.all(26),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Surah name badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFD4A843),
                                      Color(0xFFB8860B),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'سورة $surahName',
                                  style: GoogleFonts.amiri(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Ornamental divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.4,
                                      ),
                                      thickness: 0.8,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      '◆',
                                      style: TextStyle(
                                        color: AppColors.gold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.4,
                                      ),
                                      thickness: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Verses
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 380,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: sortedVerses.map((v) {
                                      final text = quran.getVerse(surah, v);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              text,
                                              textAlign: TextAlign.center,
                                              textDirection: TextDirection.rtl,
                                              style: TextStyle(
                                                fontFamily:
                                                    'KFGQPC Uthmanic Script Hafs',
                                                color: verseTextColor,
                                                fontSize: 20,
                                                height: 1.9,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '﴿ $v ﴾',
                                              style: GoogleFonts.amiri(
                                                color: AppColors.gold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Bottom divider and branding
                              Divider(color: dividerColor),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'بصائر',
                                    style: TextStyle(
                                      color: subtleTextColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                                    style: TextStyle(
                                      color: subtleTextColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.gold.withValues(alpha: 0.75),
                          ),
                          foregroundColor: AppColors.gold.withValues(
                            alpha: 0.75,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          'إلغاء',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: AppColors.gold.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD4A843), Color(0xFFB8860B)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () async {
                            try {
                              final boundary =
                                  key.currentContext!.findRenderObject()
                                      as RenderRepaintBoundary;
                              final image = await boundary.toImage(
                                pixelRatio: 3.0,
                              );
                              final byteData = await image.toByteData(
                                format: ui.ImageByteFormat.png,
                              );
                              final bytes = byteData!.buffer.asUint8List();
                              final dir = await getTemporaryDirectory();
                              final file = File(
                                '${dir.path}/ayah_${surah}_${sortedVerses.join("_")}.png',
                              );
                              await file.writeAsBytes(bytes);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              final verseRange = sortedVerses.length == 1
                                  ? 'آية ${sortedVerses.first}'
                                  : 'آيات ${sortedVerses.first}-${sortedVerses.last}';
                              await Share.shareXFiles([
                                XFile(file.path),
                              ], text: 'سورة $surahName - $verseRange\nبصائر');
                            } catch (e) {
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _snack(context, 'حدث خطأ في المشاركة');
                            }
                          },
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: Text(
                            'مشاركة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isDark,
  ) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.darkGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.darkGreen, size: 18),
      ),
      title: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: DirectionalIcon(
        isBack: false,
        size: 12,
        color: isDark ? Colors.white24 : AppColors.gray,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.ibmPlexSansArabic()),
        backgroundColor: AppColors.darkGreen,
      ),
    );
  }

  Future<void> _showTafseer(
    BuildContext context,
    int surah,
    int verse,
    String edition,
    String title,
    bool isDark,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: AppColors.darkGreen),
      ),
    );

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.alquran.cloud/v1/ayah/$surah:$verse/$edition',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (!context.mounted) return;
      Navigator.pop(context);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tafseerText = data['data']['text'];
        _showTafseerDialog(context, surah, verse, tafseerText, title, isDark);
      } else {
        _snack(context, 'تعذر جلب التفسير. حاول مرة أخرى.');
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      _snack(context, 'لا يوجد اتصال بالإنترنت أو الخادم لا يستجيب.');
    }
  }

  void _showTafseerDialog(
    BuildContext context,
    int surah,
    int verse,
    String text,
    String title,
    bool isDark,
  ) {
    final surahName = quran.getSurahNameArabic(surah);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111611) : AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.lightGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'سورة $surahName - آية $verse',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'KFGQPC Uthmanic Script Hafs',
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 20,
                      height: 1.8,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, bool enabled, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.darkGreen.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          textDirection: TextDirection.ltr,
          size: 22,
          color: enabled
              ? AppColors.darkGreen
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
    );
  }
}

// ─── QCF (King Fahd Complex 604 Page Fonts) Ottoman Page Container ───
class _QcfPageContainer extends StatefulWidget {
  final int pageNumber;
  final bool isDark;
  final int? highlightSurah;
  final int? highlightVerse;
  final void Function(int surah, int verse) onVerseTap;
  final void Function(int surah, int verse) onVerseLongPress;

  const _QcfPageContainer({
    required this.pageNumber,
    required this.isDark,
    this.highlightSurah,
    this.highlightVerse,
    required this.onVerseTap,
    required this.onVerseLongPress,
  });

  @override
  State<_QcfPageContainer> createState() => _QcfPageContainerState();
}

class _QcfPageContainerState extends State<_QcfPageContainer> {
  bool _initialized = Mushaf.isInitialized;

  @override
  void initState() {
    super.initState();
    if (!_initialized) {
      _initMushaf();
    }
  }

  Future<void> _initMushaf() async {
    try {
      await Mushaf.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.darkGreen),
            const SizedBox(height: 12),
            Text(
              'جارٍ تحميل الخط العثماني (QCF)...',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                color: widget.isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final bg = widget.isDark ? const Color(0xFF0B120D) : const Color(0xFFFBF8F2);
    final surahNamesMap = <int, String>{
      for (int i = 1; i <= 114; i++) i: quran.getSurahNameArabic(i),
    };

    MushafAyahRef? highRef;
    if (widget.highlightSurah != null && widget.highlightVerse != null) {
      highRef = MushafAyahRef(
        surahId: widget.highlightSurah!,
        ayahNumber: widget.highlightVerse!,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: HafsQcf4PageView(
          page: widget.pageNumber,
          fontScale: 1.0,
          surahNames: surahNamesMap,
          highlightedAyah: highRef,
          style: MushafStyle(
            ink: widget.isDark ? Colors.white : AppColors.textPrimary,
            muted: widget.isDark ? Colors.white70 : AppColors.textSecondary,
            accent: AppColors.darkGreen,
            accentContainer: AppColors.gold.withValues(alpha: 0.25),
            background: bg,
          ),
          onAyahLongPress: (ref) {
            widget.onVerseLongPress(ref.surahId, ref.ayahNumber);
          },
        ),
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
  final Set<int> selectedVerses;
  final int? selectedSurah;
  final double readerFontSize;
  final bool boldFont;
  final bool verticalScroll;
  final bool useQcfFont;
  final void Function(int surah, int verse) onVerseTap;
  final void Function(int surah, int verse) onVerseLongPress;

  const _MushafPageWidget({
    required this.pageNumber,
    this.highlightSurah,
    this.highlightVerse,
    required this.isDark,
    this.selectedVerses = const {},
    this.selectedSurah,
    this.readerFontSize = 22.0,
    this.boldFont = false,
    this.verticalScroll = false,
    this.useQcfFont = true,
    required this.onVerseTap,
    required this.onVerseLongPress,
  });

  @override
  State<_MushafPageWidget> createState() => _MushafPageWidgetState();
}

class _MushafPageWidgetState extends State<_MushafPageWidget>
    with AutomaticKeepAliveClientMixin {
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
    if (_cachedFontSize != null &&
        _cachedWidth == availableW &&
        _cachedHeight == availableH) {
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

    if (widget.useQcfFont && !widget.verticalScroll) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: _DecoratedMushafFrame(
          isDark: isDark,
          child: _QcfPageContainer(
            pageNumber: pageNumber,
            isDark: isDark,
            highlightSurah: highlightSurah,
            highlightVerse: highlightVerse,
            onVerseTap: widget.onVerseTap,
            onVerseLongPress: widget.onVerseLongPress,
          ),
        ),
      );
    }

    final pageData = quran.getPageData(pageNumber);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: _DecoratedMushafFrame(
        isDark: isDark,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableW = constraints.maxWidth;
            final availableH = constraints.maxHeight;
            final effectiveFontSize = widget.verticalScroll
                ? widget.readerFontSize
                : _computeFontSize(pageData, availableW, availableH);

            // Build the list of surah blocks
            final blocks = <Widget>[];
            for (int i = 0; i < pageData.length; i++) {
              final data = pageData[i];
              final surah = data['surah'] as int;
              final start = data['start'] as int;
              final end = data['end'] as int;
              final isLast = i == pageData.length - 1;

              final block = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (start == 1)
                    _buildSurahHeader(context, surah, effectiveFontSize),
                  if (start == 1 && surah != 1 && surah != 9)
                    _buildBasmala(effectiveFontSize),
                  _buildVersesBlock(
                    context,
                    surah,
                    start,
                    end,
                    effectiveFontSize,
                  ),
                ],
              );

              // In horizontal Mushaf mode, expand the last block to fill page frame.
              // In vertical scroll mode, let it flow naturally with scroll view.
              if (widget.verticalScroll) {
                blocks.add(block);
              } else {
                blocks.add(isLast ? Expanded(child: block) : block);
              }
            }

            if (widget.verticalScroll) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: _hPad,
                  vertical: _vPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: blocks,
                ),
              );
            }

            return SizedBox(
              width: availableW,
              height: availableH,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _hPad,
                  vertical: _vPad,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: blocks,
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
      final end = data['end'] as int;

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
    final marginV = fontSize * 0.15 * 2;
    final paddingV = fontSize * 0.4 * 2;
    const border = 3.0; // 1.5 * 2
    final titleFS = (fontSize * 1.4).clamp(16.0, 28.0);
    // Line height for Arabic display font is ~1.35 of em.
    final contentH = titleFS * 1.35;
    return marginV + paddingV + border + contentH;
  }

  double _measureBasmalaHeight(double fontSize) {
    final marginV = fontSize * 0.3 + fontSize * 0.1;
    final paddingV = fontSize * 0.2 * 2;
    const border = 2.0;
    final textFS = (fontSize * 1.3).clamp(14.0, 30.0);
    final contentH = textFS * 1.35;
    return marginV + paddingV + border + contentH;
  }

  double _measureVersesHeight(
    int surah,
    int start,
    int end,
    double fontSize,
    double width,
  ) {
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
      spans.add(
        TextSpan(
          text: t,
          style: TextStyle(
            fontFamily: 'KFGQPC Uthmanic Script Hafs',
            fontSize: fontSize,
            height: _lineHeight,
          ),
        ),
      );
      spans.add(
        const WidgetSpan(child: SizedBox()),
      ); // placeholder (dims set below)
      spans.add(
        TextSpan(
          text: ' ',
          style: TextStyle(
            fontFamily: 'KFGQPC Uthmanic Script Hafs',
            fontSize: fontSize,
            height: _lineHeight,
          ),
        ),
      );
    }

    final verseCount = end - start + 1;
    final tp = TextPainter(
      text: TextSpan(children: spans),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.justify,
    );
    tp.setPlaceholderDimensions(
      List.generate(
        verseCount,
        (_) => PlaceholderDimensions(
          size: Size(markBoxW, markSize),
          alignment: PlaceholderAlignment.middle,
        ),
      ),
    );
    tp.layout(maxWidth: width);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  Widget _buildSurahHeader(BuildContext context, int surah, double fontSize) {
    final verseCount = quran.getVerseCount(surah);
    final place = quran.getPlaceOfRevelation(surah) == "Makkah"
        ? "مكية"
        : "مدنية";
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: fontSize * 0.15),
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.8,
        vertical: fontSize * 0.4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkGreen.withValues(alpha: 0.25),
            AppColors.darkGreen.withValues(alpha: 0.10),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.darkGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$place • $verseCount آية',
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? Colors.white60 : AppColors.textSecondary,
              fontSize: (fontSize * 0.6).clamp(9.0, 13.0),
            ),
          ),
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
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.5,
        vertical: fontSize * 0.2,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.darkGreen.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.darkGreen.withValues(alpha: 0.3),
            width: 1,
          ),
          top: BorderSide(
            color: AppColors.darkGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.darkGreen.withValues(alpha: 0.8),
              size: fontSize * 0.9,
            ),
            SizedBox(width: fontSize * 0.4),
            Text(
              quran.basmala,
              style: TextStyle(
                fontFamily: 'KFGQPC Uthmanic Script Hafs',
                fontSize: (fontSize * 1.3).clamp(14.0, 30.0),
                color: isDark ? Colors.white : AppColors.textPrimary,
                shadows: isDark
                    ? [
                        const Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(width: fontSize * 0.4),
            Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.darkGreen.withValues(alpha: 0.8),
              size: fontSize * 0.9,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersesBlock(
    BuildContext context,
    int surah,
    int start,
    int end,
    double fontSize,
  ) {
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

      final bool isHighlighted =
          (highlightSurah != null &&
          highlightVerse != null &&
          highlightSurah == surah &&
          highlightVerse == v);

      spans.add(
        TextSpan(
          text: verseText,
          style: TextStyle(
            fontFamily: 'KFGQPC Uthmanic Script Hafs',
            fontSize: fontSize,
            fontWeight: (widget.verticalScroll && widget.boldFont)
                ? FontWeight.bold
                : FontWeight.normal,
            height: 1.8,
            color: isHighlighted
                ? Colors.black
                : (isDark ? const Color(0xFFF5F0E8) : AppColors.textPrimary),
            backgroundColor: isHighlighted
                ? Colors.yellow.withValues(alpha: 0.18)
                : null,
          ),
        ),
      );
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _AyahEndMark(
            number: v,
            isDark: isDark,
            size: (fontSize * 1.5).clamp(24.0, 38.0),
          ),
        ),
      );
      // Space character after mark
      spans.add(
        TextSpan(
          text: ' ',
          style: TextStyle(
            fontFamily: 'KFGQPC Uthmanic Script Hafs',
            fontSize: fontSize,
            height: 1.8,
          ),
        ),
      );
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.darkGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    verseText,
                    style: TextStyle(
                      fontFamily: 'KFGQPC Uthmanic Script Hafs',
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 18,
                      height: 1.8,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'سورة $surahName - آية $verse',
                  style: GoogleFonts.ibmPlexSansArabic(
                    color: AppColors.darkGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _actionTile(Icons.copy_rounded, 'نسخ الآية', () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: verseText));
                  _snack(context, 'تم نسخ الآية');
                }),
                _actionTile(Icons.menu_book_rounded, 'التفسير الميسر', () {
                  Navigator.pop(ctx);
                  _showTafseer(
                    context,
                    surah,
                    verse,
                    'ar.muyassar',
                    'التفسير الميسر',
                  );
                }),
                _actionTile(Icons.auto_stories_rounded, 'تفسير الجلالين', () {
                  Navigator.pop(ctx);
                  _showTafseer(
                    context,
                    surah,
                    verse,
                    'ar.jalalayn',
                    'تفسير الجلالين',
                  );
                }),
                _actionTile(Icons.share_rounded, 'مشاركة نص', () {
                  Navigator.pop(ctx);
                  Share.share(
                    '﴿$verse﴾ $verseText\n\n- سورة $surahName -\n\nبصائر',
                  );
                }),
                _actionTile(Icons.image_rounded, 'مشاركة كصورة', () {
                  Navigator.pop(ctx);
                  _shareAsImage(context, surah, verse);
                }),
                _actionTile(
                  Icons.bookmark_border_rounded,
                  'إضافة علامة',
                  () async {
                    Navigator.pop(ctx);
                    final box = await Hive.openBox('quran_bookmarks');
                    final key = '$surah-$verse';
                    if (box.containsKey(key)) {
                      if (context.mounted)
                        _snack(context, 'الآية موجودة بالفعل في المحفوظات');
                    } else {
                      await box.put(key, {
                        'surah': surah,
                        'verse': verse,
                        'surahName': surahName,
                        'timestamp': DateTime.now().millisecondsSinceEpoch,
                      });
                      if (context.mounted)
                        _snack(context, 'تم إضافة العلامة للمحفوظات');
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
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
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.darkGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.darkGreen, size: 18),
      ),
      title: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          color: isDark ? Colors.white : AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: DirectionalIcon(
        isBack: false,
        size: 12,
        color: isDark ? Colors.white24 : AppColors.gray,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.ibmPlexSansArabic()),
        backgroundColor: AppColors.darkGreen,
      ),
    );
  }

  Future<void> _showTafseer(
    BuildContext context,
    int surah,
    int verse,
    String edition,
    String title,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(
        child: CircularProgressIndicator(color: AppColors.darkGreen),
      ),
    );

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.alquran.cloud/v1/ayah/$surah:$verse/$edition',
            ),
          )
          .timeout(const Duration(seconds: 10));
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

  void _showTafseerDialog(
    BuildContext context,
    int surah,
    int verse,
    String text,
    String title,
  ) {
    final surahName = quran.getSurahNameArabic(surah);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111611) : AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.ibmPlexSansArabic(
                  color: AppColors.lightGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'سورة $surahName - آية $verse',
                style: GoogleFonts.ibmPlexSansArabic(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'KFGQPC Uthmanic Script Hafs',
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 20,
                      height: 1.8,
                    ),
                    textAlign: TextAlign.justify,
                  ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: key,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 340,
                    padding: const EdgeInsets.all(0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF0B301D).withValues(alpha: 0.94),
                          const Color(0xFF13482E).withValues(alpha: 0.88),
                          const Color(0xFF1E5E3D).withValues(alpha: 0.82),
                          const Color(0xFF0E2819).withValues(alpha: 0.96),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B7A4E).withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _ArabesqueWatermarkPainter(),
                      child: Stack(
                        children: [
                          // Gold geometric border
                          Positioned.fill(
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(
                                    0xFFD4A843,
                                  ).withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFD4A843,
                                    ).withValues(alpha: 0.25),
                                    width: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(26),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Top: App branding
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFD4A843,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFD4A843,
                                          ).withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.auto_awesome_rounded,
                                            color: Color(0xFFD4A843),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'آية كريمة',
                                            style:
                                                GoogleFonts.ibmPlexSansArabic(
                                                  color: const Color(
                                                    0xFFD4A843,
                                                  ),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'بصائر',
                                          style: GoogleFonts.amiri(
                                            color: const Color(0xFFD4A843),
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(
                                                0xFFD4A843,
                                              ).withValues(alpha: 0.6),
                                              width: 1,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.eco_rounded,
                                            color: Color(0xFFD4A843),
                                            size: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Verse text in elegant font
                                Text(
                                  verseText,
                                  style: const TextStyle(
                                    fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                    color: Color(0xFFFBF8F1),
                                    fontSize: 22,
                                    height: 1.95,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                // Ornamental gold frame for surah name + verse number
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(
                                        0xFFD4A843,
                                      ).withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(
                                          0xFFD4A843,
                                        ).withValues(alpha: 0.1),
                                        const Color(
                                          0xFFD4A843,
                                        ).withValues(alpha: 0.2),
                                        const Color(
                                          0xFFD4A843,
                                        ).withValues(alpha: 0.1),
                                      ],
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '◈',
                                        style: GoogleFonts.amiri(
                                          color: const Color(0xFFD4A843),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'سورة $surahName',
                                        style: GoogleFonts.amiri(
                                          color: const Color(0xFFD4A843),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '﴿ $verse ﴾',
                                        style: GoogleFonts.amiri(
                                          color: const Color(
                                            0xFFD4A843,
                                          ).withValues(alpha: 0.85),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '◈',
                                        style: GoogleFonts.amiri(
                                          color: const Color(0xFFD4A843),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Divider(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'تطبيق بصائر للقرآن الكريم والعبادات',
                                      style: GoogleFonts.ibmPlexSansArabic(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'إلغاء',
                          style: GoogleFonts.ibmPlexSansArabic(
                            color: isDark
                                ? Colors.white60
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          try {
                            final boundary =
                                key.currentContext!.findRenderObject()
                                    as RenderRepaintBoundary;
                            final image = await boundary.toImage(
                              pixelRatio: 3.0,
                            );
                            final byteData = await image.toByteData(
                              format: ui.ImageByteFormat.png,
                            );
                            final bytes = byteData!.buffer.asUint8List();
                            final dir = await getTemporaryDirectory();
                            final file = File(
                              '${dir.path}/ayah_${surah}_$verse.png',
                            );
                            await file.writeAsBytes(bytes);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            await Share.shareXFiles([
                              XFile(file.path),
                            ], text: 'سورة $surahName - آية $verse\nبصائر');
                          } catch (e) {
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            _snack(context, 'حدث خطأ في المشاركة');
                          }
                        },
                        child: Text(
                          'مشاركة',
                          style: GoogleFonts.ibmPlexSansArabic(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
  const _AyahEndMark({
    required this.number,
    required this.isDark,
    this.size = 32,
  });
  String _toArabic(int n) {
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((e) => ar[int.parse(e)]).join('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: size * 0.08),
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.circle_outlined,
            size: size,
            color: AppColors.darkGreen.withValues(alpha: 0.7),
          ),
          Text(
            _toArabic(number),
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
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
        ? const Color(0xFF0E1B13)
        : const Color(0xFFF4F9F5);
    final fillEnd = isDark ? const Color(0xFF081209) : const Color(0xFFE8F2EC);

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
              top: 4,
              right: 4,
              child: _Corner(color: cornerColor, alignment: Alignment.topRight),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: _Corner(color: cornerColor, alignment: Alignment.topLeft),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: _Corner(
                color: cornerColor,
                alignment: Alignment.bottomRight,
              ),
            ),
            Positioned(
              bottom: 4,
              left: 4,
              child: _Corner(
                color: cornerColor,
                alignment: Alignment.bottomLeft,
              ),
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
    final maxIndex = (position.maxScrollExtent / position.viewportDimension)
        .round();
    target = target.clamp(0.0, maxIndex.toDouble());
    return target * position.viewportDimension;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position is! ScrollPosition)
      return super.createBallisticSimulation(position, velocity);
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

class _ArabesqueWatermarkPainter extends CustomPainter {
  const _ArabesqueWatermarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4A843).withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    for (double r = 40; r <= 160; r += 40) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
