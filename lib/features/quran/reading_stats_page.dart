import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_colors.dart';

class ReadingStatsPage extends StatefulWidget {
  const ReadingStatsPage({super.key});

  @override
  State<ReadingStatsPage> createState() => _ReadingStatsPageState();
}

class _ReadingStatsPageState extends State<ReadingStatsPage> {
  bool _isLoading = true;
  bool _loadFailed = false;
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalSeconds = 0;
  int _completedPages = 0;
  int _todaySeconds = 0;
  int _todaySessions = 0;
  int _weekSeconds = 0;
  List<_ReadingActivity> _activity = [];
  Set<String> _activeDayKeys = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final readingBox = await Hive.openBox('reading_stats');
      final progressBox = await Hive.openBox('quran_progress');
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final activeDays = <DateTime>{};
      final activity = <_ReadingActivity>[];
      var totalSeconds = 0;
      var todaySeconds = 0;
      var todaySessions = 0;
      var weekSeconds = 0;

      for (final key in readingBox.keys) {
        if (key is! String) continue;
        final date = DateTime.tryParse(key);
        final rawSessions = readingBox.get(key);
        if (date == null || rawSessions is! List || rawSessions.isEmpty) {
          continue;
        }

        final day = DateTime(date.year, date.month, date.day);
        activeDays.add(day);
        for (final rawSession in rawSessions) {
          if (rawSession is! Map) continue;
          final session = Map<String, dynamic>.from(rawSession);
          final duration = session['duration'] is num
              ? (session['duration'] as num).toInt()
              : 0;
          totalSeconds += duration;
          if (day == today) {
            todaySeconds += duration;
            todaySessions++;
          }
          if (!day.isBefore(today.subtract(const Duration(days: 6)))) {
            weekSeconds += duration;
          }
          activity.add(
            _ReadingActivity(
              date: day,
              durationSeconds: duration,
              startPage: session['startPage'] is num
                  ? (session['startPage'] as num).toInt()
                  : null,
              endPage: session['endPage'] is num
                  ? (session['endPage'] as num).toInt()
                  : null,
              startTime: session['start'] is num
                  ? (session['start'] as num).toInt()
                  : 0,
            ),
          );
        }
      }

      final completedPages = <int>{};
      for (final key in progressBox.keys) {
        if (key is! String || !key.startsWith('read_pages_')) continue;
        final pages = progressBox.get(key);
        if (pages is! List) continue;
        if (pages.isNotEmpty) {
          final date = DateTime.tryParse(key.substring('read_pages_'.length));
          if (date != null) {
            activeDays.add(DateTime(date.year, date.month, date.day));
          }
        }
        for (final page in pages) {
          if (page is int && page >= 1 && page <= 604) {
            completedPages.add(page);
          }
        }
      }
      final currentStreak = _calculateCurrentStreak(activeDays, today);
      final longestStreak = _calculateLongestStreak(activeDays);

      activity.sort((a, b) {
        final dateOrder = b.date.compareTo(a.date);
        return dateOrder != 0 ? dateOrder : b.startTime.compareTo(a.startTime);
      });

      if (!mounted) return;
      setState(() {
        _currentStreak = currentStreak;
        _longestStreak = longestStreak;
        _totalSeconds = totalSeconds;
        _completedPages = completedPages.length;
        _todaySeconds = todaySeconds;
        _todaySessions = todaySessions;
        _weekSeconds = weekSeconds;
        _activity = activity.take(8).toList();
        _activeDayKeys = activeDays.map(_dateKey).toSet();
        _loadFailed = false;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading reading stats: $error');
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _isLoading = false;
        });
      }
    }
  }

  int _calculateCurrentStreak(Set<DateTime> activeDays, DateTime today) {
    var cursor = activeDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    if (!activeDays.contains(cursor)) return 0;

    var streak = 0;
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _calculateLongestStreak(Set<DateTime> activeDays) {
    final sortedDays = activeDays.toList()..sort();
    var longest = 0;
    var current = 0;
    DateTime? previous;

    for (final day in sortedDays) {
      current = previous != null && day.difference(previous).inDays == 1
          ? current + 1
          : 1;
      if (current > longest) longest = current;
      previous = day;
    }
    return longest;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF121A16)
        : const Color(0xFFF6F8F5);
    final completedPercent = _completedPages / 604;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: isDark
              ? const Color(0xFF0B120D)
              : AppColors.darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'إحصائيات المصحف',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.darkGreen),
              )
            : _loadFailed
            ? _buildLoadError(isDark)
            : RefreshIndicator(
                onRefresh: _loadStats,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildStreakCard(isDark),
                    const SizedBox(height: 18),
                    _sectionTitle('التقدم والالتزام', isDark),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final completionCard = _buildProgressCard(
                          title: 'إتمام الصفحات',
                          value: '${(completedPercent * 100).round()}%',
                          detail: '$_completedPages من 604 صفحة',
                          icon: Icons.menu_book_rounded,
                          color: AppColors.midGreen,
                          isDark: isDark,
                          progress: completedPercent,
                        );
                        final engagementCard = _buildMetricCard(
                          title: 'وقت التفاعل',
                          value: _formatClock(_totalSeconds),
                          detail:
                              'هذا الأسبوع ${_formatDuration(_weekSeconds)}',
                          icon: Icons.access_time_rounded,
                          color: const Color(0xFF21B978),
                          isDark: isDark,
                        );
                        if (constraints.maxWidth < 360) {
                          return Column(
                            children: [
                              completionCard,
                              const SizedBox(height: 10),
                              engagementCard,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: completionCard),
                            const SizedBox(width: 10),
                            Expanded(child: engagementCard),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildMetricCard(
                      title: 'قراءة اليوم',
                      value: _formatDuration(_todaySeconds),
                      detail: '$_todaySessions جلسة قراءة اليوم',
                      icon: Icons.auto_stories_rounded,
                      color: AppColors.gold,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(child: _sectionTitle('النشاط الأخير', isDark)),
                        Text(
                          '${_activity.length} جلسات',
                          style: _textStyle(
                            isDark,
                            size: 12,
                            color: AppColors.midGreen,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_activity.isEmpty)
                      _buildEmptyActivity(isDark)
                    else
                      ..._activity.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildActivityCard(item, isDark),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadError(bool isDark) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'تعذر تحميل إحصائيات القراءة',
            style: _textStyle(
              isDark,
              size: 15,
              weight: FontWeight.w600,
              color: null,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadStats,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );

  Widget _buildStreakCard(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1D2B24) : Colors.white;
    final muted = isDark ? Colors.white70 : const Color(0xFF63756B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE0E9E3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF27C787).withValues(alpha: 0.1),
                  border: Border.all(color: const Color(0xFF27C787), width: 5),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFF39A1E),
                  size: 38,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_currentStreak يوم',
                      style: _textStyle(
                        isDark,
                        size: 28,
                        weight: FontWeight.w800,
                        color: const Color(0xFF168D5C),
                      ),
                    ),
                    Text(
                      'سلسلة القراءة الحالية',
                      style: _textStyle(isDark, size: 13, color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'مشاركة إنجاز السلسلة',
                onPressed: () => _showStreakShareDialog(isDark),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: Color(0xFF168D5C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF27C787).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: List.generate(7, (index) {
                final day = DateTime.now().subtract(Duration(days: 6 - index));
                final key = _dateKey(day);
                final active = _activeDayKeys.contains(key);
                const labels = ['اث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        labels[day.weekday - 1],
                        style: _textStyle(
                          isDark,
                          size: 11,
                          color: muted,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? const Color(0xFF27C787)
                              : Colors.transparent,
                          border: Border.all(
                            color: active
                                ? const Color(0xFF27C787)
                                : muted.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          active ? Icons.check_rounded : Icons.circle_outlined,
                          size: 17,
                          color: active ? Colors.white : muted,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 19),
              const SizedBox(width: 6),
              Text(
                'أطول سلسلة: $_longestStreak يوم',
                style: _textStyle(
                  isDark,
                  size: 13,
                  weight: FontWeight.w700,
                  color: const Color(0xFF168D5C),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showStreakShareDialog(isDark),
                child: Text(
                  'مشاركة السلسلة',
                  style: _textStyle(
                    isDark,
                    size: 12,
                    color: const Color(0xFF168D5C),
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required String value,
    required String detail,
    required IconData icon,
    required Color color,
    required bool isDark,
    required double progress,
  }) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricHeading(title, icon, color, isDark),
          const SizedBox(height: 12),
          Text(
            value,
            style: _textStyle(
              isDark,
              size: 25,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              color: color,
            ),
          ),
          const SizedBox(height: 7),
          Text(detail, style: _textStyle(isDark, size: 11, color: null)),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String detail,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return _card(
      isDark,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _textStyle(isDark, size: 12, color: null)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: _textStyle(
                    isDark,
                    size: 20,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(detail, style: _textStyle(isDark, size: 11, color: null)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(_ReadingActivity activity, bool isDark) {
    final pagesRead = activity.startPage != null && activity.endPage != null
        ? (activity.endPage! - activity.startPage!).abs() + 1
        : 0;
    final detail = pagesRead > 0
        ? '${_formatDuration(activity.durationSeconds)} • $pagesRead صفحة'
        : _formatDuration(activity.durationSeconds);

    return _card(
      isDark,
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFF21B978),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(activity.date),
                  style: _textStyle(
                    isDark,
                    size: 14,
                    weight: FontWeight.w600,
                    color: null,
                  ),
                ),
                Text(detail, style: _textStyle(isDark, size: 12, color: null)),
              ],
            ),
          ),
          Icon(
            Icons.chevron_left_rounded,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity(bool isDark) {
    return _card(
      isDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'ابدأ القراءة اليوم لتظهر جلساتك هنا',
            style: _textStyle(isDark, size: 13, color: null),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildShareCard(double width) {
    final congratulations = _currentStreak > 0
        ? 'ما شاء الله! واصلت قراءة القرآن $_currentStreak يومًا متتاليًا.'
        : 'ابدأ اليوم صفحة جديدة مع القرآن الكريم.';

    return Container(
      width: width,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE9E0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFFF39A1E),
            size: 48,
          ),
          const SizedBox(height: 8),
          Text(
            'إنجاز قرآني',
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF168D5C),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_currentStreak يوم',
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF168D5C),
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          Text(
            'سلسلة قراءة متواصلة',
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF62756A),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F8F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              congratulations,
              style: GoogleFonts.ibmPlexSansArabic(
                color: const Color(0xFF244A36),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'أطول سلسلة: $_longestStreak يوم',
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF6D7B72),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFDCE9E0)),
          Text(
            'بصائر • رفيقك في رحلة القرآن',
            style: GoogleFonts.ibmPlexSansArabic(
              color: const Color(0xFF718078),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showStreakShareDialog(bool isDark) async {
    final key = GlobalKey();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final cardWidth = (MediaQuery.sizeOf(dialogContext).width - 72)
            .clamp(200.0, 340.0)
            .toDouble();
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: isDark ? const Color(0xFF1D2B24) : Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(key: key, child: _buildShareCard(cardWidth)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('إغلاق'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _shareStreakImage(dialogContext, key),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('مشاركة'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.darkGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareStreakImage(
    BuildContext dialogContext,
    GlobalKey key,
  ) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final renderObject = key.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Streak image is not ready to capture');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('Unable to encode streak image');
        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}/reading_streak_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
        if (!dialogContext.mounted) return;
        Navigator.pop(dialogContext);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'سلسلة قراءة القرآن: $_currentStreak يوم. ما شاء الله!');
      } finally {
        image.dispose();
      }
    } catch (error) {
      debugPrint('Error sharing reading streak: $error');
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إنشاء صورة السلسلة ومشاركتها')),
      );
    }
  }

  Widget _sectionTitle(String title, bool isDark) => Text(
    title,
    style: GoogleFonts.ibmPlexSansArabic(
      color: isDark ? Colors.white : const Color(0xFF17251C),
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _metricHeading(
    String title,
    IconData icon,
    Color color,
    bool isDark,
  ) => Row(
    children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          title,
          style: _textStyle(
            isDark,
            size: 12,
            weight: FontWeight.w600,
            color: null,
          ),
        ),
      ),
    ],
  );

  Widget _card(bool isDark, {required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1D2B24) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? Colors.white12 : const Color(0xFFE0E9E3),
      ),
    ),
    child: child,
  );

  TextStyle _textStyle(
    bool isDark, {
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => GoogleFonts.ibmPlexSansArabic(
    fontSize: size,
    fontWeight: weight,
    color: color ?? (isDark ? Colors.white70 : const Color(0xFF64736A)),
  );

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds ثانية';
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours > 0) return '$hours ساعة و$remainingMinutes دقيقة';
    return '$minutes دقيقة';
  }

  String _formatClock(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _ReadingActivity {
  final DateTime date;
  final int durationSeconds;
  final int? startPage;
  final int? endPage;
  final int startTime;

  const _ReadingActivity({
    required this.date,
    required this.durationSeconds,
    required this.startPage,
    required this.endPage,
    required this.startTime,
  });
}
