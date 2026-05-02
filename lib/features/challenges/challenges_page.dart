import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  final List<Map<String, dynamic>> _challenges = const [
    {'title': 'صيام الاثنين والخميس', 'description': 'سنة مؤكدة عن النبي ﷺ', 'icon': '🌙'},
    {'title': 'قراءة سورة الكهف', 'description': 'نور ما بين الجمعتين', 'icon': '📖'},
    {'title': 'قيام الليل', 'description': 'شرف المؤمن', 'icon': '✨'},
    {'title': 'صلاة الضحى', 'description': 'صلاة الأوابين', 'icon': '☀️'},
    {'title': 'أذكار الصباح والمساء', 'description': 'حصن المسلم', 'icon': '🛡️'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('التحديات الروحية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _challenges.length,
          itemBuilder: (context, index) {
            final challenge = _challenges[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Text(challenge['icon'], style: const TextStyle(fontSize: 32)),
                title: Text(challenge['title'], style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text(challenge['description'], style: GoogleFonts.cairo(color: AppColors.gray)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.darkGreen),
                onTap: () {
                  // TODO: Implement challenge tracking
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
