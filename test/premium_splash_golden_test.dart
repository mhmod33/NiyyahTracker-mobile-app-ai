import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niyyah_tracker_flutter/features/splash/premium_splash_page.dart';

void main() {
  testWidgets('premium splash composition', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PremiumSplashPage(skipNavigation: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/premium_splash.png'),
    );
  });
}
