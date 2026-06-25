import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cm_sha_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('hashFile matches the known SHA-256 of "abc"', () async {
    final f = File('${tmp.path}/abc.txt')..writeAsStringSync('abc');
    expect(await Sha256Verifier.hashFile(f),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('verify is case-insensitive and detects mismatch', () async {
    final f = File('${tmp.path}/abc.txt')..writeAsStringSync('abc');
    expect(
        await Sha256Verifier.verify(f,
            'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'),
        isTrue);
    expect(await Sha256Verifier.verify(f, 'deadbeef'), isFalse);
  });
}
