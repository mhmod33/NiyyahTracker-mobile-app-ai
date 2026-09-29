import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../models/dawri_model.dart';
import '../../services/dawri_service.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

/// Shows a member's profile card in a league — stats, badges, weekly prayer dots.
class MemberProfileSheet extends StatefulWidget {
  final String dawriId;
  final String userId;
  final String name;
  final bool isSupervisor;
  final Dawri dawri;

  const MemberProfileSheet({
    super.key,
    required this.dawriId,
    required this.userId,
    required this.name,
    required this.isSupervisor,
    required this.dawri,
  });

  @override
  State<MemberProfileSheet> createState() => _MemberProfileSheetState();
}

class _MemberProfileSheetState extends State<MemberProfileSheet> {
  List<DawriDayEntry> _weekEntries = [];
  DawriMember? _member;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      // Week starts Monday
      final weekStart = now.subtract(Duration(days: now.weekday - 1));

      final entries = await DawriService().getWeekEntries(
        dawriId: widget.dawriId,
        userId: widget.userId,
        weekStart: weekStart,
      );

      // Find member data from dawri
      DawriMember? member;
      for (final m in widget.dawri.members) {
        if (m.userId == widget.userId) {
          member = m;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _weekEntries = entries;
          _member = member;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _avatarColor(String name) {
    final colors = [
      AppColors.darkGreen, AppColors.midGreen, Colors.purple,
      Colors.blue, Colors.orange, Colors.pink, Colors.teal,
    ];
    return colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1F1C) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.darkGreen))
            : SingleChildScrollView(
                controller: scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Close button
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Avatar
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _avatarColor(widget.name),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                _avatarColor(widget.name).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.name.isNotEmpty
                              ? widget.name[0].toUpperCase()
                              : '؟',
                          style: _f(
                              sz: 28, fw: FontWeight.bold, c: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.name,
                      style: _f(
                        sz: 20,
                        fw: FontWeight.w800,
                        c: isDark ? Colors.white : AppColors.darkGreen,
                      ),
                    ),
                    if (widget.isSupervisor) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'مشرف الدوري',
                          style: _f(
                              sz: 12,
                              fw: FontWeight.w700,
                              c: Colors.purple),
                        ),
                      ),
                    ],
                    // Date range
                    const SizedBox(height: 6),
                    Text(
                      _weekRangeLabel(),
                      style: _f(sz: 12, c: AppColors.gray),
                    ),
                    // Badges
                    if (_member?.badges.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      _buildBadgesRow(isDark),
                    ],
                    const SizedBox(height: 20),
                    // Stats row (streak / missed / on-time)
                    _buildStatsRow(isDark),
                    const SizedBox(height: 20),
                    // Weekly prayer table
                    _buildWeeklyTable(isDark),
                    const SizedBox(height: 20),
                    // Share prompt
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.darkGreen.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.darkGreen.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.share_rounded,
                                size: 16, color: AppColors.darkGreen),
                            const SizedBox(width: 8),
                            Text(
                              'مشاركك مع دوريك • صحّحك الآن',
                              style: _f(
                                  sz: 13,
                                  fw: FontWeight.w700,
                                  c: AppColors.darkGreen),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final onTime = _weekEntries.fold<int>(
        0,
        (s, e) => s +
            e.prayers.values
                .where((p) =>
                    p == PrayerStatus.onTime ||
                    p == PrayerStatus.congregation ||
                    p == PrayerStatus.mosque)
                .length);
    final missed = _weekEntries.fold<int>(0,
        (s, e) => s + e.prayers.values.where((p) => p == PrayerStatus.missed).length);
    final streak = _member?.currentStreak ?? 0;

    return Row(
      children: [
        _StatBox(
          label: 'في الوقت',
          value: '$onTime',
          icon: Icons.check_circle_rounded,
          color: AppColors.midGreen,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _StatBox(
          label: 'فائتة',
          value: '$missed',
          icon: Icons.cancel_outlined,
          color: Colors.redAccent,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _StatBox(
          label: 'يوم متواصل',
          value: '$streak',
          icon: Icons.local_fire_department_rounded,
          color: AppColors.gold,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildWeeklyTable(bool isDark) {
    final cardBg = isDark ? Colors.white.withOpacity(0.04) : AppColors.paleGreen.withOpacity(0.5);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  'الصلاة',
                  style: _f(sz: 12, fw: FontWeight.w700, c: AppColors.gray),
                ),
              ),
              Expanded(
                child: Text(
                  'اليوم',
                  textAlign: TextAlign.center,
                  style: _f(sz: 12, fw: FontWeight.w700, c: AppColors.darkGreen),
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  'هذا الأسبوع',
                  textAlign: TextAlign.center,
                  style: _f(sz: 12, fw: FontWeight.w700, c: AppColors.gray),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          // Prayer rows
          ...DawriPrayer.all.map((prayer) {
            // Today's status
            final todayEntry = _weekEntries.firstWhere(
              (e) {
                final n = DateTime.now();
                final key =
                    '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
                return e.date == key;
              },
              orElse: () => DawriDayEntry.empty(''),
            );
            final todayStatus = todayEntry.prayers[prayer];

            // Week dots (7 days)
            final weekDots = List.generate(7, (i) {
              final d = weekStart.add(Duration(days: i));
              final key =
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              final entry = _weekEntries.firstWhere(
                (e) => e.date == key,
                orElse: () => DawriDayEntry.empty(key),
              );
              return entry.prayers[prayer];
            });

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      DawriPrayer.labelAr(prayer),
                      style: _f(
                        sz: 13,
                        fw: FontWeight.w700,
                        c: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Today status button
                  Expanded(
                    child: Center(
                      child: _TodayStatusChip(
                          status: todayStatus, isDark: isDark),
                    ),
                  ),
                  // Week dots
                  SizedBox(
                    width: 90,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: weekDots.map((s) {
                        Color dotColor;
                        switch (s) {
                          case PrayerStatus.mosque:
                            dotColor = AppColors.darkGreen;
                            break;
                          case PrayerStatus.congregation:
                            dotColor = AppColors.midGreen;
                            break;
                          case PrayerStatus.onTime:
                            dotColor = AppColors.lightGreen;
                            break;
                          case PrayerStatus.qada:
                            dotColor = AppColors.gold;
                            break;
                          case PrayerStatus.missed:
                            dotColor = Colors.redAccent.withOpacity(0.7);
                            break;
                          default:
                            dotColor = isDark
                                ? Colors.white12
                                : Colors.grey.shade300;
                        }
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Week label
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 70),
              const Spacer(),
              SizedBox(
                width: 90,
                child: Text(
                  '٧ أيام',
                  textAlign: TextAlign.center,
                  style: _f(sz: 10, c: AppColors.gray),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesRow(bool isDark) {
    final badges = _member?.badges ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'الأوسمة المكتسبة',
              style: _f(
                sz: 14,
                fw: FontWeight.w700,
                c: isDark ? Colors.white : AppColors.darkGreen,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${badges.length} مكتسب',
              style: _f(sz: 12, c: AppColors.gold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) => _BadgeCard(
              badgeId: badges[i],
              isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }

  String _weekRangeLabel() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    String _fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '${_fmt(start)} → ${_fmt(end)}';
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: _f(
                  sz: 20,
                  fw: FontWeight.w900,
                  c: isDark ? Colors.white : AppColors.textPrimary),
            ),
            Text(
              label,
              style: _f(sz: 10, c: AppColors.gray),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayStatusChip extends StatelessWidget {
  final PrayerStatus? status;
  final bool isDark;
  const _TodayStatusChip({this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (status == null || status == PrayerStatus.notLogged) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('—', style: _f(sz: 13, c: AppColors.gray)),
      );
    }
    Color bg;
    Color fg = Colors.white;
    switch (status!) {
      case PrayerStatus.mosque:
        bg = AppColors.darkGreen;
        break;
      case PrayerStatus.congregation:
        bg = AppColors.midGreen;
        break;
      case PrayerStatus.onTime:
        bg = AppColors.lightGreen;
        break;
      case PrayerStatus.qada:
        bg = AppColors.gold;
        break;
      case PrayerStatus.missed:
        bg = Colors.redAccent.withOpacity(0.7);
        break;
      default:
        bg = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status!.labelAr,
        style: _f(sz: 11, fw: FontWeight.w700, c: fg),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final String badgeId;
  final bool isDark;
  const _BadgeCard({required this.badgeId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    return Container(
      width: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _badgeIcon(badgeId),
          const SizedBox(height: 6),
          Text(
            _badgeLabel(badgeId),
            style: _f(
                sz: 9,
                fw: FontWeight.w700,
                c: isDark ? Colors.white70 : AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _badgeIcon(String id) {
    // Map badge IDs to mosque/prayer icons
    final icons = <String, String>{
      'mosque_fajr': '🕌',
      'mosque_steps': '🕌',
      'streak_7': '🔥',
      'streak_30': '⭐',
      'quran_week': '📖',
      'azkar_week': '📿',
    };
    final emoji = icons[id] ?? '🏅';
    return Text(emoji, style: const TextStyle(fontSize: 30));
  }

  String _badgeLabel(String id) {
    final labels = <String, String>{
      'mosque_fajr': 'أول خطوات المسجد',
      'mosque_steps': 'المواظب على المسجد',
      'streak_7': 'أسبوع متواصل',
      'streak_30': 'شهر متواصل',
      'quran_week': 'قارئ الأسبوع',
      'azkar_week': 'مواظب الأذكار',
    };
    return labels[id] ?? id;
  }
}
