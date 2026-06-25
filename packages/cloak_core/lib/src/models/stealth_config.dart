import 'enums.dart';
import 'proxy_config.dart';

/// Full per-profile stealth configuration. Serialized to the `stealth_json`
/// column and consumed by `StealthArgsBuilder`.
class StealthConfig {
  const StealthConfig({
    this.fingerprintSeed,
    this.platform = SpoofPlatform.auto,
    this.brand = BrowserBrand.chrome,
    this.brandVersion,
    this.platformVersion,
    this.hardwareConcurrency,
    this.deviceMemoryGB,
    this.screenWidth,
    this.screenHeight,
    this.timezone,
    this.locale,
    this.gpuVendor,
    this.gpuRenderer,
    this.noiseEnabled = true,
    this.storageQuotaMB,
    this.webrtcIpPolicy = WebRtcIpPolicy.real,
    this.explicitWebRtcIp,
    required this.proxy,
  });

  final String? fingerprintSeed;
  final SpoofPlatform platform;
  final BrowserBrand brand;
  final String? brandVersion;
  final String? platformVersion;
  final int? hardwareConcurrency;
  final int? deviceMemoryGB;
  final int? screenWidth;
  final int? screenHeight;
  final String? timezone;
  final String? locale;
  final String? gpuVendor;
  final String? gpuRenderer;
  final bool noiseEnabled;
  final int? storageQuotaMB;
  final WebRtcIpPolicy webrtcIpPolicy;
  final String? explicitWebRtcIp;
  final ProxyConfig proxy;

  factory StealthConfig.defaults() =>
      StealthConfig(proxy: ProxyConfig.disabled());

  Map<String, dynamic> toJson() => {
        'fingerprintSeed': fingerprintSeed,
        'platform': platform.name,
        'brand': brand.name,
        'brandVersion': brandVersion,
        'platformVersion': platformVersion,
        'hardwareConcurrency': hardwareConcurrency,
        'deviceMemoryGB': deviceMemoryGB,
        'screenWidth': screenWidth,
        'screenHeight': screenHeight,
        'timezone': timezone,
        'locale': locale,
        'gpuVendor': gpuVendor,
        'gpuRenderer': gpuRenderer,
        'noiseEnabled': noiseEnabled,
        'storageQuotaMB': storageQuotaMB,
        'webrtcIpPolicy': webrtcIpPolicy.name,
        'explicitWebRtcIp': explicitWebRtcIp,
        'proxy': proxy.toJson(),
      };

  factory StealthConfig.fromJson(Map<String, dynamic> json) => StealthConfig(
        fingerprintSeed: json['fingerprintSeed'] as String?,
        platform: SpoofPlatform.values.byName(json['platform'] as String),
        brand: BrowserBrand.values.byName(json['brand'] as String),
        brandVersion: json['brandVersion'] as String?,
        platformVersion: json['platformVersion'] as String?,
        hardwareConcurrency: json['hardwareConcurrency'] as int?,
        deviceMemoryGB: json['deviceMemoryGB'] as int?,
        screenWidth: json['screenWidth'] as int?,
        screenHeight: json['screenHeight'] as int?,
        timezone: json['timezone'] as String?,
        locale: json['locale'] as String?,
        gpuVendor: json['gpuVendor'] as String?,
        gpuRenderer: json['gpuRenderer'] as String?,
        noiseEnabled: (json['noiseEnabled'] as bool?) ?? true,
        storageQuotaMB: json['storageQuotaMB'] as int?,
        webrtcIpPolicy:
            WebRtcIpPolicy.values.byName(json['webrtcIpPolicy'] as String),
        explicitWebRtcIp: json['explicitWebRtcIp'] as String?,
        proxy: ProxyConfig.fromJson(json['proxy'] as Map<String, dynamic>),
      );
}
