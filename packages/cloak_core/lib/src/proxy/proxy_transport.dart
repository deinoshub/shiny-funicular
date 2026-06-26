import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:socks5_proxy/socks_client.dart';

import '../models/enums.dart';
import '../models/proxy_config.dart';
import 'proxy_test_result.dart';

/// Real network transport used by [ProxyTester] in production.
///
/// HTTP proxies use `HttpClient.findProxy` + `addProxyCredentials`; SOCKS5
/// proxies are routed via the `socks5_proxy` package. The client is always
/// closed in a `finally`.
Future<ProxyHttpResponse> defaultProxyTransport(
  ProxyConfig proxy,
  Uri url,
  Duration timeout,
) async {
  final client = HttpClient();
  try {
    final hasAuth = proxy.username != null && proxy.username!.isNotEmpty;

    if (proxy.type == ProxyType.socks5) {
      final addrs = await InternetAddress.lookup(proxy.host).timeout(timeout);
      if (addrs.isEmpty) {
        throw const SocketException('Could not resolve proxy host');
      }
      SocksTCPClient.assignToHttpClient(client, [
        ProxySettings(
          addrs.first,
          proxy.port,
          username: hasAuth ? proxy.username : null,
          password: hasAuth ? proxy.password : null,
        ),
      ]);
    } else {
      client.findProxy = (_) => 'PROXY ${proxy.host}:${proxy.port}';
      if (hasAuth) {
        client.addProxyCredentials(
          proxy.host,
          proxy.port,
          '',
          HttpClientBasicCredentials(proxy.username!, proxy.password ?? ''),
        );
      }
    }

    final request = await client.getUrl(url).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final body = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join()
        .timeout(timeout);

    if (response.statusCode == 407) {
      throw const ProxyAuthException('Proxy rejected the credentials (HTTP 407).');
    }
    return ProxyHttpResponse(response.statusCode, body);
  } on HttpException catch (e) {
    // For HTTPS-over-HTTP-proxy, a bad-credential 407 surfaces as a failed
    // CONNECT tunnel rather than a normal response.
    final m = e.message.toLowerCase();
    if (m.contains('407') || m.contains('proxy')) {
      throw const ProxyAuthException('Proxy rejected the credentials.');
    }
    rethrow;
  } finally {
    client.close(force: true);
  }
}
