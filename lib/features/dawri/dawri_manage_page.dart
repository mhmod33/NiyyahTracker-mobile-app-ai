import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
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

class DawriManagePage extends StatefulWidget {
  final Dawri dawri;
  const DawriManagePage({super.key, required this.dawri});

  @override
  State<DawriManagePage> createState() => _DawriManagePageState();
}

class _DawriManagePageState extends State<DawriManagePage> {
  late Dawri _dawri;
  bool _refreshingCode = false;
  bool _deletingLeague = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dawri = widget.dawri;
  }

  // ── Edit helpers ───────────────────────────────────────────────────────────

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _dawri.name);
    final result = await _showEditDialog(
      title: 'اسم الدوري',
      ctrl: ctrl,
      hint: 'مثال: العائلة، زملاء الجامعة',
      maxLength: 50,
    );
    if (result == null) return;
    await _saveSettings(name: result, description: _dawri.description,
        trackingMode: _dawri.trackingMode,
        selectedActivityIds: _dawri.selectedActivityIds);
  }

  Future<void> _editDescription() async {
    final ctrl = TextEditingController(text: _dawri.description);
    final result = await _showEditDialog(
      title: 'الوصف',
      ctrl: ctrl,
      hint: 'ما هو موضوع هذا الدوري؟',
      maxLength: 200,
      multiline: true,
    );
    if (result == null) return;
    await _saveSettings(name: _dawri.name, description: result,
        trackingMode: _dawri.trackingMode,
        selectedActivityIds: _dawri.selectedActivityIds);
  }

  Future<void> _editTrackingMode() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DawriTrackingMode selectedMode = _dawri.trackingMode;
    final Set<String> selectedActivities =
        Set.from(_dawri.selectedActivityIds);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scroll) => StatefulBuilder(
          builder: (ctx, setSheet) => Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('نمط التتبع',
                      style: _f(sz: 18, fw: FontWeight.w800,
                          c: isDark ? Colors.white : AppColors.darkGreen)),
                  const SizedBox(height: 16),
                  _ModeOption(
                    title: 'أساسي (فروض فقط)',
                    desc: 'تتبع الصلوات الخمس الفروض فقط.',
                    selected: selectedMode == DawriTrackingMode.basic,
                    isDark: isDark,
                    onTap: () => setSheet(() {
                      selectedMode = DawriTrackingMode.basic;
                      selectedActivities.clear();
                    }),
                  ),
                  const SizedBox(height: 10),
                  _ModeOption(
                    title: 'مخصص',
                    desc: 'الفروض مع مزيج من السنن والصيام والقرآن.',
                    selected: selectedMode == DawriTrackingMode.custom,
                    isDark: isDark,
                    onTap: () => setSheet(
                        () => selectedMode = DawriTrackingMode.custom),
                  ),
                  if (selectedMode == DawriTrackingMode.custom) ...[
                    const SizedBox(height: 16),
                    Text('الأنشطة الإضافية',
                        style: _f(sz: 14, fw: FontWeight.w700,
                            c: isDark ? Colors.white : AppColors.darkGreen)),
                    const SizedBox(height: 8),
                    ...DawriExtraActivity.all.map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setSheet(() {
                          if (selectedActivities.contains(a.id)) {
                            selectedActivities.remove(a.id);
                          } else {
                            selectedActivities.add(a.id);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: selectedActivities.contains(a.id)
                                ? AppColors.darkGreen.withOpacity(0.08)
                                : isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : AppColors.paleGreen.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedActivities.contains(a.id)
                                  ? AppColors.darkGreen.withOpacity(0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selectedActivities.contains(a.id)
                                    ? AppColors.darkGreen
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selectedActivities.contains(a.id)
                                      ? AppColors.darkGreen
                                      : AppColors.gray.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              child: selectedActivities.contains(a.id)
                                  ? const Icon(Icons.check_rounded,
                                      size: 13, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(a.icon,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.nameAr,
                                      style: _f(sz: 13, fw: FontWeight.w700,
                                          c: isDark ? Colors.white
                                              : AppColors.textPrimary)),
                                  Text(a.description,
                                      style: _f(sz: 10, c: AppColors.gray)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.darkGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('+${a.pointsPerUnit}',
                                  style: _f(sz: 10, fw: FontWeight.w800,
                                      c: AppColors.darkGreen)),
                            ),
                          ]),
                        ),
                      ),
                    )),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('حفظ',
                          style: _f(sz: 15, fw: FontWeight.bold,
                              c: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await _saveSettings(
        name: _dawri.name,
        description: _dawri.description,
        trackingMode: selectedMode,
        selectedActivityIds: selectedActivities.toList());
  }

  Future<String?> _showEditDialog({
    required String title,
    required TextEditingController ctrl,
    required String hint,
    int maxLength = 100,
    bool multiline = false,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(title,
              style: _f(sz: 17, fw: FontWeight.w800,
                  c: isDark ? Colors.white : AppColors.darkGreen)),
          content: TextField(
            controller: ctrl,
            maxLength: maxLength,
            maxLines: multiline ? 3 : 1,
            textDirection: TextDirection.rtl,
            autofocus: true,
            style: _f(sz: 15,
                c: isDark ? Colors.white : AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: _f(sz: 13, c: AppColors.gray),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : AppColors.paleGreen,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.darkGreen, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء',
                  style: _f(sz: 14, c: AppColors.gray)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkGreen,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حفظ',
                  style: _f(sz: 14, fw: FontWeight.w700,
                      c: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings({
    required String name,
    required String description,
    required DawriTrackingMode trackingMode,
    required List<String> selectedActivityIds,
  }) async {
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await DawriService().updateDawriSettings(
        dawriId: _dawri.id,
        name: name,
        description: description,
        trackingMode: trackingMode,
        selectedActivityIds: selectedActivityIds,
      );
      final updated = await DawriService().getDawri(_dawri.id);
      if (mounted && updated != null) {
        setState(() => _dawri = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الحفظ ✅', style: _f(c: Colors.white)),
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

  Future<void> _refreshCode() async {
    setState(() => _refreshingCode = true);
    try {
      await DawriService().regenerateInviteCode(_dawri.id);
      // Re-load dawri
      final updated = await DawriService().getDawri(_dawri.id);
      if (mounted && updated != null) setState(() => _dawri = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تجديد الرمز: $e', style: _f(c: Colors.white)),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingCode = false);
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _dawri.inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('تم نسخ رمز الدعوة ✅', style: _f(c: Colors.white)),
        backgroundColor: AppColors.darkGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareLink() {
    Share.share(
      'انضم إلى دوريي "${_dawri.name}" في تطبيق بصائر!\nرمز الدعوة: ${_dawri.inviteCode}',
    );
  }

  Future<void> _deleteDawri() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text('حذف الدوري؟',
              style: _f(sz: 18, fw: FontWeight.w800)),
          content: Text(
            'يُحذف الدوري نهائياً. لا يمكن التراجع عن هذا الإجراء.',
            style: _f(sz: 14, c: AppColors.gray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: _f(c: AppColors.gray)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('حذف الدوري',
                  style: _f(c: Colors.white, fw: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingLeague = true);
    try {
      await DawriService().deleteDawri(_dawri.id);
      if (mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الحذف: $e', style: _f(c: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingLeague = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9);
    final cardBg = isDark ? const Color(0xFF1A1F1C) : Colors.white;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor:
              isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
          foregroundColor: Colors.white,
          title: Column(
            children: [
              Text('إدارة الدوري',
                  style: _f(sz: 18, fw: FontWeight.w800, c: Colors.white)),
              Text(_dawri.name,
                  style: _f(sz: 12, c: Colors.white70)),
            ],
          ),
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Settings ──
              _SectionLabel(label: 'إعدادات الدوري', isDark: isDark),
              const SizedBox(height: 10),
              _EditableSettingsCard(
                dawri: _dawri,
                isDark: isDark,
                cardBg: cardBg,
                saving: _saving,
                onEditName: _editName,
                onEditDescription: _editDescription,
                onEditMode: _editTrackingMode,
              ),

              const SizedBox(height: 24),

              // ── Members ──
              Row(
                children: [
                  _SectionLabelInline(
                      label: 'الأعضاء', isDark: isDark),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.darkGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_dawri.memberIds.length}',
                      style: _f(
                          sz: 12,
                          fw: FontWeight.w800,
                          c: AppColors.darkGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  children: _dawri.members.map((m) {
                    return _MemberRow(
                        member: m, isDark: isDark, cardBg: cardBg);
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // ── Invite ──
              _SectionLabel(label: 'دعوة الأعضاء', isDark: isDark),
              const SizedBox(height: 10),
              _InviteCard(
                code: _dawri.inviteCode,
                isDark: isDark,
                cardBg: cardBg,
                refreshing: _refreshingCode,
                onCopy: _copyCode,
                onShare: _shareLink,
                onRefresh: _refreshCode,
              ),

              const SizedBox(height: 28),

              // ── Danger zone ──
              _SectionLabel(
                  label: 'منطقة الخطر',
                  isDark: isDark,
                  color: Colors.red),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_forever_rounded,
                              color: Colors.red, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'حذف هذا الدوري',
                                style: _f(
                                    sz: 15,
                                    fw: FontWeight.w700,
                                    c: Colors.red),
                              ),
                              Text(
                                'يُحذف الدوري نهائياً. لا يمكن التراجع عن هذا الإجراء.',
                                style: _f(sz: 11, c: AppColors.gray),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed:
                            _deletingLeague ? null : _deleteDawri,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _deletingLeague
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.red, strokeWidth: 2))
                            : Text(
                                'حذف الدوري',
                                style: _f(
                                    sz: 14,
                                    fw: FontWeight.w700,
                                    c: Colors.red),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Support widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color? color;
  const _SectionLabel(
      {required this.label, required this.isDark, this.color});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: _f(
          sz: 13,
          fw: FontWeight.w700,
          c: color ??
              (isDark ? Colors.white60 : AppColors.gray),
        ),
      );
}

class _SectionLabelInline extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabelInline(
      {required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: _f(
          sz: 13,
          fw: FontWeight.w700,
          c: isDark ? Colors.white60 : AppColors.gray,
        ),
      );
}

// ── Editable Settings Card ────────────────────────────────────────────────────

class _EditableSettingsCard extends StatelessWidget {
  final Dawri dawri;
  final bool isDark;
  final Color cardBg;
  final bool saving;
  final VoidCallback onEditName;
  final VoidCallback onEditDescription;
  final VoidCallback onEditMode;

  const _EditableSettingsCard({
    required this.dawri,
    required this.isDark,
    required this.cardBg,
    required this.saving,
    required this.onEditName,
    required this.onEditDescription,
    required this.onEditMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          _EditRow(
            label: 'اسم الدوري',
            value: dawri.name,
            isDark: isDark,
            isFirst: true,
            onTap: onEditName,
          ),
          _EditRow(
            label: 'الوصف',
            value: dawri.description.isNotEmpty ? dawri.description : '—',
            isDark: isDark,
            onTap: onEditDescription,
          ),
          _EditRow(
            label: 'نمط التتبع',
            value: dawri.trackingModeLabel,
            isDark: isDark,
            isLast: true,
            onTap: onEditMode,
          ),
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _EditRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.isFirst = false,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
                  ),
                ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: _f(
                  sz: 14,
                  c: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                style: _f(
                  sz: 14,
                  fw: FontWeight.w700,
                  c: isDark ? Colors.white : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.edit_rounded,
              size: 16,
              color: AppColors.darkGreen.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mode option tile (used in tracking-mode bottom sheet) ─────────────────────

class _ModeOption extends StatelessWidget {
  final String title;
  final String desc;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeOption({
    required this.title,
    required this.desc,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.darkGreen.withOpacity(0.08)
              : isDark
                  ? const Color(0xFF252B27)
                  : AppColors.paleGreen.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.darkGreen
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _f(
                      sz: 14,
                      fw: FontWeight.w800,
                      c: selected
                          ? AppColors.darkGreen
                          : isDark
                              ? Colors.white
                              : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: _f(sz: 11, c: AppColors.gray),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Keep old _MemberRow ───────────────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  final DawriMember member;
  final bool isDark;
  final Color cardBg;
  const _MemberRow(
      {required this.member,
      required this.isDark,
      required this.cardBg});

  Color _avatarColor(String name) {
    final colors = [
      AppColors.darkGreen, AppColors.midGreen, Colors.purple,
      Colors.blue, Colors.orange, Colors.pink, Colors.teal,
    ];
    return colors[name.codeUnits.fold(0, (a, b) => a + b) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _avatarColor(member.name),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : '؟',
                style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.name,
              style: _f(
                sz: 14,
                fw: FontWeight.w700,
                c: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          if (member.isSupervisor)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'مشرف',
                style: _f(
                    sz: 10, fw: FontWeight.w800, c: Colors.purple),
              ),
            ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final String code;
  final bool isDark;
  final Color cardBg;
  final bool refreshing;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onRefresh;

  const _InviteCard({
    required this.code,
    required this.isDark,
    required this.cardBg,
    required this.refreshing,
    required this.onCopy,
    required this.onShare,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkGreen.withOpacity(0.15)
            : AppColors.paleGreen,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.darkGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رمز الدعوة',
            style: _f(
              sz: 13,
              fw: FontWeight.w700,
              c: isDark ? Colors.white60 : AppColors.gray,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              code.split('').join(' '),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: isDark ? Colors.white : AppColors.darkGreen,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text('نسخ الرمز',
                      style: _f(sz: 13, fw: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkGreen,
                    side: const BorderSide(color: AppColors.darkGreen),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text('مشاركة الرابط',
                      style: _f(sz: 13, fw: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkGreen,
                    side: const BorderSide(color: AppColors.darkGreen),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.darkGreen))
                  : const Icon(Icons.refresh_rounded,
                      size: 16, color: AppColors.darkGreen),
              label: Text(
                'تجديد الرمز',
                style: _f(
                    sz: 13,
                    fw: FontWeight.w600,
                    c: AppColors.darkGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
