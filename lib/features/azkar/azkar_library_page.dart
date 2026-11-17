import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_colors.dart';
import 'azkar_counter_page.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class AzkarLibraryPage extends StatefulWidget {
  final String? initialCategory;
  const AzkarLibraryPage({super.key, this.initialCategory});

  @override
  State<AzkarLibraryPage> createState() => _AzkarLibraryPageState();
}

class _AzkarLibraryPageState extends State<AzkarLibraryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategoryKey = 'الكل';
  String _searchQuery = '';

  static const List<Map<String, dynamic>> _categories = [
    {'title': 'أذكار الصباح', 'key': 'أذكار الصباح', 'icon': '☀️', 'color': 0xFFFF9800},
    {'title': 'أذكار المساء', 'key': 'أذكار المساء', 'icon': '🌙', 'color': 0xFF3F51B5},
    {'title': 'أذكار النوم', 'key': 'أذكار النوم', 'icon': '🛌', 'color': 0xFF673AB7},
    {'title': 'أذكار بعد الصلاة', 'key': 'أذكار بعد الصلاة', 'icon': '📿', 'color': 0xFF4CAF50},
    {'title': 'أذكار الطعام', 'key': 'أذكار الطعام', 'icon': '🍽️', 'color': 0xFFFF5722},
    {'title': 'أذكار الوضوء', 'key': 'أذكار الوضوء', 'icon': '💧', 'color': 0xFF2196F3},
    {'title': 'أذكار المسجد', 'key': 'أذكار المسجد', 'icon': '🕌', 'color': 0xFF795548},
    {'title': 'تسابيح', 'key': 'تسابيح', 'icon': '📿', 'color': 0xFF9C27B0},
    {'title': 'أدعية نبوية', 'key': 'أدعية نبوية', 'icon': '🤲', 'color': 0xFF009688},
    {'title': 'عدّاد الأذكار', 'key': 'عام', 'icon': '🔢', 'color': 0xFF607D8B},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialCategory != null) {
      _selectedCategoryKey = widget.initialCategory!;
      _tabController.index = 1;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyDhikr(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الذكر'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareDhikrAsImage(BuildContext context, String text, String cat, String reward) {
    final GlobalKey repaintKey = GlobalKey();
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: repaintKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
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
                      borderRadius: BorderRadius.circular(28),
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
                  child: Stack(
                    children: [
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.gold.withValues(alpha: 0.12),
                          size: 56,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded, color: AppColors.gold, size: 14),
                                    const SizedBox(width: 5),
                                    Text(cat, style: _f(sz: 12, fw: FontWeight.w800, c: AppColors.gold)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'بصائر',
                                    style: GoogleFonts.amiri(
                                      color: AppColors.gold,
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
                                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1),
                                    ),
                                    child: const Icon(Icons.eco_rounded, color: AppColors.gold, size: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            text,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.amiri(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFBF8F1),
                              height: 1.85,
                            ),
                          ),
                          if (reward.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: Text(
                                '✨ $reward',
                                textAlign: TextAlign.center,
                                style: _f(sz: 12, fw: FontWeight.w600, c: AppColors.goldLight),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          Divider(color: Colors.white.withValues(alpha: 0.15)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'تطبيق بصائر للأذكار والعبادات',
                                style: _f(sz: 11, fw: FontWeight.w600, c: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                        if (boundary == null) return;
                        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                        if (byteData == null) return;
                        final Uint8List pngBytes = byteData.buffer.asUint8List();
                        final tempDir = await getTemporaryDirectory();
                        final file = File('${tempDir.path}/dhikr_${DateTime.now().millisecondsSinceEpoch}.png');
                        await file.writeAsBytes(pngBytes);
                        if (ctx.mounted) Navigator.pop(ctx);
                        await Share.shareXFiles([XFile(file.path)], text: text);
                      } catch (_) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        await Share.share(text);
                      }
                    },
                    icon: const Icon(Icons.image_rounded, size: 18),
                    label: Text('مشاركة الذكر كصورة', style: _f(sz: 13, fw: FontWeight.w800, c: Colors.black87)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('إغلاق', style: _f(sz: 13, fw: FontWeight.w700, c: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredDhikrs() {
    final List<Map<String, dynamic>> list = [];
    azkarCategories.forEach((catKey, category) {
      if (_selectedCategoryKey != 'الكل' && catKey != _selectedCategoryKey) {
        return;
      }
      for (final dhikr in category.items) {
        if (_searchQuery.trim().isNotEmpty) {
          final query = _searchQuery.trim().toLowerCase();
          final matchText = dhikr.text.toLowerCase().contains(query);
          final matchReward = dhikr.reward.toLowerCase().contains(query);
          if (!matchText && !matchReward) continue;
        }
        list.add({
          'category': catKey,
          'categoryTitle': category.title,
          'dhikr': dhikr,
        });
      }
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : AppColors.background;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text('الأذكار والأدعية', style: _f(fw: FontWeight.bold, sz: 18, c: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.darkGreen.withValues(alpha: 0.78),
                      AppColors.midGreen.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),
          ),
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: _f(sz: 14, fw: FontWeight.bold),
            tabs: const [
              Tab(text: 'الأقسام', icon: Icon(Icons.grid_view_rounded, size: 20)),
              Tab(text: 'بطاقات الأذكار', icon: Icon(Icons.menu_book_rounded, size: 20)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildCategoriesGrid(context, isDark, cardBg, textColor),
            _buildDhikrCardsList(context, isDark, cardBg, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(BuildContext context, bool isDark, Color cardBg, Color textColor) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.2,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final color = Color(cat['color'] as int);
        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => AzkarCounterPage(categoryKey: cat['key'] as String),
            ));
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(cat['icon'] as String, style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(height: 12),
              Text(cat['title'] as String, style: _f(fw: FontWeight.bold, sz: 15, c: textColor)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildDhikrCardsList(BuildContext context, bool isDark, Color cardBg, Color textColor) {
    final filteredDhikrs = _getFilteredDhikrs();

    return Column(
      children: [
        // ── Search & Filter Chips ──
        Container(
          color: isDark ? const Color(0xFF141916) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: _f(c: textColor),
                decoration: InputDecoration(
                  hintText: 'ابحث في الأذكار والأدعية...',
                  hintStyle: _f(c: isDark ? Colors.white38 : AppColors.gray),
                  prefixIcon: const Icon(Icons.search, color: AppColors.darkGreen),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1F2622) : const Color(0xFFF4F6F4),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip('الكل', isDark),
                    ..._categories.map((c) => _filterChip(c['key'] as String, isDark)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── Cards List ──
        Expanded(
          child: filteredDhikrs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                      const SizedBox(height: 12),
                      Text('لم يتم العثور على أذكار تطابق البحث', style: _f(c: AppColors.gray, sz: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: filteredDhikrs.length,
                  itemBuilder: (context, index) {
                    final item = filteredDhikrs[index];
                    final Dhikr dhikr = item['dhikr'] as Dhikr;
                    final String catKey = item['category'] as String;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Top Row: Category Tag + Target Count ──
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkGreen.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    catKey,
                                    style: _f(sz: 11, fw: FontWeight.bold, c: AppColors.darkGreen),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${dhikr.targetCount}x',
                                    style: _f(sz: 11, fw: FontWeight.bold, c: isDark ? AppColors.goldLight : AppColors.gold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // ── Dhikr Text ──
                            Text(
                              dhikr.text,
                              style: _f(
                                sz: 16,
                                fw: FontWeight.w700,
                                c: textColor,
                                h: 1.8,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                            if (dhikr.reward.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8F9F8),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Text('✨ ', style: TextStyle(fontSize: 12)),
                                    Expanded(
                                      child: Text(
                                        dhikr.reward,
                                        style: _f(sz: 12, c: isDark ? Colors.white70 : AppColors.gray, fw: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // ── Bottom Action Row: Start Counter + Copy + Share as Image ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.darkGreen,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: Text('فتح في العدّاد', style: _f(sz: 13, fw: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AzkarCounterPage(categoryKey: catKey),
                                      ),
                                    );
                                  },
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, color: AppColors.darkGreen, size: 20),
                                      tooltip: 'نسخ الذكر',
                                      onPressed: () => _copyDhikr(context, dhikr.text),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.image_outlined, color: AppColors.gold, size: 20),
                                      tooltip: 'مشاركة كصورة',
                                      onPressed: () => _shareDhikrAsImage(context, dhikr.text, catKey, dhikr.reward),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String key, bool isDark) {
    final selected = _selectedCategoryKey == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryKey = key),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.darkGreen
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          key,
          style: _f(
            sz: 12,
            fw: selected ? FontWeight.bold : FontWeight.w500,
            c: selected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
