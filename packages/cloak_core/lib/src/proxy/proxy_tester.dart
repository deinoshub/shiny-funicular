import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/proxy_config.dart';
import 'proxy_test_result.dart';
import 'proxy_transport.dart';

/// Runs a single through-proxy request and classifies the outcome.
///
/// The network call is delegated to an injectable [ProxyTransport] so the
/// classification/parsing logic here can be unit-tested with no network.
class ProxyTester {
  ProxyTester({ProxyTransport? transport})
      : _transport = transport ?? defaultProxyTransport;

  final ProxyTransport _transport;

  /// Endpoint hit through the proxy to learn the exit IP and geo.
  static const String echoUrl = 'https://ipwho.is/';

  /// Tests [proxy]. Never throws: failures become a [ProxyTestResult].
  Future<ProxyTestResult> test(
    ProxyConfig proxy, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final sw = Stopwatch()..start();
    try {
      final res = await _transport(proxy, Uri.parse(echoUrl), timeout);
      sw.stop();

      if (res.statusCode == 407) {
        return const ProxyTestResult(
          status: ProxyTestStatus.authFailed,
          message: 'Proxy rejected the credentials (HTTP 407).',
        );
      }
      if (res.statusCode != 200) {
        return ProxyTestResult(
          status: ProxyTestStatus.badResponse,
          message: 'Unexpected response from echo service '
              '(HTTP ${res.statusCode}).',
        );
      }

      Map<String, dynamic> json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return const ProxyTestResult(
          status: ProxyTestStatus.badResponse,
          message: 'Could not parse the echo service response.',
        );
      }

      if (json['success'] != true) {
        final msg = json['message'];
        return ProxyTestResult(
          status: ProxyTestStatus.badResponse,
          message:
              'Echo service reported failure${msg is String ? ': $msg' : ''}.',
        );
      }

      final tz = json['timezone'];
      return ProxyTestResult(
        status: ProxyTestStatus.success,
        latency: sw.elapsed,
        exitIp: json['ip'] as String?,
        country: json['country'] as String?,
        city: json['city'] as String?,
        timezone: tz is Map<String, dynamic> ? tz['id'] as String? : null,
        message: 'Connected through the proxy.',
      );
    } on ProxyAuthException catch (e) {
      return ProxyTestResult(
          status: ProxyTestStatus.authFailed, message: e.message);
    } on TimeoutException {
      return ProxyTestResult(
        status: ProxyTestStatus.timeout,
        message: 'Proxy test timed out after ${timeout.inSeconds}s.',
      );
    } on SocketException catch (e) {
      return ProxyTestResult(
        status: ProxyTestStatus.unreachable,
        message: 'Could not reach the proxy: ${e.message}.',
      );
    } catch (e) {
      return ProxyTestResult(
        status: ProxyTestStatus.unreachable,
        message: 'Proxy test failed: $e',
      );
    }
  }
}
