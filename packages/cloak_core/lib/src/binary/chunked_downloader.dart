import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

typedef DownloadProgress = void Function(double fraction, int received, int total);

/// Downloads a file using parallel HTTP Range requests, falling back to a
/// single stream when the server does not honor `Range`.
class ChunkedDownloader {
  ChunkedDownloader({
    http.Client? client,
    this.chunkCount = 6,
    this.minChunkBytes = 8 * 1024 * 1024,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final int chunkCount;
  final int minChunkBytes;

  Future<void> download({
    required Uri url,
    required File destination,
    DownloadProgress? onProgress,
  }) async {
    final total = await _contentLength(url);
    await destination.parent.create(recursive: true);

    final canRange = total != null && total > 0 && await _supportsRange(url);
    if (!canRange) {
      await _singleStream(url, destination, total, onProgress);
      return;
    }

    final ranges = _computeRanges(total, chunkCount, minChunkBytes);
    final received = List<int>.filled(ranges.length, 0);
    final tmpDir = await destination.parent
        .createTemp('${destination.uri.pathSegments.last}-parts-');

    void report() {
      if (onProgress == null) return;
      final sum = received.fold<int>(0, (a, b) => a + b);
      onProgress(sum / total, sum, total);
    }

    try {
      await Future.wait([
        for (var i = 0; i < ranges.length; i++)
          () async {
            final (start, end) = ranges[i];
            final part = File('${tmpDir.path}/part-$i');
            final req = http.Request('GET', url)
              ..headers[HttpHeaders.rangeHeader] = 'bytes=$start-$end';
            final resp = await _client.send(req);
            final sink = part.openWrite();
            await for (final bytes in resp.stream) {
              sink.add(bytes);
              received[i] += bytes.length;
              report();
            }
            await sink.close();
          }(),
      ]);

      // Concatenate parts in order.
      final out = destination.openWrite();
      for (var i = 0; i < ranges.length; i++) {
        await out.addStream(File('${tmpDir.path}/part-$i').openRead());
      }
      await out.close();
    } finally {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    }
  }

  Future<int?> _contentLength(Uri url) async {
    final resp = await _client.head(url);
    final len = resp.headers[HttpHeaders.contentLengthHeader.toLowerCase()];
    return len == null ? null : int.tryParse(len);
  }

  Future<bool> _supportsRange(Uri url) async {
    final req = http.Request('GET', url)
      ..headers[HttpHeaders.rangeHeader] = 'bytes=0-0';
    final resp = await _client.send(req);
    await resp.stream.drain<void>();
    return resp.statusCode == HttpStatus.partialContent;
  }

  Future<void> _singleStream(
      Uri url, File dest, int? total, DownloadProgress? onProgress) async {
    final resp = await _client.send(http.Request('GET', url));
    final sink = dest.openWrite();
    var received = 0;
    await for (final bytes in resp.stream) {
      sink.add(bytes);
      received += bytes.length;
      if (onProgress != null && total != null && total > 0) {
        onProgress(received / total, received, total);
      }
    }
    await sink.close();
    if (onProgress != null && total != null && total > 0) {
      onProgress(1.0, total, total);
    }
  }

  static List<(int, int)> _computeRanges(int total, int chunkCount, int minChunk) {
    final count = ((total / minChunk).ceil()).clamp(1, chunkCount);
    final size = (total / count).ceil();
    final ranges = <(int, int)>[];
    for (var start = 0; start < total; start += size) {
      final end = (start + size - 1).clamp(0, total - 1);
      ranges.add((start, end));
    }
    return ranges;
  }
}
