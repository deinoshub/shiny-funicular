import 'package:flutter/material.dart';

/// Maps stored icon-name strings to Material [IconData].
class IconCatalog {
  static const Map<String, IconData> _icons = {
    'person': Icons.person,
    'work': Icons.work,
    'shopping': Icons.shopping_cart,
    'shield': Icons.shield,
    'globe': Icons.public,
    'star': Icons.star,
    'bolt': Icons.bolt,
    'bug': Icons.bug_report,
    'rocket': Icons.rocket_launch,
    'flask': Icons.science,
  };

  static IconData iconFor(String name) => _icons[name] ?? Icons.person;
  static List<String> get names => _icons.keys.toList();
}
