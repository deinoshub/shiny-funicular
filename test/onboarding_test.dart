import 'package:cloakmanager/screens/onboarding/onboarding_screen.dart';
import 'package:cloakmanager/state/binary_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, BinaryInstallState s) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [binaryStateProvider.overrideWith(() => _Stub(s))],
      child: const MaterialApp(home: OnboardingScreen()),
    ));
    await tester.pump();
  }

  testWidgets('shows download button when not installed', (tester) async {
    await pump(tester, const NotInstalled());
    expect(find.text('Download CloakBrowser'), findsOneWidget);
  });

  testWidgets('shows progress while downloading', (tester) async {
    await pump(tester, const Downloading(0.5, 50, 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('50%'), findsOneWidget);
  });

  testWidgets('shows retry on failure', (tester) async {
    await pump(tester, const Failed('boom'));
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });
}

class _Stub extends BinaryStateController {
  _Stub(this._s);
  final BinaryInstallState _s;
  @override
  Future<BinaryInstallState> build() async => _s;
}
