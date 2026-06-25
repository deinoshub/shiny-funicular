import '../platform/platform_info.dart';

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final String downloadUrl;
  final int size;

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
        name: json['name'] as String,
        downloadUrl: json['browser_download_url'] as String,
        size: (json['size'] as num?)?.toInt() ?? 0,
      );
}

class ReleaseInfo {
  const ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.prerelease,
    required this.assets,
  });

  final String tagName;
  final String name;
  final bool prerelease;
  final List<ReleaseAsset> assets;

  bool get isPro =>
      tagName.toLowerCase().contains('pro') ||
      name.toLowerCase().contains('pro');

  /// The version string without the `chromium-v` prefix, e.g. `146.0.7680.177.5`.
  String get version => tagName.replaceFirst(RegExp(r'^chromium-v'), '');

  ReleaseAsset? assetFor(PlatformInfo platform) {
    final wanted = platform.assetName();
    for (final a in assets) {
      if (a.name == wanted) return a;
    }
    return null;
  }

  ReleaseAsset? get sha256SumsAsset {
    for (final a in assets) {
      if (a.name == 'SHA256SUMS') return a;
    }
    return null;
  }

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) => ReleaseInfo(
        tagName: json['tag_name'] as String,
        name: (json['name'] as String?) ?? '',
        prerelease: (json['prerelease'] as bool?) ?? false,
        assets: ((json['assets'] as List<dynamic>?) ?? [])
            .map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static List<ReleaseInfo> listFromJson(List<dynamic> json) =>
      json.map((e) => ReleaseInfo.fromJson(e as Map<String, dynamic>)).toList();
}
