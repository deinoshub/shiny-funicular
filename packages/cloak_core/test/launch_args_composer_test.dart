import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  Profile profile({List<String> customArgs = const [], String startUrl = 'https://example.com'}) =>
      Profile(
        id: 'p1',
        name: 'P',
        colorHex: '#fff',
        iconName: 'person',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        stealth: StealthConfig(
          fingerprintSeed: 'seed',
          proxy: ProxyConfig.disabled(),
        ),
        startUrl: startUrl,
        customArgs: customArgs,
      );

  test('composes stealth + injected + custom + url in order', () {
    final args = LaunchArgsComposer.compose(
      profile: profile(customArgs: const ['--mute-audio']),
      userDataDir: '/data/profiles/p1',
      debugPort: 9333,
    );
    expect(args.first, '--fingerprint=seed');
    expect(args, containsAllInOrder(<String>[
      '--user-data-dir=/data/profiles/p1',
      '--remote-debugging-port=9333',
      '--remote-debugging-address=127.0.0.1',
      '--no-default-browser-check',
      '--no-first-run',
      '--disable-background-mode',
      '--disable-features=TranslateUI,InfiniteSessionRestore',
      '--mute-audio',
      'https://example.com',
    ]));
    expect(args.last, 'https://example.com');
  });

  test('about:blank is still included as start url', () {
    final args = LaunchArgsComposer.compose(
      profile: profile(startUrl: 'about:blank'),
      userDataDir: '/d',
      debugPort: 9222,
    );
    expect(args.last, 'about:blank');
  });
}
