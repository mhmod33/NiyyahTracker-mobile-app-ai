import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:google_fonts/google_fonts.dart';
import '../core/app_colors.dart';
import '../services/quran_audio_service.dart';
import '../features/quran/reciter_library_page.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<QuranAudioService>(
      builder: (context, service, _) {
        final state = service.state;
        if (state.currentSurah == null) return const SizedBox.shrink();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final reciter = QuranAudioService.reciters.firstWhere(
          (r) => r.id == state.currentReciterId,
          orElse: () => QuranAudioService.reciters.first,
        );

        String trackTitle;
        if (reciter.type == ReciterType.snippets) {
          final tracks = reciter.snippetTracks ?? [];
          final idx = state.currentSurah!;
          trackTitle = idx < tracks.length ? tracks[idx].title : 'مقطع';
        } else {
          trackTitle =
              'سورة ${quran.getSurahNameArabic(state.currentSurah!.clamp(1, 114))}';
        }

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReciterLibraryPage()),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2F23) : AppColors.darkGreen,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkGreen.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trackTitle,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            reciter.nameAr,
                            style: GoogleFonts.ibmPlexSansArabic(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ControlButton(
                      icon: Icons.skip_previous_rounded,
                      onTap: () => service.playPrevious(),
                    ),
                    const SizedBox(width: 4),
                    _PlayPauseButton(service: service, state: state),
                    const SizedBox(width: 4),
                    _ControlButton(
                      icon: Icons.skip_next_rounded,
                      onTap: () => service.playNext(),
                    ),
                    const SizedBox(width: 4),
                    _ControlButton(
                      icon: Icons.close_rounded,
                      onTap: () => service.stop(),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar — always shown, uses StreamBuilder directly on player
                _LiveProgressBar(service: service),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Live Progress Bar (reads directly from AudioPlayer streams) ──────────────

class _LiveProgressBar extends StatelessWidget {
  final QuranAudioService service;
  const _LiveProgressBar({required this.service});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: service.positionStream,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: service.durationStream,
          builder: (context, durSnap) {
            final position = posSnap.data ?? Duration.zero;
            final duration = durSnap.data ?? Duration.zero;
            final progress = duration.inMilliseconds > 0
                ? (position.inMilliseconds / duration.inMilliseconds)
                    .clamp(0.0, 1.0)
                : 0.0;

            return Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: duration.inMilliseconds > 0
                        ? (v) {
                            final pos = Duration(
                              milliseconds:
                                  (v * duration.inMilliseconds).round(),
                            );
                            service.seekTo(pos);
                          }
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 10)),
                      Text(_fmt(duration),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final QuranAudioService service;
  final QuranPlaybackState state;
  const _PlayPauseButton({required this.service, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }
    return _ControlButton(
      icon: state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      onTap: () => state.isPlaying ? service.pause() : service.resume(),
      size: 28,
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _ControlButton(
      {required this.icon, required this.onTap, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
