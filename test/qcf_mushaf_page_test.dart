import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niyyah_tracker_flutter/services/qcf_mushaf_service.dart';
import 'package:niyyah_tracker_flutter/widgets/qcf_mushaf_page.dart';

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family);
  loader.addFont(Future.value(ByteData.view(
      File(path).readAsBytesSync().buffer.asByteData().buffer)));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('qcf mushaf page renders page 100', (tester) async {
    await QcfMushafService.instance.init();
    await _loadFont('QCF2100', 'qcf_test/QCF2100.ttf');
    QcfMushafService.instance.markFontLoadedForTest(100);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 700,
              child: QcfMushafPage(
                pageNumber: 100,
                isDark: false,
                onVerseTap: (_, __) {},
                onVerseLongPress: (_, __) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final richText = tester.widget<RichText>(find.byType(RichText));
    expect(richText.text is TextSpan, isTrue);

    // Measure the rendered paragraph: page 100 should produce ~15 lines.
    final renderParagraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    debugPrint('rendered size: ${renderParagraph.size}');
    // 15 lines * ~1.95 * fontSize(~25) ≈ 730; must fit in 700 -> fs reduced.
    expect(renderParagraph.size.height, lessThan(720));
    expect(renderParagraph.size.height, greaterThan(300));
  });

  testWidgets('qcf mushaf page renders page 2 (sparse + surah start)',
      (tester) async {
    await QcfMushafService.instance.init();
    await _loadFont('QCF2002', 'qcf_test/QCF2002.ttf');
    QcfMushafService.instance.markFontLoadedForTest(2);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 700,
              child: QcfMushafPage(
                pageNumber: 2,
                isDark: true,
                onVerseTap: (_, __) {},
                onVerseLongPress: (_, __) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final renderParagraph = tester.renderObject<RenderParagraph>(
      find.byType(RichText),
    );
    debugPrint('page2 rendered size: ${renderParagraph.size}');
    expect(renderParagraph.size.height, greaterThan(100));
    expect(renderParagraph.size.height, lessThan(720));
  });
}
