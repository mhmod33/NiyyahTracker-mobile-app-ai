import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// One ayah's worth of QPC V2 (1421H) page-glyph text.
/// [text] is the space-separated PUA glyphs exactly as printed on the page,
/// including the ayah-end marker as the last glyph.
class QcfAyah {
  final int surah;
  final int verse;
  final String text;
  const QcfAyah(this.surah, this.verse, this.text);
}

/// Loads the per-page QPC Hafs V2 (1421H Madani mushaf) page-glyph fonts and
/// the bundled ayah->glyph data, and registers fonts at runtime via FontLoader.
///
/// Each mushaf page has its own font (`QCF2{page}.ttf`, ~300-600 KB) hosted at
/// fonts.quran.ws. Fonts are downloaded once and cached in the app support dir.
class QcfMushafService {
  QcfMushafService._();
  static final QcfMushafService instance = QcfMushafService._();

  static const String _fontBaseUrl =
      'https://fonts.quran.ws/assets/fonts/qpc-hafs-v2/';
  static const String _dataAsset = 'assets/data/qcf_v2_pages.json';
  static const int kPageCount = 604;

  /// Empirical column width of the mushaf text block, in font units
  /// (upem = 2500 for every QCF2 page font). Used to derive the font size
  /// that reproduces the printed line breaks: glyph advances already encode
  /// word spacing and justification, so at this size the natural wrap lands
  /// on the official line breaks.
  static const double kColumnWidthUnits = 39557.0;
  static const double kUnitsPerEm = 2500.0;

  Map<int, List<QcfAyah>>? _pages;
  Future<void>? _dataFuture;
  final Map<int, Future<bool>> _fontLoads = {};
  final Set<String> _loadedFamilies = {};
  Directory? _cacheDir;

  /// Family name used for a page font, matching the font's internal name.
  static String familyFor(int page) =>
      'QCF2${page.toString().padLeft(3, '0')}';

  /// File name of the page font.
  static String fileFor(int page) => '${familyFor(page)}.ttf';

  /// Ensures the bundled ayah->glyph data is parsed. Safe to call repeatedly.
  Future<void> init() {
    return _dataFuture ??= _loadData();
  }

  Future<void> _loadData() async {
    final raw = await rootBundle.loadString(_dataAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final pages = decoded['pages'] as Map<String, dynamic>;
    final result = <int, List<QcfAyah>>{};
    pages.forEach((key, value) {
      final page = int.parse(key);
      final list = <QcfAyah>[];
      for (final item in value as List) {
        final e = item as List;
        list.add(QcfAyah(e[0] as int, e[1] as int, e[2] as String));
      }
      result[page] = list;
    });
    _pages = result;
  }

  /// Ordered ayahs (with glyph text) printed on [page], or null if data is
  /// not loaded yet / page invalid.
  List<QcfAyah>? ayahsForPage(int page) {
    final p = _pages;
    if (p == null || page < 1 || page > kPageCount) return null;
    return p[page];
  }

  bool get isDataReady => _pages != null;

  @visibleForTesting
  void markFontLoadedForTest(int page) => _loadedFamilies.add(familyFor(page));

  /// Returns true when the page font is registered and ready to render.
  bool isFontReady(int page) => _loadedFamilies.contains(familyFor(page));

  /// Downloads (once) and registers the QCF2 font for [page].
  /// Subsequent calls return the cached future/result.
  Future<bool> ensureFont(int page, {bool prefetch = true}) {
    if (page < 1 || page > kPageCount) return Future.value(false);
    final family = familyFor(page);
    if (_loadedFamilies.contains(family)) return Future.value(true);
    return _fontLoads.putIfAbsent(
      page,
      () => _loadFont(page, prefetch)
          .whenComplete(() => _fontLoads.remove(page)),
    );
  }

  Future<bool> _loadFont(int page, bool prefetch) async {
    try {
      await init();
      _cacheDir ??= await getApplicationSupportDirectory();
      final dir = Directory('${_cacheDir!.path}${Platform.pathSeparator}qcf_fonts');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}${fileFor(page)}');

      Uint8List bytes;
      if (await file.exists() && await file.length() > 10000) {
        bytes = await file.readAsBytes();
      } else {
        final response = await http
            .get(Uri.parse('$_fontBaseUrl${fileFor(page)}'))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200 || response.bodyBytes.length < 10000) {
          return false;
        }
        bytes = response.bodyBytes;
        try {
          await file.writeAsBytes(bytes, flush: true);
        } catch (_) {}
      }

      final loader = FontLoader(familyFor(page))
        ..addFont(Future.value(
            ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes)));
      await loader.load();
      _loadedFamilies.add(familyFor(page));

      // Warm the neighbouring pages so swiping stays smooth. Neighbours do
      // not prefetch further, so this never cascades through the whole mushaf.
      if (prefetch) {
        unawaited(ensureFont(page + 1, prefetch: false));
        unawaited(ensureFont(page - 1, prefetch: false));
      }
      return true;
    } catch (e) {
      debugPrint('QcfMushafService: failed to load font for page $page: $e');
      return false;
    }
  }
}
