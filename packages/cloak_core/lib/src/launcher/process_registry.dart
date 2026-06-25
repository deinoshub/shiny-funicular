import 'dart:async';
import 'running_process.dart';

/// Tracks running browser processes keyed by profile id.
class ProcessRegistry {
  final Map<String, RunningProcess> _byProfile = {};
  final StreamController<Set<String>> _controller =
      StreamController<Set<String>>.broadcast();

  void add(RunningProcess process) {
    _byProfile[process.profileId] = process;
    _emit();
  }

  RunningProcess? byProfile(String profileId) => _byProfile[profileId];

  List<RunningProcess> get all => List.unmodifiable(_byProfile.values);

  bool isRunning(String profileId) => _byProfile.containsKey(profileId);

  void remove(String profileId) {
    if (_byProfile.remove(profileId) != null) _emit();
  }

  Stream<Set<String>> get runningProfileIds => _controller.stream;

  void _emit() => _controller.add(_byProfile.keys.toSet());

  void dispose() => _controller.close();
}
