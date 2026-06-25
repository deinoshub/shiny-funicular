import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/data/database.dart';
import 'package:cloakmanager/data/profile_dao.dart';
import 'package:cloakmanager/screens/editor/editor_screen.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Profile _profile(String id, String name) => Profile(
      id: id,
      name: name,
      colorHex: '#fff',
      iconName: 'person',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      stealth: StealthConfig.defaults(),
    );

void main() {
  testWidgets('delete button removes the profile after confirmation',
      (tester) async {
    final db = AppDatabase.memory();
    final dao = ProfileDao(db);
    addTearDown(db.close);
    await dao.upsert(_profile('p1', 'Alpha'));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        profileDaoProvider.overrideWithValue(dao),
      ],
      child: const MaterialApp(
        home: Scaffold(body: EditorScreen(profileId: 'p1')),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete profile?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await dao.all(), isEmpty);
  });
}
