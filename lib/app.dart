import 'package:flutter/material.dart';

import 'screens/home/home_shell.dart';

class CloakManagerApp extends StatelessWidget {
  const CloakManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloakManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E81F4)),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
