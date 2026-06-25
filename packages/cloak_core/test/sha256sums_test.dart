import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses standard sha256sum lines', () {
    const content = '''
505582aa1bd3971c577f70e0c0000000000000000000000000000000000000000  cloakbrowser-darwin-arm64.tar.gz
4a12bcde0000000000000000000000000000000000000000000000000000aaaa *cloakbrowser-windows-x64.zip
''';
    final sums = Sha256Sums.parse(content);
    expect(sums.hashFor('cloakbrowser-darwin-arm64.tar.gz'),
        '505582aa1bd3971c577f70e0c0000000000000000000000000000000000000000');
    expect(sums.hashFor('cloakbrowser-windows-x64.zip'),
        '4a12bcde0000000000000000000000000000000000000000000000000000aaaa');
    expect(sums.hashFor('missing.tar.gz'), isNull);
  });

  test('ignores blank lines', () {
    final sums = Sha256Sums.parse('\n\n  \n');
    expect(sums.hashFor('anything'), isNull);
  });
}
