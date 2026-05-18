import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../core/app_colors.dart';
import '../../models/study_track_model.dart';
import '../../services/study_track_service.dart';

TextStyle _f({
  double sz = 14,
  FontWeight fw = FontWeight.w400,
  Color? c,
  double? h,
}) =>
    GoogleFonts.ibmPlexSansArabic(
        fontSize: sz, fontWeight: fw, color: c, height: h);

class StudyPlaylistDetailPage extends StatefulWidget {
  final String playlistId;
  final StudyTrackService service;

  const StudyPlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.service,
  });

  @override
  State<StudyPlaylistDetailPage> createState() =>
      _StudyPlaylistDetailPageState();
}

class _StudyPlaylistDetailPageState extends State<StudyPlaylistDetailPage> {
  StudyPlaylist? _playlist;
  bool _isImporting = false;
  String? _importError;

  @override
  void initState() {
    super.initState();
    _load();
    _autoImportIfNeeded();
  }

  void _autoImportIfNeeded() {
    final p = _playlist;
    if (p == null) return;
    final url = p.externalUrl ?? '';
    final isPlaylist = StudyPlaylist.extractYoutubePlaylistId(url) != null;
    if (p.type == StudySourceType.youtube &&
        url.isNotEmpty &&
        isPlaylist &&
        p.items.isEmpty) {
      _importFromYouTube();
    }
  }

  Future<void> _importFromYouTube() async {
    final url = _playlist?.externalUrl;
    if (url == null || url.isEmpty) return;

    final playlistId = StudyPlaylist.extractYoutubePlaylistId(url);
    if (playlistId == null || playlistId.isEmpty) {
      if (mounted) setState(() => _importError = 'تعذّر استخراج معرّف القائمة من الرابط');
      return;
    }

    if (mounted) setState(() { _isImporting = true; _importError = null; });

    final yt = YoutubeExplode();
    try {
      final videos = yt.playlists.getVideos(playlistId);
      final items = <StudyItem>[];
      int index = 0;
      await for (final video in videos) {
        items.add(StudyItem(
          id: const Uuid().v4(),
          title: video.title,
          videoUrl: 'https://youtube.com/watch?v=${video.id.value}',
          orderIndex: index++,
        ));
      }
      if (items.isEmpty) {
        if (mounted) setState(() => _importError = 'لم يتم العثور على فيديوهات في هذه القائمة');
        return;
      }
      await widget.service.savePlaylist(_playlist!.copyWith(items: items));
      if (mounted) _load();
    } catch (e) {
      if (mounted) setState(() => _importError = 'فشل الاستيراد — تحقق من اتصالك بالإنترنت');
    } finally {
      yt.close();
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _load() {
    setState(() => _playlist = widget.service.getPlaylist(widget.playlistId));
  }

  Future<void> _toggleWatched(String itemId) async {
    await widget.service.toggleItemWatched(widget.playlistId, itemId);
    _load();
  }

  Future<void> _deleteItem(String itemId) async {
    await widget.service.deleteItem(widget.playlistId, itemId);
    _load();
  }

  Future<void> _showAddEpisodeSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEpisodeSheet(
        service: widget.service,
        playlistId: widget.playlistId,
        nextIndex: _playlist?.items.length ?? 0,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAF9);
    final p = _playlist;

    if (p == null) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.darkGreen),
        ),
      );
    }

    final isYoutube = p.type == StudySourceType.youtube;
    final accent = isYoutube ? const Color(0xFFE53935) : AppColors.darkGreen;
    final sortedItems = p.sortedItems;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: isDark ? const Color(0xFF0D2818) : accent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (isYoutube && p.externalUrl != null && p.externalUrl!.isNotEmpty)
                  _isImporting
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download_rounded, color: Colors.white),
                          tooltip: 'استيراد الحلقات',
                          onPressed: _importFromYouTube,
                        ),
                if (p.externalUrl != null && p.externalUrl!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                    tooltip: 'فتح الرابط',
                    onPressed: () => _launchUrl(p.externalUrl!),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isYoutube
                          ? [const Color(0xFFB71C1C), const Color(0xFFE53935)]
                          : isDark
                              ? [const Color(0xFF0D2818), const Color(0xFF051109)]
                              : [const Color(0xFF145A3A), const Color(0xFF1E8255)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isYoutube
                                      ? Icons.smart_display_rounded
                                      : Icons.menu_book_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.title,
                                        style: _f(sz: 20, fw: FontWeight.w900, c: Colors.white)),
                                    if (p.description != null && p.description!.isNotEmpty)
                                      Text(p.description!,
                                          style: _f(sz: 12, c: Colors.white70)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Progress summary row
                          Row(
                            children: [
                              _ProgressRing(
                                progress: p.progress,
                                size: 52,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${(p.progress * 100).round()}% مكتمل',
                                    style: _f(sz: 16, fw: FontWeight.w900, c: Colors.white),
                                  ),
                                  Text(
                                    p.totalCount == 0
                                        ? 'لا توجد حلقات — اضغط + للإضافة'
                                        : 'شاهدت ${p.watchedCount} من ${p.totalCount} حلقة',
                                    style: _f(sz: 12, c: Colors.white70),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              if (p.isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('مكتملة ✓',
                                      style: _f(
                                          sz: 11,
                                          fw: FontWeight.bold,
                                          c: Colors.white)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Open URL Banner ──
            if (p.externalUrl != null && p.externalUrl!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: GestureDetector(
                    onTap: () => _launchUrl(p.externalUrl!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isYoutube
                                ? Icons.smart_display_rounded
                                : Icons.open_in_new_rounded,
                            color: accent,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isYoutube
                                  ? 'فتح قائمة التشغيل على يوتيوب'
                                  : 'فتح الرابط الخارجي',
                              style: _f(
                                  sz: 13,
                                  fw: FontWeight.w700,
                                  c: accent),
                            ),
                          ),
                          Icon(Icons.arrow_back_ios_rounded,
                              size: 12, color: accent),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Import error banner ──
            if (_importError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_importError!, style: _f(sz: 12, c: Colors.red))),
                    ]),
                  ),
                ),
              ),

            // ── Episodes list ──
            if (_isImporting)
              SliverFillRemaining(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: accent),
                    const SizedBox(height: 16),
                    Text('جارٍ استيراد الحلقات من يوتيوب...', style: _f(sz: 14, c: AppColors.gray)),
                  ]),
                ),
              )
            else if (sortedItems.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyEpisodes(isDark, accent))
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'الحلقات (${p.totalCount})',
                    style: _f(
                        sz: 16,
                        fw: FontWeight.w800,
                        c: isDark ? Colors.white : AppColors.dark),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = sortedItems[i];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _confirmDeleteItem(item);
                          return false;
                        },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _EpisodeTile(
                            item: item,
                            index: i + 1,
                            isDark: isDark,
                            accent: accent,
                            onToggle: () => _toggleWatched(item.id),
                            onDelete: () => _confirmDeleteItem(item),
                            onOpenUrl: item.hasUrl
                                ? () => _launchUrl(item.videoUrl!)
                                : null,
                          ),
                        ),
                      );
                    },
                    childCount: sortedItems.length,
                  ),
                ),
              ),
            ],
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddEpisodeSheet,
          backgroundColor: accent,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text('إضافة حلقة',
              style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildEmptyEpisodes(bool isDark, Color accent) {
    final isYt = _playlist?.type == StudySourceType.youtube &&
        (_playlist?.externalUrl?.isNotEmpty ?? false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.1 : 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.playlist_add_rounded, size: 44, color: accent),
          ),
          const SizedBox(height: 18),
          Text('لا توجد حلقات بعد',
              style: _f(sz: 18, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.dark)),
          const SizedBox(height: 8),
          Text(
            isYt
                ? 'اضغط على الزر أدناه لاستيراد جميع الحلقات تلقائياً من يوتيوب'
                : 'اضغط على "+ إضافة حلقة" لتبدأ بتتبع تقدمك\nيمكنك إضافة رابط الحلقة لفتحها بسرعة',
            style: _f(sz: 13, c: AppColors.gray, h: 1.7),
            textAlign: TextAlign.center,
          ),
          if (isYt) ...[          
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _importFromYouTube,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                label: Text('استيراد الحلقات من يوتيوب',
                    style: _f(sz: 14, fw: FontWeight.bold, c: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteItem(StudyItem item) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1F1C) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('حذف الحلقة',
              style: _f(sz: 17, fw: FontWeight.w800, c: isDark ? Colors.white : AppColors.darkGreen)),
          content: Text('هل تريد حذف "${item.title}"؟',
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
    if (confirmed == true) await _deleteItem(item.id);
  }
}

// ── Progress Ring ──────────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;

  const _ProgressRing({
    required this.progress,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(progress: progress, color: color),
        child: Center(
          child: Text(
            '${(progress * 100).round()}%',
            style: _f(sz: size * 0.22, fw: FontWeight.w900, c: color),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Episode Tile ───────────────────────────────────────────────────────────

class _EpisodeTile extends StatelessWidget {
  final StudyItem item;
  final int index;
  final bool isDark;
  final Color accent;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onOpenUrl;

  const _EpisodeTile({
    required this.item,
    required this.index,
    required this.isDark,
    required this.accent,
    required this.onToggle,
    required this.onDelete,
    this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showItemMenu(context),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? (item.isWatched
                  ? accent.withValues(alpha: 0.12)
                  : const Color(0xFF151C17))
              : (item.isWatched
                  ? accent.withValues(alpha: 0.06)
                  : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isWatched
                ? accent.withValues(alpha: isDark ? 0.3 : 0.2)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.withValues(alpha: 0.12)),
          ),
        ),
        child: Row(
          children: [
            // Episode number
            Container(
              width: 44,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: _f(sz: 14, fw: FontWeight.w900, c: accent),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: _f(
                  sz: 14,
                  fw: FontWeight.w600,
                  c: item.isWatched
                      ? (isDark ? Colors.white54 : AppColors.gray)
                      : (isDark ? Colors.white : AppColors.dark),
                  h: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Open URL button
            if (onOpenUrl != null)
              IconButton(
                icon: Icon(Icons.play_circle_rounded, color: accent, size: 22),
                onPressed: onOpenUrl,
                tooltip: 'فتح الحلقة',
                splashRadius: 20,
              ),
            // Watched checkbox
            GestureDetector(
              onTap: onToggle,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: item.isWatched
                      ? accent
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.isWatched
                        ? accent
                        : AppColors.gray.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: item.isWatched
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemMenu(BuildContext context) {
    final isDarkCtx = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkCtx ? const Color(0xFF1A1F1C) : Colors.white,
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
                  leading: Icon(
                    item.isWatched
                        ? Icons.remove_done_rounded
                        : Icons.check_circle_rounded,
                    color: accent,
                  ),
                  title: Text(
                    item.isWatched ? 'تحديد كـ "لم تُشاهَد"' : 'تحديد كـ "تمت مشاهدتها"',
                    style: _f(sz: 14, c: isDarkCtx ? Colors.white : AppColors.dark),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onToggle();
                  },
                ),
                if (onOpenUrl != null)
                  ListTile(
                    leading: Icon(Icons.open_in_new_rounded, color: accent),
                    title: Text('فتح الحلقة',
                        style: _f(sz: 14, c: isDarkCtx ? Colors.white : AppColors.dark)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onOpenUrl!();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: Text('حذف الحلقة',
                      style: _f(sz: 14, c: Colors.red, fw: FontWeight.w600)),
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
}

// ── Add Episode Bottom Sheet ───────────────────────────────────────────────

class _AddEpisodeSheet extends StatefulWidget {
  final StudyTrackService service;
  final String playlistId;
  final int nextIndex;

  const _AddEpisodeSheet({
    required this.service,
    required this.playlistId,
    required this.nextIndex,
  });

  @override
  State<_AddEpisodeSheet> createState() => _AddEpisodeSheetState();
}

class _AddEpisodeSheetState extends State<_AddEpisodeSheet> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _isSaving = true);
    final item = StudyItem(
      id: const Uuid().v4(),
      title: title,
      videoUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      orderIndex: widget.nextIndex,
    );
    await widget.service.addItem(widget.playlistId, item);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1F1C) : Colors.white;

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
              Text('إضافة حلقة',
                  style: _f(sz: 20, fw: FontWeight.w900, c: isDark ? Colors.white : AppColors.darkGreen)),
              const SizedBox(height: 6),
              Text('الحلقة رقم ${widget.nextIndex + 1}',
                  style: _f(sz: 13, c: AppColors.gray)),
              const SizedBox(height: 22),

              // Title
              Text('عنوان الحلقة *',
                  style: _f(sz: 13, fw: FontWeight.w700, c: isDark ? Colors.white70 : AppColors.dark)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                textDirection: TextDirection.rtl,
                style: _f(sz: 14, c: isDark ? Colors.white : AppColors.dark),
                decoration: InputDecoration(
                  hintText: 'مثال: الحلقة 1 — مولد النبي ﷺ',
                  hintStyle: _f(sz: 13, c: AppColors.gray),
                  prefixIcon: const Icon(Icons.play_lesson_rounded,
                      size: 18, color: AppColors.darkGreen),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.paleGreen.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // URL
              Text('رابط الحلقة (اختياري)',
                  style: _f(sz: 13, fw: FontWeight.w700, c: isDark ? Colors.white70 : AppColors.dark)),
              const SizedBox(height: 6),
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                style: _f(sz: 14, c: isDark ? Colors.white : AppColors.dark),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=...',
                  hintStyle: _f(sz: 13, c: AppColors.gray),
                  prefixIcon: const Icon(Icons.link_rounded,
                      size: 18, color: AppColors.darkGreen),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.paleGreen.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('إضافة الحلقة',
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
