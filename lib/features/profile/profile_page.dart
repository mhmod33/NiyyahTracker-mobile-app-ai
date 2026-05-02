import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../ramadan/ramadan_page.dart';
import '../hajj/hajj_page.dart';
import '../auth/login_page.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const String _appVersion = '1.0.0';
  static const String _buildNumber = '1';

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AppAuthProvider>();
    final name = authProvider.displayName;
    final email = authProvider.email;
    final phone = authProvider.phone;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverAppBar(
              expandedHeight: 220,
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
                      colors: [AppColors.darkGreen, AppColors.midGreen, AppColors.lightGreen.withOpacity(0.8)],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)],
                          ),
                          child: Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '؟',
                              style: _f(sz: 32, fw: FontWeight.w800, c: AppColors.darkGreen),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(name, style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white)),
                        if (email.isNotEmpty)
                          Text(email, style: _f(sz: 13, c: Colors.white70)),
                        if (phone.isNotEmpty && email.isEmpty)
                          Text(phone, style: _f(sz: 13, c: Colors.white70)),
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
                    if (email.isNotEmpty)
                      _InfoTile(icon: Icons.email_rounded, label: 'البريد الإلكتروني', value: email),
                    if (phone.isNotEmpty)
                      _InfoTile(icon: Icons.phone_rounded, label: 'رقم الهاتف', value: phone),
                    if (authProvider.userProfile != null && authProvider.userProfile!['streakDays'] != null)
                      _InfoTile(
                        icon: Icons.local_fire_department_rounded,
                        label: 'أيام متتالية',
                        value: '${authProvider.userProfile!['streakDays']} يوم',
                      ),
                    const SizedBox(height: 20),

                    // ── Settings ──
                    _SectionTitle(title: 'الإعدادات'),
                    const SizedBox(height: 12),

                    // Dark mode toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: SwitchListTile(
                        value: themeProvider.isDarkMode,
                        onChanged: (_) => themeProvider.toggleTheme(),
                        title: Text('الوضع الداكن', style: _f(fw: FontWeight.w700, sz: 14)),
                        subtitle: Text(themeProvider.isDarkMode ? 'مُفعّل' : 'غير مُفعّل', style: _f(sz: 12, c: AppColors.textSecondary)),
                        secondary: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.amber.withOpacity(0.15) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: isDark ? Colors.amber : AppColors.darkGreen, size: 20),
                        ),
                        activeTrackColor: AppColors.darkGreen,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SettingsTile(icon: Icons.notifications_rounded, title: 'الإشعارات', subtitle: 'إدارة تنبيهات الأذكار', onTap: () {}),
                    _SettingsTile(icon: Icons.language_rounded, title: 'اللغة', subtitle: 'العربية', onTap: () {}),
                    const SizedBox(height: 20),

                    // ── Special Modes ──
                    _SectionTitle(title: 'أوضاع خاصة'),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.nightlight_round,
                      title: 'مود رمضان',
                      subtitle: 'متابعة العبادات في رمضان',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RamadanPage())),
                    ),
                    _SettingsTile(
                      icon: Icons.landscape_rounded,
                      title: 'مود الحج',
                      subtitle: 'دليل مناسك الحج',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HajjPage())),
                    ),
                    const SizedBox(height: 20),

                    // ── About ──
                    _SectionTitle(title: 'حول التطبيق'),
                    const SizedBox(height: 12),
                    _SettingsTile(icon: Icons.info_rounded, title: 'النية', subtitle: 'الإصدار $_appVersion+$_buildNumber', onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'النية',
                        applicationVersion: '$_appVersion+$_buildNumber',
                        children: [Text('تطبيق لتتبع العبادات والنية اليومية', style: _f())],
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
                          // Show confirmation dialog
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('تسجيل الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                                content: Text('هل أنت متأكد من تسجيل الخروج؟', style: GoogleFonts.cairo()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[600],
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text('تسجيل الخروج', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (shouldLogout == true && context.mounted) {
                            await context.read<AppAuthProvider>().signOut();
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                                (route) => false,
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: Text('تسجيل الخروج', style: _f(fw: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[600],
                          side: BorderSide(color: Colors.red[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('وإنما لكل امرئ ما نوى', style: _f(sz: 14, c: AppColors.gray, fw: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('v$_appVersion', style: _f(sz: 11, c: AppColors.gray)),
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
  final IconData icon; final String label; final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.paleGreen, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.darkGreen, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: _f(sz: 11, c: AppColors.gray, fw: FontWeight.w600)),
          Text(value, style: _f(sz: 14, fw: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Align(alignment: Alignment.centerRight, child: Text(title, style: _f(sz: 17, fw: FontWeight.w800)));
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.darkGreen, size: 20)),
        title: Text(title, style: _f(fw: FontWeight.w700, sz: 14)),
        subtitle: Text(subtitle, style: _f(sz: 12, c: AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.gray),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
