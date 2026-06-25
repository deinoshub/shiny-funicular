import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/binary_state.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(binaryStateProvider);
    final notifier = ref.read(binaryStateProvider.notifier);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: async.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (state) => switch (state) {
              Downloading(:final fraction, :final received, :final total) =>
                Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Downloading CloakBrowser…'),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: fraction == 0 ? null : fraction),
                  const SizedBox(height: 8),
                  Text('${(fraction * 100).round()}%  '
                      '(${received ~/ 1000000} / ${total ~/ 1000000} MB)'),
                ]),
              Verifying() => const Text('Verifying download…'),
              Extracting() => const Text('Extracting…'),
              Failed(:final message) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Download failed: $message'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: notifier.downloadLatest,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              _ => Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Welcome to CloakManager',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Download the stealth Chromium binary to get started.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: notifier.downloadLatest,
                    child: const Text('Download CloakBrowser'),
                  ),
                ]),
            },
          ),
        ),
      ),
    );
  }
}
