/// Parsed `SHA256SUMS` file: a map of filename → lowercase hex digest.
class Sha256Sums {
  Sha256Sums(this._byName);

  final Map<String, String> _byName;

  factory Sha256Sums.parse(String content) {
    final map = <String, String>{};
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final hash = parts.first.toLowerCase();
      var name = parts.sublist(1).join(' ');
      if (name.startsWith('*')) name = name.substring(1);
      map[name] = hash;
    }
    return Sha256Sums(map);
  }

  String? hashFor(String filename) => _byName[filename];
}
