import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/dawri_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/dawri_service.dart';
import 'dawri_detail_page.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class CreateDawriPage extends StatefulWidget {
  const CreateDawriPage({super.key});

  @override
  State<CreateDawriPage> createState() => _CreateDawriPageState();
}

class _CreateDawriPageState extends State<CreateDawriPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DawriTrackingMode _mode = DawriTrackingMode.basic;
  final Set<String> _selectedActivities = {};
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _nameCtrl.text.trim().isNotEmpty &&
      (_mode == DawriTrackingMode.basic || _selectedActivities.isNotEmpty);

  Future<void> _create() async {
    if (!_canCreate) return;
    final auth = context.read<AppAuthProvider>();
    setState(() => _creating = true);
    try {
      final dawri = await DawriService().createDawri(
        supervisorId: auth.userId,
        supervisorName: auth.displayName,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        trackingMode: _mode,
        selectedActivityIds: _mode == DawriTrackingMode.custom
            ? _selectedActivities.toList()
            : [],
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DawriDetailPage(dawriId: dawri.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إنشاء الدوري: $e',
              style: _f(c: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor:
              isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          foregroundColor: Colors.white,
          title: Text(
            'دوري جديد',
            style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
        ),
        bottomNavigationBar: _buildBottomBar(isDark),
        body: SingleChildScrollView(
          padding:
              const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Name ──
              _SectionLabel(label: 'اسم الدوري'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                maxLength: 50,
                textDirection: TextDirection.rtl,
                style: _f(
                    sz: 15,
                    c: isDark ? Colors.white : AppColors.textPrimary),
                onChanged: (_) => setState(() {}),
                decoration: _inputDeco(
                  isDark: isDark,
                  hint: 'مثال: العائلة، زملاء الجامعة',
                  counter: true,
                ),
              ),

              const SizedBox(height: 20),

              // ── Description ──
              _SectionLabel(label: 'الوصف', optional: true),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                style: _f(
                    sz: 14,
                    c: isDark ? Colors.white : AppColors.textPrimary),
                decoration: _inputDeco(
                  isDark: isDark,
                  hint: 'ما هو موضوع هذا الدوري؟',
                ),
              ),

              const SizedBox(height: 28),

              // ── Tracking mode ──
              _SectionLabel(label: 'نمط التتبع'),
              const SizedBox(height: 12),

              _TrackingModeCard(
                title: 'أساسي (فروض فقط)',
                description: 'تتبع الصلوات الخمس الفروض فقط.',
                icon: Icons.check_rounded,
                mode: DawriTrackingMode.basic,
                selectedMode: _mode,
                isDark: isDark,
                onTap: () => setState(() {
                  _mode = DawriTrackingMode.basic;
                  _selectedActivities.clear();
                }),
              ),
              const SizedBox(height: 10),
              _TrackingModeCard(
                title: 'مخصص',
                description: 'الفروض مع مزيج يختاره المنشئ: السنن، الصيام، تلاوة القرآن.',
                icon: Icons.auto_fix_high_rounded,
                mode: DawriTrackingMode.custom,
                selectedMode: _mode,
                isDark: isDark,
                onTap: () => setState(() => _mode = DawriTrackingMode.custom),
              ),

              // ── Activity picker for custom mode ──
              if (_mode == DawriTrackingMode.custom) ...[
                const SizedBox(height: 24),
                _SectionLabel(label: 'ماذا يحسب هذا الدوري؟'),
                const SizedBox(height: 6),
                Text(
                  'اختر ما تريد أن يحصل عليه الأعضاء نقاطاً إضافية مقابله. الفروض دائماً محسوبة.',
                  style: _f(sz: 12, c: AppColors.gray),
                ),
                const SizedBox(height: 14),
                ...DawriExtraActivity.all.map(
                  (activity) => _ActivityTile(
                    activity: activity,
                    selected: _selectedActivities.contains(activity.id),
                    isDark: isDark,
                    onToggle: () {
                      setState(() {
                        if (_selectedActivities.contains(activity.id)) {
                          _selectedActivities.remove(activity.id);
                        } else {
                          _selectedActivities.add(activity.id);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _InfoBanner(
                  text:
                      'جميع الدوريات خاصة. الأعضاء ينضمون بالدعوة فقط.',
                  isDark: isDark,
                ),
              ] else ...[
                const SizedBox(height: 24),
                _InfoBanner(
                  text: 'جميع الدوريات خاصة. الأعضاء ينضمون بالدعوة فقط.',
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _canCreate && !_creating ? _create : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.darkGreen,
              disabledBackgroundColor: AppColors.gray.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _creating
                ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                : Text(
                    'إنشاء الدوري',
                    style: _f(
                        sz: 16, fw: FontWeight.bold, c: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required bool isDark,
    required String hint,
    bool counter = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: _f(sz: 14, c: AppColors.gray),
      counterStyle: _f(sz: 11, c: AppColors.gray),
      counterText: counter ? null : '',
      filled: true,
      fillColor:
          isDark ? Colors.white.withOpacity(0.05) : AppColors.paleGreen,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.darkGreen, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── Support Widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool optional;
  const _SectionLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          label,
          style: _f(
            sz: 15,
            fw: FontWeight.w700,
            c: isDark ? Colors.white : AppColors.darkGreen,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '(اختياري)',
            style: _f(sz: 12, c: AppColors.gray),
          ),
        ],
      ],
    );
  }
}

class _TrackingModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final DawriTrackingMode mode;
  final DawriTrackingMode selectedMode;
  final bool isDark;
  final VoidCallback onTap;

  const _TrackingModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.mode,
    required this.selectedMode,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = mode == selectedMode;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkGreen.withOpacity(0.08)
              : isDark
                  ? const Color(0xFF1A1F1C)
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.darkGreen : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.darkGreen : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.darkGreen
                      : AppColors.gray.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _f(
                      sz: 15,
                      fw: FontWeight.w800,
                      c: isSelected
                          ? AppColors.darkGreen
                          : isDark
                              ? Colors.white
                              : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: _f(sz: 12, c: AppColors.gray),
                  ),
                ],
              ),
            ),
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.darkGreen
                    : AppColors.gray.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppColors.gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final DawriExtraActivity activity;
  final bool selected;
  final bool isDark;
  final VoidCallback onToggle;

  const _ActivityTile({
    required this.activity,
    required this.selected,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.darkGreen.withOpacity(0.07)
                : isDark
                    ? const Color(0xFF1A1F1C)
                    : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.darkGreen.withOpacity(0.4)
                  : Colors.transparent,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            children: [
              // Radio
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.darkGreen : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.darkGreen
                        : AppColors.gray.withOpacity(0.4),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              // Points badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+${activity.pointsPerUnit}',
                  style: _f(
                    sz: 11,
                    fw: FontWeight.w800,
                    c: AppColors.darkGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
              const SizedBox(width: 8),
              Text(activity.icon, style: const TextStyle(fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final bool isDark;
  const _InfoBanner({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.darkGreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.darkGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: _f(sz: 12, c: AppColors.darkGreen),
            ),
          ),
        ],
      ),
    );
  }
}
