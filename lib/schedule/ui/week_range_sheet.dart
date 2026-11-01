import 'package:flutter/material.dart';

import '../../app/controller.dart';
import '../../l10n/l10n.dart';
import '../../ui/design.dart';
import '../../ui/editor_sheet.dart';
import '../../ui/sheet_layout.dart';
import '../model.dart';

Future<({int first, int last})?> showWeekRangeSheet(
  BuildContext context, {
  required int first,
  required int last,
  AppController? controller,
}) => showAppSheet<({int first, int last})>(
  context: context,
  builder: (_) =>
      _WeekRangeSheet(first: first, last: last, controller: controller),
);

Future<void> manageTermWeeks(
  BuildContext context,
  AppController controller,
) async {
  final schedule = controller.timetable.schedule!;
  await showWeekRangeSheet(
    context,
    first: schedule.firstWeek,
    last: schedule.lastWeek,
    controller: controller,
  );
}

class _WeekRangeSheet extends StatefulWidget {
  const _WeekRangeSheet({
    required this.first,
    required this.last,
    this.controller,
  });

  final int first;
  final int last;
  final AppController? controller;

  @override
  State<_WeekRangeSheet> createState() => _WeekRangeSheetState();
}

class _WeekRangeSheetState extends State<_WeekRangeSheet> {
  final _form = GlobalKey<FormState>();
  late final _first = TextEditingController(text: '${widget.first}');
  late final _last = TextEditingController(text: '${widget.last}');
  bool _saving = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  String? _validateWeek(String? value) {
    final week = int.tryParse(value!.trim());
    if (week == null) return context.l10n.weekIntegerRequired;
    if (week == 0) return context.l10n.weekZeroInvalid;
    return null;
  }

  void _step(TextEditingController field, int delta) {
    final current =
        int.tryParse(field.text.trim()) ??
        (field == _first ? widget.first : widget.last);
    final next = weekFromOffset(weekOffset(current) + delta);
    field.value = TextEditingValue(
      text: '$next',
      selection: TextSelection.collapsed(offset: '$next'.length),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final range = (
      first: int.parse(_first.text.trim()),
      last: int.parse(_last.text.trim()),
    );
    final controller = widget.controller;
    if (controller != null) {
      setState(() {
        _saving = true;
      });
      final saved = await controller.timetable.setWeekRange(
        first: range.first,
        last: range.last,
      );
      if (!mounted) return;
      if (!saved) {
        setState(() {
          _saving = false;
        });
        return;
      }
    }
    if (mounted) Navigator.pop(context, range);
  }

  Widget _input(
    String label,
    TextEditingController field, {
    bool last = false,
  }) {
    final firstWeek = int.tryParse(_first.text.trim());
    final lastWeek = int.tryParse(_last.text.trim());
    final canMoveInward =
        firstWeek == null || lastWeek == null || firstWeek < lastWeek;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: label,
          child: TextFormField(
            controller: field,
            enabled: !_saving,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textInputAction: last ? TextInputAction.done : TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              errorMaxLines: 3,
              prefixIcon: IconButton(
                tooltip: context.l10n.decreaseWeek,
                onPressed: _saving || (last && !canMoveInward)
                    ? null
                    : () => _step(field, -1),
                icon: const Icon(Icons.remove_rounded, size: 20),
              ),
              suffixIcon: IconButton(
                tooltip: context.l10n.increaseWeek,
                onPressed: _saving || (!last && !canMoveInward)
                    ? null
                    : () => _step(field, 1),
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
            ),
            validator: (value) {
              final error = _validateWeek(value);
              if (error != null || !last) return error;
              final first = int.tryParse(_first.text.trim());
              return first != null && int.parse(value!.trim()) < first
                  ? context.l10n.weekOrderInvalid
                  : null;
            },
            onFieldSubmitted: last ? (_) => _save() : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final minimumFieldWidth =
        96 + MediaQuery.textScalerOf(context).scale(15) * 4 + 16;
    final first = _input(l10n.weekStart, _first);
    final last = _input(l10n.weekEnd, _last, last: true);

    return EditorSheet(
      title: l10n.weekRangeDialogTitle,
      formKey: _form,
      saving: _saving,
      onSave: _save,
      saveLabel: Text(_saving ? l10n.saving : l10n.confirm),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (constraints.maxWidth >= minimumFieldWidth * 2 + AppSpacing.xl)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: first),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      42,
                      AppSpacing.sm,
                      0,
                    ),
                    child: Text('—'),
                  ),
                  Expanded(child: last),
                ],
              )
            else ...[
              first,
              const SizedBox(height: AppSpacing.lg),
              last,
            ],
          ],
        ),
      ),
    );
  }
}
