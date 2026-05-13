import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import '../../services/azan_service.dart';
import 'muazzin_selection_page.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class AzanSettingsPage extends StatefulWidget {
  const AzanSettingsPage({super.key});

  @override
  State<AzanSettingsPage> createState() => _AzanSettingsPageState();
}

class _AzanSettingsPageState extends State<AzanSettingsPage> {
  final AzanService _azanService = AzanService();

  bool _azanEnabled = true;
  bool _fajrEnabled = true;
  bool _dhuhrEnabled = true;
  bool _asrEnabled = true;
  bool _maghribEnabled = true;
  bool _ishaEnabled = true;
  String _selectedMuazzinName = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _azanEnabled = _azanService.azanEnabled;
      _fajrEnabled = _azanService.fajrAzanEnabled;
      _dhuhrEnabled = _azanService.dhuhrAzanEnabled;
      _asrEnabled = _azanService.asrAzanEnabled;
      _maghribEnabled = _azanService.maghribAzanEnabled;
      _ishaEnabled = _azanService.ishaAzanEnabled;
      _selectedMuazzinName = _azanService.selectedMuazzin.nameAr;
    });
  }

  Future<void> _setAzanEnabled(bool value) async {
    setState(() => _isLoading = true);
    try {
      await _azanService.setAzanEnabled(value);
      setState(() => _azanEnabled = value);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setPrayerEnabled(String prayer, bool value) async {
    setState(() => _isLoading = true);
    try {
      switch (prayer) {
        case 'fajr':
          await _azanService.setFajrAzanEnabled(value);
          setState(() => _fajrEnabled = value);
          break;
        case 'dhuhr':
          await _azanService.setDhuhrAzanEnabled(value);
          setState(() => _dhuhrEnabled = value);
          break;
        case 'asr':
          await _azanService.setAsrAzanEnabled(value);
          setState(() => _asrEnabled = value);
          break;
        case 'maghrib':
          await _azanService.setMaghribAzanEnabled(value);
          setState(() => _maghribEnabled = value);
          break;
        case 'isha':
          await _azanService.setIshaAzanEnabled(value);
          setState(() => _ishaEnabled = value);
          break;
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('حدث خطأ: $message'), backgroundColor: Colors.red),
    );
  }

  void _openMuazzinSelection() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MuazzinSelectionPage()),
    );
    // Refresh after returning
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7F6);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.darkGreen),
              )
            : CustomScrollView(
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 12,
                        bottom: 32,
                        left: 20,
                        right: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF0D2818), const Color(0xFF0A3D22)]
                              : [const Color(0xFF145A3A), const Color(0xFF1E8255)],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const DirectionalIcon(
                                    isBack: true,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'إعدادات الأذان',
                                  textAlign: TextAlign.center,
                                  style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'تخصيص صوت الأذان لكل صلاة',
                            style: _f(sz: 14, fw: FontWeight.w500, c: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Settings Content ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Master Toggle
                        _SettingsSection(
                          title: 'الأذان',
                          icon: Icons.volume_up_rounded,
                          isDark: isDark,
                          children: [
                            _SettingsTile(
                              title: 'تفعيل الأذان',
                              subtitle: 'تشغيل صوت الأذان عند دخول وقت الصلاة',
                              icon: Icons.notifications_active_rounded,
                              value: _azanEnabled,
                              onChanged: _setAzanEnabled,
                              isDark: isDark,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Muazzin Selection
                        _SettingsSection(
                          title: 'المؤذن',
                          icon: Icons.record_voice_over_rounded,
                          isDark: isDark,
                          children: [
                            _NavigationTile(
                              title: 'اختيار المؤذن',
                              subtitle: _selectedMuazzinName,
                              icon: Icons.person_rounded,
                              onTap: _openMuazzinSelection,
                              isDark: isDark,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Per-Prayer Settings
                        AnimatedOpacity(
                          opacity: _azanEnabled ? 1.0 : 0.5,
                          duration: const Duration(milliseconds: 200),
                          child: IgnorePointer(
                            ignoring: !_azanEnabled,
                            child: _SettingsSection(
                              title: 'الأذان لكل صلاة',
                              icon: Icons.mosque_rounded,
                              isDark: isDark,
                              children: [
                                _SettingsTile(
                                  title: 'أذان الفجر',
                                  subtitle: 'صوت أذان مميز للفجر',
                                  icon: Icons.wb_twilight_rounded,
                                  value: _fajrEnabled,
                                  onChanged: (v) => _setPrayerEnabled('fajr', v),
                                  isDark: isDark,
                                ),
                                _SettingsTile(
                                  title: 'أذان الظهر',
                                  subtitle: 'تشغيل الأذان عند دخول وقت الظهر',
                                  icon: Icons.light_mode_rounded,
                                  value: _dhuhrEnabled,
                                  onChanged: (v) => _setPrayerEnabled('dhuhr', v),
                                  isDark: isDark,
                                ),
                                _SettingsTile(
                                  title: 'أذان العصر',
                                  subtitle: 'تشغيل الأذان عند دخول وقت العصر',
                                  icon: Icons.cloud_rounded,
                                  value: _asrEnabled,
                                  onChanged: (v) => _setPrayerEnabled('asr', v),
                                  isDark: isDark,
                                ),
                                _SettingsTile(
                                  title: 'أذان المغرب',
                                  subtitle: 'تشغيل الأذان عند دخول وقت المغرب',
                                  icon: Icons.wb_twilight_rounded,
                                  value: _maghribEnabled,
                                  onChanged: (v) => _setPrayerEnabled('maghrib', v),
                                  isDark: isDark,
                                ),
                                _SettingsTile(
                                  title: 'أذان العشاء',
                                  subtitle: 'تشغيل الأذان عند دخول وقت العشاء',
                                  icon: Icons.nights_stay_rounded,
                                  value: _ishaEnabled,
                                  onChanged: (v) => _setPrayerEnabled('isha', v),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Debug Test Button
                        _SettingsSection(
                          title: 'اختبار الأذان',
                          icon: Icons.bug_report_rounded,
                          isDark: isDark,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    'اضغط لجدولة أذان تجريبي بعد 10 ثوانٍ\n(يعمل حتى لو أغلقت التطبيق)',
                                    textAlign: TextAlign.center,
                                    style: _f(sz: 13, c: isDark ? Colors.white60 : Colors.black54),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await _azanService.debugTestAzan();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('🧪 تم جدولة أذان تجريبي - سيعمل بعد 10 ثوانٍ'),
                                            backgroundColor: Color(0xFF1B7A4E),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.play_arrow_rounded),
                                      label: Text('تجربة الأذان (10 ثوانٍ)', style: _f(sz: 14, fw: FontWeight.w600, c: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1B7A4E),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Reusable Widgets ──

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool isDark;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final sectionBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.darkGreen, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: _f(sz: 18, fw: FontWeight.w700, c: textColor),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white60 : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFF0F4F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? AppColors.darkGreen : subColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _f(sz: 16, fw: FontWeight.w600, c: textColor)),
                Text(subtitle, style: _f(sz: 12, fw: FontWeight.w400, c: subColor)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.darkGreen,
            activeTrackColor: AppColors.darkGreen.withOpacity(0.3),
            inactiveThumbColor: isDark ? Colors.grey[600] : Colors.grey[400],
            inactiveTrackColor: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _NavigationTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.darkGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.darkGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _f(sz: 16, fw: FontWeight.w600, c: textColor)),
                  Text(subtitle, style: _f(sz: 13, fw: FontWeight.w500, c: AppColors.darkGreen)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.darkGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const DirectionalIcon(
                isBack: false,
                size: 16,
                color: AppColors.darkGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
