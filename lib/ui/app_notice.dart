import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_page.dart';
import 'design.dart';

OverlayEntry? _notice;

/// The root overlay keeps feedback visible above course detail sheets.
void showAppNotice(
  BuildContext context,
  String message, {
  ({String label, VoidCallback onPressed})? action,
}) => showOverlayNotice(
  Overlay.of(context, rootOverlay: true),
  message,
  action: action,
);

/// Allows an undo action to outlive the route where it started.
void showOverlayNotice(
  OverlayState overlay,
  String message, {
  ({String label, VoidCallback onPressed})? action,
}) {
  dismissAppNotice();
  late final OverlayEntry entry;
  void dismiss() {
    if (identical(_notice, entry)) dismissAppNotice();
  }

  entry = OverlayEntry(
    builder: (context) {
      final theme = Theme.of(context);
      return _NoticeLifetime(
        duration: Duration(seconds: action == null ? 2 : 5),
        onDismiss: dismiss,
        child: Positioned(
          bottom:
              math.max(
                MediaQuery.viewInsetsOf(context).bottom,
                appNavigationBarHeight(context) +
                    MediaQuery.viewPaddingOf(context).bottom,
              ) +
              16,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            bottom: false,
            minimum: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: appControlSize.height,
                  maxWidth: 560,
                ),
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  onDismiss: dismiss,
                  child: Dismissible(
                    key: ObjectKey(entry),
                    direction: DismissDirection.horizontal,
                    resizeDuration: null,
                    movementDuration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : Durations.short4,
                    onDismissed: (_) => dismiss(),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      child: Material(
                        color: theme.colorScheme.inverseSurface,
                        borderRadius: AppCorners.control,
                        elevation: 6,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    message,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onInverseSurface,
                                    ),
                                  ),
                                ),
                              ),
                              if (action != null) ...[
                                const SizedBox(width: 12),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        theme.colorScheme.inversePrimary,
                                  ),
                                  onPressed: () {
                                    dismiss();
                                    action.onPressed();
                                  },
                                  child: Text(action.label),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  _notice = entry;
  overlay.insert(entry);
}

void dismissAppNotice() {
  final entry = _notice;
  _notice = null;
  entry?.remove();
  entry?.dispose();
}

class _NoticeLifetime extends StatefulWidget {
  const _NoticeLifetime({
    required this.duration,
    required this.onDismiss,
    required this.child,
  });
  final Duration duration;
  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<_NoticeLifetime> createState() => _NoticeLifetimeState();
}

class _NoticeLifetimeState extends State<_NoticeLifetime> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer.cancel();
    widget.onDismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
