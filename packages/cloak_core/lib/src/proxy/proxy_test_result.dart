import '../models/proxy_config.dart';

/// Outcome category of a proxy connection test.
enum ProxyTestStatus { success, authFailed, unreachable, timeout, badResponse }

/// Minimal HTTP response captured by a [ProxyTransport].
class ProxyHttpResponse {
  const ProxyHttpResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

/// Thrown by a transport when the proxy rejects the supplied credentials.
class ProxyAuthException implements Exception {
  const ProxyAuthException([this.message = 'Proxy authentication failed.']);
  final String message;
  @override
  String toString() => 'ProxyAuthException: $message';
}

/// Performs a single GET through [proxy] to [url], honouring [timeout].
///
/// Returns the response, or throws [ProxyAuthException] (bad credentials),
/// `TimeoutException`, `SocketException` (unreachable), or another error.
typedef ProxyTransport = Future<ProxyHttpResponse> Function(
  ProxyConfig proxy,
  Uri url,
  Duration timeout,
);

/// Result of [ProxyTester.test]. Immutable; safe to compare by value.
class ProxyTestResult {
  const ProxyTestResult({
    required this.status,
    required this.message,
    this.latency,
    this.exitIp,
    this.country,
    this.city,
    this.timezone,
  });

  final ProxyTestStatus status;
  final String message;
  final Duration? latency;
  final String? exitIp;
  final String? country;
  final String? city;
  final String? timezone;

  @override
  bool operator ==(Object other) =>
      other is ProxyTestResult &&
      other.status == status &&
      other.message == message &&
      other.latency == latency &&
      other.exitIp == exitIp &&
      other.country == country &&
      other.city == city &&
      other.timezone == timezone;

  @override
  int get hashCode =>
      Object.hash(status, message, latency, exitIp, country, city, timezone);
}
