import '../models/profile.dart';
import '../stealth/stealth_args_builder.dart';

/// Builds the full Chromium argument vector for launching a profile.
class LaunchArgsComposer {
  const LaunchArgsComposer._();

  static List<String> compose({
    required Profile profile,
    required String userDataDir,
    required int debugPort,
  }) {
    return [
      ...StealthArgsBuilder.build(profile.stealth),
      '--user-data-dir=$userDataDir',
      '--remote-debugging-port=$debugPort',
      '--remote-debugging-address=127.0.0.1',
      '--no-default-browser-check',
      '--no-first-run',
      '--disable-background-mode',
      '--disable-features=TranslateUI,InfiniteSessionRestore',
      ...profile.customArgs,
      if (profile.startUrl.isNotEmpty) profile.startUrl,
    ];
  }
}
