import 'dart:convert';
import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory base;
  late AppPaths paths;
  late ProcessRegistry registry;
  late HttpServer cdpServer;

  setUp(() async {
    base = Directory.systemTemp.createTempSync('cm_launch_');
    paths = AppPaths(base);
    registry = ProcessRegistry();
    // Stand-in CDP HTTP endpoint so waitUntilReady succeeds.
    cdpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    cdpServer.listen((req) async {
      if (req.uri.path == '/json/version') {
        req.response.write(jsonEncode({
          'webSocketDebuggerUrl': 'ws://127.0.0.1:${cdpServer.port}/devtools/browser/x'
        }));
      }
      await req.response.close();
    });
  });
  tearDown(() async {
    registry.dispose();
    await cdpServer.close(force: true);
    base.deleteSync(recursive: true);
  });

  Profile profile({bool persistent = true}) => Profile(
        id: 'p1',
        name: 'P',
        colorHex: '#fff',
        iconName: 'person',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        stealth: StealthConfig(proxy: ProxyConfig.disabled()),
        persistent: persistent,
        startUrl: 'about:blank',
      );

  test('launch spawns, waits for CDP, and registers the process', () async {
    final launcher = BrowserLauncher(
      paths: paths,
      registry: registry,
      // Force discovery at the stand-in CDP server's port.
      portAllocator: _FixedPortAllocator(cdpServer.port),
      discovery: CdpDiscovery(),
      spawn: (exe, args, {environment}) async =>
          await Process.start(_sleepCommand.first, _sleepCommand.sublist(1)),
    );

    final running = await launcher.launch(
      profile: profile(),
      executablePath: '/unused/fake-chromium',
    );

    expect(running.debugPort, cdpServer.port);
    expect(registry.isRunning('p1'), isTrue);
    expect(Directory(running.userDataDir).existsSync(), isTrue);

    await launcher.stop('p1');
    expect(registry.isRunning('p1'), isFalse);
  });
}

// A cross-platform "sleep ~30s" command for the fake browser process.
List<String> get _sleepCommand => Platform.isWindows
    ? ['cmd', '/c', 'ping', '127.0.0.1', '-n', '30']
    : ['sleep', '30'];

class _FixedPortAllocator implements PortAllocator {
  _FixedPortAllocator(this.port);
  final int port;
  @override
  int get start => port;
  @override
  int get end => port;
  @override
  Future<int> allocate() async => port;
}
