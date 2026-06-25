import 'package:flutter/material.dart';

/// A text field that owns a persistent [TextEditingController], created once
/// from [initialValue]. Because the controller is not recreated on every
/// parent rebuild, the caret no longer jumps to the end while typing.
///
/// To reset the field to a new value (e.g. switching profiles), give the
/// surrounding widget a new key so this State is recreated.
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
    return TextField(
      controller: _controller,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(hintText: widget.hintText),
      onChanged: widget.onChanged,
    );
  }
}
