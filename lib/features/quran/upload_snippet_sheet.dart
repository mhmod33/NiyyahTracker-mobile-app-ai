import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/quran_audio_service.dart';

/// Bottom sheet for adding or editing a snippet (admin or canUpload users).
Future<void> showUploadSnippetSheet({
  required BuildContext context,
  required Future<void> Function() onSaved,
  String? editReciterId,
  int? editTrackIndex,
  String? initialReciterName,
  String? initialTitle,
  String? initialLink,
}) {
  if (!context.read<AppAuthProvider>().canUpload) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ليس لديك صلاحية رفع الروابط — اطلبها من المدير',
          style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      ),
    );
    return Future.value();
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _UploadSnippetSheet(
      onSaved: onSaved,
      editReciterId: editReciterId,
      editTrackIndex: editTrackIndex,
      initialReciterName: initialReciterName,
      initialTitle: initialTitle,
      initialLink: initialLink,
    ),
  );
}

class _UploadSnippetSheet extends StatefulWidget {
  final Future<void> Function() onSaved;
  final String? editReciterId;
  final int? editTrackIndex;
  final String? initialReciterName;
  final String? initialTitle;
  final String? initialLink;

  const _UploadSnippetSheet({
    required this.onSaved,
    this.editReciterId,
    this.editTrackIndex,
    this.initialReciterName,
    this.initialTitle,
    this.initialLink,
  });

  bool get isEditing =>
      editReciterId != null &&
      editTrackIndex != null &&
      editReciterId!.isNotEmpty;

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
    if (widget.isEditing) {
      _selectedReciterName = widget.initialReciterName;
      _titleCtl.text = widget.initialTitle ?? '';
      _linkCtl.text = widget.initialLink ?? '';
      return;
    }
    final reciters = QuranAudioService.reciters
        .where((r) => r.type == ReciterType.snippets)
        .toList();
    if (reciters.isEmpty) {
      _addingNew = true;
    } else {
      _selectedReciterName = reciters.first.nameAr;
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

  bool get _isNewReciterName {
    final name = _reciterName;
    if (name.isEmpty) return false;
    if (!_addingNew) return true;
    return !QuranAudioService.reciters.any(
      (r) => r.nameAr.trim().toLowerCase() == name.toLowerCase(),
    );
  }

  bool get _canSave {
    if (_isSaving || !_isValidUrl || _titleCtl.text.trim().isEmpty) {
      return false;
    }
    if (widget.isEditing) return true;
    return _isNewReciterName;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final auth = context.read<AppAuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!auth.canUpload) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'ليس لديك صلاحية رفع الروابط — اطلبها من المدير',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);

    try {
      if (widget.isEditing) {
        await QuranAudioService().editSharedLink(
          reciterId: widget.editReciterId!,
          trackIndex: widget.editTrackIndex!,
          trackTitle: _titleCtl.text.trim(),
          remoteUrl: _linkCtl.text.trim(),
        );
      } else {
        await QuranAudioService().addSharedLink(
          reciterName: _reciterName,
          trackTitle: _titleCtl.text.trim(),
          remoteUrl: _linkCtl.text.trim(),
          uploadedByUid: auth.userId,
          uploadedByName: auth.displayName,
        );
      }
      await widget.onSaved();
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'تم تحديث المقطع — سيظهر لجميع المستخدمين'
                : 'تمت إضافة المقطع — سيظهر لجميع المستخدمين',
            style: GoogleFonts.ibmPlexSansArabic(color: Colors.white),
          ),
          backgroundColor: AppColors.darkGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
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
                  widget.isEditing ? 'تعديل مقطع برابط' : 'إضافة مقطع برابط',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isEditing
                      ? 'عدّل العنوان أو رابط SoundCloud / الملف الصوتي'
                      : 'اختر قارئاً موجوداً أو أضف قارئاً جديداً ثم احفظ الرابط الصوتي',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : AppColors.gray,
                  ),
                ),
                if (!widget.isEditing) ...[
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
                        _addingNew = true;
                        _selectedReciterName = null;
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
                      labelText: 'اسم القارئ الجديد',
                      prefixIcon: const Icon(Icons.person_add_alt_1_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                ] else ...[
                  const SizedBox(height: 18),
                  Text(
                    'القارئ: ${widget.initialReciterName ?? ''}',
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  widget.isEditing ? 'رابط الملف الصوتي' : '2. رابط الملف الصوتي',
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
                  'يمكنك لصق رابط SoundCloud (soundcloud.com أو on.soundcloud.com) أو رابطاً مباشراً لملف صوتي (mp3/m4a)',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : AppColors.gray,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isEditing ? 'عنوان المقطع' : '3. عنوان المقطع',
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
                      _isSaving
                          ? 'جاري الحفظ...'
                          : (widget.isEditing ? 'حفظ التعديلات' : 'حفظ المقطع'),
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
    if (widget.isEditing) {
      if (_linkCtl.text.trim().isEmpty) return 'أدخل رابط الملف الصوتي';
      if (!_isValidUrl) return 'الرابط غير صالح — يجب أن يبدأ بـ http أو https';
      if (_titleCtl.text.trim().isEmpty) return 'اكتب عنوان المقطع';
      return '';
    }
    if (_reciterName.isEmpty) return 'اختر قارئاً أو أدخل اسم قارئ جديد';
    if (!_isNewReciterName) return 'هذا القارئ موجود بالفعل — أدخل اسماً جديداً';
    if (_linkCtl.text.trim().isEmpty) return 'أدخل رابط الملف الصوتي';
    if (!_isValidUrl) return 'الرابط غير صالح — يجب أن يبدأ بـ http أو https';
    if (_titleCtl.text.trim().isEmpty) return 'اكتب عنوان المقطع';
    return '';
  }
}
