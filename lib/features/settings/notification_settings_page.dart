import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../services/notification_service.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationService _notificationService = NotificationService();
  
  bool _morningAzkarEnabled = true;
  bool _eveningAzkarEnabled = true;
  bool _prayerTimesEnabled = true;
  bool _azkarReminderEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _morningAzkarEnabled = _notificationService.morningAzkarEnabled;
      _eveningAzkarEnabled = _notificationService.eveningAzkarEnabled;
      _prayerTimesEnabled = _notificationService.prayerTimesEnabled;
      _azkarReminderEnabled = _notificationService.azkarReminderEnabled;
    });
  }

  Future<void> _updateSetting(String setting, bool value) async {
    setState(() => _isLoading = true);
    
    try {
      switch (setting) {
        case 'morning_azkar':
          await _notificationService.setMorningAzkarEnabled(value);
          setState(() => _morningAzkarEnabled = value);
          break;
        case 'evening_azkar':
          await _notificationService.setEveningAzkarEnabled(value);
          setState(() => _eveningAzkarEnabled = value);
          break;
        case 'prayer_times':
          await _notificationService.setPrayerTimesEnabled(value);
          setState(() => _prayerTimesEnabled = value);
          break;
        case 'azkar_reminder':
          await _notificationService.setAzkarReminderEnabled(value);
          setState(() => _azkarReminderEnabled = value);
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testNotification() async {
    try {
      await _notificationService.showTestNotification(context: context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال إشعار اختباري'),
            backgroundColor: AppColors.darkGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الإشعار: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7F6);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white60 : AppColors.textSecondary;

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
                                  child: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'الإشعارات',
                                  textAlign: TextAlign.center,
                                  style: _f(
                                    sz: 20,
                                    fw: FontWeight.w800,
                                    c: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'تخصيص إشعارات التطبيق',
                            style: _f(
                              sz: 14,
                              fw: FontWeight.w500,
                              c: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Settings Sections ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Azkar Settings
                        _SettingsSection(
                          title: 'إشعارات الأذكار',
                          icon: Icons.auto_stories_rounded,
                          isDark: isDark,
                          children: [
                            _SettingsTile(
                              title: 'أذكار الصباح',
                              subtitle: 'تذكير في الساعة 5:00 صباحاً',
                              icon: Icons.wb_twilight_rounded,
                              value: _morningAzkarEnabled,
                              onChanged: (value) => _updateSetting('morning_azkar', value),
                              isDark: isDark,
                            ),
                            _SettingsTile(
                              title: 'أذكار المساء',
                              subtitle: 'تذكير في الساعة 6:00 مساءً',
                              icon: Icons.nights_stay_rounded,
                              value: _eveningAzkarEnabled,
                              onChanged: (value) => _updateSetting('evening_azkar', value),
                              isDark: isDark,
                            ),
                            _SettingsTile(
                              title: 'تذكيرات دورية',
                              subtitle: 'كل ساعتين خلال اليوم',
                              icon: Icons.timer_rounded,
                              value: _azkarReminderEnabled,
                              onChanged: (value) => _updateSetting('azkar_reminder', value),
                              isDark: isDark,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Prayer Settings
                        _SettingsSection(
                          title: 'إشعارات الصلاة',
                          icon: Icons.mosque_rounded,
                          isDark: isDark,
                          children: [
                            _SettingsTile(
                              title: 'أوقات الصلاة',
                              subtitle: 'تنبيه قبل كل صلاة',
                              icon: Icons.access_time_rounded,
                              value: _prayerTimesEnabled,
                              onChanged: (value) => _updateSetting('prayer_times', value),
                              isDark: isDark,
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
                  child: Icon(
                    icon,
                    color: AppColors.darkGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: _f(
                    sz: 18,
                    fw: FontWeight.w700,
                    c: textColor,
                  ),
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
                Text(
                  title,
                  style: _f(
                    sz: 16,
                    fw: FontWeight.w600,
                    c: textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: _f(
                    sz: 12,
                    fw: FontWeight.w400,
                    c: subColor,
                  ),
                ),
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

class _TestTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _TestTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white60 : AppColors.textSecondary;

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
              child: Icon(
                icon,
                color: AppColors.darkGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _f(
                      sz: 16,
                      fw: FontWeight.w600,
                      c: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: _f(
                      sz: 12,
                      fw: FontWeight.w400,
                      c: subColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.darkGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: AppColors.darkGreen,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
