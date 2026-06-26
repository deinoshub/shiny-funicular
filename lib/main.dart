import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:system_theme/system_theme.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemTheme.fallbackColor = const Color(0xFF5E81F4);
  await SystemTheme.accentColor.load();
  await const MacosWindowUtilsConfig().apply();
  runApp(const ProviderScope(child: CloakManagerApp()));
}
