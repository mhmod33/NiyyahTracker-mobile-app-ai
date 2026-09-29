import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/dawri_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/dawri_service.dart';
import 'dawri_manage_page.dart';
import 'prayer_log_sheet.dart';
import 'member_profile_sheet.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class DawriDetailPage extends StatefulWidget {
  final String dawriId;
  const DawriDetailPage({super.key, required this.dawriId});

  @override
  State<DawriDetailPage> createState() => _DawriDetailPageState();
}

class _DawriDetailPageState extends State<DawriDetailPage>
    with SingleTickerProviderStateMixin {
  final DawriService _service = DawriService();
  late TabController _tabCtrl;
  Dawri? _dawri;
  List<DawriMemberWeekStats> _leaderboard = [];
  bool _loadingBoard = true;
  String _period = 'today'; // 'today' | 'week' | 'month'

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final periods = ['today', 'week', 'month'];
        setState(() => _period = periods[_tabCtrl.index]);
        _loadBoard();
      }
    });
    _loadDawri();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDawri() async {
    final d = await _service.getDawri(widget.dawriId);
    if (!mounted) return;
    setState(() => _dawri = d);
    _loadBoard();
  }

  Future<void> _loadBoard() async {
    if (_dawri == null) return;
    setState(() => _loadingBoard = true);
    try {
      final board = await _service.getLeaderboard(
          dawri: _dawri!, period: _period);
      if (mounted) setState(() => _leaderboard = board);
    } finally {
      if (mounted) setState(() => _loadingBoard = false);
    }
  }

  String get _todayDate {
    final n = DateTime.now();
    final days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return 'اليوم • ${n.day} ${months[n.month - 1]} ${n.year},  ${days[n.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9);
    final userId = context.read<AppAuthProvider>().userId;

    if (_dawri == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.darkGreen),
        ),
      );
    }

    final isSupervisor = _dawri!.supervisorId == userId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor:
              isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          foregroundColor: Colors.white,
          title: Text(
            _dawri!.name,
            style: _f(sz: 18, fw: FontWeight.w800, c: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            if (isSupervisor)
              IconButton(
                icon: const Icon(Icons.settings_rounded, color: Colors.white70),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DawriManagePage(dawri: _dawri!),
                    ),
                  );
                  _loadDawri();
                },
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_dawri!.trackingMode == DawriTrackingMode.custom ? 'مخصص' : 'أساسي'}، ${_dawri!.memberIds.length} أعضاء  -  تحسب النقاط طبقاً لـ: الفروض',
                        style: _f(sz: 11, c: Colors.white70),
                      ),
                      if (isSupervisor)
                        Text(
                          'إدارة',
                          style: _f(sz: 11, fw: FontWeight.w700, c: AppColors.gold),
                        ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppColors.gold,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(child: Text('اليوم', style: _f(sz: 14, fw: FontWeight.w700))),
                    Tab(child: Text('هذا الأسبوع', style: _f(sz: 14, fw: FontWeight.w700))),
                    Tab(child: Text('الشهر', style: _f(sz: 14, fw: FontWeight.w700))),
                  ],
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => PrayerLogSheet(
                dawri: _dawri!,
                userId: userId,
              ),
            );
            _loadDawri();
          },
          backgroundColor: AppColors.darkGreen,
          icon: const Icon(Icons.edit_calendar_rounded, color: Colors.white),
          label: Text(
            'سجّل صلاتك',
            style: _f(sz: 14, fw: FontWeight.w700, c: Colors.white),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _loadDawri,
          color: AppColors.darkGreen,
          child: Column(
            children: [
              // Date label
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.gray, size: 20),
                        Text(
                          _todayDate,
                          style: _f(sz: 13, c: AppColors.gray),
                        ),
                        const Icon(Icons.chevron_left_rounded,
                            color: AppColors.gray, size: 20),
                      ],
                    ),
                    // Sort toggle
                    Text(
                      'الترتيب: اليوم • بالنقاط',
                      style: _f(sz: 11, c: AppColors.gray),
                    ),
                  ],
                ),
              ),

              // Prayer summary row (today's prayers across all members)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildPrayerSummaryRow(isDark, userId),
              ),

              // Leaderboard list
              Expanded(
                child: _loadingBoard
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.darkGreen))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _leaderboard.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final stats = _leaderboard[i];
                          final isMe = stats.userId == userId;
                          return _MemberLeaderCard(
                            stats: stats,
                            isMe: isMe,
                            isDark: isDark,
                            dawri: _dawri!,
                            onTap: () async {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => MemberProfileSheet(
                                  dawriId: _dawri!.id,
                                  userId: stats.userId,
                                  name: stats.name,
                                  isSupervisor: stats.isSupervisor,
                                  dawri: _dawri!,
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
      ),
    );
  }

  Widget _buildPrayerSummaryRow(bool isDark, String userId) {
    // Find current user's today summary
    final myEntry = _leaderboard.firstWhere(
      (m) => m.userId == userId,
      orElse: () => DawriMemberWeekStats(
        userId: userId,
        name: '',
        rank: 0,
        weekPoints: 0,
        totalPoints: 0,
        streak: 0,
        missedCount: 0,
        onTimeCount: 0,
        todayPrayers: {},
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: DawriPrayer.all.map((p) {
        final status = myEntry.todayPrayers[p];
        final done = status != null &&
            status != PrayerStatus.notLogged &&
            status != PrayerStatus.missed;
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.darkGreen
                    : (isDark
                        ? Colors.white.withOpacity(0.07)
                        : AppColors.paleGreen),
                shape: BoxShape.circle,
                border: Border.all(
                  color: done
                      ? AppColors.darkGreen
                      : Colors.transparent,
                ),
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 22)
                    : Text(
                        (DawriPrayer.all.indexOf(p) + 1).toString(),
                        style: _f(
                          sz: 15,
                          fw: FontWeight.w800,
                          c: isDark ? Colors.white38 : AppColors.gray,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              DawriPrayer.shortLabelAr(p),
              style: _f(sz: 11, fw: FontWeight.w700, c: AppColors.gray),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── Member Leaderboard Card ────────────────────────────────────────────────────

class _MemberLeaderCard extends StatelessWidget {
  final DawriMemberWeekStats stats;
  final bool isMe;
  final bool isDark;
  final Dawri dawri;
  final VoidCallback onTap;

  const _MemberLeaderCard({
    required this.stats,
    required this.isMe,
    required this.isDark,
    required this.dawri,
    required this.onTap,
  });

  Color _avatarColor(String name) {
    final colors = [
      AppColors.darkGreen, AppColors.midGreen, Colors.purple,
      Colors.blue, Colors.orange, Colors.pink, Colors.teal,
    ];
    return colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isMe
        ? AppColors.darkGreen.withOpacity(0.08)
        : isDark
            ? const Color(0xFF1A1F1C)
            : Colors.white;

    final rankColor = stats.rank == 1
        ? AppColors.gold
        : stats.rank == 2
            ? const Color(0xFFB0BEC5)
            : stats.rank == 3
                ? const Color(0xFFBCAAA4)
                : AppColors.gray;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe
                ? AppColors.darkGreen.withOpacity(0.3)
                : isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.transparent,
          ),
          boxShadow: [
            if (!isDark && isMe)
              BoxShadow(
                color: AppColors.darkGreen.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Rank
                SizedBox(
                  width: 32,
                  child: Text(
                    stats.rank <= 3
                        ? _rankEmoji(stats.rank)
                        : '${stats.rank}',
                    style: stats.rank <= 3
                        ? const TextStyle(fontSize: 22)
                        : _f(
                            sz: 16,
                            fw: FontWeight.w800,
                            c: rankColor,
                          ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _avatarColor(stats.name),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isMe ? AppColors.gold : Colors.transparent,
                      width: isMe ? 2 : 0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      stats.name.isNotEmpty
                          ? stats.name[0].toUpperCase()
                          : '؟',
                      style: _f(
                          sz: 16, fw: FontWeight.bold, c: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + supervisor badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stats.name + (isMe ? ' (أنت)' : ''),
                              style: _f(
                                sz: 14,
                                fw: FontWeight.w800,
                                c: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (stats.isSupervisor)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'مشرف',
                                style: _f(
                                    sz: 9,
                                    fw: FontWeight.w800,
                                    c: Colors.purple),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stats.streak} يوم متتالي',
                        style: _f(sz: 11, c: AppColors.gray),
                      ),
                    ],
                  ),
                ),
                // Points
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stats.weekPoints}',
                      style: _f(
                        sz: 22,
                        fw: FontWeight.w900,
                        c: isDark ? Colors.white : AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      'نقطة',
                      style: _f(sz: 10, c: AppColors.gray),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Prayer status row
            Row(
              children: [
                const SizedBox(width: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: DawriPrayer.all.map((p) {
                      final status = stats.todayPrayers[p];
                      return _PrayerDot(prayer: p, status: status);
                    }).toList(),
                  ),
                ),
              ],
            ),
            // Extra activities chips (if custom mode)
            if (dawri.trackingMode == DawriTrackingMode.custom &&
                stats.todayExtras.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: stats.todayExtras.entries.map((e) {
                  final act = DawriExtraActivity.all.firstWhere(
                    (a) => a.id == e.key,
                    orElse: () => const DawriExtraActivity(
                      id: '', nameAr: '?', description: '', icon: '?',
                      pointsPerUnit: 0,
                    ),
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${act.icon} ${act.nameAr}',
                      style: _f(
                          sz: 10,
                          fw: FontWeight.w700,
                          c: AppColors.gold),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _rankEmoji(int rank) {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '$rank';
    }
  }
}

class _PrayerDot extends StatelessWidget {
  final String prayer;
  final PrayerStatus? status;
  const _PrayerDot({required this.prayer, this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color dotColor;
    Widget? child;
    switch (status) {
      case PrayerStatus.mosque:
        dotColor = AppColors.darkGreen;
        child = const Icon(Icons.mosque_rounded, size: 12, color: Colors.white);
        break;
      case PrayerStatus.congregation:
        dotColor = AppColors.midGreen;
        child = const Icon(Icons.people_rounded, size: 12, color: Colors.white);
        break;
      case PrayerStatus.onTime:
        dotColor = AppColors.lightGreen;
        child = const Icon(Icons.check_rounded, size: 12, color: Colors.white);
        break;
      case PrayerStatus.qada:
        dotColor = AppColors.gold;
        child = const Icon(Icons.replay_rounded, size: 12, color: Colors.white);
        break;
      case PrayerStatus.missed:
        dotColor = Colors.red.shade300;
        child = const Icon(Icons.close_rounded, size: 12, color: Colors.white);
        break;
      default:
        dotColor = isDark ? Colors.white12 : AppColors.paleGreen;
        child = null;
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: child ??
                Text(
                  DawriPrayer.shortLabelAr(prayer)[0],
                  style: _f(
                    sz: 9,
                    fw: FontWeight.w700,
                    c: isDark ? Colors.white30 : AppColors.gray,
                  ),
                ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          DawriPrayer.shortLabelAr(prayer),
          style: _f(sz: 9, c: AppColors.gray),
        ),
      ],
    );
  }
}
