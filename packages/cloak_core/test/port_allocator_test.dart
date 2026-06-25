import 'dart:io';
import 'package:cloak_core/cloak_core.dart';
import 'package:test/test.dart';

void main() {
  test('allocate returns a port within the range', () async {
    const alloc = PortAllocator(start: 9222, end: 10222);
    final port = await alloc.allocate();
    expect(port, inInclusiveRange(9222, 10222));
  });

  test('allocate skips a port already bound', () async {
    // Occupy the first port in a tiny range, expect the next one.
    final occupied = await ServerSocket.bind('127.0.0.1', 0);
    final p = occupied.port;
    final alloc = PortAllocator(start: p, end: p + 1);
    final got = await alloc.allocate();
    expect(got, p + 1);
    await occupied.close();
  });

  test('allocate throws when no port is free', () async {
    final occupied = await ServerSocket.bind('127.0.0.1', 0);
    final p = occupied.port;
    final alloc = PortAllocator(start: p, end: p);
    expect(alloc.allocate(), throwsStateError);
    await occupied.close();
  });
}
