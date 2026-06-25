import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

final selectedProfileIdProvider = StateProvider<String?>((ref) => null);

final runningProfilesProvider = StreamProvider<Set<String>>((ref) {
  final registry = ref.watch(processRegistryProvider);
  return registry.runningProfileIds;
});
