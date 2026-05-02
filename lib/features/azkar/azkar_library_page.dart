import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import 'azkar_counter_page.dart';

class AzkarLibraryPage extends StatelessWidget {
  const AzkarLibraryPage({super.key});

  static const List<Map<String, dynamic>> _categories = [
    {'title': 'أذكار الصباح', 'icon': '☀️', 'color': 0xFFFF9800},
    {'title': 'أذكار المساء', 'icon': '🌙', 'color': 0xFF3F51B5},
    {'title': 'أذكار النوم', 'icon': '🛌', 'color': 0xFF673AB7},
    {'title': 'أذكار بعد الصلاة', 'icon': '📿', 'color': 0xFF4CAF50},
    {'title': 'أدعية نبوية', 'icon': '🤲', 'color': 0xFF009688},
  ];

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
          title: Text('الأذكار والأدعية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          foregroundColor: Colors.white,
        ),
        body: GridView.builder(
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
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AzkarCounterPage()));
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text(cat['icon'] as String, style: const TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(height: 12),
                    Text(cat['title'] as String, style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
