import 'package:cloak_core/cloak_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../../state/providers.dart';
import '../../widgets/draft_text_field.dart';
import '../../widgets/labeled_field.dart';

class ProxyTab extends ConsumerStatefulWidget {
  const ProxyTab({super.key, required this.draft, required this.onChanged});
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  @override
  ConsumerState<ProxyTab> createState() => _ProxyTabState();
}

class _ProxyTabState extends ConsumerState<ProxyTab> {
  bool _testing = false;
  ProxyTestResult? _result;

  ProxyConfig get px => widget.draft.stealth.proxy;

  void _set(ProxyConfig next) => widget.onChanged(widget.draft
      .copyWith(stealth: widget.draft.stealth.copyWith(proxy: next)));

  bool get _canTest =>
      px.enabled && px.host.isNotEmpty && px.port > 0 && !_testing;

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    final result = await ref.read(proxyTesterProvider).test(px);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LabeledField(
          label: 'Enabled',
          child: Align(
            alignment: Alignment.centerLeft,
            child: MacosSwitch(
                value: px.enabled,
                onChanged: (v) => _set(px.copyWith(enabled: v))),
          ),
        ),
        LabeledField(
          label: 'Type',
          child: Align(
            alignment: Alignment.centerLeft,
            child: MacosPopupButton<ProxyType>(
              value: px.type,
              onChanged: (v) => _set(px.copyWith(type: v)),
              items: [
                for (final t in ProxyType.values)
                  MacosPopupMenuItem(value: t, child: Text(t.name)),
              ],
            ),
          ),
        ),
        LabeledField(
          label: 'Host',
          child: DraftTextField(
            initialValue: px.host,
            onChanged: (v) => _set(px.copyWith(host: v)),
          ),
        ),
        LabeledField(
          label: 'Port',
          child: DraftTextField(
            initialValue: px.port == 0 ? '' : '${px.port}',
            keyboardType: TextInputType.number,
            onChanged: (v) => _set(px.copyWith(port: int.tryParse(v) ?? 0)),
          ),
        ),
        LabeledField(
          label: 'Username',
          child: DraftTextField(
            initialValue: px.username ?? '',
            onChanged: (v) => _set(px.copyWith(username: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Password',
          child: DraftTextField(
            initialValue: px.password ?? '',
            obscureText: true,
            onChanged: (v) => _set(px.copyWith(password: v.isEmpty ? null : v)),
          ),
        ),
        LabeledField(
          label: 'Bypass list',
          child: DraftTextField(
            initialValue: px.bypassList,
            hintText: 'localhost,127.0.0.1',
            onChanged: (v) => _set(px.copyWith(bypassList: v)),
          ),
        ),
        LabeledField(
          label: 'GeoIP (timezone/locale from exit IP)',
          child: Align(
            alignment: Alignment.centerLeft,
            child: MacosSwitch(
                value: px.geoipEnabled,
                onChanged: (v) => _set(px.copyWith(geoipEnabled: v))),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: PushButton(
            controlSize: ControlSize.large,
            secondary: true,
            onPressed: _canTest ? _test : null,
            child: const Text('Test Connection'),
          ),
        ),
        if (_testing || _result != null) ...[
          const SizedBox(height: 12),
          _ProxyTestPanel(testing: _testing, result: _result),
        ],
      ],
    );
  }
}

class _ProxyTestPanel extends StatelessWidget {
  const _ProxyTestPanel({required this.testing, required this.result});
  final bool testing;
  final ProxyTestResult? result;

  @override
  Widget build(BuildContext context) {
    final typography = MacosTheme.of(context).typography;
    if (testing) {
      return Row(
        children: const [
          SizedBox(width: 16, height: 16, child: ProgressCircle()),
          SizedBox(width: 12),
          Text('Testing…'),
        ],
      );
    }

    if (result == null) return const SizedBox.shrink();
    final r = result!;
    final ok = r.status == ProxyTestStatus.success;
    final color =
        ok ? MacosColors.systemGreenColor : MacosColors.systemRedColor;

    final lines = <String>[];
    if (ok) {
      if (r.latency != null) {
        lines.add('Latency: ${r.latency!.inMilliseconds} ms');
      }
      if (r.exitIp != null) lines.add('Exit IP: ${r.exitIp}');
      final geo = [r.city, r.country]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
      if (geo.isNotEmpty) lines.add('Location: $geo');
      if (r.timezone != null) lines.add('Timezone: ${r.timezone}');
    } else {
      lines.add(r.message);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MacosIcon(
                  ok
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.xmark_circle_fill,
                  color: color,
                  size: 18),
              const SizedBox(width: 8),
              Text(ok ? 'Proxy OK' : 'Proxy test failed',
                  style: typography.headline.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 8),
          for (final l in lines) Text(l),
        ],
      ),
    );
  }
}
