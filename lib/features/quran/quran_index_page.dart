import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quran/quran.dart' as quran;
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import '../wird/daily_wird_page.dart';
import 'reciter_library_page.dart';
import 'surah_reader_page.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

String _toArabicNumerals(int number) {
  const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return number.toString().split('').map((d) => ar[int.parse(d)]).join();
}

String _removeDiacritics(String text) {
  return text.replaceAll(RegExp(r'[ً-ٰٟۖ-ۭ]'), '');
}

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});
  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  // 0 = السور, 1 = الأجزاء, 2 = المحفوظات
  int _selectedSegment = 0;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchCtrl.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleQuranRadio() async {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReciterLibraryPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Soft sage-mint background matching the attached reference image
    final pageBg = isDark ? const Color(0xFF0C1713) : const Color(0xFFD6EAE3);
    final headerBtnBg = isDark ? const Color(0xFF1A2C25) : const Color(0xFFF3F8F6);
    final titleColor = isDark ? Colors.white : const Color(0xFF28433A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: pageBg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Bar (Matches reference image: rounded square buttons on sides, centered title) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Right button (Back arrow in RTL)
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 48,
                        height: 42,
                        decoration: BoxDecoration(
                          color: headerBtnBg,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: DirectionalIcon(
                            isBack: true,
                            size: 18,
                            color: titleColor,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'القرآن الكريم',
                      style: _f(sz: 20, fw: FontWeight.w800, c: titleColor),
                    ),
                    // Left button (Bookmarks / Menu toggle)
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedSegment = _selectedSegment == 2 ? 0 : 2;
                      }),
                      child: Container(
                        width: 48,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _selectedSegment == 2
                              ? const Color(0xFF7B9B91)
                              : headerBtnBg,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _selectedSegment == 2
                                ? Icons.bookmark_rounded
                                : Icons.bookmarks_outlined,
                            size: 20,
                            color: _selectedSegment == 2 ? Colors.white : titleColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search Pill Bar (Matches reference: white pill with search icon on right, sparkle on left) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF162620) : const Color(0xFFF7FBF9),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: _f(
                      sz: 14,
                      fw: FontWeight.w600,
                      c: isDark ? Colors.white : const Color(0xFF28433A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن سورة أو آية',
                      hintStyle: _f(
                        sz: 13,
                        c: isDark ? Colors.white38 : const Color(0xFF93ABA3),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDark ? Colors.white54 : const Color(0xFF7B9B91),
                        size: 22,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : GestureDetector(
                              onTap: () => _showAdvancedVerseSearch(context),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: isDark ? Colors.white38 : const Color(0xFF8BA89E),
                                size: 20,
                              ),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Two Feature Cards Row: الختمات (Right) & إذاعة القرآن (Left) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _TopBannerActionCard(
                        title: 'الختمات',
                        icon: Icons.book_rounded,
                        isDark: isDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DailyWirdPage()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TopBannerActionCard(
                        title: 'إذاعة القرآن',
                        icon: Icons.radio_rounded,
                        isDark: isDark,
                        onTap: _toggleQuranRadio,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Segmented Toggle Pill: السور (Right) | الأجزاء (Left) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF162620) : const Color(0xFFF7FBF9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      _SegmentPillTab(
                        label: 'السور',
                        selected: _selectedSegment == 0,
                        isDark: isDark,
                        onTap: () => setState(() => _selectedSegment = 0),
                      ),
                      _SegmentPillTab(
                        label: 'الأجزاء',
                        selected: _selectedSegment == 1,
                        isDark: isDark,
                        onTap: () => setState(() => _selectedSegment = 1),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Last Read Progress Banner + Friday Al-Kahf Banner ──
              _buildResumeReadingStrip(isDark),
              _buildKahfFridayBanner(isDark),

              // ── Main Content Body (2-Column Grid for Surahs, Juz Grid, or Bookmarks) ──
              Expanded(
                child: _selectedSegment == 0
                    ? _buildSurahGrid(isDark)
                    : _selectedSegment == 1
                        ? _buildJuzGrid(isDark)
                        : _buildBookmarksList(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Resume Reading Strip (Synchronized with Home Screen Progress) ──
  Widget _buildResumeReadingStrip(bool isDark) {
    if (!Hive.isBoxOpen('quran_progress')) return const SizedBox.shrink();
    return ValueListenableBuilder<Box>(
      valueListenable: Hive.box('quran_progress').listenable(),
      builder: (context, box, _) {
        final raw = box.get('last_read');
        if (raw == null || raw is! Map) return const SizedBox.shrink();
        final page = (raw['page'] as num?)?.toInt() ?? 1;
        final surahNum = (raw['surahNumber'] as num?)?.toInt() ?? 1;
        final surahName = (raw['surahName'] as String?) ?? quran.getSurahNameArabic(surahNum);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SurahReaderPage(
                  surahNumber: surahNum,
                  initialPage: page,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1D352C) : const Color(0xFF7B9B91),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_added_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'متابعة القراءة: سورة $surahName • صفحة ${_toArabicNumerals(page)}',
                      style: _f(sz: 13, fw: FontWeight.w700, c: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'أكمل',
                      style: _f(sz: 11, fw: FontWeight.w800, c: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 2-Column Surah Grid (Matching Attached Reference Image) ──
  Widget _buildSurahGrid(bool isDark) {
    final normalizedQuery = _removeDiacritics(_searchQuery.toLowerCase());
    final surahNumbers = List<int>.generate(114, (i) => i + 1).where((n) {
      if (normalizedQuery.isEmpty) return true;
      final arName = _removeDiacritics(quran.getSurahNameArabic(n));
      final enName = quran.getSurahName(n).toLowerCase();
      return arName.contains(normalizedQuery) ||
          enName.contains(normalizedQuery) ||
          n.toString() == normalizedQuery;
    }).toList();

    return FutureBuilder<Box>(
      future: Hive.openBox('surah_bookmarks'),
      builder: (context, snapshot) {
        final sBox = snapshot.data;

        if (surahNumbers.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: isDark ? Colors.white30 : const Color(0xFF7B9B91),
                ),
                const SizedBox(height: 10),
                Text(
                  'لم يتم العثور على سورة مطابقة',
                  style: _f(
                    sz: 15,
                    fw: FontWeight.w700,
                    c: isDark ? Colors.white60 : const Color(0xFF4F6F65),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showAdvancedVerseSearch(context, initialQuery: _searchQuery),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: Text('البحث في آيات القرآن عن "$_searchQuery"', style: _f(fw: FontWeight.w700)),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.72,
          ),
          itemCount: surahNumbers.length,
          itemBuilder: (ctx, i) {
            final n = surahNumbers[i];
            final isBookmarked = sBox?.containsKey('$n') ?? false;
            final place = quran.getPlaceOfRevelation(n) == 'Makkah' ? 'مكية' : 'مدنية';
            final versesAr = _toArabicNumerals(quran.getVerseCount(n));

            return _SurahGridCard(
              surahNumber: n,
              arabicNumber: _toArabicNumerals(n),
              nameArabic: 'سُورَةُ ${quran.getSurahNameArabic(n)}',
              subtitle: '$place  •  آياتها: $versesAr',
              isDark: isDark,
              bookmarked: isBookmarked,
              onTap: () => Navigator.push(
                ctx,
                MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: n)),
              ),
              onLongPress: sBox == null
                  ? null
                  : () async {
                      final key = '$n';
                      if (sBox.containsKey(key)) {
                        await sBox.delete(key);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('تم إزالة السورة من المحفوظات', style: _f(c: Colors.white)),
                              backgroundColor: AppColors.darkGreen,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        await sBox.put(key, {
                          'surah': n,
                          'surahName': quran.getSurahNameArabic(n),
                          'timestamp': DateTime.now().millisecondsSinceEpoch,
                        });
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('تم حفظ السورة في المحفوظات', style: _f(c: Colors.white)),
                              backgroundColor: AppColors.darkGreen,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                      setState(() {});
                    },
            );
          },
        );
      },
    );
  }

  // ── 2-Column Juz Grid ──
  Widget _buildJuzGrid(bool isDark) {
    const startPages = [
      1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
      202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
      402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
    ];
    const startSurahs = [
      1, 2, 2, 3, 4, 4, 5, 6, 7, 8,
      9, 11, 12, 15, 17, 18, 21, 23, 25, 27,
      29, 33, 36, 39, 41, 46, 51, 58, 67, 78,
    ];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.72,
      ),
      itemCount: 30,
      itemBuilder: (ctx, i) {
        final juz = i + 1;
        final page = startPages[i];
        final surah = startSurahs[i];
        return _SurahGridCard(
          surahNumber: juz,
          arabicNumber: _toArabicNumerals(juz),
          nameArabic: 'الجُزْءُ ${_toArabicNumerals(juz)}',
          subtitle: 'يبدأ من صفحة ${_toArabicNumerals(page)}',
          isDark: isDark,
          bookmarked: false,
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => SurahReaderPage(
                surahNumber: surah,
                initialPage: page,
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Al-Kahf Friday Banner ──
  Widget _buildKahfFridayBanner(bool isDark) {
    final now = DateTime.now();
    if (now.weekday != DateTime.friday) return const SizedBox.shrink();

    return FutureBuilder<Box>(
      future: Hive.openBox('kahf_tracker'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return ValueListenableBuilder<Box>(
          valueListenable: snapshot.data!.listenable(),
          builder: (context, kahfBox, _) {
            final dayKey = '${now.year}-${now.month}-${now.day}';
            final isDone = kahfBox.containsKey(dayKey);
            return GestureDetector(
              onTap: isDone
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SurahReaderPage(surahNumber: 18)),
                      ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162620) : const Color(0xFFF3F8F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDone
                        ? AppColors.darkGreen.withValues(alpha: 0.35)
                        : const Color(0xFFD4A017).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDone ? Icons.check_circle_rounded : Icons.auto_stories_rounded,
                      color: isDone ? AppColors.darkGreen : const Color(0xFFD4A017),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isDone
                            ? 'بارك الله فيك! قرأتَ سورة الكهف اليوم'
                            : 'تذكير يوم الجمعة: قراءة سورة الكهف',
                        style: _f(
                          sz: 12,
                          fw: FontWeight.w700,
                          c: isDark ? Colors.white : const Color(0xFF28433A),
                        ),
                      ),
                    ),
                    if (!isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B9B91),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'اقرأ',
                          style: _f(sz: 11, fw: FontWeight.w800, c: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Bookmarks List ──
  Widget _buildBookmarksList(bool isDark) {
    return FutureBuilder(
      future: Future.wait([
        Hive.openBox('quran_bookmarks'),
        Hive.openBox('surah_bookmarks'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.darkGreen));
        }
        final boxes = snapshot.data as List<dynamic>;
        final verseBox = boxes[0] as Box;
        final surahBox = boxes[1] as Box;

        return ValueListenableBuilder<Box>(
          valueListenable: verseBox.listenable(),
          builder: (context, vBox, _) {
            return ValueListenableBuilder<Box>(
              valueListenable: surahBox.listenable(),
              builder: (context, sBox, _) {
                final surahItems = sBox.values.toList().cast<Map>();
                final verseItems = vBox.values.toList().cast<Map>();

                if (surahItems.isEmpty && verseItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border_rounded,
                          size: 56,
                          color: isDark ? Colors.white24 : const Color(0xFF7B9B91),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد محفوظات حالياً',
                          style: _f(
                            sz: 16,
                            fw: FontWeight.w700,
                            c: isDark ? Colors.white54 : const Color(0xFF4F6F65),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'اضغط مطولاً على أي سورة لحفظها في المفضلة',
                          style: _f(
                            sz: 12,
                            c: isDark ? Colors.white38 : const Color(0xFF7B9B91),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (surahItems.isNotEmpty) ...[
                      Text(
                        'السور المحفوظة',
                        style: _f(
                          sz: 15,
                          fw: FontWeight.w800,
                          c: isDark ? Colors.white : const Color(0xFF28433A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.72,
                        ),
                        itemCount: surahItems.length,
                        itemBuilder: (ctx, idx) {
                          final item = surahItems[idx];
                          final s = item['surah'] as int;
                          final place = quran.getPlaceOfRevelation(s) == 'Makkah' ? 'مكية' : 'مدنية';
                          return _SurahGridCard(
                            surahNumber: s,
                            arabicNumber: _toArabicNumerals(s),
                            nameArabic: 'سُورَةُ ${quran.getSurahNameArabic(s)}',
                            subtitle: '$place  •  آياتها: ${_toArabicNumerals(quran.getVerseCount(s))}',
                            isDark: isDark,
                            bookmarked: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: s)),
                            ),
                            onLongPress: () => sBox.delete('$s'),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (verseItems.isNotEmpty) ...[
                      Text(
                        'الآيات المحفوظة',
                        style: _f(
                          sz: 15,
                          fw: FontWeight.w800,
                          c: isDark ? Colors.white : const Color(0xFF28433A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...verseItems.map((item) {
                        final s = item['surah'] as int;
                        final v = item['verse'] as int;
                        final sName = item['surahName'] as String;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF162620) : const Color(0xFFF3F8F6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            title: Text(
                              'سورة $sName • آية ${_toArabicNumerals(v)}',
                              style: _f(
                                sz: 15,
                                fw: FontWeight.w800,
                                c: isDark ? Colors.white : const Color(0xFF28433A),
                              ),
                            ),
                            subtitle: Text(
                              quran.getVerse(s, v),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'KFGQPC Uthmanic Script Hafs',
                                fontSize: 14,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              onPressed: () => vBox.delete('$s-$v'),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SurahReaderPage(surahNumber: s, initialVerse: v),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAdvancedVerseSearch(BuildContext context, {String initialQuery = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuranSearchSheet(initialQuery: initialQuery),
    );
  }
}

/// Top feature card ("الختمات" / "إذاعة القرآن") styled after the attached image
class _TopBannerActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _TopBannerActionCard({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF162620) : const Color(0xFFF3F8F6);
    final badgeBg = isDark ? const Color(0xFF213830) : const Color(0xFFDCEBE5);
    final iconColor = isDark ? const Color(0xFF88B3A6) : const Color(0xFF6B8E83);
    final textColor = isDark ? Colors.white : const Color(0xFF28433A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Soft decorative circle on the top-right corner like the reference screenshot
            Positioned(
              right: -18,
              top: -18,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badgeBg.withValues(alpha: 0.55),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      title,
                      style: _f(sz: 14, fw: FontWeight.w800, c: textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented pill tab ("السور" / "الأجزاء")
class _SegmentPillTab extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _SegmentPillTab({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? const Color(0xFF2A4A3E) : const Color(0xFF7B9B91);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: _f(
              sz: 13,
              fw: selected ? FontWeight.w800 : FontWeight.w600,
              c: selected
                  ? Colors.white
                  : (isDark ? Colors.white60 : const Color(0xFF7B9B91)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Distinctive 2-Column Surah Card matching the reference screenshot:
/// Rounded off-white card, right-docked soft sage-mint number badge with Arabic numeral,
/// calligraphic Surah title (`Al Mushaf` / `Amiri`), and subtitle (`مكية • آياتها: ٧`).
class _SurahGridCard extends StatelessWidget {
  final int surahNumber;
  final String arabicNumber;
  final String nameArabic;
  final String subtitle;
  final bool isDark;
  final bool bookmarked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SurahGridCard({
    required this.surahNumber,
    required this.arabicNumber,
    required this.nameArabic,
    required this.subtitle,
    required this.isDark,
    required this.bookmarked,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF162620) : const Color(0xFFF3F8F6);
    final badgeBg = isDark ? const Color(0xFF223C33) : const Color(0xFFC7E2D9);
    final titleColor = isDark ? Colors.white : const Color(0xFF28433A);
    final subColor = isDark ? Colors.white60 : const Color(0xFF6B857C);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: bookmarked
              ? Border.all(color: const Color(0xFF7B9B91), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (bookmarked)
              const Positioned(
                top: 8,
                left: 10,
                child: Icon(
                  Icons.bookmark_rounded,
                  size: 15,
                  color: Color(0xFF7B9B91),
                ),
              ),
            Row(
              children: [
                // Right-docked vertical rounded tab with Arabic-Indic number (١, ٢, ٣...)
                Container(
                  width: 34,
                  height: 46,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    arabicNumber,
                    style: _f(
                      sz: 15,
                      fw: FontWeight.w800,
                      c: titleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Calligraphic Surah Name & Subtitle
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            nameArabic,
                            style: GoogleFonts.amiri(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                              height: 1.25,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            subtitle,
                            style: _f(
                              sz: 11,
                              fw: FontWeight.w600,
                              c: subColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Advanced Verse Search Sheet ───
class _QuranSearchSheet extends StatefulWidget {
  final String initialQuery;
  const _QuranSearchSheet({this.initialQuery = ''});
  @override
  State<_QuranSearchSheet> createState() => _QuranSearchSheetState();
}

class _QuranSearchSheetState extends State<_QuranSearchSheet> {
  late final TextEditingController _ctrl;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      _search(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    final normalizedQ = _removeDiacritics(q.toLowerCase().trim());
    final List<Map<String, dynamic>> res = [];
    for (int s = 1; s <= 114; s++) {
      try {
        final vc = quran.getVerseCount(s);
        for (int v = 1; v <= vc; v++) {
          final verse = quran.getVerse(s, v);
          if (_removeDiacritics(verse.toLowerCase()).contains(normalizedQ)) {
            res.add({'s': s, 'v': v});
            if (res.length >= 40) break;
          }
        }
        if (res.length >= 40) break;
      } catch (_) {
        continue;
      }
    }
    setState(() => _results = res);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF101E19) : const Color(0xFFF3F8F6);
    final textCol = isDark ? Colors.white : const Color(0xFF28433A);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              onChanged: _search,
              autofocus: true,
              style: _f(sz: 14, fw: FontWeight.w600, c: textCol),
              decoration: InputDecoration(
                hintText: 'ابحث عن كلمة أو آية في المصحف...',
                hintStyle: _f(sz: 13, c: textCol.withValues(alpha: 0.45)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7B9B91)),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ctrl.text.length >= 2 && _results.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد نتائج مطابقة',
                        style: _f(sz: 14, c: textCol.withValues(alpha: 0.5)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final r = _results[i];
                        final s = r['s'] as int;
                        final v = r['v'] as int;
                        return ListTile(
                          title: Text(
                            quran.getVerse(s, v),
                            style: TextStyle(
                              fontFamily: 'KFGQPC Uthmanic Script Hafs',
                              color: textCol,
                              fontSize: 17,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'سورة ${quran.getSurahNameArabic(s)} • آية ${_toArabicNumerals(v)}',
                            style: _f(sz: 12, c: const Color(0xFF7B9B91), fw: FontWeight.w700),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SurahReaderPage(surahNumber: s, initialVerse: v),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
