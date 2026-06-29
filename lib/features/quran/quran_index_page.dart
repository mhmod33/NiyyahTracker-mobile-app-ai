import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'surah_reader_page.dart';

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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('المصحف الشريف', style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.search_rounded, size: 24), onPressed: () => _showSearch(context)),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
            unselectedLabelStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.white70),
            tabs: const [Tab(text: 'السور'), Tab(text: 'الأجزاء'), Tab(text: 'المحفوظات')],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildSurahList(isDark), _buildJuzList(isDark), _buildBookmarksList(isDark)],
        ),
      ),
    );
  }

  // ─── Surah List with bookmark support ───
  Widget _buildSurahList(bool isDark) {
    return FutureBuilder<Box>(
      future: Hive.openBox('surah_bookmarks'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
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
        final surahBookmarksBox = snapshot.data!;
        return ValueListenableBuilder<Box>(
          valueListenable: surahBookmarksBox.listenable(),
          builder: (context, sBox, _) {
            return Column(
              children: [
                _buildKahfFridayBanner(isDark),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: 114,
                    itemBuilder: (ctx, i) {
                      final n = i + 1;
                      final isBookmarked = sBox.containsKey('$n');
                      return _QuranIndexTile(
                        index: n,
                        title: quran.getSurahNameArabic(n),
                        subtitle: '${quran.getVerseCount(n)} آية • ${quran.getPlaceOfRevelation(n) == "Makkah" ? "مكية" : "مدنية"}',
                        isDark: isDark,
                        bookmarked: isBookmarked,
                        onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: n))),
                        onLongPress: () async {
                          final key = '$n';
                          if (sBox.containsKey(key)) {
                            await surahBookmarksBox.delete(key);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text('تم إزالة السورة من المحفوظات', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                                backgroundColor: AppColors.darkGreen,
                                duration: const Duration(seconds: 2),
                              ));
                            }
                          } else {
                            await surahBookmarksBox.put(key, {
                              'surah': n,
                              'surahName': quran.getSurahNameArabic(n),
                              'timestamp': DateTime.now().millisecondsSinceEpoch,
                            });
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text('تم إضافة السورة إلى المحفوظات', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
                                backgroundColor: AppColors.darkGreen,
                                duration: const Duration(seconds: 2),
                              ));
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Al-Kahf Friday banner — only visible on Fridays ───
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
                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: 18))),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDone
                        ? [AppColors.darkGreen.withValues(alpha: 0.18), AppColors.darkGreen.withValues(alpha: 0.06)]
                        : [const Color(0xFFD4A017).withValues(alpha: 0.18), const Color(0xFFD4A017).withValues(alpha: 0.06)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDone
                        ? AppColors.darkGreen.withValues(alpha: 0.35)
                        : const Color(0xFFD4A017).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (isDone ? AppColors.darkGreen : const Color(0xFFD4A017)).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          isDone ? Icons.check_circle_rounded : Icons.menu_book_rounded,
                          color: isDone ? AppColors.darkGreen : const Color(0xFFD4A017),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سورة الكهف - يوم الجمعة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            isDone
                                ? 'بارك الله فيك! قرأتَ سورة الكهف اليوم'
                                : 'لم تقرأ سورة الكهف بعد • اضغط للقراءة',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.darkGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('اقرأ', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
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

  Widget _buildJuzList(bool isDark) {
    final startSurahs = {1:1,2:2,3:2,4:3,5:4,6:4,7:5,8:6,9:7,10:8,11:9,12:11,13:12,14:15,15:17,16:18,17:21,18:23,19:25,20:27,21:29,22:33,23:36,24:39,25:41,26:46,27:51,28:58,29:67,30:78};
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 30,
      itemBuilder: (ctx, i) {
        final juz = i + 1;
        return _QuranIndexTile(
          index: juz, title: 'الجزء $juz', subtitle: 'الجزء رقم $juz في المصحف الشريف', isDark: isDark,
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: startSurahs[juz] ?? 1))),
        );
      },
    );
  }

  // ─── Bookmarks tab — surah bookmarks + verse bookmarks in sections ───
  Widget _buildBookmarksList(bool isDark) {
    return FutureBuilder(
      future: Future.wait([
        Hive.openBox('quran_bookmarks'),
        Hive.openBox('surah_bookmarks'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.darkGreen));
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
                        Icon(Icons.bookmark_border_rounded, size: 60, color: isDark ? Colors.white24 : Colors.black12),
                        const SizedBox(height: 16),
                        Text('لا توجد محفوظات حالياً', style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white38 : Colors.black38, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('اضغط مطولاً على سورة لحفظها', style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13)),
                      ],
                    ),
                  );
                }

                surahItems.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
                verseItems.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (surahItems.isNotEmpty) ...[
                      _sectionHeader('السور المحفوظة', isDark),
                      ...surahItems.map((item) {
                        final s = item['surah'] as int;
                        final sName = item['surahName'] as String;
                        return _QuranIndexTile(
                          index: s,
                          title: 'سورة $sName',
                          subtitle: '${quran.getVerseCount(s)} آية',
                          isDark: isDark,
                          bookmarked: true,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: s))),
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                title: Text('حذف؟', style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white : Colors.black87)),
                                content: Text('هل تريد إزالة هذه السورة من المحفوظات؟', style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white70 : Colors.black54)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) await surahBox.delete('$s');
                          },
                        );
                      }),
                    ],
                    if (verseItems.isNotEmpty) ...[
                      _sectionHeader('الآيات المحفوظة', isDark),
                      ...verseItems.map((item) {
                        final s = item['surah'] as int;
                        final v = item['verse'] as int;
                        final sName = item['surahName'] as String;
                        return _QuranIndexTile(
                          index: v,
                          title: 'سورة $sName',
                          subtitle: 'آية رقم $v',
                          isDark: isDark,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: s, initialVerse: v))),
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                title: Text('حذف؟', style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white : Colors.black87)),
                                content: Text('هل تريد إزالة هذه الآية من المحفوظات؟', style: GoogleFonts.ibmPlexSansArabic(color: isDark ? Colors.white70 : Colors.black54)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) await verseBox.delete('$s-$v');
                          },
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

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.darkGreen, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.ibmPlexSansArabic(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _QuranSearchSheet(),
    );
  }
}

String _removeDiacritics(String text) {
  return text.replaceAll(RegExp(r'[ً-ٰٟۖ-ۭ]'), '');
}

class _QuranIndexTile extends StatelessWidget {
  final int index;
  final String title, subtitle;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool bookmarked;

  const _QuranIndexTile({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
    this.bookmarked = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
        boxShadow: [BoxShadow(color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.darkGreen.withValues(alpha: 0.1), AppColors.darkGreen.withValues(alpha: 0.05)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkGreen.withValues(alpha: 0.2)),
          ),
          child: Center(child: Text('$index', style: GoogleFonts.ibmPlexSansArabic(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkGreen))),
        ),
        title: Text(title, style: GoogleFonts.amiri(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Text(subtitle, style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, color: subtitleColor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bookmarked) ...[
              Icon(Icons.bookmark_rounded, color: AppColors.darkGreen, size: 16),
              const SizedBox(width: 4),
            ],
            DirectionalIcon(isBack: false, size: 14, color: isDark ? Colors.white60 : Colors.black38),
          ],
        ),
      ),
    );
  }
}

// ─── Search sheet with surah filter ───
class _QuranSearchSheet extends StatefulWidget {
  @override
  State<_QuranSearchSheet> createState() => _QuranSearchSheetState();
}

class _QuranSearchSheetState extends State<_QuranSearchSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  int? _filterSurah;

  void _search(String q) {
    if (q.length < 2) { setState(() => _results = []); return; }
    final normalizedQ = _removeDiacritics(q.toLowerCase().trim());
    final List<Map<String, dynamic>> res = [];
    final startS = _filterSurah ?? 1;
    final endS = _filterSurah ?? 114;
    for (int s = startS; s <= endS; s++) {
      try {
        final vc = quran.getVerseCount(s);
        for (int v = 1; v <= vc; v++) {
          try {
            final verse = quran.getVerse(s, v);
            if (_removeDiacritics(verse.toLowerCase()).contains(normalizedQ)) {
              res.add({'s': s, 'v': v});
              if (res.length >= 50) break;
            }
          } catch (_) { continue; }
        }
        if (res.length >= 50) break;
      } catch (_) { continue; }
    }
    setState(() => _results = res.take(30).toList());
  }

  void _showSurahPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text('تصفية بسورة', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (_filterSurah != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _filterSurah = null);
                          Navigator.pop(ctx);
                          _search(_ctrl.text);
                        },
                        child: Text('إلغاء الفلتر', style: GoogleFonts.ibmPlexSansArabic(color: Colors.red, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  itemCount: 114,
                  itemBuilder: (ctx2, i) {
                    final s = i + 1;
                    final isSelected = _filterSurah == s;
                    return ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.darkGreen : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(child: Text('$s', style: GoogleFonts.ibmPlexSansArabic(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white60))),
                      ),
                      title: Text(quran.getSurahNameArabic(s), style: GoogleFonts.amiri(color: isSelected ? AppColors.lightGreen : Colors.white, fontSize: 16)),
                      subtitle: Text('${quran.getVerseCount(s)} آية', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white38, fontSize: 11)),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.darkGreen) : null,
                      onTap: () {
                        setState(() => _filterSurah = s);
                        Navigator.pop(ctx);
                        _search(_ctrl.text);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl, onChanged: _search, autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'ابحث عن آية...', hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: AppColors.darkGreen),
                  filled: true, fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showSurahPicker,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _filterSurah != null ? AppColors.darkGreen : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.filter_list_rounded, color: _filterSurah != null ? Colors.white : Colors.white38, size: 22),
              ),
            ),
          ],
        ),
        if (_filterSurah != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GestureDetector(
              onTap: () { setState(() => _filterSurah = null); _search(_ctrl.text); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.darkGreen.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(quran.getSurahNameArabic(_filterSurah!), style: GoogleFonts.amiri(color: AppColors.lightGreen, fontSize: 14)),
                    const SizedBox(width: 6),
                    const Icon(Icons.close_rounded, color: AppColors.lightGreen, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: _ctrl.text.length >= 2 && _results.isEmpty
              ? Center(child: Text('لا توجد نتائج', style: GoogleFonts.ibmPlexSansArabic(color: Colors.white38, fontSize: 14)))
              : ListView.builder(
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
      ]),
    );
  }
}
