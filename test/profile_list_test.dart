import 'package:cloakmanager/data/database.dart';
import 'package:cloakmanager/data/profile_dao.dart';
import 'package:cloakmanager/state/profile_list.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      profileDaoProvider.overrideWithValue(ProfileDao(db)),
    ]);
    addTearDown(() {
      container.dispose();
      db.close();
    });
  });

  test('create adds a profile and refreshes the list', () async {
    final controller = container.read(profileListProvider.notifier);
    await container.read(profileListProvider.future); // initial load (empty)
    final created = await controller.create('My Profile');
    expect(created.name, 'My Profile');
    final list = await container.read(profileListProvider.future);
    expect(list.map((p) => p.name), contains('My Profile'));
  });

  test('remove deletes a profile', () async {
    final controller = container.read(profileListProvider.notifier);
    final p = await controller.create('Temp');
    await controller.remove(p.id);
    final list = await container.read(profileListProvider.future);
    expect(list.where((e) => e.id == p.id), isEmpty);
  });
}
