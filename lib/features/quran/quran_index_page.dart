import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
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
          title: Text('المصحف الشريف', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.search_rounded, size: 24), onPressed: () => _showSearch(context)),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
            unselectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.white70),
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

  Widget _buildHizbList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 60,
      itemBuilder: (ctx, i) {
        final hizb = i + 1;
        return _QuranIndexTile(
          index: hizb, title: 'الحزب $hizb', subtitle: 'الحزب رقم $hizb من القرآن الكريم', isDark: isDark,
          onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => SurahReaderPage(surahNumber: 1))),
        );
      },
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
  return text.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
}

class _QuranIndexTile extends StatelessWidget {
  final int index; final String title, subtitle; final bool isDark; final VoidCallback onTap;
  const _QuranIndexTile({required this.index, required this.title, required this.subtitle, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
        boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.darkGreen.withOpacity(0.1), AppColors.darkGreen.withOpacity(0.05)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkGreen.withOpacity(0.2)),
          ),
          child: Center(child: Text('$index', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkGreen))),
        ),
        title: Text(title, style: GoogleFonts.amiri(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Text(subtitle, style: GoogleFonts.cairo(fontSize: 12, color: subtitleColor)),
        trailing: DirectionalIcon(isBack: false, size: 14, color: isDark ? Colors.white60 : Colors.black38),
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
    if (q.length < 2) { setState(() => _results = []); return; }
    final normalizedQ = _removeDiacritics(q.toLowerCase().trim());
    final List<Map<String, dynamic>> res = [];
    for (int s = 1; s <= 114; s++) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(color: Color(0xFF121212), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
          controller: _ctrl, onChanged: _search, autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'ابحث عن آية...', hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: AppColors.darkGreen),
            filled: true, fillColor: Colors.white10,
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
      ]),
    );
  }
}
