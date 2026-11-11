import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../agenda_color.dart';

class AgendaColorPickerResult {
  const AgendaColorPickerResult(this.color);

  final AgendaColor? color;
}

Future<AgendaColorPickerResult?> showAgendaColorPicker(
  BuildContext context, {
  AgendaColor? initialColor,
}) async {
  final l10n = context.l10n;
  final defaultColor = Theme.of(context).colorScheme.secondary;
  final initial = initialColor == null
      ? defaultColor
      : Color(initialColor.value);
  var selected = initial;
  final swatches = <ColorSwatch<Object>, String>{
    ColorTools.createPrimarySwatch(defaultColor): l10n.agendaColorDefault,
    for (final color in AgendaColor.presets)
      ColorTools.createPrimarySwatch(Color(color.value)): color.localizedLabel(
        l10n,
      ),
  };
  final confirmed =
      await ColorPicker(
        color: initial,
        onColorChanged: (color) => selected = color,
        title: Text(
          l10n.agendaColorPickerTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        mainAxisSize: MainAxisSize.min,
        padding: EdgeInsets.zero,
        width: 36,
        height: 36,
        borderRadius: 18,
        spacing: 6,
        runSpacing: 6,
        wheelDiameter: 190,
        enableOpacity: false,
        showColorCode: true,
        colorCodeHasColor: true,
        pickerTypeLabels: {
          ColorPickerType.custom: l10n.agendaColorPresets,
          ColorPickerType.wheel: l10n.agendaColorCustomSection,
        },
        customColorSwatchesAndNames: swatches,
        pickersEnabled: const {
          ColorPickerType.both: false,
          ColorPickerType.primary: false,
          ColorPickerType.accent: false,
          ColorPickerType.bw: false,
          ColorPickerType.custom: true,
          ColorPickerType.wheel: true,
        },
        copyPasteBehavior: const ColorPickerCopyPasteBehavior(
          copyFormat: ColorPickerCopyFormat.numHexRRGGBB,
          copyButton: true,
          pasteButton: true,
          editFieldCopyButton: true,
          parseShortHexCode: true,
          longPressMenu: true,
          secondaryMenu: true,
        ),
        actionButtons: ColorPickerActionButtons(
          dialogOkButtonLabel: l10n.apply,
          dialogOkButtonType: ColorPickerActionButtonType.filled,
          dialogCancelButtonLabel: l10n.cancel,
        ),
      ).showPickerDialog(
        context,
        semanticLabel: l10n.agendaColorPickerTitle,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        actionsPadding: const EdgeInsets.all(24),
        insetPadding: DialogTheme.of(context).insetPadding!,
      );
  if (!confirmed) return null;

  final value = selected.withValues(alpha: 1).toARGB32();
  if (value == defaultColor.withValues(alpha: 1).toARGB32()) {
    return const AgendaColorPickerResult(null);
  }
  return AgendaColorPickerResult(
    AgendaColor.presetByValue(value) ?? AgendaColor(value),
  );
}
