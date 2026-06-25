import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class ResumePart {
  ResumePart({required this.index, required this.receivedBytes, required this.path});
  final int index;
  int receivedBytes;
  final String path;

  Map<String, dynamic> toJson() =>
      {'index': index, 'receivedBytes': receivedBytes, 'path': path};

  factory ResumePart.fromJson(Map<String, dynamic> j) => ResumePart(
        index: (j['index'] as num).toInt(),
        receivedBytes: (j['receivedBytes'] as num).toInt(),
        path: j['path'] as String,
      );
}

class ResumeState {
  ResumeState({
    required this.url,
    required this.totalBytes,
    required this.sha256,
    required this.chunkSize,
    required this.parts,
    required this.startedAt,
    required this.updatedAt,
  });

  String url;
  int totalBytes;
  String sha256;
  int chunkSize;
  List<ResumePart> parts;
  DateTime startedAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'url': url,
        'totalBytes': totalBytes,
        'sha256': sha256,
        'chunkSize': chunkSize,
        'parts': parts.map((e) => e.toJson()).toList(),
        'startedAt': startedAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory ResumeState.fromJson(Map<String, dynamic> j) => ResumeState(
        url: j['url'] as String,
        totalBytes: (j['totalBytes'] as num).toInt(),
        sha256: j['sha256'] as String,
        chunkSize: (j['chunkSize'] as num).toInt(),
        parts: (j['parts'] as List<dynamic>)
            .map((e) => ResumePart.fromJson(e as Map<String, dynamic>))
            .toList(),
        startedAt: DateTime.parse(j['startedAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

/// Persists per-download resume state as `<downloadsDir>/<sha256>.json`.
class ResumeStore {
  ResumeStore(this.downloadsDir);
  final Directory downloadsDir;

  File _file(String assetSha256) =>
      File(p.join(downloadsDir.path, '$assetSha256.json'));

  Future<ResumeState?> load(String assetSha256) async {
    final f = _file(assetSha256);
    if (!await f.exists()) return null;
    return ResumeState.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  }

  Future<void> save(ResumeState state, {required String assetSha256}) async {
    await downloadsDir.create(recursive: true);
    await _file(assetSha256)
        .writeAsString(jsonEncode(state.toJson()), flush: true);
  }

  Future<void> delete(String assetSha256) async {
    final f = _file(assetSha256);
    if (await f.exists()) await f.delete();
  }

  Future<void> purgeExpired(
      {Duration maxAge = const Duration(days: 7), DateTime? now}) async {
    if (!await downloadsDir.exists()) return;
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(maxAge);
    await for (final entity in downloadsDir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final state = ResumeState.fromJson(
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>);
        if (state.updatedAt.isBefore(cutoff)) await entity.delete();
      } catch (_) {
        await entity.delete(); // corrupt → drop
      }
    }
  }
}
