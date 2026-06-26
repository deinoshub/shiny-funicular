import 'package:flutter/cupertino.dart';

/// Maps stored icon-name strings to Cupertino (SF-style) [IconData].
class IconCatalog {
  static const Map<String, IconData> _icons = {
    'person': CupertinoIcons.person,
    'work': CupertinoIcons.briefcase,
    'shopping': CupertinoIcons.cart,
    'shield': CupertinoIcons.shield,
    'globe': CupertinoIcons.globe,
    'star': CupertinoIcons.star,
    'bolt': CupertinoIcons.bolt,
    'bug': CupertinoIcons.ant,
    'rocket': CupertinoIcons.rocket,
    'flask': CupertinoIcons.lab_flask,
  };

  static IconData iconFor(String name) => _icons[name] ?? CupertinoIcons.person;
  static List<String> get names => _icons.keys.toList();
}
