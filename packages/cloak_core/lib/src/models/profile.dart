import 'stealth_config.dart';

/// A managed CloakBrowser profile. Mirrors the `profiles` table.
class Profile {
  const Profile({
    required this.id,
    required this.name,
    this.notes = '',
    required this.colorHex,
    required this.iconName,
    this.groupName,
    required this.createdAt,
    required this.updatedAt,
    this.lastLaunchedAt,
    required this.stealth,
    this.persistent = true,
    this.startUrl = 'about:blank',
    this.customArgs = const [],
    this.customEnv = const {},
    this.tags = const [],
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String notes;
  final String colorHex;
  final String iconName;
  final String? groupName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLaunchedAt;
  final StealthConfig stealth;
  final bool persistent;
  final String startUrl;
  final List<String> customArgs;
  final Map<String, String> customEnv;
  final List<String> tags;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
        'colorHex': colorHex,
        'iconName': iconName,
        'groupName': groupName,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'lastLaunchedAt': lastLaunchedAt?.toUtc().toIso8601String(),
        'stealth': stealth.toJson(),
        'persistent': persistent,
        'startUrl': startUrl,
        'customArgs': customArgs,
        'customEnv': customEnv,
        'tags': tags,
        'sortOrder': sortOrder,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        notes: (json['notes'] as String?) ?? '',
        colorHex: json['colorHex'] as String,
        iconName: json['iconName'] as String,
        groupName: json['groupName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        lastLaunchedAt: json['lastLaunchedAt'] == null
            ? null
            : DateTime.parse(json['lastLaunchedAt'] as String),
        stealth:
            StealthConfig.fromJson(json['stealth'] as Map<String, dynamic>),
        persistent: (json['persistent'] as bool?) ?? true,
        startUrl: (json['startUrl'] as String?) ?? 'about:blank',
        customArgs:
            (json['customArgs'] as List<dynamic>? ?? []).cast<String>(),
        customEnv: (json['customEnv'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v as String)),
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
        sortOrder: (json['sortOrder'] as int?) ?? 0,
      );
}
