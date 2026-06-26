import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

/// A text field that owns a persistent [TextEditingController], created once
/// from [initialValue], so the caret does not jump while typing. Give the
/// surrounding widget a new key to reset the field (e.g. switching profiles).
class DraftTextField extends StatefulWidget {
  const DraftTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;
  final String? hintText;
  final bool obscureText;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  State<DraftTextField> createState() => _DraftTextFieldState();
}

class _DraftTextFieldState extends State<DraftTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MacosTextField(
      controller: _controller,
      obscureText: widget.obscureText,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      keyboardType: widget.keyboardType,
      placeholder: widget.hintText,
      onChanged: widget.onChanged,
    );
  }
}
