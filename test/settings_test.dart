import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Versions list renders installed versions', (tester) async {
    final versions = [
      InstalledVersion(
        version: '146.0.1',
        releaseTag: 'chromium-v146.0.1',
        appPath: 'binary/146.0.1',
        sizeBytes: 200000000,
        sha256: 'abc',
        installedAt: DateTime.utc(2026),
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: VersionsList(
        versions: versions,
        activeVersion: '146.0.1',
        onSetActive: (_) {},
        onDelete: (_) {},
        onDownloadLatest: () {},
      ),
    ));
    expect(find.textContaining('146.0.1'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
  });
}
