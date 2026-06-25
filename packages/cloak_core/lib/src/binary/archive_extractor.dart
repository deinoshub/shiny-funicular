import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Extracts `.tar.gz`/`.tgz` and `.zip` archives to a directory.
class ArchiveExtractor {
  const ArchiveExtractor._();

  static Future<void> extract({
    required File archive,
    required Directory destination,
  }) async {
    final name = archive.path.toLowerCase();
    final bytes = await archive.readAsBytes();
    final Archive decoded;
    if (name.endsWith('.zip')) {
      decoded = ZipDecoder().decodeBytes(bytes);
    } else if (name.endsWith('.tar.gz') || name.endsWith('.tgz')) {
      decoded = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } else {
      throw UnsupportedError('Unsupported archive: ${archive.path}');
    }

    await destination.create(recursive: true);
    for (final entry in decoded) {
      final outPath = p.join(destination.path, entry.name);
      if (entry.isFile) {
        final f = File(outPath);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(entry.content as List<int>);
        if (!Platform.isWindows && (entry.mode & 0x40) != 0) {
          // Owner-execute bit set in the archive → make executable.
          await Process.run('chmod', ['+x', outPath]);
        }
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }
}
