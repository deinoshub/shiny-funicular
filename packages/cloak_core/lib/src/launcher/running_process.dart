/// A live browser process launched for a profile.
class RunningProcess {
  const RunningProcess({
    required this.profileId,
    required this.pid,
    required this.debugPort,
    required this.cdpHttpUrl,
    required this.ephemeral,
    required this.userDataDir,
  });

  final String profileId;
  final int pid;
  final int debugPort;
  final String cdpHttpUrl; // e.g. http://127.0.0.1:9333
  final bool ephemeral;
  final String userDataDir;
}
