import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import '../../core/app_colors.dart';

class QuranPage extends StatelessWidget {
  const QuranPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('المصحف الشريف', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
        ),
        body: ListView.builder(
          itemCount: 114,
          itemBuilder: (context, index) {
            final surahNumber = index + 1;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.paleGreen,
                  child: Text('$surahNumber', style: const TextStyle(color: AppColors.darkGreen, fontWeight: FontWeight.bold)),
                ),
                title: Text(
                  quran.getSurahNameArabic(surahNumber),
                  style: GoogleFonts.amiri(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${quran.getVerseCount(surahNumber)} آية - ${quran.getPlaceOfRevelation(surahNumber) == 'Makkah' ? 'مكية' : 'مدنية'}',
                  style: GoogleFonts.cairo(fontSize: 12),
                ),
                trailing: const Icon(Icons.menu_book, color: AppColors.darkGreen),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahDetailsPage(surahNumber: surahNumber),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class SurahDetailsPage extends StatelessWidget {
  final int surahNumber;
  const SurahDetailsPage({super.key, required this.surahNumber});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(quran.getSurahNameArabic(surahNumber), style: GoogleFonts.amiri(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: quran.getVerseCount(surahNumber),
          itemBuilder: (context, index) {
            final verseNumber = index + 1;
            return Column(
              children: [
                if (index == 0 && surahNumber != 1 && surahNumber != 9)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      quran.basmala,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.amiri(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${quran.getVerse(surahNumber, verseNumber, textAlign: false)} ($verseNumber)',
                    textAlign: TextAlign.justify,
                    style: GoogleFonts.amiri(fontSize: 20, height: 2),
                  ),
                ),
                const Divider(),
              ],
            );
          },
        ),
      ),
    );
  }
}
