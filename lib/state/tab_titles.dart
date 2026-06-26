import 'dart:async';

import 'package:cloak_core/cloak_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'selection.dart';

const _pollInterval = Duration(seconds: 3);

/// Polls each running profile's CDP `/json` endpoint and exposes a map of
/// profile id -> active tab label (title, or URL host as a fallback).
/// Auto-disposes when nothing watches it, which stops the polling loop.
final tabTitlesProvider =
    StreamProvider.autoDispose<Map<String, String>>((ref) async* {
  final running = ref.watch(runningProfilesProvider).valueOrNull ?? const <String>{};
  if (running.isEmpty) {
    yield const {};
    return;
  }

  final registry = ref.watch(processRegistryProvider);
  final discovery = CdpDiscovery();
  ref.onDispose(discovery.close);

  final labels = <String, String>{};

  Future<void> poll() async {
    for (final id in running) {
      final httpUrl = registry.byProfile(id)?.cdpHttpUrl;
      if (httpUrl == null) continue;
      try {
        final label = await discovery.activePageLabel(httpUrl);
        if (label != null) labels[id] = label;
      } catch (_) {
        // Keep the previous label on transient CDP/HTTP errors.
      }
    }
    labels.removeWhere((id, _) => !running.contains(id));
  }

  await poll();
  yield Map.unmodifiable(labels);

  await for (final _ in Stream<void>.periodic(_pollInterval)) {
    await poll();
    yield Map.unmodifiable(labels);
  }
});
