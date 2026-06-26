import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:system_theme/system_theme.dart';

import 'app.dart';

Future<void> _configureWindow() async {
  await WindowManipulator.initialize();
  await WindowManipulator.addToolbar();
  await WindowManipulator.setToolbarStyle(
    toolbarStyle: NSWindowToolbarStyle.unified,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemTheme.fallbackColor = const Color(0xFF5E81F4);
  await SystemTheme.accentColor.load();
  await _configureWindow();
  runApp(const ProviderScope(child: CloakManagerApp()));
}
