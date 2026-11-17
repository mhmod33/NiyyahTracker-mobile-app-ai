import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;

import '../core/app_colors.dart';
import '../services/qcf_mushaf_service.dart';

/// Renders one page of the 1421H Madani mushaf using the official QPC
/// page-glyph fonts (QCF2{page}.ttf).
///
/// Each ayah is a sequence of private-use glyphs whose advances already encode
/// the printed word spacing and justification. Joining tokens with zero-width
/// spaces gives the line breaker break opportunities at word boundaries, so at
/// the correct font size the natural wrap reproduces the official printed
/// line breaks.
class QcfMushafPage extends StatefulWidget {
  final int pageNumber;
  final int? highlightSurah;
  final int? highlightVerse;
  final bool isDark;
  final Set<int> selectedVerses;
  final int? selectedSurah;
  final bool verticalScroll;
  final void Function(int surah, int verse) onVerseTap;
  final void Function(int surah, int verse) onVerseLongPress;

  const QcfMushafPage({
    super.key,
    required this.pageNumber,
    this.highlightSurah,
    this.highlightVerse,
    required this.isDark,
    this.selectedVerses = const {},
    this.selectedSurah,
    this.verticalScroll = false,
    required this.onVerseTap,
    required this.onVerseLongPress,
  });

  @override
  State<QcfMushafPage> createState() => _QcfMushafPageState();
}

class _QcfMushafPageState extends State<QcfMushafPage> {
  static const double _hPad = 10.0;
  static const double _vPad = 6.0;
  static const String _zwsp = '​';

  // Cached fit results keyed by available size, mirroring the legacy widget.
  double? _cachedFontSize;
  double? _cachedWidth;
  double? _cachedHeight;

  List<QcfAyah>? get _ayahs =>
      QcfMushafService.instance.ayahsForPage(widget.pageNumber);

  /// Font size at which the mushaf column width (in font units) exactly
  /// matches the available width — the size that reproduces printed breaks.
  double _fitWidthFontSize(double availableW) =>
      availableW * QcfMushafService.kUnitsPerEm /
      QcfMushafService.kColumnWidthUnits;

  /// Picks the largest font size whose rendered page still fits [availableH].
  /// Never exceeds the width-fit size so line breaks stay faithful.
  double _computeFontSize(double availableW, double availableH) {
    if (_cachedFontSize != null &&
        _cachedWidth == availableW &&
        _cachedHeight == availableH) {
      return _cachedFontSize!;
    }

    final maxFs = _fitWidthFontSize(availableW);
    double lo = 6.0, hi = maxFs;
    for (int i = 0; i < 14; i++) {
      final mid = (lo + hi) / 2;
      final content = _buildContent(mid, availableW);
      final tp = _measure(content, availableW);
      final h = tp.height;
      tp.dispose();
      if (h <= availableH) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    _cachedFontSize = lo;
    _cachedWidth = availableW;
    _cachedHeight = availableH;
    return lo;
  }

  TextPainter _measure(_QcfContent content, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(children: content.spans),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.justify,
      locale: const Locale('ar'),
    );
    if (content.placeholders.isNotEmpty) {
      tp.setPlaceholderDimensions(content.placeholders);
    }
    tp.layout(maxWidth: maxWidth);
    return tp;
  }

  /// Builds the span tree for the whole page at [fontSize].
  /// Surah cartouches and basmalas are full-width WidgetSpans so they occupy
  /// their own lines exactly like the printed mushaf.
  _QcfContent _buildContent(double fontSize, double availableW) {
    final ayahs = _ayahs ?? const <QcfAyah>[];
    final spans = <InlineSpan>[];
    final ranges = <_QcfVerseRange>[];
    final placeholders = <PlaceholderDimensions>[];
    int charOffset = 0;

    int i = 0;
    while (i < ayahs.length) {
      final runSurah = ayahs[i].surah;
      int j = i;
      while (j < ayahs.length && ayahs[j].surah == runSurah) {
        j++;
      }
      final run = ayahs.sublist(i, j);
      final startsSurah = run.first.verse == 1;

      if (startsSurah) {
        // Surah cartouche (~2 mushaf lines tall).
        final headerH = _headerHeight(fontSize);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox(
              width: availableW,
              child: _buildSurahHeader(runSurah, fontSize),
            ),
          ),
        );
        placeholders.add(
          PlaceholderDimensions(
            size: Size(availableW, headerH),
            alignment: PlaceholderAlignment.middle,
          ),
        );
        if (runSurah != 1 && runSurah != 9) {
          final basmalaH = _basmalaHeight(fontSize);
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(
                width: availableW,
                child: _buildBasmala(fontSize),
              ),
            ),
          );
          placeholders.add(
            PlaceholderDimensions(
              size: Size(availableW, basmalaH),
              alignment: PlaceholderAlignment.middle,
            ),
          );
        }
      }

      for (int k = 0; k < run.length; k++) {
        final ayah = run[k];
        final tokens = ayah.text
            .split(' ')
            .where((t) => t.isNotEmpty)
            .join(_zwsp);
        if (tokens.isEmpty) continue;

        final isHighlighted = widget.highlightSurah == ayah.surah &&
            widget.highlightVerse == ayah.verse;
        final isSelected = widget.selectedSurah == ayah.surah &&
            widget.selectedVerses.contains(ayah.verse);

        final startOffset = charOffset;
        spans.add(
          TextSpan(
            text: tokens,
            style: TextStyle(
              fontFamily: QcfMushafService.familyFor(widget.pageNumber),
              fontSize: fontSize,
              color: isHighlighted
                  ? Colors.black
                  : (widget.isDark
                      ? const Color(0xFFF5F0E8)
                      : AppColors.textPrimary),
              backgroundColor: isHighlighted
                  ? Colors.yellow.withValues(alpha: 0.18)
                  : (isSelected
                      ? AppColors.gold.withValues(alpha: 0.22)
                      : null),
            ),
          ),
        );
        charOffset += tokens.length;

        // Break opportunity + spacing between consecutive ayahs.
        if (k < run.length - 1) {
          spans.add(const TextSpan(text: _zwsp));
          charOffset += 1;
        }

        ranges.add(
          _QcfVerseRange(startOffset, charOffset, ayah.surah, ayah.verse),
        );
      }
      i = j;
    }

    return _QcfContent(
      spans: spans,
      ranges: ranges,
      placeholders: placeholders,
    );
  }

  // Heights must match the rendered header/basmala widgets (same math as the
  // legacy mushaf page's measurement helpers).
  double _headerHeight(double fontSize) {
    final marginV = fontSize * 0.15 * 2;
    final paddingV = fontSize * 0.4 * 2;
    const border = 3.0;
    final titleFS = (fontSize * 1.4).clamp(16.0, 28.0);
    return marginV + paddingV + border + titleFS * 1.35;
  }

  double _basmalaHeight(double fontSize) {
    final marginV = fontSize * 0.3 + fontSize * 0.1;
    final paddingV = fontSize * 0.2 * 2;
    const border = 2.0;
    final textFS = (fontSize * 1.3).clamp(14.0, 30.0);
    return marginV + paddingV + border + textFS * 1.35;
  }

  Widget _buildSurahHeader(int surah, double fontSize) {
    final verseCount = quran.getVerseCount(surah);
    final place = quran.getPlaceOfRevelation(surah) == "Makkah" ? "مكية" : "مدنية";
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: fontSize * 0.15),
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.8,
        vertical: fontSize * 0.4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkGreen.withValues(alpha: 0.25),
            AppColors.darkGreen.withValues(alpha: 0.10),
          ],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.darkGreen.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$place • $verseCount آية',
            style: GoogleFonts.ibmPlexSansArabic(
              color: widget.isDark ? Colors.white60 : AppColors.textSecondary,
              fontSize: (fontSize * 0.6).clamp(9.0, 13.0),
            ),
          ),
          Text(
            'سورة ${quran.getSurahNameArabic(surah)}',
            style: TextStyle(
              fontFamily: 'KFGQPC Uthmanic Script Hafs',
              fontSize: (fontSize * 1.4).clamp(16.0, 28.0),
              color: widget.isDark ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: fontSize * 3),
        ],
      ),
    );
  }

  Widget _buildBasmala(double fontSize) {
    return Container(
      margin: EdgeInsets.only(bottom: fontSize * 0.3, top: fontSize * 0.1),
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.5,
        vertical: fontSize * 0.2,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.darkGreen.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.darkGreen.withValues(alpha: 0.3),
            width: 1,
          ),
          top: BorderSide(
            color: AppColors.darkGreen.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.darkGreen.withValues(alpha: 0.8),
              size: fontSize * 0.9,
            ),
            SizedBox(width: fontSize * 0.4),
            Text(
              quran.basmala,
              style: TextStyle(
                fontFamily: 'KFGQPC Uthmanic Script Hafs',
                fontSize: (fontSize * 1.3).clamp(14.0, 30.0),
                color: widget.isDark ? Colors.white : AppColors.textPrimary,
                shadows: widget.isDark
                    ? const [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(width: fontSize * 0.4),
            Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.darkGreen.withValues(alpha: 0.8),
              size: fontSize * 0.9,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ayahs = _ayahs;
    if (ayahs == null || ayahs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: _vPad),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableW = constraints.maxWidth;
          final availableH = constraints.maxHeight;
          final fontSize = widget.verticalScroll
              ? _fitWidthFontSize(availableW)
              : _computeFontSize(availableW, availableH);
          final content = _buildContent(fontSize, availableW);

          final text = _QcfTappableRichText(
            textSpan: TextSpan(children: content.spans),
            ranges: content.ranges,
            placeholderDimensions: content.placeholders,
            onVerseTap: widget.onVerseTap,
            onVerseLongPress: widget.onVerseLongPress,
          );

          if (widget.verticalScroll) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SizedBox(width: availableW, child: text),
            );
          }
          return SizedBox(
            width: availableW,
            height: availableH,
            child: text,
          );
        },
      ),
    );
  }
}

class _QcfContent {
  final List<InlineSpan> spans;
  final List<_QcfVerseRange> ranges;
  final List<PlaceholderDimensions> placeholders;
  const _QcfContent({
    required this.spans,
    required this.ranges,
    required this.placeholders,
  });
}

class _QcfVerseRange {
  final int startOffset;
  final int endOffset;
  final int surah;
  final int verse;
  const _QcfVerseRange(this.startOffset, this.endOffset, this.surah, this.verse);
}

/// Tap/long-press hit-testing for the mushaf page.
///
/// Like the legacy reader, this uses onTapUp + TextPainter offset lookup
/// instead of per-span gesture recognizers, so horizontal PageView swipes are
/// never blocked by the gesture arena.
class _QcfTappableRichText extends StatelessWidget {
  final TextSpan textSpan;
  final List<_QcfVerseRange> ranges;
  final List<PlaceholderDimensions> placeholderDimensions;
  final void Function(int surah, int verse) onVerseTap;
  final void Function(int surah, int verse) onVerseLongPress;

  const _QcfTappableRichText({
    required this.textSpan,
    required this.ranges,
    required this.placeholderDimensions,
    required this.onVerseTap,
    required this.onVerseLongPress,
  });

  _QcfVerseRange? _rangeAt(Offset localPos, double width) {
    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.justify,
      locale: const Locale('ar'),
    );
    if (placeholderDimensions.isNotEmpty) {
      tp.setPlaceholderDimensions(placeholderDimensions);
    }
    tp.layout(maxWidth: width);
    final offset = tp.getPositionForOffset(localPos).offset;
    tp.dispose();

    for (final range in ranges) {
      if (offset >= range.startOffset && offset < range.endOffset) {
        return range;
      }
    }
    // Tapped on a header/basmala or a gap — use the nearest preceding range.
    _QcfVerseRange? best;
    for (final range in ranges) {
      if (range.startOffset <= offset) {
        best = range;
      } else {
        break;
      }
    }
    return best ?? (ranges.isNotEmpty ? ranges.first : null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTapUp: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final range = _rangeAt(details.localPosition, renderBox.size.width);
        if (range != null) onVerseTap(range.surah, range.verse);
      },
      onLongPressStart: (details) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final range = _rangeAt(details.localPosition, renderBox.size.width);
        if (range != null) onVerseLongPress(range.surah, range.verse);
      },
      child: RichText(
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
        locale: const Locale('ar'),
        text: textSpan,
      ),
    );
  }
}
