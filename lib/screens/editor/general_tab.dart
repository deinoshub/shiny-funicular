import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';

import '../../widgets/icon_catalog.dart';
import '../../widgets/labeled_field.dart';

class GeneralTab extends StatelessWidget {
  const GeneralTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LabeledField(
          label: 'Name',
          child: TextField(
            controller: TextEditingController(text: draft.name)
              ..selection = TextSelection.collapsed(offset: draft.name.length),
            onChanged: (v) => onChanged(draft.copyWith(name: v)),
          ),
        ),
        LabeledField(
          label: 'Group',
          child: TextField(
            controller: TextEditingController(text: draft.groupName ?? ''),
            onChanged: (v) =>
                onChanged(draft.copyWith(groupName: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Icon',
          child: DropdownButton<String>(
            value: IconCatalog.names.contains(draft.iconName)
                ? draft.iconName
                : IconCatalog.names.first,
            items: [
              for (final n in IconCatalog.names)
                DropdownMenuItem(
                    value: n,
                    child: Row(children: [
                      Icon(IconCatalog.iconFor(n)),
                      const SizedBox(width: 8),
                      Text(n),
                    ])),
            ],
            onChanged: (v) => onChanged(draft.copyWith(iconName: v)),
          ),
        ),
        LabeledField(
          label: 'Persistent',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch(
              value: draft.persistent,
              onChanged: (v) => onChanged(draft.copyWith(persistent: v)),
            ),
          ),
        ),
        LabeledField(
          label: 'Start URL',
          child: TextField(
            controller: TextEditingController(text: draft.startUrl),
            onChanged: (v) => onChanged(draft.copyWith(startUrl: v)),
          ),
        ),
        LabeledField(
          label: 'Notes',
          child: TextField(
            maxLines: 3,
            controller: TextEditingController(text: draft.notes),
            onChanged: (v) => onChanged(draft.copyWith(notes: v)),
          ),
        ),
      ],
    );
  }
}
