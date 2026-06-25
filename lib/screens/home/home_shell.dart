import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/binary_state.dart';
import '../onboarding/onboarding_screen.dart';
import 'home_screen.dart';

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
        Installed() => const HomeScreen(),
        _ => const OnboardingScreen(),
      },
    );
  }
}
