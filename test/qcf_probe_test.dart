import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family);
  loader.addFont(Future.value(ByteData.view(
      File(path).readAsBytesSync().buffer.asByteData().buffer)));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('qcf separators probe', () async {
    await _loadFont('QCF2100', 'qcf_test/QCF2100.ttf');

    final page100 = <String>[];
    for (final l in File('mushaf_v2.txt').readAsLinesSync()) {
      if (l.startsWith('100,')) page100.addAll(l.substring(4).trim().split(' '));
    }
    debugPrint('tokens: ${page100.length}');

    for (final entry in {
      'none': '',
      'zwsp': '​',
      'space': ' ',
      'thin': ' ',
    }.entries) {
      final tp = TextPainter(
        text: TextSpan(
          text: page100.join(entry.value),
          style: const TextStyle(fontFamily: 'QCF2100', fontSize: 20),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: 10000);
      debugPrint('${entry.key}: totalWidth=${tp.width.toStringAsFixed(1)}');
      tp.dispose();
    }

    final zwspText = page100.join('​');
    for (final fs in [20.0, 22.0, 23.0, 24.0]) {
      final tp = TextPainter(
        text: TextSpan(
          text: zwspText,
          style: TextStyle(fontFamily: 'QCF2100', fontSize: fs),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
      )..layout(maxWidth: 360);
      debugPrint('zwsp fs=$fs lines=${tp.computeLineMetrics().length} '
          'h=${tp.height.toStringAsFixed(0)} w=${tp.width.toStringAsFixed(0)}');
      tp.dispose();
    }
    final spText = page100.join(' ');
    for (final fs in [20.0, 22.0, 23.0, 24.0]) {
      final tp = TextPainter(
        text: TextSpan(
          text: spText,
          style: TextStyle(fontFamily: 'QCF2100', fontSize: fs),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
      )..layout(maxWidth: 360);
      debugPrint('space fs=$fs lines=${tp.computeLineMetrics().length} '
          'h=${tp.height.toStringAsFixed(0)} w=${tp.width.toStringAsFixed(0)}');
      tp.dispose();
    }
  });
}
