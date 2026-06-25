import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get colorHex => text().withDefault(const Constant('#5E81F4'))();
  TextColumn get iconName => text().withDefault(const Constant('person'))();
  TextColumn get groupName => text().nullable()();
  RealColumn get createdAt => real()();
  RealColumn get updatedAt => real()();
  RealColumn get lastLaunchedAt => real().nullable()();
  TextColumn get stealthJson => text()();
  BoolColumn get persistent => boolean().withDefault(const Constant(true))();
  TextColumn get startUrl =>
      text().withDefault(const Constant('about:blank'))();
  TextColumn get customArgsJson => text().withDefault(const Constant('[]'))();
  TextColumn get customEnvJson => text().withDefault(const Constant('{}'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Profiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
