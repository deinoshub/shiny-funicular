import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('cm_arc_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('extracts a .zip into destination', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('dir/hello.txt', 5, 'hello'.codeUnits));
    final zipBytes = ZipEncoder().encode(archive)!;
    final zip = File('${tmp.path}/a.zip')..writeAsBytesSync(zipBytes);
    final dest = Directory('${tmp.path}/out');

    await ArchiveExtractor.extract(archive: zip, destination: dest);

    expect(File('${dest.path}/dir/hello.txt').readAsStringSync(), 'hello');
  });

  test('extracts a .tar.gz into destination', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('bin/run', 3, 'abc'.codeUnits));
    final tarBytes = TarEncoder().encode(archive);
    final gz = GZipEncoder().encode(tarBytes)!;
    final tgz = File('${tmp.path}/a.tar.gz')..writeAsBytesSync(gz);
    final dest = Directory('${tmp.path}/out2');

    await ArchiveExtractor.extract(archive: tgz, destination: dest);

    expect(File('${dest.path}/bin/run').readAsStringSync(), 'abc');
  });

  test('unsupported extension throws', () {
    final f = File('${tmp.path}/a.rar')..writeAsBytesSync([0]);
    expect(
      () => ArchiveExtractor.extract(archive: f, destination: tmp),
      throwsUnsupportedError,
    );
  });
}
