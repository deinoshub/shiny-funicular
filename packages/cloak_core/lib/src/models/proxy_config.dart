import 'enums.dart';

/// Per-profile proxy settings. Maps to `--proxy-server` / `--proxy-bypass-list`.
class ProxyConfig {
  const ProxyConfig({
    required this.enabled,
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.bypassList = '',
    this.geoipEnabled = false,
  });

  final bool enabled;
  final ProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;

  /// Comma-separated hosts that bypass the proxy (Chrome `--proxy-bypass-list` syntax).
  final String bypassList;

  /// When true, the binary resolves the proxy exit IP to auto-set timezone/locale.
  final bool geoipEnabled;

  factory ProxyConfig.disabled() => const ProxyConfig(
        enabled: false,
        type: ProxyType.http,
        host: '',
        port: 0,
      );

  String get _scheme => type == ProxyType.socks5 ? 'socks5' : 'http';

  /// `<scheme>://host:port` — the value for Chromium's `--proxy-server`.
  ///
  /// Chromium's `--proxy-server` does NOT accept inline `user:pass@`
  /// credentials; including them makes the host unparseable and yields
  /// `ERR_NO_SUPPORTED_PROXIES`. Credentials are handled separately.
  String get serverEndpoint => '$_scheme://$host:$port';

  /// `<scheme>://[user:pass@]host:port` — for display / connection testing,
  /// NOT for the launch flag. Use [serverEndpoint] for `--proxy-server`.
  String get serverString {
    final hasAuth = (username != null && username!.isNotEmpty);
    final auth = hasAuth ? '$username:${password ?? ''}@' : '';
    return '$_scheme://$auth$host:$port';
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'type': type.name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'bypassList': bypassList,
        'geoipEnabled': geoipEnabled,
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
        enabled: json['enabled'] as bool,
        type: ProxyType.values.byName(json['type'] as String),
        host: json['host'] as String,
        port: json['port'] as int,
        username: json['username'] as String?,
        password: json['password'] as String?,
        bypassList: (json['bypassList'] as String?) ?? '',
        geoipEnabled: (json['geoipEnabled'] as bool?) ?? false,
      );

  ProxyConfig copyWith({
    bool? enabled,
    ProxyType? type,
    String? host,
    int? port,
    String? username,
    String? password,
    String? bypassList,
    bool? geoipEnabled,
  }) =>
      ProxyConfig(
        enabled: enabled ?? this.enabled,
        type: type ?? this.type,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
        bypassList: bypassList ?? this.bypassList,
        geoipEnabled: geoipEnabled ?? this.geoipEnabled,
      );

  @override
  bool operator ==(Object other) =>
      other is ProxyConfig &&
      other.enabled == enabled &&
      other.type == type &&
      other.host == host &&
      other.port == port &&
      other.username == username &&
      other.password == password &&
      other.bypassList == bypassList &&
      other.geoipEnabled == geoipEnabled;

  @override
  int get hashCode => Object.hash(
        enabled, type, host, port, username, password, bypassList, geoipEnabled,
      );
}
