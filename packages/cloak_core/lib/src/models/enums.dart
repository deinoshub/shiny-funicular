/// Spoofed OS reported by CloakBrowser. `auto` means "let the binary decide"
/// (the `--fingerprint-platform` flag is omitted).
enum SpoofPlatform { auto, macos, windows, linux }

/// Browser brand spoofed in the User-Agent and Client Hints.
enum BrowserBrand { chrome, edge, opera, vivaldi }

extension BrowserBrandDefaults on BrowserBrand {
  /// Default brand version used when `StealthConfig.brandVersion` is null.
  String get defaultVersion => switch (this) {
        BrowserBrand.chrome => '146.0.7680.177',
        BrowserBrand.edge => '146.0.7680.79',
        BrowserBrand.opera => '115.0.5322.68',
        BrowserBrand.vivaldi => '7.5.3735.44',
      };
}

/// WebRTC IP exposure policy.
enum WebRtcIpPolicy { real, spoofAuto, spoofExplicit }

/// Proxy transport.
enum ProxyType { http, socks5 }
