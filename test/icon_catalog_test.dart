import 'package:cloakmanager/widgets/color_hex.dart';
import 'package:cloakmanager/widgets/icon_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iconFor returns a fallback for unknown names', () {
    expect(IconCatalog.iconFor('definitely-not-an-icon'), Icons.person);
    expect(IconCatalog.names, contains('person'));
  });

  test('colorFromHex parses #RRGGBB', () {
    expect(colorFromHex('#5E81F4'), const Color(0xFF5E81F4));
    expect(colorFromHex('bad'), const Color(0xFF5E81F4)); // fallback
  });
}
