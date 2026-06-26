import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('ProxyTestResult has value equality', () {
    const a = ProxyTestResult(
        status: ProxyTestStatus.success, message: 'ok', exitIp: '1.2.3.4');
    const b = ProxyTestResult(
        status: ProxyTestStatus.success, message: 'ok', exitIp: '1.2.3.4');
    const c = ProxyTestResult(
        status: ProxyTestStatus.unreachable, message: 'no');
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a, isNot(equals(c)));
  });

  test('ProxyAuthException carries its message', () {
    expect(const ProxyAuthException('bad creds').message, 'bad creds');
  });

  test('ProxyHttpResponse stores status and body', () {
    const r = ProxyHttpResponse(200, '{}');
    expect(r.statusCode, 200);
    expect(r.body, '{}');
  });
}
