import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lavka_update/lavka_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    LavkaUpdate.resetForTest();
    LavkaUpdate.configure(appId: 'potik');
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Potik',
      packageName: 'com.softimply.potik',
      version: '1.0.0',
      buildNumber: '45',
      buildSignature: '',
    );
  });

  Widget app(Widget home) => MaterialApp(
        builder: (context, child) => LavkaUpdateGate(child: child!),
        home: Scaffold(body: home),
      );

  test('versionLabel drops the bracket when the name ends in the build', () {
    expect(versionLabel('1.0.47', 47), '1.0.47');
    expect(versionLabel('1.0.0', 45), '1.0.0 (45)');
    expect(versionLabel('1.47', 47), '1.47');
  });

  testWidgets('version tile shows this build', (tester) async {
    await tester.pumpWidget(app(const LavkaVersionTile()));
    await tester.pumpAndSettle();
    expect(find.text('Version 1.0.0 (45)'), findsOneWidget);
    // The test host isn't Android, so no network check happens.
    expect(find.text('Installed from Lavka'), findsOneWidget);
  });

  testWidgets('version text is compact', (tester) async {
    await tester.pumpWidget(app(const LavkaVersionText()));
    await tester.pumpAndSettle();
    expect(find.text('v1.0.0 (45)'), findsOneWidget);
  });

  testWidgets('banner appears for a newer build and Later hides it', (tester) async {
    await tester.pumpWidget(app(const LavkaVersionTile()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lavka-update-banner')), findsNothing);

    LavkaUpdate.status.value = const LavkaUpdateStatus(
      versionName: '1.0.0',
      versionCode: 45,
      latestVersionName: '1.0.1',
      latestVersionCode: 47,
      updateAvailable: true,
      pageUrl: 'https://lavka.softimply.tech/apps/potik',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lavka-update-banner')), findsOneWidget);
    expect(find.text('1.0.1 (47) · you have 1.0.0 (45)'), findsOneWidget);
    expect(find.text('Update available: 1.0.1 (47)'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lavka-update-banner')), findsNothing);

    // A build newer than the dismissed one brings it back.
    LavkaUpdate.status.value = const LavkaUpdateStatus(
      versionName: '1.0.0',
      versionCode: 45,
      latestVersionName: '1.0.2',
      latestVersionCode: 48,
      updateAvailable: true,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lavka-update-banner')), findsOneWidget);
  });
}
