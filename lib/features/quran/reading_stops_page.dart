import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quran/quran.dart' as quran;
import '../../core/app_colors.dart';
import 'surah_reader_page.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) => GoogleFonts.ibmPlexSansArabic(
  fontSize: sz,
  fontWeight: fw,
  color: c,
  height: h,
);

String _arNum(int n) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : digits[d];
  }).join();
}

String _timeAgo(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inHours < 1) return 'منذ ${_arNum(diff.inMinutes)} دقيقة';
  if (diff.inDays < 1) return 'منذ ${_arNum(diff.inHours)} ساعة';
  if (diff.inDays < 30) return 'منذ ${_arNum(diff.inDays)} يوم';
  return '${dt.day}/${dt.month}/${dt.year}';
}

/// Shows every partial-reading stop recorded by the mushaf reader —
/// each contiguous run of pages inside a surah, so unfinished surahs
/// are never lost when the reader jumps to another surah.
class ReadingStopsPage extends StatelessWidget {
  const ReadingStopsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0A0A0A)
            : AppColors.background,
        appBar: AppBar(
          backgroundColor: isDark
              ? const Color(0xFF0D2818)
              : AppColors.darkGreen,
          foregroundColor: Colors.white,
          title: Text(
            'مواضع توقف القراءة',
            style: _f(sz: 17, fw: FontWeight.w800, c: Colors.white),
          ),
          centerTitle: true,
        ),
        body: !Hive.isBoxOpen('quran_progress')
            ? const SizedBox.shrink()
            : ValueListenableBuilder<Box>(
                valueListenable: Hive.box(
                  'quran_progress',
                ).listenable(keys: ['reading_stops']),
                builder: (context, box, _) {
                  final raw = box.get('reading_stops');
                  final stops = raw is List
                      ? raw.whereType<Map>().toList().reversed.toList()
                      : <Map>[];

                  if (stops.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_border_rounded,
                            size: 56,
                            color: isDark
                                ? Colors.white24
                                : AppColors.darkGreen.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد مواضع محفوظة بعد',
                            style: _f(
                              sz: 16,
                              fw: FontWeight.w700,
                              c: isDark ? Colors.white54 : AppColors.darkGreen,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'عندما تتوقف في منتصف سورة وتنتقل لأخرى،\nسيُحفظ موضعك هنا لتكمل لاحقاً',
                            textAlign: TextAlign.center,
                            style: _f(
                              sz: 12,
                              c: isDark
                                  ? Colors.white38
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: stops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = stops[i];
                      final surahNum =
                          (item['surahNumber'] as num?)?.toInt() ?? 1;
                      final surahName =
                          (item['surahName'] as String?) ??
                          quran.getSurahNameArabic(surahNum);
                      final startPage =
                          (item['startPage'] as num?)?.toInt() ?? 1;
                      final endPage =
                          (item['endPage'] as num?)?.toInt() ?? startPage;
                      final ts =
                          (item['lastTimestamp'] as num?)?.toInt() ??
                          (item['firstTimestamp'] as num?)?.toInt() ??
                          0;
                      final pageLabel = startPage == endPage
                          ? 'صفحة ${_arNum(endPage)} من 604'
                          : 'صفحات ${_arNum(startPage)} – ${_arNum(endPage)} من 604';

                      return Material(
                        color: isDark ? const Color(0xFF16241D) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SurahReaderPage(
                                surahNumber: surahNum,
                                initialPage: endPage,
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : AppColors.paleGreen,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: AppColors.gold,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'سورة $surahName',
                                        style: _f(
                                          sz: 15,
                                          fw: FontWeight.w800,
                                          c: isDark
                                              ? Colors.white
                                              : AppColors.darkGreen,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$pageLabel • قراءة جزئية',
                                        style: _f(
                                          sz: 11.5,
                                          c: isDark
                                              ? Colors.white54
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _timeAgo(ts),
                                      style: _f(
                                        sz: 10.5,
                                        fw: FontWeight.w600,
                                        c: AppColors.gold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Icon(
                                      Icons.play_circle_outline_rounded,
                                      color: AppColors.darkGreen,
                                      size: 20,
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
                },
              ),
      ),
    );
  }
}
