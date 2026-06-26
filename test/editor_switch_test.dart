import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/data/database.dart';
import 'package:cloakmanager/data/profile_dao.dart';
import 'package:cloakmanager/screens/editor/editor_screen.dart';
import 'package:cloakmanager/state/providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart';

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
  late AppDatabase db;
  late ProfileDao dao;

  setUp(() async {
    db = AppDatabase.memory();
    dao = ProfileDao(db);
    await dao.upsert(_profile('p1', 'Alpha'));
    await dao.upsert(_profile('p2', 'Beta'));
  });
  tearDown(() => db.close());

  String nameFieldText(WidgetTester tester) => tester
      .widget<MacosTextField>(find.byType(MacosTextField).first)
      .controller!
      .text;

  testWidgets('editor shows a Launch button and resets when profile changes',
      (tester) async {
    var selected = 'p1';
    late StateSetter rebuild;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        profileDaoProvider.overrideWithValue(dao),
      ],
      child: MacosApp(
        home: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return MacosWindow(
            child: EditorScreen(key: ValueKey(selected), profileId: selected),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Launch'), findsOneWidget);
    expect(nameFieldText(tester), 'Alpha');

    rebuild(() => selected = 'p2');
    await tester.pumpAndSettle();
    expect(nameFieldText(tester), 'Beta');
  });
}
