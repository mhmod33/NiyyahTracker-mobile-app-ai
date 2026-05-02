import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class AzkarLibraryPage extends StatelessWidget {
  const AzkarLibraryPage({super.key});

  final List<Map<String, dynamic>> _categories = const [
    {'title': 'أذكار الصباح', 'icon': '☀️'},
    {'title': 'أذكار المساء', 'icon': '🌙'},
    {'title': 'أذكار النوم', 'icon': '🛌'},
    {'title': 'أذكار بعد الصلاة', 'icon': '📿'},
    {'title': 'أدعية نبوية', 'icon': '🤲'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('الأذكار والأدعية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
        ),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return InkWell(
              onTap: () {
                // TODO: Show specific azkar
              },
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat['icon'], style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      cat['title'],
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
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
