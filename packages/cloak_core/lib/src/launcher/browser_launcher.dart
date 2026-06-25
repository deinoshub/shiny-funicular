import 'dart:async';
import 'dart:io';

import '../cdp/cdp_client.dart';
import '../cdp/cdp_discovery.dart';
import '../cdp/proxy_authenticator.dart';
import '../models/profile.dart';
import '../storage/app_paths.dart';
import 'launch_args_composer.dart';
import 'port_allocator.dart';
import 'process_registry.dart';
import 'running_process.dart';

class LaunchException implements Exception {
  LaunchException(this.message);
  final String message;
  @override
  String toString() => 'LaunchException: $message';
}

typedef SpawnFn = Future<Process> Function(
  String executable,
  List<String> args, {
  Map<String, String>? environment,
});

/// Launches and stops per-profile browser processes.
class BrowserLauncher {
  BrowserLauncher({
    required this.paths,
    required this.registry,
    PortAllocator? portAllocator,
    CdpDiscovery? discovery,
    SpawnFn? spawn,
  })  : _ports = portAllocator ?? const PortAllocator(),
        _discovery = discovery ?? CdpDiscovery(),
        _spawn = spawn ?? Process.start;

  final AppPaths paths;
  final ProcessRegistry registry;
  final PortAllocator _ports;
  final CdpDiscovery _discovery;
  final SpawnFn _spawn;

  final Map<String, Process> _processes = {};
  final Map<String, ProxyAuthenticator> _authenticators = {};

  Future<RunningProcess> launch({
    required Profile profile,
    required String executablePath,
  }) async {
    final (userDataDir, ephemeral) = await _resolveUserDataDir(profile);
    final port = await _ports.allocate();

    // When an authenticated proxy is in play, the browser must NOT receive
    // the start_url as a CLI arg: it would navigate immediately and fire its
    // first request before our ProxyAuthenticator can intercept the 407.
    // We instead omit it and navigate via CDP after auth is wired up.
    final proxy = profile.stealth.proxy;
    final needsProxyAuth =
        proxy.enabled && (proxy.username?.isNotEmpty ?? false);
    final args = LaunchArgsComposer.compose(
      profile: profile,
      userDataDir: userDataDir,
      debugPort: port,
      startUrlOverride: needsProxyAuth ? '' : null,
    );

    final Process process;
    try {
      process = await _spawn(executablePath, args,
          environment: profile.customEnv.isEmpty ? null : profile.customEnv);
    } catch (e) {
      throw LaunchException('Failed to start $executablePath: $e');
    }

    final httpBase = 'http://127.0.0.1:$port';
    final ready = await _discovery.waitUntilReady(httpBase);
    if (!ready) {
      process.kill();
      throw LaunchException('CDP endpoint did not come up on port $port');
    }

    if (needsProxyAuth) {
      try {
        final browserWs = await _discovery.browserWebSocketUrl(httpBase);
        final auth = ProxyAuthenticator(
          browserWsUrl: browserWs,
          username: proxy.username!,
          password: proxy.password ?? '',
        );
        await auth.start();
        _authenticators[profile.id] = auth;

        // Now that Fetch is enabled on the browser session and auto-attach
        // with waitForDebuggerOnStart is wired up, create the page target
        // ourselves. The new target is auto-attached and paused; the
        // authenticator's handler will enable Fetch on its session and
        // resume it before the page can fire requests.
        if (profile.startUrl.isNotEmpty) {
          await _navigateAfterAuth(browserWs, profile.startUrl);
        }
      } catch (_) {
        // Proxy auth setup failed; the page may still prompt for credentials.
      }
    }

    final running = RunningProcess(
      profileId: profile.id,
      pid: process.pid,
      debugPort: port,
      cdpHttpUrl: httpBase,
      ephemeral: ephemeral,
      userDataDir: userDataDir,
    );
    _processes[profile.id] = process;
    registry.add(running);

    // Auto-cleanup when the process exits on its own.
    unawaited(process.exitCode.then((_) => _cleanup(profile.id)));
    return running;
  }

  /// Creates a new page target for [url]. The ProxyAuthenticator's
  /// Target.setAutoAttach handler will Fetch.enable + runIfWaitingForDebugger
  /// on the new target's session so it can actually load the URL.
  Future<void> _navigateAfterAuth(String browserWsUrl, String url) async {
    final nav = CdpClient(browserWsUrl);
    try {
      await nav.connect();
      await nav.send('Target.createTarget', {'url': url});
    } finally {
      await nav.close();
    }
  }

  Future<void> stop(String profileId) async {
    _processes[profileId]?.kill();
    await _cleanup(profileId);
  }

  Future<void> stopAll() async {
    for (final id in _processes.keys.toList()) {
      await stop(id);
    }
  }

  Future<void> _cleanup(String profileId) async {
    final running = registry.byProfile(profileId);
    _processes.remove(profileId);
    await _authenticators.remove(profileId)?.stop();
    registry.remove(profileId);
    if (running != null && running.ephemeral) {
      final dir = Directory(running.userDataDir);
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  Future<(String dir, bool ephemeral)> _resolveUserDataDir(Profile profile) async {
    if (profile.persistent) {
      final dir = paths.profileDir(profile.id);
      await dir.create(recursive: true);
      return (dir.path, false);
    }
    final tmp = await Directory.systemTemp
        .createTemp('cloakbrowser-ephemeral-${profile.id}-');
    return (tmp.path, true);
  }
}
