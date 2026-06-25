import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  RunningProcess proc(String id, int pid) => RunningProcess(
        profileId: id,
        pid: pid,
        debugPort: 9222,
        cdpHttpUrl: 'http://127.0.0.1:9222',
        ephemeral: false,
        userDataDir: '/d/$id',
      );

  test('add/byProfile/isRunning/remove', () {
    final reg = ProcessRegistry();
    expect(reg.isRunning('a'), isFalse);
    reg.add(proc('a', 1));
    expect(reg.isRunning('a'), isTrue);
    expect(reg.byProfile('a')?.pid, 1);
    reg.remove('a');
    expect(reg.isRunning('a'), isFalse);
    reg.dispose();
  });

  test('runningProfileIds stream reflects changes', () async {
    final reg = ProcessRegistry();
    final emissions = <Set<String>>[];
    final sub = reg.runningProfileIds.listen(emissions.add);
    reg.add(proc('a', 1));
    reg.add(proc('b', 2));
    reg.remove('a');
    await Future<void>.delayed(Duration.zero);
    expect(emissions.last, {'b'});
    await sub.cancel();
    reg.dispose();
  });
}
