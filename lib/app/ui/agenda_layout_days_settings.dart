import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../agenda/model.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../settings_controller.dart';

class AgendaLayoutDaysSettingsTile extends StatelessWidget {
  const AgendaLayoutDaysSettingsTile({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: settings.agendaLayoutDays,
    builder: (context, days, _) => ListTile(
      key: const ValueKey('agenda-layout-days-settings'),
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: const Icon(Icons.view_week_outlined),
      title: Text(context.l10n.settingsAgendaLayoutDays),
      subtitle: Text(context.l10n.agendaTailDaysValue(days)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AgendaLayoutDaysScreen(settings: settings),
        ),
      ),
    ),
  );
}

class AgendaLayoutDaysScreen extends StatefulWidget {
  const AgendaLayoutDaysScreen({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  State<AgendaLayoutDaysScreen> createState() => _AgendaLayoutDaysScreenState();
}

class _AgendaLayoutDaysScreenState extends State<AgendaLayoutDaysScreen> {
  late final _days = TextEditingController(
    text: widget.settings.agendaLayoutDays.value.toString(),
  );
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    widget.settings.agendaLayoutDays.addListener(_syncValue);
  }

  void _syncValue() {
    if (!mounted) return;
    setState(() {
      _days.text = widget.settings.agendaLayoutDays.value.toString();
      _invalid = false;
    });
  }

  Future<void> _saveText(String text) async {
    final value = int.tryParse(text);
    if (value == null ||
        value < AgendaEntry.minTailDays ||
        value > AgendaEntry.maxTailDays) {
      setState(() => _invalid = true);
      return;
    }
    await widget.settings.setAgendaLayoutDays(value);
    _syncValue();
  }

  @override
  void didUpdateWidget(covariant AgendaLayoutDaysScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      oldWidget.settings.agendaLayoutDays.removeListener(_syncValue);
      widget.settings.agendaLayoutDays.addListener(_syncValue);
      _syncValue();
    }
  }

  @override
  void dispose() {
    widget.settings.agendaLayoutDays.removeListener(_syncValue);
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppRoutePage(
    title: context.l10n.settingsAgendaLayoutDays,
    child: ValueListenableBuilder(
      valueListenable: widget.settings.agendaLayoutDays,
      builder: (context, days, _) {
        final l10n = context.l10n;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(l10n.agendaLayoutDaysDescription),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('agenda-layout-days-input'),
              controller: _days,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.settingsAgendaLayoutDays,
                suffixText: l10n.agendaLayoutDaysUnit,
                helperText: l10n.agendaLayoutDaysRange,
                errorText: _invalid ? l10n.agendaLayoutDaysRange : null,
              ),
              onFieldSubmitted: _saveText,
            ),
            const SizedBox(height: 12),
            Semantics(
              label: l10n.settingsAgendaLayoutDays,
              child: Slider(
                key: const ValueKey('agenda-layout-days-slider'),
                min: AgendaEntry.minTailDays.toDouble(),
                max: AgendaEntry.maxTailDays.toDouble(),
                divisions: AgendaEntry.maxTailDays - AgendaEntry.minTailDays,
                value: days.toDouble(),
                label: l10n.agendaTailDaysValue(days),
                semanticFormatterCallback: (value) =>
                    l10n.agendaTailDaysValue(value.round()),
                onChanged: (value) =>
                    widget.settings.setAgendaLayoutDays(value.round()),
              ),
            ),
            Text(
              l10n.agendaTailDaysValue(days),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    ),
  );
}
