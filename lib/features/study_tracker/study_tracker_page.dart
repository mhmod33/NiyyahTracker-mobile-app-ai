import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_colors.dart';
import '../../models/study_track_model.dart';
import '../../services/study_track_service.dart';
import 'study_playlist_detail_page.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) =>
    GoogleFonts.ibmPlexSansArabic(
        fontSize: sz, fontWeight: fw, color: c, height: h);

class StudyTrackerPage extends StatefulWidget {
  const StudyTrackerPage({super.key});

  @override
  State<StudyTrackerPage> createState() => _StudyTrackerPageState();
}

class _StudyTrackerPageState extends State<StudyTrackerPage> {
  final StudyTrackService _service = StudyTrackService();
  List<StudyPlaylist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.init();
    if (mounted) {
      setState(() {
        _playlists = _service.getAllPlaylists();
        _isLoading = false;
      });
    }
  }

  void _reload() => setState(() => _playlists = _service.getAllPlaylists());

  Future<void> _showAddSheet() async {
    final result = await showModalBottomSheet<StudyPlaylist>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPlaylistSheet(service: _service),
    );
    if (result != null) _reload();
  }

  Future<void> _openPlaylist(StudyPlaylist playlist) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudyPlaylistDetailPage(
          playlistId: playlist.id,
          service: _service,
        ),
      ),
    );
    _reload();
  }

  Future<void> _deletePlaylist(String id) async {
    await _service.deletePlaylist(id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isDark),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.darkGreen),
                ),
              )
            else if (_playlists.isEmpty)
              SliverFillRemaining(child: _buildEmpty(isDark))
            else ...[
              SliverToBoxAdapter(child: _buildStats(isDark)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final p = _playlists[i];
                      return Dismissible(
                        key: ValueKey(p.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _confirmDelete(p);
                          return false;
                        },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 24),
                          child: const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _PlaylistCard(
                            playlist: p,
                            isDark: isDark,
                            onTap: () => _openPlaylist(p),
                            onDelete: () => _confirmDelete(p),
                          ),
                        ),
                      );
                    },
                    childCount: _playlists.length,
                  ),
                ),
              ),
            ],
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddSheet,
          backgroundColor: AppColors.darkGreen,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text('إضافة سلسلة', style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0D2818) : AppColors.darkGreen,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0D2818), const Color(0xFF051109)]
                  : [const Color(0xFF145A3A), const Color(0xFF1E8255)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('متابعة الدراسة',
                      style: _f(sz: 24, fw: FontWeight.w900, c: Colors.white)),
                  Text('تابع مسيرتك في العلم والتعلّم',
                      style: _f(sz: 13, c: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(bool isDark) {
    final total = _playlists.length;
    final completed = _playlists.where((p) => p.isCompleted).length;
    final inProgress = _playlists.where((p) => !p.isCompleted && p.totalCount > 0).length;
    final totalWatched = _playlists.fold(0, (s, p) => s + p.watchedCount);
    final totalEps = _playlists.fold(0, (s, p) => s + p.totalCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          _StatChip(label: 'سلسلة', value: '$total', icon: Icons.playlist_play_rounded, isDark: isDark),
          const SizedBox(width: 10),
          _StatChip(label: 'مكتملة', value: '$completed', icon: Icons.check_circle_rounded, isDark: isDark, color: AppColors.midGreen),
          const SizedBox(width: 10),
          _StatChip(label: 'حلقة شاهدت', value: totalEps > 0 ? '$totalWatched/$totalEps' : '0', icon: Icons.play_circle_rounded, isDark: isDark, color: AppColors.gold),
          const SizedBox(width: 10),
          _StatChip(label: 'جارية', value: '$inProgress', icon: Icons.timelapse_rounded, isDark: isDark, color: Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.paleGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school_rounded,
                  size: 56, color: AppColors.darkGreen.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 24),
            Text('لا توجد سلاسل بعد',
                style: _f(sz: 20, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
            const SizedBox(height: 10),
            Text(
              'أضف سلسلة دراسية أو علمية لتتابع تقدمك\nيمكنك ربط قائمة تشغيل يوتيوب أو إضافة محتوى يدوياً',
              style: _f(sz: 13, c: AppColors.gray, h: 1.7),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(StudyPlaylist playlist) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('حذف السلسلة', style: _f(sz: 17, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
          content: Text('هل أنت متأكد من حذف "${playlist.title}"؟ لا يمكن التراجع.',
              style: _f(sz: 14, c: AppColors.gray)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: _f(sz: 14, c: AppColors.gray)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('حذف', style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) await _deletePlaylist(playlist.id);
  }
}

// ── Stat Chip ──────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isDark;
  final Color? color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.darkGreen;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
          boxShadow: isDark
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(height: 4),
            Text(value,
                style: _f(sz: 13, fw: FontWeight.w900, c: isDark ? Colors.white : AppColors.dark)),
            Text(label,
                style: _f(sz: 9, c: AppColors.gray),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Playlist Card ──────────────────────────────────────────────────────────

class _PlaylistCard extends StatelessWidget {
  final StudyPlaylist playlist;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlaylistCard({
    required this.playlist,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  Color get _accentColor =>
      playlist.type == StudySourceType.youtube ? const Color(0xFFE53935) : AppColors.darkGreen;

  @override
  Widget build(BuildContext context) {
    final hasUrl = playlist.externalUrl != null && playlist.externalUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C17) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _accentColor.withValues(alpha: isDark ? 0.3 : 0.15),
          ),
          boxShadow: isDark
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            // Left accent strip + icon
            Container(
              width: 56,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_accentColor, _accentColor.withValues(alpha: 0.7)],
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    playlist.type == StudySourceType.youtube
                        ? Icons.smart_display_rounded
                        : Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playlist.type == StudySourceType.youtube ? 'YT' : 'يدوي',
                    style: _f(sz: 9, fw: FontWeight.bold, c: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            playlist.title,
                            style: _f(
                                sz: 15,
                                fw: FontWeight.w800,
                                c: isDark ? Colors.white : AppColors.dark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (playlist.isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.midGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('مكتملة ✓',
                                style: _f(sz: 10, fw: FontWeight.bold, c: AppColors.midGreen)),
                          ),
                      ],
                    ),
                    if (playlist.description != null && playlist.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        playlist.description!,
                        style: _f(sz: 11, c: AppColors.gray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: playlist.progress,
                        minHeight: 6,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppColors.grayLight,
                        valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          playlist.totalCount == 0
                              ? 'لا توجد حلقات'
                              : '${playlist.watchedCount} من ${playlist.totalCount} حلقة',
                          style: _f(sz: 11, c: AppColors.gray),
                        ),
                        const Spacer(),
                        if (playlist.totalCount > 0)
                          Text(
                            '${(playlist.progress * 100).round()}%',
                            style: _f(sz: 12, fw: FontWeight.w800, c: _accentColor),
                          ),
                        if (hasUrl) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _launchUrl(playlist.externalUrl!),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.open_in_new_rounded,
                                  size: 14, color: _accentColor),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_back_ios_rounded,
                size: 14, color: AppColors.gray.withValues(alpha: 0.5)),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: Text('حذف السلسلة',
                      style: _f(sz: 15, c: Colors.red, fw: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

// ── Add Playlist Bottom Sheet ──────────────────────────────────────────────

class _AddPlaylistSheet extends StatefulWidget {
  final StudyTrackService service;
  const _AddPlaylistSheet({required this.service});

  @override
  State<_AddPlaylistSheet> createState() => _AddPlaylistSheetState();
}

class _AddPlaylistSheetState extends State<_AddPlaylistSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _isSaving = false;
  StudySourceType _type = StudySourceType.manual;
  bool _isSingleVideo = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _onUrlChanged(String val) {
    final isYt = StudyPlaylist.isYoutubeUrl(val);
    final hasList = StudyPlaylist.extractYoutubePlaylistId(val) != null;
    final hasVideo = StudyPlaylist.extractYoutubeVideoId(val) != null;
    setState(() {
      _type = isYt ? StudySourceType.youtube : StudySourceType.manual;
      _isSingleVideo = isYt && hasVideo && !hasList;
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    final url = _urlCtrl.text.trim();

    List<StudyItem> initialItems = const [];
    if (_isSingleVideo && url.isNotEmpty) {
      initialItems = [
        StudyItem(
          id: const Uuid().v4(),
          title: title,
          videoUrl: url,
          orderIndex: 0,
        ),
      ];
    }

    final playlist = StudyPlaylist(
      id: const Uuid().v4(),
      title: title,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      externalUrl: url.isEmpty ? null : url,
      type: _type,
      items: initialItems,
      createdAt: DateTime.now(),
    );
    await widget.service.savePlaylist(playlist);
    if (mounted) Navigator.pop(context, playlist);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1F1C) : Colors.white;
    final isYoutube = _type == StudySourceType.youtube;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 20,
          left: 24,
          right: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('إضافة سلسلة جديدة',
                  style: _f(sz: 20, fw: FontWeight.w900, c: isDark ? Colors.white : AppColors.darkGreen)),
              const SizedBox(height: 6),
              Text('سيرة نبوية، محاضرات، دورات علمية...',
                  style: _f(sz: 13, c: AppColors.gray)),
              const SizedBox(height: 24),

              // Title
              _InputField(
                controller: _titleCtrl,
                label: 'اسم السلسلة *',
                hint: 'مثال: السيرة النبوية - الدكتور علي الصلابي',
                icon: Icons.title_rounded,
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              // Description
              _InputField(
                controller: _descCtrl,
                label: 'وصف مختصر (اختياري)',
                hint: 'موضوع السلسلة أو ملاحظات',
                icon: Icons.notes_rounded,
                isDark: isDark,
                maxLines: 2,
              ),
              const SizedBox(height: 14),

              // URL
              _InputField(
                controller: _urlCtrl,
                label: 'رابط يوتيوب أو خارجي (اختياري)',
                hint: 'رابط قائمة تشغيل أو فيديو منفرد',
                icon: Icons.link_rounded,
                isDark: isDark,
                onChanged: _onUrlChanged,
                keyboardType: TextInputType.url,
              ),

              // Auto-detect YouTube badge
              if (isYoutube) ...[  
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSingleVideo
                            ? Icons.play_circle_rounded
                            : Icons.smart_display_rounded,
                        color: const Color(0xFFE53935),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isSingleVideo
                              ? 'رابط فيديو منفرد — سيتم إضافة حلقة واحدة تلقائياً'
                              : 'قائمة تشغيل يوتيوب — سيتم استيراد الحلقات تلقائياً عند الفتح',
                          style: _f(sz: 11, c: const Color(0xFFE53935)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving || _titleCtrl.text.trim().isEmpty ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    disabledBackgroundColor: AppColors.darkGreen.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('إضافة السلسلة',
                          style: _f(sz: 16, fw: FontWeight.bold, c: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Input Field ─────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isDark;
  final int maxLines;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.maxLines = 1,
    this.onChanged,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _f(sz: 13, fw: FontWeight.w700, c: isDark ? Colors.white70 : AppColors.dark)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          keyboardType: keyboardType,
          textDirection: TextDirection.rtl,
          style: _f(sz: 14, c: isDark ? Colors.white : AppColors.dark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _f(sz: 13, c: AppColors.gray),
            prefixIcon: Icon(icon, size: 18, color: AppColors.darkGreen),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.paleGreen.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.darkGreen.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.darkGreen.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
