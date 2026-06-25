import 'dart:io';

/// Finds a free localhost TCP port for the Chromium remote-debugging endpoint.
class PortAllocator {
  const PortAllocator({this.start = 9222, this.end = 10222});

  final int start;
  final int end;

  /// Returns the first free port in `[start, end]`. Throws [StateError] if
  /// every port in the range is in use.
  Future<int> allocate() async {
    for (var port = start; port <= end; port++) {
      try {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
        await socket.close();
        return port;
      } on SocketException {
        continue;
      }
    }
    throw StateError('No free port in range $start-$end');
  }
}
