import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/installed_version.dart';
import '../models/release_info.dart';
import '../platform/platform_info.dart';
import '../storage/app_paths.dart';
import 'archive_extractor.dart';
import 'chunked_downloader.dart';
import 'sha256_verifier.dart';
import 'sha256sums.dart';

/// Orchestrates discovery, download, verification, extraction, and tracking
/// of CloakBrowser binaries.
class BinaryManager {
  BinaryManager({
    required this.paths,
    required this.platform,
    http.Client? client,
    ChunkedDownloader? downloader,
  })  : _client = client ?? http.Client(),
        _downloader = downloader ?? ChunkedDownloader(client: client);

  final AppPaths paths;
  final PlatformInfo platform;
  final http.Client _client;
  final ChunkedDownloader _downloader;

  static const releasesApi =
      'https://api.github.com/repos/CloakHQ/cloakbrowser/releases?per_page=30';

  /// The latest non-pro release that publishes an asset for [platform].
  /// Not every release ships every platform, so callers must filter rather
  /// than assume the newest release is installable.
  Future<ReleaseInfo?> latestCompatibleRelease() async {
    final releases = await listReleases();
    for (final r in releases) {
      if (!r.isPro && r.assetFor(platform) != null) return r;
    }
    return null;
  }

  Future<BinaryManifest> loadManifest() async {
    final manifestFile = paths.manifestFile;
    if (await manifestFile.exists()) {
      return BinaryManifest.fromJson(
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>);
    }
    final legacy = paths.legacyBinaryInfoFile;
    if (await legacy.exists()) {
      final migrated = BinaryManifest.fromLegacyBinaryInfo(
          jsonDecode(await legacy.readAsString()) as Map<String, dynamic>);
      await saveManifest(migrated);
      await legacy.delete();
      return migrated;
    }
    return BinaryManifest.empty();
  }

  Future<void> saveManifest(BinaryManifest manifest) async {
    await paths.baseDir.create(recursive: true);
    await paths.manifestFile
        .writeAsString(jsonEncode(manifest.toJson()), flush: true);
  }

  /// Absolute path to the launchable executable inside an installed version.
  String executablePathFor(InstalledVersion v) {
    final root = p.join(paths.baseDir.path, v.appPath);
    return switch (platform.os) {
      'macos' => p.join(root, 'Contents', 'MacOS', 'Chromium'),
      'windows' => p.join(root, 'chrome.exe'),
      _ => p.join(root, 'chrome'),
    };
  }

  Future<List<ReleaseInfo>> listReleases() async {
    final resp = await _client.get(Uri.parse(releasesApi),
        headers: {'Accept': 'application/vnd.github+json'});
    if (resp.statusCode != 200) {
      throw HttpException('GitHub API ${resp.statusCode}');
    }
    return ReleaseInfo.listFromJson(jsonDecode(resp.body) as List<dynamic>);
  }

  /// Downloads + verifies + extracts [release]'s platform asset. Returns the
  /// resulting [InstalledVersion]; the caller registers it in the manifest.
  Future<InstalledVersion> install(
    ReleaseInfo release, {
    DownloadProgress? onProgress,
  }) async {
    final asset = release.assetFor(platform);
    if (asset == null) {
      throw StateError('No asset for ${platform.os}/${platform.arch}');
    }
    final sumsAsset = release.sha256SumsAsset;
    if (sumsAsset == null) {
      throw StateError('Release ${release.tagName} has no SHA256SUMS');
    }

    await paths.downloadsDir.create(recursive: true);
    final archiveFile = File(p.join(paths.downloadsDir.path, asset.name));

    await _downloader.download(
      url: Uri.parse(asset.downloadUrl),
      destination: archiveFile,
      onProgress: onProgress,
    );

    // Fetch and check SHA-256.
    final sumsResp = await _client.get(Uri.parse(sumsAsset.downloadUrl));
    final expected = Sha256Sums.parse(sumsResp.body).hashFor(asset.name);
    if (expected == null) {
      throw StateError('SHA256SUMS missing entry for ${asset.name}');
    }
    if (!await Sha256Verifier.verify(archiveFile, expected)) {
      await archiveFile.delete();
      throw StateError('SHA-256 mismatch for ${asset.name}');
    }

    final versionDir = paths.binaryVersionDir(release.version);
    if (await versionDir.exists()) await versionDir.delete(recursive: true);
    await ArchiveExtractor.extract(
        archive: archiveFile, destination: versionDir);

    if (platform.os == 'macos') {
      await Process.run('xattr', ['-cr', versionDir.path]);
    }
    await archiveFile.delete();

    final appPath = _findAppPath(versionDir);
    return InstalledVersion(
      version: release.version,
      releaseTag: release.tagName,
      appPath: p.relative(appPath, from: paths.baseDir.path),
      sizeBytes: asset.size,
      sha256: expected,
      installedAt: DateTime.now().toUtc(),
    );
  }

  String _findAppPath(Directory versionDir) {
    if (platform.os == 'macos') {
      // Find the *.app bundle (usually Chromium.app) at the top level.
      for (final e in versionDir.listSync()) {
        if (e is Directory && e.path.endsWith('.app')) return e.path;
      }
    }
    return versionDir.path;
  }
}
