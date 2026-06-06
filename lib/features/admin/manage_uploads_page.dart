import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';

class ManageUploadsPage extends StatefulWidget {
  const ManageUploadsPage({super.key});

  @override
  State<ManageUploadsPage> createState() => _ManageUploadsPageState();
}

class _ManageUploadsPageState extends State<ManageUploadsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> _toggleUploadPermission(
    BuildContext context,
    String userId,
    String userName,
    bool currentValue,
  ) async {
    final auth = context.read<AppAuthProvider>();
    final newValue = !currentValue;
    final ok = await auth.setUserCanUpload(userId, newValue);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (newValue
                  ? 'تم تفعيل رفع المقاطع لـ $userName'
                  : 'تم إلغاء صلاحية الرفع لـ $userName')
              : 'فشل التحديث. تأكد من نشر قواعد Firestore (firestore.rules)',
          style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
        ),
        backgroundColor: ok ? AppColors.darkGreen : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AppAuthProvider>();

    if (!auth.isAdmin) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.darkGreen,
            foregroundColor: Colors.white,
            title: Text('إدارة صلاحية الرفع',
                style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'هذه الصفحة للمديرين فقط',
                style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text('إدارة صلاحية الرفع',
              style: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.paleGreen.withValues(alpha: isDark ? 0.15 : 1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkGreen.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'فعّل المفتاح ليستطيع المستخدم رفع مقاطع صوتية إلى مزامير القرآن. المديرون لديهم هذه الصلاحية دائماً.',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : AppColors.darkGreen,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'خطأ في تحميل المستخدمين.\nانشر ملف firestore.rules من المشروع إلى Firebase Console.',
                          style: GoogleFonts.ibmPlexSansArabic(color: Colors.red, height: 1.6),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = [...snapshot.data!.docs]
                    ..sort((a, b) {
                      final na = (a.data() as Map)['name'] as String? ?? '';
                      final nb = (b.data() as Map)['name'] as String? ?? '';
                      return na.compareTo(nb);
                    });

                  if (users.isEmpty) {
                    return Center(
                      child: Text('لا يوجد مستخدمون',
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 16, color: AppColors.gray)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final doc = users[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] as String? ?? 'مستخدم';
                      final email = data['email'] as String? ?? '';
                      final canUpload = data['canUpload'] == true;
                      final role = data['role'] as String? ?? 'user';
                      final isAdminUser = role == 'admin';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isAdminUser
                                    ? AppColors.gold.withValues(alpha: 0.15)
                                    : AppColors.darkGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isAdminUser ? Icons.shield_rounded : Icons.person_rounded,
                                color: isAdminUser ? AppColors.gold : AppColors.darkGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : AppColors.textPrimary)),
                                  if (email.isNotEmpty)
                                    Text(email,
                                        style: GoogleFonts.ibmPlexSansArabic(
                                            fontSize: 11, color: AppColors.gray)),
                                  if (isAdminUser)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'مدير — رفع دائم',
                                        style: GoogleFonts.ibmPlexSansArabic(
                                          fontSize: 10,
                                          color: AppColors.gold,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isAdminUser)
                              Icon(Icons.check_circle_rounded,
                                  color: AppColors.gold.withValues(alpha: 0.8), size: 28)
                            else
                              Switch(
                                value: canUpload,
                                onChanged: (_) => _toggleUploadPermission(
                                  context,
                                  doc.id,
                                  name,
                                  canUpload,
                                ),
                                activeTrackColor: AppColors.darkGreen.withValues(alpha: 0.3),
                                activeThumbColor: AppColors.darkGreen,
                              ),
                          ],
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
