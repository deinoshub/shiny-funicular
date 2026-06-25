import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/data/database.dart';
import 'package:cloakmanager/data/profile_dao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProfileDao dao;
  setUp(() {
    db = AppDatabase.memory();
    dao = ProfileDao(db);
  });
  tearDown(() => db.close());

  Profile sample(String id) => Profile(
        id: id,
        name: 'Work',
        colorHex: '#5E81F4',
        iconName: 'person',
        createdAt: DateTime.utc(2026, 6, 25, 12),
        updatedAt: DateTime.utc(2026, 6, 25, 12),
        stealth: StealthConfig(
          fingerprintSeed: 's',
          proxy: ProxyConfig.disabled(),
        ),
        customArgs: const ['--mute-audio'],
        customEnv: const {'TZ': 'UTC'},
        tags: const ['work'],
      );

  test('upsert then all() round-trips including stealth + lists', () async {
    await dao.upsert(sample('p1'));
    final all = await dao.all();
    expect(all, hasLength(1));
    expect(all.single.stealth.fingerprintSeed, 's');
    expect(all.single.customArgs, ['--mute-audio']);
    expect(all.single.customEnv, {'TZ': 'UTC'});
    expect(all.single.tags, ['work']);
  });

  test('upsert updates an existing row', () async {
    await dao.upsert(sample('p1'));
    await dao.upsert(sample('p1'));
    expect(await dao.all(), hasLength(1));
  });

  test('delete removes the row', () async {
    await dao.upsert(sample('p1'));
    await dao.delete('p1');
    expect(await dao.all(), isEmpty);
  });

  test('touchLastLaunched sets the timestamp', () async {
    await dao.upsert(sample('p1'));
    await dao.touchLastLaunched('p1', DateTime.utc(2026, 6, 26));
    final p = (await dao.all()).single;
    expect(p.lastLaunchedAt, DateTime.utc(2026, 6, 26));
  });
}
