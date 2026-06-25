import '../models/enums.dart';
import '../models/stealth_config.dart';

/// Maps a [StealthConfig] to CloakBrowser `--fingerprint-*` / `--proxy-*`
/// flags. Emits ONLY stealth/proxy flags — manager-injected flags
/// (`--user-data-dir`, `--remote-debugging-*`, …) are added by the launcher.
class StealthArgsBuilder {
  const StealthArgsBuilder._();

  static List<String> build(StealthConfig c) {
    final args = <String>[];

    final seed = c.fingerprintSeed;
    if (seed != null && seed.isNotEmpty) {
      args.add('--fingerprint=$seed');
    }

    if (c.platform != SpoofPlatform.auto) {
      args.add('--fingerprint-platform=${c.platform.name}');
    }

    // Brand is always emitted (defaults to chrome).
    args.add('--fingerprint-brand=${c.brand.name}');
    if (c.brandVersion != null) {
      args.add('--fingerprint-brand-version=${c.brandVersion}');
    }
    if (c.platformVersion != null) {
      args.add('--fingerprint-platform-version=${c.platformVersion}');
    }

    _addIfNotNull(args, '--fingerprint-hardware-concurrency', c.hardwareConcurrency);
    _addIfNotNull(args, '--fingerprint-device-memory', c.deviceMemoryGB);
    _addIfNotNull(args, '--fingerprint-screen-width', c.screenWidth);
    _addIfNotNull(args, '--fingerprint-screen-height', c.screenHeight);
    _addIfNotNull(args, '--fingerprint-timezone', c.timezone);
    _addIfNotNull(args, '--fingerprint-locale', c.locale);
    _addIfNotNull(args, '--fingerprint-gpu-vendor', c.gpuVendor);
    _addIfNotNull(args, '--fingerprint-gpu-renderer', c.gpuRenderer);

    if (!c.noiseEnabled) {
      args.add('--fingerprint-noise=false');
    }
    _addIfNotNull(args, '--fingerprint-storage-quota', c.storageQuotaMB);

    switch (c.webrtcIpPolicy) {
      case WebRtcIpPolicy.real:
        break;
      case WebRtcIpPolicy.spoofAuto:
        args.add('--fingerprint-webrtc-ip=auto');
      case WebRtcIpPolicy.spoofExplicit:
        final ip = c.explicitWebRtcIp;
        if (ip != null && ip.isNotEmpty) {
          args.add('--fingerprint-webrtc-ip=$ip');
        }
    }

    if (c.proxy.enabled) {
      args.add('--proxy-server=${c.proxy.serverString}');
      if (c.proxy.bypassList.isNotEmpty) {
        args.add('--proxy-bypass-list=${c.proxy.bypassList}');
      }
    }

    return args;
  }

  static void _addIfNotNull(List<String> args, String flag, Object? value) {
    if (value != null) args.add('$flag=$value');
  }
}
