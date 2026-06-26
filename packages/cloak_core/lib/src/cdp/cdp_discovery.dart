import 'dart:convert';
import 'package:http/http.dart' as http;

class CdpTarget {
  const CdpTarget({
    required this.targetId,
    required this.type,
    required this.title,
    required this.url,
    this.webSocketDebuggerUrl,
  });

  final String targetId;
  final String type;
  final String title;
  final String url;
  final String? webSocketDebuggerUrl;

  factory CdpTarget.fromJson(Map<String, dynamic> j) => CdpTarget(
        targetId: (j['id'] ?? j['targetId'] ?? '') as String,
        type: (j['type'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        webSocketDebuggerUrl: j['webSocketDebuggerUrl'] as String?,
      );
}

/// Reads the Chromium remote-debugging HTTP endpoints (`/json/*`).
class CdpDiscovery {
  CdpDiscovery({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<String> browserWebSocketUrl(String httpBase) async {
    final resp = await _client.get(Uri.parse('$httpBase/json/version'));
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final url = json['webSocketDebuggerUrl'] as String?;
    if (url == null) {
      throw StateError('No webSocketDebuggerUrl at $httpBase/json/version');
    }
    return url;
  }

  Future<List<CdpTarget>> targets(String httpBase) async {
    final resp = await _client.get(Uri.parse('$httpBase/json'));
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((e) => CdpTarget.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches the targets at [httpBase] and returns a short label for the
  /// active page: its title, or the URL host when the title is empty.
  /// Returns null when no usable page target exists.
  Future<String?> activePageLabel(String httpBase) async =>
      pickActivePageLabel(await targets(httpBase));

  /// Pure label picker over already-fetched [targets]. The `/json` list is in
  /// most-recently-used order, so the first page target is the active one.
  static String? pickActivePageLabel(List<CdpTarget> targets) {
    for (final t in targets) {
      if (t.type != 'page') continue;
      final title = t.title.trim();
      if (title.isNotEmpty) return title;
      final host = Uri.tryParse(t.url)?.host ?? '';
      if (host.isNotEmpty) return host;
    }
    return null;
  }

  void close() => _client.close();

  Future<bool> waitUntilReady(
    String httpBase, {
    Duration timeout = const Duration(seconds: 20),
    Duration interval = const Duration(milliseconds: 200),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        await browserWebSocketUrl(httpBase);
        return true;
      } catch (_) {
        await Future<void>.delayed(interval);
      }
    }
    return false;
  }
}
