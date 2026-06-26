import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../widgets/draft_text_field.dart';

/// Renders the exact launch argv (with placeholder dir/port) for the draft.
String computedArgsPreview(Profile draft) => LaunchArgsComposer.compose(
      profile: draft,
      userDataDir: '<profiles>/${draft.id}',
      debugPort: 9222,
    ).join('\n');

class AdvancedTab extends StatelessWidget {
  const AdvancedTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Custom Chromium args (one per line)',
            style: theme.typography.headline),
        const SizedBox(height: 6),
        DraftTextField(
          maxLines: 4,
          initialValue: draft.customArgs.join('\n'),
          onChanged: (v) => onChanged(draft.copyWith(
            customArgs: v
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(),
          )),
        ),
        const SizedBox(height: 16),
        Text('Environment variables (KEY=VALUE per line)',
            style: theme.typography.headline),
        const SizedBox(height: 6),
        DraftTextField(
          maxLines: 3,
          initialValue:
              draft.customEnv.entries.map((e) => '${e.key}=${e.value}').join('\n'),
          onChanged: (v) => onChanged(draft.copyWith(customEnv: _parseEnv(v))),
        ),
        const SizedBox(height: 16),
        Text('Computed arguments', style: theme.typography.headline),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.canvasColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: MacosColors.systemGrayColor.withValues(alpha: 0.3)),
          ),
          child: SelectableText(
            computedArgsPreview(draft),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  static Map<String, String> _parseEnv(String text) {
    final map = <String, String>{};
    for (final line in text.split('\n')) {
      final idx = line.indexOf('=');
      if (idx <= 0) continue;
      map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
    }
    return map;
  }
}
