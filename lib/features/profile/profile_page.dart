import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/theme_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const String _appVersion = '1.0.0';
  static const String _buildNumber = '1';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber ?? 'غير محدد';
    final name = user?.displayName ?? 'مستخدم النية';
    final email = user?.email ?? '';
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: AppColors.darkGreen,
              leading: IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.darkGreen,
                        AppColors.midGreen,
                        AppColors.lightGreen.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20),
                            ],
                          ),
                          child: Center(
                            child: Icon(Icons.person_rounded, size: 40, color: AppColors.darkGreen),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(name, style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                        if (phone != 'غير محدد')
                          Text(phone, style: GoogleFonts.cairo(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Content ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Info cards
                    _InfoTile(icon: Icons.phone_rounded, label: 'رقم الهاتف', value: phone),
                    if (email.isNotEmpty)
                      _InfoTile(icon: Icons.email_rounded, label: 'البريد الإلكتروني', value: email),
                    const SizedBox(height: 24),

                    // ── Dark Mode Toggle ──
                    _SectionTitle(title: 'الإعدادات'),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: SwitchListTile(
                        value: themeProvider.isDarkMode,
                        onChanged: (_) => themeProvider.toggleTheme(),
                        title: Text('الوضع الداكن', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text(
                          themeProvider.isDarkMode ? 'مُفعّل' : 'غير مُفعّل',
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        secondary: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.amber.withOpacity(0.15) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: isDark ? Colors.amber : AppColors.darkGreen,
                            size: 20,
                          ),
                        ),
                        activeColor: AppColors.darkGreen,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingsTile(icon: Icons.notifications_rounded, title: 'الإشعارات', subtitle: 'إدارة تنبيهات الأذكار', onTap: () {}),
                    _SettingsTile(icon: Icons.language_rounded, title: 'اللغة', subtitle: 'العربية', onTap: () {}),
                    const SizedBox(height: 24),

                    // ── About ──
                    _SectionTitle(title: 'حول التطبيق'),
                    const SizedBox(height: 12),
                    _SettingsTile(icon: Icons.info_rounded, title: 'النية', subtitle: 'الإصدار $_appVersion+$_buildNumber', onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'النية',
                        applicationVersion: '$_appVersion+$_buildNumber',
                        children: [
                          Text('تطبيق لتتبع العبادات والنية اليومية', style: GoogleFonts.cairo()),
                        ],
                      );
                    }),
                    _SettingsTile(icon: Icons.star_rounded, title: 'قيّم التطبيق', subtitle: 'ساعدنا بتقييمك', onTap: () {}),
                    _SettingsTile(icon: Icons.share_rounded, title: 'مشاركة التطبيق', subtitle: 'انشر الخير', onTap: () {}),
                    const SizedBox(height: 30),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: Text('تسجيل الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'وإنما لكل امرئ ما نوى',
                      style: GoogleFonts.cairo(fontSize: 14, color: AppColors.gray, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v$_appVersion',
                      style: GoogleFonts.cairo(fontSize: 11, color: AppColors.gray),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.paleGreen, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.darkGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.gray, fontWeight: FontWeight.w600)),
                Text(value, style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(title, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.darkGreen, size: 20),
        ),
        title: Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.gray),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
