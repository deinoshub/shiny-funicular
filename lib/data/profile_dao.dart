import 'dart:convert';

import 'package:cloak_core/cloak_core.dart';
import 'package:drift/drift.dart';

import 'database.dart';

class ProfileDao {
  ProfileDao(this.db);
  final AppDatabase db;

  Future<List<Profile>> all() async {
    final rows = await (db.select(db.profiles)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    return rows.map(_toModel).toList();
  }

  Future<void> upsert(Profile p) =>
      db.into(db.profiles).insertOnConflictUpdate(_toRow(p));

  Future<void> delete(String id) =>
      (db.delete(db.profiles)..where((t) => t.id.equals(id))).go();

  Future<void> touchLastLaunched(String id, DateTime when) =>
      (db.update(db.profiles)..where((t) => t.id.equals(id))).write(
        ProfilesCompanion(lastLaunchedAt: Value(_toEpoch(when))),
      );

  // --- mapping helpers ---

  static double _toEpoch(DateTime d) => d.toUtc().millisecondsSinceEpoch / 1000.0;
  static DateTime _fromEpoch(double s) =>
      DateTime.fromMillisecondsSinceEpoch((s * 1000).round(), isUtc: true);

  Profile _toModel(ProfileRow r) => Profile(
        id: r.id,
        name: r.name,
        notes: r.notes,
        colorHex: r.colorHex,
        iconName: r.iconName,
        groupName: r.groupName,
        createdAt: _fromEpoch(r.createdAt),
        updatedAt: _fromEpoch(r.updatedAt),
        lastLaunchedAt:
            r.lastLaunchedAt == null ? null : _fromEpoch(r.lastLaunchedAt!),
        stealth: StealthConfig.fromJson(
            jsonDecode(r.stealthJson) as Map<String, dynamic>),
        persistent: r.persistent,
        startUrl: r.startUrl,
        customArgs:
            (jsonDecode(r.customArgsJson) as List<dynamic>).cast<String>(),
        customEnv: (jsonDecode(r.customEnvJson) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String)),
        tags: (jsonDecode(r.tagsJson) as List<dynamic>).cast<String>(),
        sortOrder: r.sortOrder,
      );

  ProfilesCompanion _toRow(Profile p) => ProfilesCompanion(
        id: Value(p.id),
        name: Value(p.name),
        notes: Value(p.notes),
        colorHex: Value(p.colorHex),
        iconName: Value(p.iconName),
        groupName: Value(p.groupName),
        createdAt: Value(_toEpoch(p.createdAt)),
        updatedAt: Value(_toEpoch(p.updatedAt)),
        lastLaunchedAt: Value(
            p.lastLaunchedAt == null ? null : _toEpoch(p.lastLaunchedAt!)),
        stealthJson: Value(jsonEncode(p.stealth.toJson())),
        persistent: Value(p.persistent),
        startUrl: Value(p.startUrl),
        customArgsJson: Value(jsonEncode(p.customArgs)),
        customEnvJson: Value(jsonEncode(p.customEnv)),
        tagsJson: Value(jsonEncode(p.tags)),
        sortOrder: Value(p.sortOrder),
      );
}
