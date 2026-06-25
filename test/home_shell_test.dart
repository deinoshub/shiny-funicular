import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/home/home_shell.dart';
import 'package:cloakmanager/screens/onboarding/onboarding_screen.dart';
import 'package:cloakmanager/state/binary_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, BinaryInstallState state) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        binaryStateProvider.overrideWith(() => _StubBinaryState(state)),
      ],
      child: const MaterialApp(home: HomeShell()),
    ));
    await tester.pump();
  }

  testWidgets('shows onboarding when not installed', (tester) async {
    await pump(tester, const NotInstalled());
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('shows home when installed', (tester) async {
    final v = InstalledVersion(
      version: '146.0.1',
      releaseTag: 'chromium-v146.0.1',
      appPath: 'binary/146.0.1',
      sizeBytes: 1,
      sha256: 'abc',
      installedAt: DateTime.utc(2026),
    );
    await pump(tester, Installed(v));
    expect(find.byKey(const Key('home')), findsOneWidget);
  });
}

class _StubBinaryState extends BinaryStateController {
  _StubBinaryState(this._state);
  final BinaryInstallState _state;
  @override
  Future<BinaryInstallState> build() async => _state;
}
