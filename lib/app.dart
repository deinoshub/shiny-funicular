import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import 'screens/home/home_shell.dart';
import 'theme/app_theme.dart';

class CloakManagerApp extends StatelessWidget {
  const CloakManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MacosApp(
      title: 'CloakManager',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}
