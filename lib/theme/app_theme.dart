import 'package:macos_ui/macos_ui.dart';
import 'package:system_theme/system_theme.dart';

MacosThemeData buildLightTheme() => MacosThemeData.light().copyWith(
      primaryColor: SystemTheme.accentColor.accent,
    );

MacosThemeData buildDarkTheme() => MacosThemeData.dark().copyWith(
      primaryColor: SystemTheme.accentColor.accent,
    );
