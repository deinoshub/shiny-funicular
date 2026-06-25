import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cm_resume_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ResumeState state() => ResumeState(
        url: 'https://example/a.tar.gz',
        totalBytes: 1000,
        sha256: 'abc',
        chunkSize: 500,
        parts: [
          ResumePart(index: 0, receivedBytes: 500, path: 'part-0'),
          ResumePart(index: 1, receivedBytes: 100, path: 'part-1'),
        ],
        startedAt: DateTime.utc(2026, 6, 25),
        updatedAt: DateTime.utc(2026, 6, 25),
      );

  test('save then load round-trips', () async {
    final store = ResumeStore(dir);
    await store.save(state(), assetSha256: 'abc');
    final loaded = await store.load('abc');
    expect(loaded?.totalBytes, 1000);
    expect(loaded?.parts[1].receivedBytes, 100);
  });

  test('load returns null when absent', () async {
    expect(await ResumeStore(dir).load('nope'), isNull);
  });

  test('delete removes the state', () async {
    final store = ResumeStore(dir);
    await store.save(state(), assetSha256: 'abc');
    await store.delete('abc');
    expect(await store.load('abc'), isNull);
  });

  test('purgeExpired removes states older than maxAge', () async {
    final store = ResumeStore(dir);
    final old = state()..updatedAt = DateTime.utc(2026, 6, 1);
    await store.save(old, assetSha256: 'abc');
    await store.purgeExpired(
      maxAge: const Duration(days: 7),
      now: DateTime.utc(2026, 6, 25),
    );
    expect(await store.load('abc'), isNull);
  });
}
