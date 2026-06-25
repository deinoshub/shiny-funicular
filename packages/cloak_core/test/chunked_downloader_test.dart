import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late List<int> payload;
  late Directory tmp;
  late bool supportRange;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('cm_dl_');
    payload = List<int>.generate(50000, (i) => i % 256);
    supportRange = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (supportRange && range != null) {
        final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
        final start = int.parse(m.group(1)!);
        final end = m.group(2)!.isEmpty ? payload.length - 1 : int.parse(m.group(2)!);
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers.set(HttpHeaders.contentLengthHeader, end - start + 1);
        req.response.add(payload.sublist(start, end + 1));
      } else {
        req.response.statusCode = HttpStatus.ok;
        req.response.headers.set(HttpHeaders.contentLengthHeader, payload.length);
        req.response.add(payload);
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  Uri url() => Uri.parse('http://127.0.0.1:${server.port}/file.bin');

  test('parallel chunked download reproduces the payload', () async {
    final dest = File('${tmp.path}/out.bin');
    var lastFraction = 0.0;
    await ChunkedDownloader(chunkCount: 4, minChunkBytes: 1)
        .download(url: url(), destination: dest, onProgress: (f, r, t) => lastFraction = f);
    expect(dest.readAsBytesSync(), equals(payload));
    expect(lastFraction, closeTo(1.0, 0.001));
  });

  test('falls back to single-stream when server ignores Range', () async {
    supportRange = false;
    final dest = File('${tmp.path}/out2.bin');
    await ChunkedDownloader(chunkCount: 4, minChunkBytes: 1)
        .download(url: url(), destination: dest);
    expect(dest.readAsBytesSync(), equals(payload));
  });
}
