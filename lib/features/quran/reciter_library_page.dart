import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import '../../services/quran_audio_service.dart';
import '../../services/reciter_download_service.dart';

class ReciterLibraryPage extends StatefulWidget {
  /// If provided, tapping a reciter will immediately play this surah.
  final int? surahToPlay;

  const ReciterLibraryPage({super.key, this.surahToPlay});

  @override
  State<ReciterLibraryPage> createState() => _ReciterLibraryPageState();
}

class _ReciterLibraryPageState extends State<ReciterLibraryPage> {
  @override
  void initState() {
    super.initState();
    // Refresh download states from disk every time page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dl = ReciterDownloadService();
      for (final r in QuranAudioService.reciters) {
        if (r.type == ReciterType.full) {
          dl.refreshState(r.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioService = context.watch<QuranAudioService>();
    final dlService = context.watch<ReciterDownloadService>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: DirectionalIcon(isBack: true, size: 20, color: Colors.white),
            ),
          ),
          title: Text(
            'مكتبة القراء',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Now playing banner
            if (audioService.state.currentSurah != null)
              _NowPlayingBanner(audioService: audioService, isDark: isDark),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Snippets section ──
                  _SectionHeader(title: 'متاح الآن', subtitle: 'مدمج في التطبيق', isDark: isDark),
                  const SizedBox(height: 8),
                  ...QuranAudioService.reciters
                      .where((r) => r.type == ReciterType.snippets)
                      .map((r) => _SnippetReciterCard(
                            reciter: r,
                            audioService: audioService,
                            surahToPlay: widget.surahToPlay,
                            isDark: isDark,
                          )),

                  const SizedBox(height: 24),

                  // ── Full reciters section ──
                  _SectionHeader(
                    title: 'قراء كاملون',
                    subtitle: 'يتطلب تحميلاً لأول مرة',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  ...QuranAudioService.reciters
                      .where((r) => r.type == ReciterType.full)
                      .map((r) => _FullReciterCard(
                            reciter: r,
                            audioService: audioService,
                            dlService: dlService,
                            surahToPlay: widget.surahToPlay,
                            isDark: isDark,
                          )),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Now Playing Banner ───────────────────────────────────────────────────────

class _NowPlayingBanner extends StatelessWidget {
  final QuranAudioService audioService;
  final bool isDark;
  const _NowPlayingBanner({required this.audioService, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final state = audioService.state;
    final reciter = QuranAudioService.reciters.firstWhere(
      (r) => r.id == state.currentReciterId,
      orElse: () => QuranAudioService.reciters.first,
    );

    // For snippets use track title, for full reciters use surah name
    String trackTitle;
    if (reciter.type == ReciterType.snippets) {
      final tracks = reciter.snippetTracks ?? [];
      final idx = state.currentSurah ?? 0;
      trackTitle = idx < tracks.length ? tracks[idx].title : 'مقطع';
    } else {
      final surahNum = state.currentSurah ?? 1;
      trackTitle = 'سورة ${quran.getSurahNameArabic(surahNum.clamp(1, 114))}';
    }

    return Container(
      color: AppColors.darkGreen,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'يُشغَّل الآن: $trackTitle',
              style: GoogleFonts.ibmPlexSansArabic(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => state.isPlaying ? audioService.pause() : audioService.resume(),
            child: Icon(
              state.isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => audioService.stop(),
            child: const Icon(Icons.stop_circle_rounded, color: Colors.white70, size: 24),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.darkGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.darkGreen,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                color: isDark ? Colors.white54 : AppColors.gray,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Snippet Reciter Card ─────────────────────────────────────────────────────

class _SnippetReciterCard extends StatelessWidget {
  final Reciter reciter;
  final QuranAudioService audioService;
  final int? surahToPlay;
  final bool isDark;

  const _SnippetReciterCard({
    required this.reciter,
    required this.audioService,
    required this.surahToPlay,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = audioService.selectedReciterId == reciter.id;
    final isPlaying = audioService.state.currentReciterId == reciter.id &&
        audioService.state.isPlaying;

    return GestureDetector(
      onTap: () async {
        await audioService.setSelectedReciter(reciter.id);
        // Snippets always show the track picker — surahToPlay doesn't apply
        if (context.mounted) {
          _showSurahPicker(context, reciter.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.darkGreen
                : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.darkGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPlaying ? Icons.graphic_eq_rounded : Icons.menu_book_rounded,
                color: AppColors.darkGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reciter.nameAr,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reciter.description,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : AppColors.gray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '✓ متاح أوفلاين',
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.darkGreen : Colors.grey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  void _showSurahPicker(BuildContext context, String reciterId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final audioSvc = context.read<QuranAudioService>();
    final tracks = reciter.snippetTracks ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اختر مقطعاً',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: tracks.length,
                  itemBuilder: (_, i) {
                    final track = tracks[i];
                    final isPlaying = audioSvc.state.currentSurah == i &&
                        audioSvc.state.currentReciterId == reciterId &&
                        audioSvc.state.isPlaying;
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? AppColors.darkGreen
                              : AppColors.darkGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.graphic_eq_rounded
                              : Icons.play_arrow_rounded,
                          color: isPlaying ? Colors.white : AppColors.darkGreen,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        track.title,
                        style: GoogleFonts.ibmPlexSansArabic(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: isPlaying
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        audioSvc.playSurah(i, reciterId: reciterId);
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
}

// ─── Full Reciter Card ────────────────────────────────────────────────────────

class _FullReciterCard extends StatelessWidget {
  final Reciter reciter;
  final QuranAudioService audioService;
  final ReciterDownloadService dlService;
  final int? surahToPlay;
  final bool isDark;

  const _FullReciterCard({
    required this.reciter,
    required this.audioService,
    required this.dlService,
    required this.surahToPlay,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dlState = dlService.stateFor(reciter.id);
    final isSelected = audioService.selectedReciterId == reciter.id;
    final isPlaying = audioService.state.currentReciterId == reciter.id &&
        audioService.state.isPlaying;
    // Consider "ready" if at least 1 surah is downloaded (partial is still usable)
    final isFullyDownloaded = dlState.downloadedCount == 114;
    final hasAnyDownloaded = dlState.downloadedCount > 0;
    final estimatedMb = ReciterDownloadService.estimatedSizeMb[reciter.id] ?? 650;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.darkGreen
              : (isDark ? Colors.white12 : Colors.black12),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPlaying ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  color: AppColors.darkGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reciter.nameAr,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reciter.description,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : AppColors.gray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _StatusBadge(
                      dlState: dlState,
                      isFullyDownloaded: isFullyDownloaded,
                      estimatedMb: estimatedMb,
                    ),
                  ],
                ),
              ),
              if (isFullyDownloaded)
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.darkGreen : Colors.grey,
                  size: 22,
                ),
            ],
          ),

          // Download progress bar
          if (dlState.isDownloading) ...[
            const SizedBox(height: 12),
            _DownloadProgress(dlState: dlState, isDark: isDark),
          ],

          const SizedBox(height: 12),

          // Action buttons
          _ActionButtons(
            reciter: reciter,
            dlState: dlState,
            isFullyDownloaded: isFullyDownloaded,
            hasAnyDownloaded: hasAnyDownloaded,
            isSelected: isSelected,
            audioService: audioService,
            dlService: dlService,
            surahToPlay: surahToPlay,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ReciterDownloadState dlState;
  final bool isFullyDownloaded;
  final double estimatedMb;
  const _StatusBadge({
    required this.dlState,
    required this.isFullyDownloaded,
    required this.estimatedMb,
  });

  @override
  Widget build(BuildContext context) {
    if (isFullyDownloaded) {
      return _badge('✓ محمّل بالكامل (114 سورة)', Colors.green);
    }
    if (dlState.downloadedCount > 0) {
      return _badge(
        '${dlState.downloadedCount}/114 سورة — متاح جزئياً',
        Colors.orange,
      );
    }
    return _badge('يحتاج تحميل (~${estimatedMb.round()} MB)', Colors.blue);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  final ReciterDownloadState dlState;
  final bool isDark;
  const _DownloadProgress({required this.dlState, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'جاري تحميل سورة ${dlState.currentSurah ?? ''}...',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                color: isDark ? Colors.white70 : AppColors.gray,
              ),
            ),
            Text(
              '${dlState.downloadedCount}/${dlState.totalCount}',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: dlState.progress,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.darkGreen),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Reciter reciter;
  final ReciterDownloadState dlState;
  final bool isFullyDownloaded;
  final bool hasAnyDownloaded;
  final bool isSelected;
  final QuranAudioService audioService;
  final ReciterDownloadService dlService;
  final int? surahToPlay;
  final bool isDark;

  const _ActionButtons({
    required this.reciter,
    required this.dlState,
    required this.isFullyDownloaded,
    required this.hasAnyDownloaded,
    required this.isSelected,
    required this.audioService,
    required this.dlService,
    required this.surahToPlay,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Has at least some surahs downloaded — show play + options
    if (hasAnyDownloaded && !dlState.isDownloading) {
      return Row(
        children: [
          Expanded(
            child: _Btn(
              label: isFullyDownloaded ? 'اختر سورة' : 'تشغيل المحمّل',
              icon: Icons.queue_music_rounded,
              color: AppColors.darkGreen,
              onTap: () => _showSurahPickerFull(context),
            ),
          ),
          const SizedBox(width: 8),
          if (!isFullyDownloaded)
            _Btn(
              label: 'استكمال',
              icon: Icons.download_rounded,
              color: Colors.orange,
              outlined: true,
              onTap: () => dlService.downloadReciter(reciter.id),
            )
          else
            _Btn(
              label: 'حذف',
              icon: Icons.delete_outline_rounded,
              color: Colors.red,
              outlined: true,
              onTap: () => _confirmDelete(context),
            ),
        ],
      );
    }

    if (dlState.isDownloading) {
      return _Btn(
        label: 'إيقاف التحميل',
        icon: Icons.stop_rounded,
        color: Colors.red,
        outlined: true,
        onTap: () => dlService.cancelDownload(reciter.id),
        fullWidth: true,
      );
    }

    // Nothing downloaded yet
    return Row(
      children: [
        Expanded(
          child: _Btn(
            label: 'تحميل للاستخدام أوفلاين',
            icon: Icons.download_rounded,
            color: AppColors.darkGreen,
            onTap: () => dlService.downloadReciter(reciter.id),
          ),
        ),
        const SizedBox(width: 8),
        _Btn(
          label: 'بث',
          icon: Icons.wifi_rounded,
          color: Colors.blue,
          outlined: true,
          onTap: () async {
            await audioService.setSelectedReciter(reciter.id);
            final surah = surahToPlay ?? 1;
            await audioService.playSurah(surah, reciterId: reciter.id);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }

  void _showSurahPickerFull(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                reciter.nameAr,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.darkGreen,
                ),
              ),
              Text(
                'اختر السورة',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13, color: isDark ? Colors.white54 : AppColors.gray,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: 114,
                  itemBuilder: (_, i) {
                    final surahNum = i + 1;
                    final isPlaying =
                        audioService.state.currentSurah == surahNum &&
                        audioService.state.currentReciterId == reciter.id &&
                        audioService.state.isPlaying;
                    return ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? AppColors.darkGreen
                              : AppColors.darkGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: isPlaying
                              ? const Icon(Icons.graphic_eq_rounded,
                                  color: Colors.white, size: 16)
                              : Text(
                                  '$surahNum',
                                  style: GoogleFonts.ibmPlexSansArabic(
                                    color: AppColors.darkGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        quran.getSurahNameArabic(surahNum),
                        style: GoogleFonts.amiri(
                          fontSize: 18,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        '${quran.getVerseCount(surahNum)} آية',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : AppColors.gray,
                        ),
                      ),                      onTap: () async {
                        Navigator.pop(ctx);
                        await audioService.setSelectedReciter(reciter.id);
                        await audioService.playSurah(surahNum, reciterId: reciter.id);
                        if (context.mounted) Navigator.pop(context);
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'حذف التسجيلات؟',
            style: GoogleFonts.ibmPlexSansArabic(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.darkGreen,
            ),
          ),
          content: Text(
            'سيتم حذف جميع ملفات ${reciter.nameAr} من جهازك. يمكنك إعادة تحميلها لاحقاً.',
            style: GoogleFonts.ibmPlexSansArabic(
              color: isDark ? Colors.white70 : AppColors.gray,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء',
                  style: GoogleFonts.ibmPlexSansArabic(color: AppColors.gray)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                dlService.deleteReciter(reciter.id);
              },
              child: Text('حذف',
                  style: GoogleFonts.ibmPlexSansArabic(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final bool fullWidth;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = outlined
        ? OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label,
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          )
        : ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 16),
            label: Text(label,
                style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );

    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
