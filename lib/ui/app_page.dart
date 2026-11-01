import 'package:flutter/material.dart';

import 'design.dart';

double appNavigationBarHeight(BuildContext context) =>
    56 + MediaQuery.textScalerOf(context).scale(12);

/// Shared frame for the main destinations.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.leading,
    this.maxWidth = 1200,
    this.safeBottom = false,
  });

  final Widget title;
  final Widget child;
  final List<Widget> actions;
  final Widget? leading;
  final double maxWidth;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: safeBottom,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = constraints.maxWidth < 680 ? 16.0 : 24.0;
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final splitHeader =
                actions.isNotEmpty &&
                constraints.maxWidth < 480 &&
                (constraints.maxWidth < 360 || textScale > 1.3);

            Widget titleRow({required bool includeActions}) => ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  ?leading,
                  if (leading != null) const SizedBox(width: 4),
                  Expanded(
                    child: DefaultTextStyle(
                      style: Theme.of(context).appBarTheme.titleTextStyle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: title,
                    ),
                  ),
                  if (includeActions) ...actions,
                ],
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset, vertical: 4),
                  child: splitHeader
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            titleRow(includeActions: false),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(children: actions),
                              ),
                            ),
                          ],
                        )
                      : titleRow(includeActions: true),
                ),
                Expanded(child: child),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class AppRoutePage extends StatelessWidget {
  const AppRoutePage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.maxWidth = 960,
    this.showProgress = false,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;
  final bool showProgress;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppPage(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: const BackButton(),
      actions: actions,
      maxWidth: maxWidth,
      safeBottom: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: appProgressHeight,
            child: showProgress
                ? const LinearProgressIndicator(minHeight: appProgressHeight)
                : null,
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
