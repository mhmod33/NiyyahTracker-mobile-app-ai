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

/// Bottom sheet for logging daily prayers (and extras) in a league.
class PrayerLogSheet extends StatefulWidget {
  final Dawri dawri;
  final String userId;

  const PrayerLogSheet({
    super.key,
    required this.dawri,
    required this.userId,
  });

  @override
  State<PrayerLogSheet> createState() => _PrayerLogSheetState();
}

class _PrayerLogSheetState extends State<PrayerLogSheet> {
  final Map<String, PrayerStatus> _prayers = {};
  final Map<String, int> _extras = {};
  bool _saving = false;
  bool _loadingExisting = true;

  // Points per prayer status for quick reference display
  static const List<_PrayerOption> _options = [
    _PrayerOption(
      status: PrayerStatus.onTime,
      label: 'في الوقت',
      badge: '10+ نقطة',
      icon: Icons.access_time_filled_rounded,
      color: AppColors.lightGreen,
    ),
    _PrayerOption(
      status: PrayerStatus.congregation,
      label: 'في جماعة',
      badge: '13+ نقطة',
      icon: Icons.people_rounded,
      color: AppColors.midGreen,
    ),
    _PrayerOption(
      status: PrayerStatus.mosque,
      label: 'في المسجد',
      badge: '15+ نقطة',
      icon: Icons.mosque_rounded,
      color: AppColors.darkGreen,
    ),
    _PrayerOption(
      status: PrayerStatus.qada,
      label: 'قضاء',
      badge: '3+ نقطة',
      icon: Icons.replay_rounded,
      color: AppColors.gold,
    ),
    _PrayerOption(
      status: PrayerStatus.missed,
      label: 'فائتة',
      badge: '',
      icon: Icons.cancel_outlined,
      color: Colors.redAccent,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final entry = await DawriService().getTodayEntry(
        dawriId: widget.dawri.id,
        userId: widget.userId,
      );
      if (entry != null && mounted) {
        setState(() {
          _prayers.addAll(entry.prayers);
          _extras.addAll(entry.extras);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingExisting = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DawriService().saveDayEntry(
        dawriId: widget.dawri.id,
        userId: widget.userId,
        prayers: _prayers,
        extras: _extras,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ السجل بنجاح ✅',
                style: _f(c: Colors.white)),
            backgroundColor: AppColors.darkGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحفظ: $e', style: _f(c: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int get _totalPoints {
    int pts = 0;
    for (final s in _prayers.values) {
      pts += s.points;
    }
    for (final e in _extras.entries) {
      final act = DawriExtraActivity.all.firstWhere(
        (a) => a.id == e.key,
        orElse: () => const DawriExtraActivity(
            id: '', nameAr: '', description: '', icon: '', pointsPerUnit: 0),
      );
      pts += e.value * act.pointsPerUnit;
    }
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1F1C) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _loadingExisting
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.darkGreen))
            : Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سجّل صلواتك اليوم',
                                style: _f(
                                  sz: 18,
                                  fw: FontWeight.w800,
                                  c: isDark ? Colors.white : AppColors.darkGreen,
                                ),
                              ),
                              Text(
                                'كل صلاة تُحسب، مهما كان وقتها',
                                style: _f(sz: 12, c: AppColors.gray),
                              ),
                            ],
                          ),
                        ),
                        // Points preview
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.darkGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.gold, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$_totalPoints نقطة',
                                style: _f(
                                  sz: 13,
                                  fw: FontWeight.w800,
                                  c: AppColors.darkGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Prayers
                          ...DawriPrayer.all.map((p) =>
                              _buildPrayerSection(p, isDark)),

                          // Extras (custom mode only)
                          if (widget.dawri.trackingMode ==
                                  DawriTrackingMode.custom &&
                              widget.dawri.activeExtras.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'العبادات الإضافية',
                              style: _f(
                                sz: 16,
                                fw: FontWeight.w800,
                                c: isDark ? Colors.white : AppColors.darkGreen,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...widget.dawri.activeExtras.map(
                                (a) => _buildExtraActivity(a, isDark)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Save bar
                  _buildSaveBar(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildPrayerSection(String prayer, bool isDark) {
    final selected = _prayers[prayer];
    final prayerTime = _prayerTime(prayer);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : AppColors.paleGreen.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected != null
                ? AppColors.darkGreen.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prayer header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    DawriPrayer.labelAr(prayer),
                    style: _f(
                      sz: 16,
                      fw: FontWeight.w800,
                      c: isDark ? Colors.white : AppColors.darkGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ ${_prayerNameEn(prayer)}',
                    style: _f(sz: 12, c: AppColors.gray),
                  ),
                  const Spacer(),
                  Text(
                    prayerTime,
                    style: _f(
                        sz: 13,
                        fw: FontWeight.w600,
                        c: AppColors.gold),
                  ),
                ],
              ),
            ),
            // Options
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: _options.map((opt) {
                  final isSelected = selected == opt.status;
                  // Sunnah toggle (only visible after onTime/congregation/mosque)
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _prayers.remove(prayer);
                          } else {
                            _prayers[prayer] = opt.status;
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? opt.color.withOpacity(0.12)
                              : (isDark
                                  ? Colors.white.withOpacity(0.03)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? opt.color.withOpacity(0.6)
                                : Colors.transparent,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Circle radio
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? opt.color
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? opt.color
                                      : AppColors.gray.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      size: 13, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(opt.icon,
                                      size: 16,
                                      color: isSelected
                                          ? opt.color
                                          : AppColors.gray),
                                  const SizedBox(width: 6),
                                  Text(
                                    opt.label,
                                    style: _f(
                                      sz: 14,
                                      fw: FontWeight.w700,
                                      c: isSelected
                                          ? opt.color
                                          : isDark
                                              ? Colors.white70
                                              : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (opt.status == PrayerStatus.missed) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      'سجلها وانطلق إلى الأمام',
                                      style: _f(sz: 10, c: AppColors.gray),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (opt.badge.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: opt.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  opt.badge,
                                  style: _f(
                                    sz: 10,
                                    fw: FontWeight.w800,
                                    c: opt.color,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // Sunnah toggle (only for logged prayers)
            if (selected != null &&
                selected != PrayerStatus.missed &&
                selected != PrayerStatus.qada &&
                selected != PrayerStatus.notLogged) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    Switch(
                      value: false, // simplified for MVP
                      onChanged: null,
                      activeColor: AppColors.darkGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السنة',
                            style: _f(
                              sz: 13,
                              fw: FontWeight.w700,
                              c: AppColors.gray,
                            ),
                          ),
                          Text(
                            'أخر حالة الصلاة أولاً',
                            style: _f(sz: 10, c: AppColors.gray),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExtraActivity(DawriExtraActivity activity, bool isDark) {
    final count = _extras[activity.id] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: count > 0
                ? AppColors.gold.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(activity.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.nameAr,
                    style: _f(
                      sz: 14,
                      fw: FontWeight.w700,
                      c: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    activity.description,
                    style: _f(sz: 11, c: AppColors.gray),
                  ),
                ],
              ),
            ),
            // Counter
            Row(
              children: [
                _CounterBtn(
                  icon: Icons.remove_rounded,
                  onTap: count > 0
                      ? () => setState(() {
                            _extras[activity.id] = count - 1;
                            if (_extras[activity.id] == 0) {
                              _extras.remove(activity.id);
                            }
                          })
                      : null,
                  isDark: isDark,
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: _f(
                      sz: 17,
                      fw: FontWeight.w900,
                      c: count > 0
                          ? AppColors.gold
                          : AppColors.gray,
                    ),
                  ),
                ),
                _CounterBtn(
                  icon: Icons.add_rounded,
                  onTap: () => setState(() {
                    _extras[activity.id] = count + 1;
                  }),
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F1C) : Colors.white,
        border: Border(
          top: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _prayers.isNotEmpty && !_saving ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.darkGreen,
            disabledBackgroundColor: AppColors.gray.withOpacity(0.3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _saving
              ? const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2)
              : Text('حفظ',
                  style: _f(sz: 16, fw: FontWeight.bold, c: Colors.white)),
        ),
      ),
    );
  }

  String _prayerTime(String prayer) {
    // Simplified — in production, use adhan package for actual times
    switch (prayer) {
      case DawriPrayer.fajr:    return '4:45 ص';
      case DawriPrayer.dhuhr:   return '12:10 م';
      case DawriPrayer.asr:     return '3:30 م';
      case DawriPrayer.maghrib: return '6:45 م';
      case DawriPrayer.isha:    return '8:15 م';
      default:                  return '';
    }
  }

  String _prayerNameEn(String prayer) {
    switch (prayer) {
      case DawriPrayer.fajr:    return 'Fajr';
      case DawriPrayer.dhuhr:   return 'Dhuhr';
      case DawriPrayer.asr:     return 'Asr';
      case DawriPrayer.maghrib: return 'Maghrib';
      case DawriPrayer.isha:    return 'Isha';
      default:                  return prayer;
    }
  }
}

class _PrayerOption {
  final PrayerStatus status;
  final String label;
  final String badge;
  final IconData icon;
  final Color color;
  const _PrayerOption({
    required this.status,
    required this.label,
    required this.badge,
    required this.icon,
    required this.color,
  });
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;
  const _CounterBtn({required this.icon, this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.darkGreen.withOpacity(0.12)
              : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? AppColors.darkGreen : AppColors.gray,
        ),
      ),
    );
  }
}
