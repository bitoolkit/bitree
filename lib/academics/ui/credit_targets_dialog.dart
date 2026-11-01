import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/design.dart';
import '../controller.dart';

Future<void> editCreditTargets(
  BuildContext context,
  AcademicController controller,
) => showAppDialog<void>(
  context: context,
  builder: (_) => _CreditTargetsDialog(controller: controller),
);

class _CreditTargetsDialog extends StatefulWidget {
  const _CreditTargetsDialog({required this.controller});

  final AcademicController controller;

  @override
  State<_CreditTargetsDialog> createState() => _CreditTargetsDialogState();
}

class _CreditTargetsDialogState extends State<_CreditTargetsDialog> {
  final _form = GlobalKey<FormState>();
  late final _total = TextEditingController(
    text: widget.controller.record.targetCredits?.toString() ?? '',
  );
  late final _targets = <String, TextEditingController>{
    for (final category in {
      ...widget.controller.record.categoryTargets.keys,
      for (final grade in widget.controller.record.grades)
        widget.controller.record.categoryOf(grade),
    })
      category: TextEditingController(
        text:
            widget.controller.record.categoryTargets[category]?.toString() ??
            '',
      ),
  };
  final _newCategory = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _total.dispose();
    _newCategory.dispose();
    for (final input in _targets.values) {
      input.dispose();
    }
    super.dispose();
  }

  String? _validateCredits(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = double.tryParse(text);
    return value == null || !value.isFinite || value < 0
        ? context.l10n.enterNonNegativeCredits
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final record = widget.controller.record;
    final saved = await widget.controller.save(
      record.withCreditTargets(
        total: _total.text.trim().isEmpty ? null : double.parse(_total.text),
        categories: {
          for (final entry in _targets.entries)
            if (entry.value.text.trim().isNotEmpty)
              entry.key: double.parse(entry.value.text),
        },
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.reviewCreditTargets),
        content: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _total,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.totalCreditTarget,
                  helperText: l10n.leaveBlankSchoolRequirement,
                ),
                validator: _validateCredits,
              ),
              for (final entry in _targets.entries) ...[
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: entry.value,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.categoryCreditTarget(entry.key),
                    helperText: l10n.leaveBlankCancelTarget,
                  ),
                  validator: _validateCredits,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategory,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: l10n.addCourseCategory,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.addCategory,
                    onPressed: _saving
                        ? null
                        : () {
                            final category = _newCategory.text.trim();
                            if (category.isEmpty) return;
                            setState(() {
                              _targets.putIfAbsent(
                                category,
                                TextEditingController.new,
                              );
                              _newCategory.clear();
                            });
                          },
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.saving : l10n.save),
          ),
        ],
      ),
    );
  }
}
