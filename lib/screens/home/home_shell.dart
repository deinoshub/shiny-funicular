import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';
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
      loading: () => const Center(child: ProgressCircle()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (s) => switch (s) {
        Installed() => const HomeScreen(),
        _ => const OnboardingScreen(),
      },
    );
  }
}
