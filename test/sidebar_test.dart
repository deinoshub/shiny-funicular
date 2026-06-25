import 'package:cloak_core/cloak_core.dart';
import 'package:cloakmanager/screens/home/sidebar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Profile p(String name, {String? group, List<String> tags = const []}) => Profile(
        id: name,
        name: name,
        colorHex: '#fff',
        iconName: 'person',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        stealth: StealthConfig.defaults(),
        groupName: group,
        tags: tags,
      );

  test('filter matches name case-insensitively', () {
    final list = [p('Work'), p('Shopping'), p('work-2')];
    final got = filterProfiles(list, 'work');
    expect(got.map((e) => e.name), ['Work', 'work-2']);
  });

  test('filter matches tags', () {
    final list = [p('A', tags: ['us-east']), p('B', tags: ['eu'])];
    expect(filterProfiles(list, 'us-east').single.name, 'A');
  });

  test('empty query returns all', () {
    final list = [p('A'), p('B')];
    expect(filterProfiles(list, '   '), hasLength(2));
  });
}
