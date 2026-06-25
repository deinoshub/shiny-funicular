import 'package:cloakmanager/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to a MaterialApp titled CloakManager', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CloakManagerApp()));
    expect(find.byType(CloakManagerApp), findsOneWidget);
  });
}
