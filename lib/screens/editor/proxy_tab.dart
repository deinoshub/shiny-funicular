import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/material.dart';

import '../../widgets/labeled_field.dart';

class ProxyTab extends StatelessWidget {
  const ProxyTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  ProxyConfig get px => draft.stealth.proxy;
  void _set(ProxyConfig next) =>
      onChanged(draft.copyWith(stealth: draft.stealth.copyWith(proxy: next)));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LabeledField(
          label: 'Enabled',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch(
                value: px.enabled, onChanged: (v) => _set(px.copyWith(enabled: v))),
          ),
        ),
        LabeledField(
          label: 'Type',
          child: DropdownButton<ProxyType>(
            value: px.type,
            items: [
              for (final t in ProxyType.values)
                DropdownMenuItem(value: t, child: Text(t.name)),
            ],
            onChanged: (v) => _set(px.copyWith(type: v)),
          ),
        ),
        LabeledField(
          label: 'Host',
          child: TextField(
            controller: TextEditingController(text: px.host),
            onChanged: (v) => _set(px.copyWith(host: v)),
          ),
        ),
        LabeledField(
          label: 'Port',
          child: TextField(
            controller: TextEditingController(text: px.port == 0 ? '' : '${px.port}'),
            keyboardType: TextInputType.number,
            onChanged: (v) => _set(px.copyWith(port: int.tryParse(v) ?? 0)),
          ),
        ),
        LabeledField(
          label: 'Username',
          child: TextField(
            controller: TextEditingController(text: px.username ?? ''),
            onChanged: (v) => _set(px.copyWith(username: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Password',
          child: TextField(
            obscureText: true,
            controller: TextEditingController(text: px.password ?? ''),
            onChanged: (v) => _set(px.copyWith(password: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Bypass list',
          child: TextField(
            controller: TextEditingController(text: px.bypassList),
            decoration: const InputDecoration(hintText: 'localhost,127.0.0.1'),
            onChanged: (v) => _set(px.copyWith(bypassList: v)),
          ),
        ),
        LabeledField(
          label: 'GeoIP (timezone/locale from exit IP)',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Switch(
                value: px.geoipEnabled,
                onChanged: (v) => _set(px.copyWith(geoipEnabled: v))),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('Test Connection'),
            onPressed: px.enabled ? () => _test(context) : null,
          ),
        ),
      ],
    );
  }

  void _test(BuildContext context) {
    // Best-effort feedback: show the composed server string so the user can
    // verify their inputs. A real through-proxy reachability check is a
    // post-M5 follow-up.
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proxy configured: ${px.serverString}')));
  }
}
