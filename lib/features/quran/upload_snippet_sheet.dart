import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/quran_audio_service.dart';

/// Bottom sheet for adding a snippet by direct audio link (admin only).
Future<void> showUploadSnippetSheet({
  required BuildContext context,
  required VoidCallback onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _UploadSnippetSheet(onSaved: onSaved),
  );
}

class _UploadSnippetSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const _UploadSnippetSheet({required this.onSaved});

  @override
  State<_UploadSnippetSheet> createState() => _UploadSnippetSheetState();
}

class _UploadSnippetSheetState extends State<_UploadSnippetSheet> {
  String? _selectedReciterName;
  bool _addingNew = false;
  bool _isSaving = false;

  final _titleCtl = TextEditingController();
  final _newReciterCtl = TextEditingController();
  final _linkCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final reciters = QuranAudioService.reciters
        .where((r) => r.type == ReciterType.snippets)
        .toList();
    if (reciters.isNotEmpty) {
      _selectedReciterName = reciters.first.nameAr;
    } else {
      _addingNew = true;
    }
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _newReciterCtl.dispose();
    _linkCtl.dispose();
    super.dispose();
  }

  String get _reciterName => _addingNew
      ? _newReciterCtl.text.trim()
      : (_selectedReciterName ?? '').trim();

  bool get _isValidUrl {
    final uri = Uri.tryParse(_linkCtl.text.trim());
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  bool get _canSave =>
      !_isSaving &&
      _isValidUrl &&
      _titleCtl.text.trim().isNotEmpty &&
      _reciterName.isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    final auth = context.read<AppAuthProvider>();
    setState(() => _isSaving = true);

    try {
      await QuranAudioService().addSharedLink(
        reciterName: _reciterName,
        trackTitle: _titleCtl.text.trim(),
        remoteUrl: _linkCtl.text.trim(),
        uploadedByUid: auth.userId,
        uploadedByName: auth.displayName,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة المقطع — سيظهر لجميع المستخدمين',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
          ),
          backgroundColor: AppColors.darkGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل الحفظ: $e',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final allSnippetReciters = QuranAudioService.reciters
        .where((r) => r.type == ReciterType.snippets)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => Material(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'إضافة مقطع برابط',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اختر القارئ وأدخل رابطاً مباشراً للملف الصوتي ثم احفظ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : AppColors.gray,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '1. اختر القارئ',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...allSnippetReciters.map((r) {
                      final selected =
                          !_addingNew && _selectedReciterName == r.nameAr;
                      return ChoiceChip(
                        label: Text(
                          r.nameAr,
                          style: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                        ),
                        selected: selected,
                        selectedColor: AppColors.darkGreen,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : null,
                        ),
                        onSelected: (_) => setState(() {
                          _selectedReciterName = r.nameAr;
                          _addingNew = false;
                          _newReciterCtl.clear();
                        }),
                      );
                    }),
                    ChoiceChip(
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        'قارئ جديد',
                        style: GoogleFonts.ibmPlexSansArabic(fontSize: 12),
                      ),
                      selected: _addingNew,
                      selectedColor: AppColors.gold,
                      onSelected: (_) => setState(() {
                        _addingNew = !_addingNew;
                        if (_addingNew) _selectedReciterName = null;
                      }),
                    ),
                  ],
                ),
                if (_addingNew) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newReciterCtl,
                    textDirection: TextDirection.rtl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'اسم القارئ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  '2. رابط الملف الصوتي',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkCtl,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/audio.mp3',
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'يجب أن يكون رابطاً مباشراً لملف صوتي (mp3/m4a) — روابط صفحات مثل SoundCloud لا تعمل',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : AppColors.gray,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '3. عنوان المقطع',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtl,
                  textDirection: TextDirection.rtl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'مثال: سورة الرحمن',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (!_canSave && !_isSaving) ...[
                  const SizedBox(height: 10),
                  Text(
                    _hintMessage(),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 12,
                      color: AppColors.gold,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _canSave ? _save : null,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, color: Colors.white),
                    label: Text(
                      _isSaving ? 'جاري الحفظ...' : 'حفظ المقطع',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      disabledBackgroundColor: AppColors.darkGreen.withValues(
                        alpha: 0.35,
                      ),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hintMessage() {
    if (_reciterName.isEmpty) return 'اختر قارئاً أو أضف قارئاً جديداً';
    if (_linkCtl.text.trim().isEmpty) return 'أدخل رابط الملف الصوتي';
    if (!_isValidUrl) return 'الرابط غير صالح — يجب أن يبدأ بـ http أو https';
    if (_titleCtl.text.trim().isEmpty) return 'اكتب عنوان المقطع';
    return '';
  }
}
