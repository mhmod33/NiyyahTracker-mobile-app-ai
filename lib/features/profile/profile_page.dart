import 'dart:ui';
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

  static const String _appVersion = '1.1.0';

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
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Modern Header ──
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              stretch: true,
              backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(10.0),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15)),
                        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark 
                            ? [const Color(0xFF0D2818), const Color(0xFF051109)]
                            : [AppColors.darkGreen, AppColors.midGreen],
                        ),
                      ),
                    ),
                    // Abstract shapes for texture
                    Positioned(
                      top: -50, right: -50,
                      child: CircleAvatar(radius: 100, backgroundColor: Colors.white.withOpacity(0.05)),
                    ),
                    
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Avatar with ring
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 2),
                          ),
                          child: Container(
                            width: 90, height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 25)],
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '؟',
                                style: _f(sz: 42, fw: FontWeight.w800, c: AppColors.darkGreen),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(name, style: _f(sz: 22, fw: FontWeight.w800, c: Colors.white)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(email.isNotEmpty ? email : phone, 
                            style: _f(sz: 12, c: Colors.white70, fw: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Modern Content ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── User Stats ──
                    _buildStatsRow(authProvider, isDark),
                    const SizedBox(height: 32),

                    // ── Settings Group ──
                    _SectionHeader(title: 'الإعدادات والتفضيلات', isDark: isDark),
                    _ProfileCard(
                      isDark: isDark,
                      children: [
                        _ModernSettingsTile(
                          icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: Colors.amber,
                          title: 'الوضع الداكن',
                          subtitle: themeProvider.isDarkMode ? 'مُفعّل' : 'غير مُفعّل',
                          trailing: Switch.adaptive(
                            value: themeProvider.isDarkMode,
                            onChanged: (_) => themeProvider.toggleTheme(),
                            activeColor: AppColors.gold,
                          ),
                        ),
                        const _Divider(),
                        _ModernSettingsTile(
                          icon: Icons.notifications_active_rounded,
                          color: Colors.blue,
                          title: 'تنبيهات الأذكار',
                          subtitle: 'إدارة مواعيد التذكير',
                          onTap: () {},
                        ),
                        const _Divider(),
                        _ModernSettingsTile(
                          icon: Icons.translate_rounded,
                          color: Colors.teal,
                          title: 'لغة التطبيق',
                          subtitle: 'العربية',
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _SectionHeader(title: 'الأنماط الخاصة', isDark: isDark),
                    _ProfileCard(
                      isDark: isDark,
                      children: [
                        _ModernSettingsTile(
                          icon: Icons.nights_stay_rounded,
                          color: Colors.indigo,
                          title: 'مود رمضان',
                          subtitle: 'متابعة الصيام والقيام',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RamadanPage())),
                        ),
                        const _Divider(),
                        _ModernSettingsTile(
                          icon: Icons.mosque_rounded,
                          color: Colors.green,
                          title: 'مود الحج والعمرة',
                          subtitle: 'دليل المناسك الكامل',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HajjPage())),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    _SectionHeader(title: 'عن النية', isDark: isDark),
                    _ProfileCard(
                      isDark: isDark,
                      children: [
                        _ModernSettingsTile(
                          icon: Icons.info_outline_rounded,
                          color: Colors.grey,
                          title: 'حول التطبيق',
                          subtitle: 'الإصدار $_appVersion',
                          onTap: () {},
                        ),
                        const _Divider(),
                        _ModernSettingsTile(
                          icon: Icons.star_border_rounded,
                          color: Colors.orange,
                          title: 'قيّم تجربتك',
                          subtitle: 'رأيك يهمنا في تطوير التطبيق',
                          onTap: () {},
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                    // Logout
                    _buildLogoutButton(context, isDark),
                    
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Text('وإنما لكل امرئ ما نوى', style: _f(sz: 14, c: isDark ? Colors.white38 : AppColors.gray, fw: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('صنع بكل حب للمسلمين 🤍', style: _f(sz: 11, c: isDark ? Colors.white24 : AppColors.gray)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(AppAuthProvider auth, bool isDark) {
    return Row(
      children: [
        _StatItem(label: 'أيام متتالية', value: '${auth.userProfile?['streakDays'] ?? 0}', icon: Icons.local_fire_department_rounded, color: Colors.orange, isDark: isDark),
        const SizedBox(width: 12),
        _StatItem(label: 'إجمالي الحسنات', value: '١,٢٤٠', icon: Icons.auto_graph_rounded, color: Colors.green, isDark: isDark),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () => _handleLogout(context),
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text('تسجيل الخروج', style: _f(fw: FontWeight.w800, c: Colors.white, sz: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('تسجيل الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          content: Text('هل أنت متأكد من رغبتك في مغادرة التطبيق؟', style: GoogleFonts.cairo()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: _f(c: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('نعم، خروج', style: TextStyle(color: Colors.white)),
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
  }
}

class _StatItem extends StatelessWidget {
  final String label, value; final IconData icon; final Color color; final bool isDark;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: _f(sz: 20, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
            Text(label, style: _f(sz: 12, c: isDark ? Colors.white54 : AppColors.gray)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title; final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Text(title, style: _f(sz: 16, fw: FontWeight.w800, c: isDark ? AppColors.gold : AppColors.darkGreen)),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final List<Widget> children; final bool isDark;
  const _ProfileCard({required this.children, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }
}

class _ModernSettingsTile extends StatelessWidget {
  final IconData icon; final Color color; final String title, subtitle; final Widget? trailing; final VoidCallback? onTap;
  const _ModernSettingsTile({required this.icon, required this.color, required this.title, required this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: _f(fw: FontWeight.w700, sz: 14)),
      subtitle: Text(subtitle, style: _f(sz: 11, c: AppColors.textSecondary)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.gray),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 64, endIndent: 16, color: Theme.of(context).dividerColor.withOpacity(0.05));
}
