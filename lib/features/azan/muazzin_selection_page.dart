import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/directional_icon.dart';
import '../../services/azan_service.dart';

TextStyle _f({double sz = 14, FontWeight fw = FontWeight.w400, Color? c, double? h}) =>
    GoogleFonts.ibmPlexSansArabic(fontSize: sz, fontWeight: fw, color: c, height: h);

class MuazzinSelectionPage extends StatefulWidget {
  const MuazzinSelectionPage({super.key});

  @override
  State<MuazzinSelectionPage> createState() => _MuazzinSelectionPageState();
}

class _MuazzinSelectionPageState extends State<MuazzinSelectionPage> {
  final AzanService _azanService = AzanService();
  late String _selectedMuazzinId;
  String? _playingMuazzinId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _selectedMuazzinId = _azanService.selectedMuazzinId;
  }

  @override
  void dispose() {
    if (_isPlaying) {
      _azanService.stopAzan();
    }
    super.dispose();
  }

  Future<void> _selectMuazzin(String muazzinId) async {
    setState(() => _selectedMuazzinId = muazzinId);
    await _azanService.setSelectedMuazzin(muazzinId);
  }

  Future<void> _togglePreview(String muazzinId) async {
    if (_isPlaying && _playingMuazzinId == muazzinId) {
      await _azanService.stopAzan();
      setState(() {
        _isPlaying = false;
        _playingMuazzinId = null;
      });
    } else {
      if (_isPlaying) {
        await _azanService.stopAzan();
      }
      setState(() {
        _isPlaying = true;
        _playingMuazzinId = muazzinId;
      });
      await _azanService.previewAzan(muazzinId);
      // Auto-stop after playback ends
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && _playingMuazzinId == muazzinId) {
          setState(() {
            _isPlaying = false;
            _playingMuazzinId = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7F6);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  bottom: 32,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF0D2818), const Color(0xFF0A3D22)]
                        : [const Color(0xFF145A3A), const Color(0xFF1E8255)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const DirectionalIcon(
                              isBack: true,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'اختيار المؤذن',
                            textAlign: TextAlign.center,
                            style: _f(sz: 20, fw: FontWeight.w800, c: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.mosque_rounded,
                              color: AppColors.goldLight,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اختر صوت المؤذن المفضل',
                                  style: _f(sz: 14, fw: FontWeight.w600, c: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'اضغط على زر التشغيل للاستماع قبل الاختيار',
                                  style: _f(sz: 12, fw: FontWeight.w400, c: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Muazzin List ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final muazzin = AzanService.availableMuazzins[index];
                    final isSelected = muazzin.id == _selectedMuazzinId;
                    final isCurrentlyPlaying =
                        _isPlaying && _playingMuazzinId == muazzin.id;

                    return _MuazzinCard(
                      muazzin: muazzin,
                      isSelected: isSelected,
                      isPlaying: isCurrentlyPlaying,
                      isDark: isDark,
                      onSelect: () => _selectMuazzin(muazzin.id),
                      onTogglePreview: () => _togglePreview(muazzin.id),
                    );
                  },
                  childCount: AzanService.availableMuazzins.length,
                ),
              ),
            ),

            // ── Info Section ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.gold.withOpacity(0.08)
                        : AppColors.goldBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.gold.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'سيتم تشغيل صوت الأذان المختار تلقائياً عند دخول وقت كل صلاة. '
                          'أذان الفجر يكون مختلفاً عن باقي الصلوات.',
                          style: _f(
                            sz: 13,
                            fw: FontWeight.w500,
                            c: isDark ? AppColors.gold : AppColors.dark,
                            h: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuazzinCard extends StatelessWidget {
  final Muazzin muazzin;
  final bool isSelected;
  final bool isPlaying;
  final bool isDark;
  final VoidCallback onSelect;
  final VoidCallback onTogglePreview;

  const _MuazzinCard({
    required this.muazzin,
    required this.isSelected,
    required this.isPlaying,
    required this.isDark,
    required this.onSelect,
    required this.onTogglePreview,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.darkGreen;
    final cardBg = isSelected
        ? (isDark ? accent.withOpacity(0.12) : accent.withOpacity(0.05))
        : (isDark ? const Color(0xFF1A1F1C) : Colors.white);
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white60 : AppColors.textSecondary;

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accent.withOpacity(isDark ? 0.6 : 0.4)
                : (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accent : subColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),

            // Muazzin info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    muazzin.nameAr,
                    style: _f(
                      sz: 16,
                      fw: isSelected ? FontWeight.w700 : FontWeight.w600,
                      c: isSelected ? accent : textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    muazzin.description,
                    style: _f(sz: 12, fw: FontWeight.w400, c: subColor),
                  ),
                ],
              ),
            ),

            // Play/Stop button
            GestureDetector(
              onTap: onTogglePreview,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? Colors.red.withOpacity(0.1)
                      : accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPlaying
                        ? Colors.red.withOpacity(0.3)
                        : accent.withOpacity(0.2),
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: isPlaying ? Colors.red : accent,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
