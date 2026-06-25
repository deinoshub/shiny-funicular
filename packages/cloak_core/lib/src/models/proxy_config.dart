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

  /// `<scheme>://[user:pass@]host:port` for `--proxy-server`.
  String get serverString {
    final scheme = type == ProxyType.socks5 ? 'socks5' : 'http';
    final hasAuth = (username != null && username!.isNotEmpty);
    final auth = hasAuth ? '$username:${password ?? ''}@' : '';
    return '$scheme://$auth$host:$port';
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
