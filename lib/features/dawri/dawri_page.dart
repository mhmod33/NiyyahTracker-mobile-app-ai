import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/dawri_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/dawri_service.dart';
import 'create_dawri_page.dart';
import 'join_dawri_page.dart';
import 'dawri_detail_page.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class DawriPage extends StatefulWidget {
  const DawriPage({super.key});

  @override
  State<DawriPage> createState() => _DawriPageState();
}

class _DawriPageState extends State<DawriPage> {
  final DawriService _service = DawriService();
  List<Dawri> _dawriList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDawri();
  }

  Future<void> _loadDawri() async {
    final userId = context.read<AppAuthProvider>().userId;
    if (userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getUserDawriList(userId);
      if (mounted) setState(() => _dawriList = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGuest = !context.read<AppAuthProvider>().isAuthenticated;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          title: Text(
            'دورياتي',
            style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            if (!isGuest) ...[
              // Join by code
              IconButton(
                icon: const Icon(Icons.vpn_key_rounded, color: Colors.white),
                tooltip: 'الانضمام برمز',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JoinDawriPage()),
                  );
                  _loadDawri();
                },
              ),
              // Create new
              IconButton(
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                tooltip: 'إنشاء دوري',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateDawriPage()),
                  );
                  _loadDawri();
                },
              ),
            ],
          ],
        ),
        body: isGuest
            ? _buildGuestBanner(isDark)
            : RefreshIndicator(
                onRefresh: _loadDawri,
                color: AppColors.darkGreen,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.darkGreen))
                    : _error != null
                        ? _buildError(isDark)
                        : _dawriList.isEmpty
                            ? _buildEmpty(isDark)
                            : _buildList(isDark),
              ),
      ),
    );
  }

  Widget _buildList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _dawriList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, i) {
        final dawri = _dawriList[i];
        final userId = context.read<AppAuthProvider>().userId;
        final isSupervisor = dawri.supervisorId == userId;
        return _DawriCard(
          dawri: dawri,
          isSupervisor: isSupervisor,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DawriDetailPage(dawriId: dawri.id),
              ),
            );
            _loadDawri();
          },
        );
      },
    );
  }

  Widget _buildEmpty(bool isDark) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  size: 64,
                  color: AppColors.darkGreen.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'لا توجد دوريات بعد',
                style: _f(
                  sz: 20,
                  fw: FontWeight.w800,
                  c: isDark ? Colors.white : AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'أنشئ دورياً جديداً أو انضم\nإلى دوري بالرمز',
                textAlign: TextAlign.center,
                style: _f(sz: 14, c: AppColors.gray),
              ),
              const SizedBox(height: 36),
              _ActionButton(
                icon: Icons.add_rounded,
                label: 'إنشاء دوري جديد',
                isPrimary: true,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateDawriPage()),
                  );
                  _loadDawri();
                },
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.vpn_key_rounded,
                label: 'الانضمام برمز دعوة',
                isPrimary: false,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const JoinDawriPage()),
                  );
                  _loadDawri();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 52, color: Colors.red.shade300),
          const SizedBox(height: 14),
          Text(
            'حدث خطأ في التحميل',
            style: _f(sz: 16, fw: FontWeight.w700, c: isDark ? Colors.white : AppColors.darkGreen),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadDawri,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestBanner(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 56, color: AppColors.gold),
            ),
            const SizedBox(height: 24),
            Text(
              'الدوريات',
              style: _f(
                sz: 24,
                fw: FontWeight.w900,
                c: isDark ? Colors.white : AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'انضم إلى دوري مع أصدقائك وتنافسوا\nعلى أداء الصلوات والعبادات',
              textAlign: TextAlign.center,
              style: _f(sz: 14, c: AppColors.gray),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'سجل دخولك أولاً',
                  style: _f(sz: 16, fw: FontWeight.bold, c: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dawri Card ─────────────────────────────────────────────────────────────────

class _DawriCard extends StatelessWidget {
  final Dawri dawri;
  final bool isSupervisor;
  final bool isDark;
  final VoidCallback onTap;

  const _DawriCard({
    required this.dawri,
    required this.isSupervisor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final isCustom = dawri.trackingMode == DawriTrackingMode.custom;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Mode badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCustom
                          ? AppColors.gold.withOpacity(0.15)
                          : AppColors.darkGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCustom ? 'مخصص' : 'أساسي',
                      style: _f(
                        sz: 11,
                        fw: FontWeight.w800,
                        c: isCustom ? AppColors.gold : AppColors.darkGreen,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isSupervisor)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'مشرف',
                        style: _f(
                          sz: 10,
                          fw: FontWeight.w700,
                          c: Colors.purple,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  // Favourite star
                  Icon(
                    Icons.star_border_rounded,
                    size: 20,
                    color: AppColors.gray.withOpacity(0.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                dawri.name,
                style: _f(
                  sz: 18,
                  fw: FontWeight.w800,
                  c: isDark ? Colors.white : AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              // Status + member count
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dawri.isActive ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dawri.isActive ? 'نشط' : 'منتهي',
                    style: _f(
                      sz: 12,
                      fw: FontWeight.w600,
                      c: dawri.isActive
                          ? AppColors.midGreen
                          : AppColors.gray,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.people_outline_rounded,
                    size: 14,
                    color: AppColors.gray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${dawri.memberIds.length} ${dawri.trackingMode == DawriTrackingMode.custom ? '• مخصص' : '• أساسي'}',
                    style: _f(sz: 12, c: AppColors.gray),
                  ),
                ],
              ),
              // Member avatars
              if (dawri.members.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: Stack(
                    children: [
                      ...List.generate(
                        dawri.members.length > 5 ? 5 : dawri.members.length,
                        (i) => Positioned(
                          right: i * 22.0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _avatarColor(
                                  dawri.members[i].name),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cardBg,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                dawri.members[i].name.isNotEmpty
                                    ? dawri.members[i].name[0].toUpperCase()
                                    : '؟',
                                style: _f(
                                  sz: 12,
                                  fw: FontWeight.bold,
                                  c: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (dawri.members.length > 5)
                        Positioned(
                          right: 5 * 22.0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.gray.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(color: cardBg, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '+${dawri.members.length - 5}',
                                style: _f(sz: 9, fw: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      AppColors.darkGreen,
      AppColors.midGreen,
      Colors.purple,
      Colors.blue,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];
    return colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }
}

// ── Reusable action button ─────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: isPrimary
            ? ElevatedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, color: Colors.white, size: 20),
                label:
                    Text(label, style: _f(sz: 15, fw: FontWeight.bold, c: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 20),
                label: Text(label, style: _f(sz: 15, fw: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.darkGreen,
                  side: const BorderSide(color: AppColors.darkGreen),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
      ),
    );
  }
}
