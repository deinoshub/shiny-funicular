class InstalledVersion {
  const InstalledVersion({
    required this.version,
    required this.releaseTag,
    required this.appPath,
    required this.sizeBytes,
    required this.sha256,
    required this.installedAt,
    this.lastUsedAt,
  });

  final String version;
  final String releaseTag;
  final String appPath; // relative to AppPaths.baseDir
  final int sizeBytes;
  final String sha256;
  final DateTime installedAt;
  final DateTime? lastUsedAt;

  Map<String, dynamic> toJson() => {
        'version': version,
        'releaseTag': releaseTag,
        'appPath': appPath,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'installedAt': installedAt.toUtc().toIso8601String(),
        'lastUsedAt': lastUsedAt?.toUtc().toIso8601String(),
      };

  factory InstalledVersion.fromJson(Map<String, dynamic> json) =>
      InstalledVersion(
        version: json['version'] as String,
        releaseTag: json['releaseTag'] as String,
        appPath: json['appPath'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        sha256: json['sha256'] as String,
        installedAt: DateTime.parse(json['installedAt'] as String),
        lastUsedAt: json['lastUsedAt'] == null
            ? null
            : DateTime.parse(json['lastUsedAt'] as String),
      );
}

class BinaryManifest {
  const BinaryManifest({
    required this.schemaVersion,
    required this.activeVersion,
    required this.versions,
  });

  final int schemaVersion;
  final String? activeVersion;
  final List<InstalledVersion> versions;

  static BinaryManifest empty() =>
      const BinaryManifest(schemaVersion: 2, activeVersion: null, versions: []);

  InstalledVersion? get active {
    for (final v in versions) {
      if (v.version == activeVersion) return v;
    }
    return null;
  }

  BinaryManifest _copy({String? activeVersion, List<InstalledVersion>? versions}) =>
      BinaryManifest(
        schemaVersion: schemaVersion,
        activeVersion: activeVersion ?? this.activeVersion,
        versions: versions ?? this.versions,
      );

  BinaryManifest withVersionAdded(InstalledVersion v) {
    final next = versions.where((e) => e.version != v.version).toList()..add(v);
    return _copy(versions: next);
  }

  BinaryManifest withVersionRemoved(String version) {
    final next = versions.where((e) => e.version != version).toList();
    final active = activeVersion == version ? null : activeVersion;
    return BinaryManifest(
        schemaVersion: schemaVersion, activeVersion: active, versions: next);
  }

  BinaryManifest withActive(String version) => _copy(activeVersion: version);

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'activeVersion': activeVersion,
        'versions': versions.map((v) => v.toJson()).toList(),
      };

  factory BinaryManifest.fromJson(Map<String, dynamic> json) => BinaryManifest(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 2,
        activeVersion: json['activeVersion'] as String?,
        versions: ((json['versions'] as List<dynamic>?) ?? [])
            .map((e) => InstalledVersion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  factory BinaryManifest.fromLegacyBinaryInfo(Map<String, dynamic> legacy) {
    final v = InstalledVersion.fromJson(legacy);
    return BinaryManifest(
        schemaVersion: 2, activeVersion: v.version, versions: [v]);
  }
}
