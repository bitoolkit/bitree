import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppCorners {
  static const controlRadius = Radius.circular(10);
  static const _panelRadius = Radius.circular(20);
  static const compact = BorderRadius.all(Radius.circular(6));
  static const control = BorderRadius.all(controlRadius);
  static const panel = BorderRadius.all(_panelRadius);
  static const sheet = BorderRadius.vertical(top: _panelRadius);
}

const appControlShape = RoundedRectangleBorder(
  borderRadius: AppCorners.control,
);
const appPanelShape = RoundedRectangleBorder(borderRadius: AppCorners.panel);
const appControlHeight = 48.0;
const appControlSize = Size(48, appControlHeight);
const appProgressHeight = 3.0;
const appControlPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.lg,
  vertical: AppSpacing.md,
);
const appSheetContentPadding = EdgeInsets.fromLTRB(
  AppSpacing.xl,
  AppSpacing.sm,
  AppSpacing.xl,
  AppSpacing.lg,
);
const appSheetListPadding = EdgeInsets.fromLTRB(
  AppSpacing.sm,
  0,
  AppSpacing.sm,
  AppSpacing.md,
);
const appSheetActionPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.xl,
  vertical: AppSpacing.md,
);

const appMenuMotion = AnimationStyle(
  duration: Durations.medium2,
  reverseDuration: Durations.short4,
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.easeInOutCubic,
);
