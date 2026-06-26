import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/settings/settings_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';

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
    await tester.pumpWidget(MacosApp(
      home: CupertinoPageScaffold(
        child: SafeArea(
          child: VersionsList(
            versions: versions,
            activeVersion: '146.0.1',
            onSetActive: (_) {},
            onDelete: (_) {},
            onDownloadLatest: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('146.0.1'), findsOneWidget);
    expect(find.text('active'), findsOneWidget);
  });
}
