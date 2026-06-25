import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('allocate returns a port within the range (real bind)', () async {
    const alloc = PortAllocator(start: 9222, end: 10222);
    final port = await alloc.allocate();
    expect(port, inInclusiveRange(9222, 10222));
  });

  test('allocate skips ports the probe reports busy', () async {
    // Only the second port in the range is free.
    final alloc =
        PortAllocator(start: 100, end: 101, probe: (p) async => p == 101);
    expect(await alloc.allocate(), 101);
  });

  test('allocate throws when the probe reports all busy', () async {
    final alloc = PortAllocator(start: 100, end: 100, probe: (p) async => false);
    expect(alloc.allocate(), throwsStateError);
  });
}
