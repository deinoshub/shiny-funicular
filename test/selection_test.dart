import 'package:cloakmanager/state/selection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected id defaults null and can be set', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(selectedProfileIdProvider), isNull);
    c.read(selectedProfileIdProvider.notifier).state = 'p1';
    expect(c.read(selectedProfileIdProvider), 'p1');
  });
}
