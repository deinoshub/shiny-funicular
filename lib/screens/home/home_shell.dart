import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/binary_state.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(binaryStateProvider);
    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (s) => switch (s) {
        Installed() => const _HomePlaceholder(),
        _ => const _NotInstalledView(),
      },
    );
  }
}

class _NotInstalledView extends ConsumerWidget {
  const _NotInstalledView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('not-installed'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('CloakBrowser is not installed yet.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.read(binaryStateProvider.notifier).downloadLatest(),
              child: const Text('Download CloakBrowser'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(key: Key('home'), body: Center(child: Text('CloakManager')));
}
