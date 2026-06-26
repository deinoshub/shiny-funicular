import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/editor/proxy_tab.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile() => Profile(
      id: 'p1',
      name: 'Work',
      colorHex: '#fff',
      iconName: 'person',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      startUrl: 'https://example.com',
      stealth: StealthConfig(
        fingerprintSeed: 'seed',
        proxy: const ProxyConfig(
          enabled: true,
          type: ProxyType.http,
          host: 'proxy.test',
          port: 8080,
        ),
      ),
    );

Future<void> _pump(WidgetTester tester, ProxyTester fake) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [proxyTesterProvider.overrideWithValue(fake)],
    child: MaterialApp(
      home: Scaffold(
        body: ProxyTab(draft: _profile(), onChanged: (_) {}),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('shows success panel with exit IP and geo', (tester) async {
    final fake = ProxyTester(
      transport: (_, __, ___) async => const ProxyHttpResponse(
        200,
        '{"success":true,"ip":"203.0.113.7","country":"France",'
        '"city":"Paris","timezone":{"id":"Europe/Paris"}}',
      ),
    );
    await _pump(tester, fake);
    await tester.tap(find.text('Test Connection'));
    await tester.pump(); // kick off async test (spinner)
    await tester.pump(const Duration(milliseconds: 50)); // future resolves
    expect(find.text('Proxy OK'), findsOneWidget);
    expect(find.textContaining('203.0.113.7'), findsOneWidget);
    expect(find.textContaining('Paris, France'), findsOneWidget);
  });

  testWidgets('shows error panel on auth failure', (tester) async {
    final fake = ProxyTester(
      transport: (_, __, ___) async =>
          throw const ProxyAuthException('bad creds'),
    );
    await _pump(tester, fake);
    await tester.tap(find.text('Test Connection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Proxy test failed'), findsOneWidget);
    expect(find.textContaining('bad creds'), findsOneWidget);
  });
}
