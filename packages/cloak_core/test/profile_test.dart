import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  Profile sample() => Profile(
        id: 'abc-123',
        name: 'Work',
        colorHex: '#5E81F4',
        iconName: 'person',
        createdAt: DateTime.utc(2026, 6, 25, 12),
        updatedAt: DateTime.utc(2026, 6, 25, 12),
        stealth: StealthConfig.defaults(),
        startUrl: 'https://example.com',
        customArgs: const ['--mute-audio'],
        customEnv: const {'TZ': 'UTC'},
        tags: const ['work', 'us'],
        sortOrder: 3,
      );

  test('JSON round-trips including nested stealth', () {
    final p = sample();
    final decoded = Profile.fromJson(p.toJson());
    expect(decoded.toJson(), equals(p.toJson()));
  });

  test('dates serialize as ISO-8601', () {
    final json = sample().toJson();
    expect(json['createdAt'], '2026-06-25T12:00:00.000Z');
    expect(json['lastLaunchedAt'], isNull);
  });
}
