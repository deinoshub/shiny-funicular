import 'package:cloakmanager/data/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('can insert and read back a profile row', () async {
    final db = AppDatabase.memory();
    await db.into(db.profiles).insert(ProfilesCompanion.insert(
          id: 'p1',
          name: 'Work',
          createdAt: 100.0,
          updatedAt: 100.0,
          stealthJson: '{}',
        ));
    final rows = await db.select(db.profiles).get();
    expect(rows.single.name, 'Work');
    expect(rows.single.persistent, isTrue);
    await db.close();
  });
}
