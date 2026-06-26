import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.running});
  final bool running;

  @override
  Widget build(BuildContext context) => Icon(
        CupertinoIcons.circle_fill,
        size: 10,
        color: running ? MacosColors.systemGreenColor : MacosColors.systemGrayColor,
      );
}
