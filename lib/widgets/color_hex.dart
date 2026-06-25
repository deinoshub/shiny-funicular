import 'package:flutter/material.dart';

const _fallback = Color(0xFF5E81F4);

/// Parses `#RRGGBB` / `#RRGGBBAA`; returns a fallback on bad input.
Color colorFromHex(String hex) {
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return _fallback;
  final value = int.tryParse(h, radix: 16);
  return value == null ? _fallback : Color(value);
}
