import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart' as uuid_pkg;
import '../../core/app_colors.dart';
import '../../models/worship_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/fajr_tree_widget.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c);

// ── Day record ────────────────────────────────────────────────────────────────

class _DayRecord {
  final DateTime date;
  bool prayed;
  bool wokeWithAlarm;
  String? docId;

  _DayRecord({
    required this.date,
    this.prayed = false,
    this.wokeWithAlarm = false,
    this.docId,
  });
}

// ── Page ──────────────────────────────────────────────────────────────────────

class FajrStreakPage extends StatefulWidget {
  const FajrStreakPage({super.key});

  @override
  State<FajrStreakPage> createState() => _FajrStreakPageState();
}

class _FajrStreakPageState extends State<FajrStreakPage> {
  final _firebaseService = FirebaseService();
  List<_DayRecord> _days = [];
  bool _loading = true;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) { setState(() => _loading = false); return; }

    final today = DateTime.now();
    final weekStart = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));

    try {
      final records = await _firebaseService.getWorshipsInRange(
          userId, weekStart, today);

      // Build lookup by date key
      final byDate = <String, DailyWorship>{};
      for (final r in records) {
        final k = _dateKey(r.date);
        byDate[k] = r;
      }

      final days = List.generate(7, (i) {
        final d = weekStart.add(Duration(days: i));
        final r = byDate[_dateKey(d)];
        return _DayRecord(
          date: d,
          prayed: r?.prayerCount != null && r!.prayerCount > 0,
          wokeWithAlarm: r?.worships['fajr_woke_alarm'] == true,
          docId: r?.id,
        );
      });

      // Streak = consecutive days ending today with prayed == true
      int streak = 0;
      for (int i = days.length - 1; i >= 0; i--) {
        if (days[i].prayed) streak++; else break;
      }

      setState(() {
        _days = days;
        _streak = streak;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _saveDay(_DayRecord day) async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) return;

    final docId = day.docId ?? const uuid_pkg.Uuid().v4();

    // Merge with any existing record for this date
    List<DailyWorship> existing = [];
    try {
      existing = await _firebaseService.getDailyWorshipByDate(userId, day.date);
    } catch (_) {}

    final prev = existing.firstOrNull;
    final updatedWorships = <String, bool>{
      ...?prev?.worships,
      'fajr_woke_alarm': day.wokeWithAlarm,
    };

    final worship = DailyWorship(
      id: prev?.id ?? docId,
      date: day.date,
      prayerCount: day.prayed ? (prev?.prayerCount ?? 0).clamp(1, 5) : 0,
      quranPages: prev?.quranPages ?? 0,
      worships: updatedWorships,
    );

    await _firebaseService.saveDailyWorship(userId, worship);

    // Recompute streak
    int streak = 0;
    for (int i = _days.length - 1; i >= 0; i--) {
      if (_days[i].prayed) streak++; else break;
    }
    setState(() {
      day.docId = worship.id;
      _streak = streak;
    });
  }

  // ── Bottom sheet to log a day ──────────────────────────────────────────────

  void _showLogSheet(_DayRecord day) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool prayed = day.prayed;
    bool woke  = day.wokeWithAlarm;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A14) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white24
                            : Colors.black.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  Text(
                    'تعديل التسجيل — ${_arabicDay(day.date)}، ${day.date.day} ${_arabicMonth(day.date.month)}',
                    style: _f(sz: 16, fw: FontWeight.w800,
                        c: isDark ? Colors.white : AppColors.textPrimary),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 20),

                  // Prayer row
                  Text('الصلاة', style: _f(sz: 12,
                      c: isDark ? Colors.white54 : AppColors.textSecondary),
                    textAlign: TextAlign.right),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _ToggleBtn(
                      label: 'نعم، صليت',
                      dotColor: AppColors.darkGreen,
                      selected: prayed,
                      isDark: isDark,
                      onTap: () => setSheet(() => prayed = true),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _ToggleBtn(
                      label: 'لم أصل',
                      dotColor: Colors.red,
                      selected: !prayed,
                      isDark: isDark,
                      onTap: () => setSheet(() => prayed = false),
                    )),
                  ]),
                  const SizedBox(height: 16),

                  // Wakeup row
                  Text('الاستيقاظ', style: _f(sz: 12,
                      c: isDark ? Colors.white54 : AppColors.textSecondary),
                    textAlign: TextAlign.right),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _ToggleBtn(
                      label: 'نعم، استيقظت',
                      dotColor: AppColors.darkGreen,
                      selected: woke,
                      isDark: isDark,
                      onTap: () => setSheet(() => woke = true),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _ToggleBtn(
                      label: 'لم أستيقظ',
                      dotColor: Colors.red,
                      selected: !woke,
                      isDark: isDark,
                      onTap: () => setSheet(() => woke = false),
                    )),
                  ]),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.black.withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('إلغاء',
                            style: _f(sz: 14, fw: FontWeight.w600,
                                c: isDark ? Colors.white60 : AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          setState(() {
                            day.prayed = prayed;
                            day.wokeWithAlarm = woke;
                          });
                          await _saveDay(day);
                        },
                        child: Text('حفظ',
                            style: _f(sz: 14, fw: FontWeight.w700,
                                c: Colors.white)),
                      ),
                    ),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _arabicDay(DateTime d) {
    const days = ['الإثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    return days[d.weekday - 1];
  }

  static String _arabicMonth(int m) {
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
        'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return months[m - 1];
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0F0B) : const Color(0xFFF3F7F4);
    final textCol = isDark ? Colors.white : AppColors.textPrimary;
    final subCol = isDark ? Colors.white54 : AppColors.textSecondary;
    final cardBg = isDark ? const Color(0xFF131A14) : Colors.white;

    final allPrayed = _days.every((d) => d.prayed);
    final today = DateTime.now();
    final weekStart = _days.isNotEmpty ? _days.first.date : today.subtract(const Duration(days: 6));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.darkGreen))
            : CustomScrollView(
                slivers: [
                  // ── App bar ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 12,
                        bottom: 20,
                        left: 20,
                        right: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF0D2818), const Color(0xFF051109)]
                              : [const Color(0xFF145A3A), const Color(0xFF1E8255)],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text('سجل المتابعة',
                                  style: _f(sz: 18, fw: FontWeight.w800,
                                      c: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'قم بتأكيد حالة صلاة الفجر في الأيام التالية',
                            style: _f(sz: 15, fw: FontWeight.w600,
                                c: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── All-done banner ─────────────────────────────────────
                  if (allPrayed && _days.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.lightGreen.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text('تم تسجيل جميع أيامك، تقبل الله منك',
                                style: _f(sz: 17, fw: FontWeight.w800, c: textCol),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text(
                              'أحب الأعمال إلى الله أدومها وإن قل. نلقاك غدًا إن شاء الله',
                              style: _f(sz: 13, c: subCol),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Day cards ────────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final day = _days[i];
                          final isToday = day.date.year == today.year &&
                              day.date.month == today.month &&
                              day.date.day == today.day;
                          final isFuture = day.date.isAfter(today);

                          return _DayCard(
                            day: day,
                            isToday: isToday,
                            isFuture: isFuture,
                            isDark: isDark,
                            onEdit: isFuture ? null : () => _showLogSheet(day),
                          );
                        },
                        childCount: _days.length,
                      ),
                    ),
                  ),

                  // ── Log button ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkGreen,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.edit_calendar_rounded,
                            color: Colors.white, size: 20),
                        label: Text('تسجيل الصلوات',
                            style: _f(sz: 15, fw: FontWeight.w700,
                                c: Colors.white)),
                        onPressed: () {
                          // Open today's sheet
                          final todayRecord = _days.lastWhere(
                            (d) => d.date.year == today.year &&
                                d.date.month == today.month &&
                                d.date.day == today.day,
                            orElse: () => _days.last,
                          );
                          _showLogSheet(todayRecord);
                        },
                      ),
                    ),
                  ),

                  // ── Tree mini-preview ────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      child: FajrTreeWidget(
                        streak: _streak,
                        weekDays: _days.map((d) => d.prayed).toList(),
                        weekStart: weekStart,
                        isDark: isDark,
                        // No onTap here — already on the streak page
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Day card ──────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final _DayRecord day;
  final bool isToday;
  final bool isFuture;
  final bool isDark;
  final VoidCallback? onEdit;

  const _DayCard({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.isDark,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF131A14) : Colors.white;
    final textCol = isDark ? Colors.white : AppColors.textPrimary;
    final subCol = isDark ? Colors.white54 : AppColors.textSecondary;

    const dayNames = {
      1: 'الإثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس',
      5: 'الجمعة',  6: 'السبت',    7: 'الأحد',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? AppColors.darkGreen.withValues(alpha: 0.4)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Day status dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFuture
                    ? Colors.grey.withValues(alpha: 0.3)
                    : (day.prayed ? AppColors.darkGreen : Colors.red.shade400),
              ),
            ),
            const SizedBox(width: 12),

            // Day name + details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday
                        ? '${dayNames[day.date.weekday] ?? ''} (اليوم)'
                        : (dayNames[day.date.weekday] ?? ''),
                    style: _f(
                      sz: 14,
                      fw: isToday ? FontWeight.w800 : FontWeight.w600,
                      c: isToday ? AppColors.darkGreen : textCol,
                    ),
                  ),
                  if (!isFuture) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: day.prayed
                              ? AppColors.darkGreen
                              : Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'الصلاة  ${day.prayed ? "صليت" : "لم أصل"}',
                        style: _f(sz: 12, c: subCol),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Row(children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: day.wokeWithAlarm
                              ? AppColors.darkGreen
                              : Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'الاستيقاظ بالمنبه  '
                        '${day.wokeWithAlarm ? "استيقظت" : "غير المنبه"}',
                        style: _f(sz: 12, c: subCol),
                      ),
                    ]),
                  ] else
                    Text('لم يحن وقتها بعد',
                        style: _f(sz: 11, c: subCol)),
                ],
              ),
            ),

            // Edit icon
            if (!isFuture && onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_rounded,
                      size: 15,
                      color: isDark ? Colors.white38 : AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Toggle button ─────────────────────────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ToggleBtn({
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (isDark
            ? dotColor.withValues(alpha: 0.15)
            : dotColor.withValues(alpha: 0.07))
        : (isDark ? const Color(0xFF1C2A1E) : const Color(0xFFF5F7F5));

    final border = selected
        ? dotColor.withValues(alpha: 0.5)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: dotColor),
            ),
            const SizedBox(width: 7),
            Text(label,
                style: _f(
                  sz: 13,
                  fw: selected ? FontWeight.w700 : FontWeight.w500,
                  c: selected
                      ? (isDark ? Colors.white : AppColors.textPrimary)
                      : (isDark ? Colors.white54 : AppColors.textSecondary),
                )),
          ],
        ),
      ),
    );
  }
}
