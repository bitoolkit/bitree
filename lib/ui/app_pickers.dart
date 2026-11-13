import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  SelectableDayPredicate? selectableDayPredicate,
}) => showDatePicker(
  context: context,
  initialDate: initialDate,
  firstDate: firstDate,
  lastDate: lastDate,
  selectableDayPredicate: selectableDayPredicate,
  builder: _pickerDialogBuilder,
);

Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
}) => showTimePicker(
  context: context,
  initialTime: initialTime,
  helpText: helpText,
  // The app's dialog width fits the portrait dial even in a short window.
  orientation: Orientation.portrait,
  builder: _pickerDialogBuilder,
);

Widget _pickerDialogBuilder(BuildContext context, Widget? child) {
  final media = MediaQuery.of(context);
  final theme = DialogTheme.of(context);
  final inset = theme.insetPadding!;
  final width = math.min(
    theme.constraints!.maxWidth,
    media.size.width - inset.horizontal,
  );

  // Native pickers reserve 16px per side. Their orientation should follow
  // the dialog width rather than the full desktop window.
  return Padding(
    padding: EdgeInsets.only(left: inset.left - 16, right: inset.right - 16),
    child: MediaQuery(
      data: media.copyWith(size: Size(width, media.size.height)),
      child: child!,
    ),
  );
}
