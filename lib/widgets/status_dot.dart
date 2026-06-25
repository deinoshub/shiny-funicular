import 'package:flutter/material.dart';

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.running});
  final bool running;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.circle,
        size: 10,
        color: running ? Colors.green : Colors.grey,
      );
}
