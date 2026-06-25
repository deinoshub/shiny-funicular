import '../models/profile.dart';
import '../stealth/stealth_args_builder.dart';

/// Builds the full Chromium argument vector for launching a profile.
class LaunchArgsComposer {
  const LaunchArgsComposer._();

  static List<String> compose({
    required Profile profile,
    required String userDataDir,
    required int debugPort,
    String? startUrlOverride,
  }) {
    // When override is null, fall back to the profile's URL.
    // When override is an empty string, suppress the URL entirely
    // (used by BrowserLauncher when proxy auth must be wired up first).
    final url = startUrlOverride ?? profile.startUrl;
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
      if (url.isNotEmpty) url,
    ];
  }
}
