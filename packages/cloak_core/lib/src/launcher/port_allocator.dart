import 'dart:io';

/// Probes whether [port] is free. Returns true if available.
typedef PortProbe = Future<bool> Function(int port);

/// Finds a free localhost TCP port for the Chromium remote-debugging endpoint.
class PortAllocator {
  const PortAllocator({this.start = 9222, this.end = 10222, PortProbe? probe})
      : _probe = probe;

  final int start;
  final int end;
  final PortProbe? _probe;

  /// Returns the first free port in `[start, end]`. Throws [StateError] if
  /// every port in the range is in use.
  Future<int> allocate() async {
    final probe = _probe ?? _bindProbe;
    for (var port = start; port <= end; port++) {
      if (await probe(port)) return port;
    }
    throw StateError('No free port in range $start-$end');
  }

  static Future<bool> _bindProbe(int port) async {
    try {
      final socket =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      await socket.close();
      return true;
    } on SocketException {
      return false;
    }
  }
}
