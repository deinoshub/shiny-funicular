import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';

import '../../widgets/draft_text_field.dart';
import '../../widgets/labeled_field.dart';

class StealthTab extends StatelessWidget {
  const StealthTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  StealthConfig get s => draft.stealth;
  void _set(StealthConfig next) => onChanged(draft.copyWith(stealth: next));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(context, 'Identity'),
        LabeledField(
          label: 'Fingerprint seed',
          child: DraftTextField(
            initialValue: s.fingerprintSeed ?? '',
            hintText: 'blank = random each launch',
            onChanged: (v) =>
                _set(s.copyWith(fingerprintSeed: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Fingerprint noise',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch(
              value: s.noiseEnabled,
              onChanged: (v) => _set(s.copyWith(noiseEnabled: v)),
            ),
          ),
        ),
        _section(context, 'Platform'),
        LabeledField(
          label: 'Platform',
          child: DropdownButton<SpoofPlatform>(
            value: s.platform,
            items: [
              for (final pf in SpoofPlatform.values)
                DropdownMenuItem(value: pf, child: Text(pf.name)),
            ],
            onChanged: (v) => _set(s.copyWith(platform: v)),
          ),
        ),
        _section(context, 'Brand'),
        LabeledField(
          label: 'Brand',
          child: DropdownButton<BrowserBrand>(
            value: s.brand,
            items: [
              for (final b in BrowserBrand.values)
                DropdownMenuItem(value: b, child: Text(b.name)),
            ],
            onChanged: (v) => _set(s.copyWith(brand: v)),
          ),
        ),
        LabeledField(
          label: 'Brand version',
          child: DraftTextField(
            initialValue: s.brandVersion ?? '',
            hintText: s.brand.defaultVersion,
            onChanged: (v) =>
                _set(s.copyWith(brandVersion: v.isEmpty ? null : v)),
          ),
        ),
        _section(context, 'Hardware'),
        _intField(context, 'CPU cores', s.hardwareConcurrency,
            (n) => _set(s.copyWith(hardwareConcurrency: n))),
        _intField(context, 'Device memory (GB)', s.deviceMemoryGB,
            (n) => _set(s.copyWith(deviceMemoryGB: n))),
        _intField(context, 'Screen width', s.screenWidth,
            (n) => _set(s.copyWith(screenWidth: n))),
        _intField(context, 'Screen height', s.screenHeight,
            (n) => _set(s.copyWith(screenHeight: n))),
        _section(context, 'Locale'),
        _strField(context, 'Timezone', s.timezone,
            (v) => _set(s.copyWith(timezone: v)), hint: 'America/New_York'),
        _strField(context, 'Locale', s.locale,
            (v) => _set(s.copyWith(locale: v)), hint: 'en-US'),
        _section(context, 'GPU'),
        _strField(context, 'GPU vendor', s.gpuVendor,
            (v) => _set(s.copyWith(gpuVendor: v))),
        _strField(context, 'GPU renderer', s.gpuRenderer,
            (v) => _set(s.copyWith(gpuRenderer: v))),
        _section(context, 'Advanced'),
        _intField(context, 'Storage quota (MB)', s.storageQuotaMB,
            (n) => _set(s.copyWith(storageQuotaMB: n))),
        LabeledField(
          label: 'WebRTC IP policy',
          child: DropdownButton<WebRtcIpPolicy>(
            value: s.webrtcIpPolicy,
            items: [
              for (final w in WebRtcIpPolicy.values)
                DropdownMenuItem(value: w, child: Text(w.name)),
            ],
            onChanged: (v) => _set(s.copyWith(webrtcIpPolicy: v)),
          ),
        ),
        if (s.webrtcIpPolicy == WebRtcIpPolicy.spoofExplicit)
          _strField(context, 'Explicit WebRTC IP', s.explicitWebRtcIp,
              (v) => _set(s.copyWith(explicitWebRtcIp: v))),
      ],
    );
  }

  Widget _section(BuildContext c, String title) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(title, style: Theme.of(c).textTheme.titleMedium),
      );

  Widget _strField(BuildContext c, String label, String? value,
          ValueChanged<String?> onChanged, {String? hint}) =>
      LabeledField(
        label: label,
        child: DraftTextField(
          initialValue: value ?? '',
          hintText: hint,
          onChanged: (v) => onChanged(v.isEmpty ? null : v),
        ),
      );

  Widget _intField(BuildContext c, String label, int? value,
          ValueChanged<int?> onChanged) =>
      LabeledField(
        label: label,
        child: DraftTextField(
          initialValue: value?.toString() ?? '',
          keyboardType: TextInputType.number,
          onChanged: (v) => onChanged(v.isEmpty ? null : int.tryParse(v)),
        ),
      );
}
