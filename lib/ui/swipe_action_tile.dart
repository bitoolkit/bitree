import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

class TileSwipeAction {
  const TileSwipeAction({
    required this.label,
    required this.releaseLabel,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onInvoke,
  });

  final String label;
  final String releaseLabel;
  final IconData icon;
  final Color background;
  final Color foreground;

  /// Return true when the row is removed; false restores it after a failure.
  final Future<bool> Function() onInvoke;
}

/// Short swipes reveal a button; full swipes invoke it on release.
/// The list owns row removal and its size animation.
class SwipeActionTile extends StatefulWidget {
  const SwipeActionTile({
    super.key,
    this.leftAction,
    this.rightAction,
    required this.enabled,
    required this.child,
  }) : assert(leftAction != null || rightAction != null);

  /// Action invoked when the content moves physically left, regardless of locale.
  final TileSwipeAction? leftAction;
  final TileSwipeAction? rightAction;
  final bool enabled;
  final Widget child;

  @override
  State<SwipeActionTile> createState() => _SwipeActionTileState();
}

class _SwipeActionTileState extends State<SwipeActionTile>
    with SingleTickerProviderStateMixin {
  late final _position = AnimationController(
    vsync: this,
    value: 0,
    lowerBound: -1,
    upperBound: 1,
  )..addListener(_positionChanged);
  double _width = 0;
  ScrollPosition? _scrollPosition;
  bool _dragging = false;
  bool _wasReady = false;
  bool _running = false;

  double get _offset => _position.value * _width;
  double get _threshold => (_width * 0.5).clamp(128, 216);
  double get _actionWidth =>
      MediaQuery.textScalerOf(context).scale(80).clamp(80, _width * 0.4);
  bool get _ready => _offset.abs() >= _threshold;
  TileSwipeAction? get _action =>
      _offset < 0 ? widget.leftAction : widget.rightAction;

  void _positionChanged() {
    if (_dragging && _ready && !_wasReady) HapticFeedback.selectionClick();
    _wasReady = _ready;
    setState(() {});
  }

  Future<void> _settle(double target) async {
    try {
      await _position
          .animateTo(
            target,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : Duration(
                    milliseconds:
                        (180 * (target - _position.value).abs().clamp(0.45, 1))
                            .round(),
                  ),
            curve: Curves.easeOutCubic,
          )
          .orCancel;
    } on TickerCanceled {
      // A new drag or disposing the row interrupts the settling animation.
    }
  }

  void _start(DragStartDetails details) {
    _position.stop();
    _dragging = true;
  }

  void _update(DragUpdateDetails details) {
    _position.value = (_position.value + details.delta.dx / _width).clamp(
      widget.leftAction == null ? 0 : -1,
      widget.rightAction == null ? 0 : 1,
    );
  }

  void _end(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final action = _action;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity * _offset.sign < -400) {
      _settle(0);
    } else if (_ready && action != null) {
      _invoke(action, _position.value.sign);
    } else if (action != null &&
        (_offset.abs() >= _actionWidth / 2 || velocity * _offset.sign > 600)) {
      _settle(_position.value.sign * _actionWidth / _width);
    } else {
      _settle(0);
    }
  }

  void _cancel() {
    if (!_dragging) return;
    _close();
  }

  void _close() {
    if (_running) return;
    _dragging = false;
    if (_position.value != 0) _settle(0);
  }

  void _scrollingChanged() {
    if (_scrollPosition!.isScrollingNotifier.value) _close();
  }

  Future<void> _invoke(TileSwipeAction action, double direction) async {
    if (_running || !widget.enabled) return;
    setState(() => _running = true);
    var removed = false;
    try {
      await _settle(direction);
      if (!mounted) return;
      removed = await action.onInvoke();
    } finally {
      if (mounted) {
        setState(() => _running = false);
        if (!removed) _settle(0);
      }
    }
  }

  Widget _background(TileSwipeAction action, Alignment alignment) => Material(
    color: action.background,
    child: InkWell(
      onTap: widget.enabled && !_running
          ? () => _invoke(action, _position.value.sign)
          : null,
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: _actionWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 22, color: action.foreground),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _ready ? action.releaseLabel : action.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: action.foreground),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (position == _scrollPosition) return;
    _scrollPosition?.isScrollingNotifier.removeListener(_scrollingChanged);
    _scrollPosition = position;
    _scrollPosition?.isScrollingNotifier.addListener(_scrollingChanged);
  }

  @override
  void didUpdateWidget(covariant SwipeActionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled && !_running) {
      _close();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_scrollingChanged);
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _width = constraints.maxWidth;
      final enabled = widget.enabled && !_running;
      final action = _action;
      return Semantics(
        customSemanticsActions: enabled
            ? {
                if (widget.leftAction case final left?)
                  CustomSemanticsAction(label: left.label): () =>
                      _invoke(left, -1),
                if (widget.rightAction case final right?)
                  CustomSemanticsAction(label: right.label): () =>
                      _invoke(right, 1),
              }
            : null,
        child: TapRegion(
          enabled: _offset != 0 && !_running,
          onTapOutside: (_) => _close(),
          child: ClipRect(
            child: AbsorbPointer(
              absorbing: _running,
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  if (enabled)
                    _RowDragRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _RowDragRecognizer
                        >(
                          () => _RowDragRecognizer(debugOwner: this),
                          (recognizer) => recognizer
                            ..dragStartBehavior = DragStartBehavior.down
                            ..allowLeft = widget.leftAction != null
                            ..allowRight = widget.rightAction != null
                            ..gestureSettings = MediaQuery.gestureSettingsOf(
                              context,
                            )
                            ..onStart = _start
                            ..onUpdate = _update
                            ..onEnd = _end
                            ..onCancel = _cancel,
                        ),
                },
                child: Stack(
                  children: [
                    if (action != null && _offset != 0)
                      Positioned.fill(
                        child: ClipRect(
                          clipper: _RevealedActionClipper(_offset),
                          child: _background(
                            action,
                            _offset < 0
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(_offset, 0),
                      child: GestureDetector(
                        onTap: _offset != 0 ? _close : null,
                        child: AbsorbPointer(
                          absorbing: _offset != 0,
                          child: Material(
                            type: MaterialType.transparency,
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _RevealedActionClipper extends CustomClipper<Rect> {
  const _RevealedActionClipper(this.offset);

  final double offset;

  @override
  Rect getClip(Size size) => offset < 0
      ? Rect.fromLTRB(size.width + offset, 0, size.width, size.height)
      : Rect.fromLTRB(0, 0, offset, size.height);

  @override
  bool shouldReclip(_RevealedActionClipper oldClipper) =>
      offset != oldClipper.offset;
}

class _RowDragRecognizer extends HorizontalDragGestureRecognizer {
  _RowDragRecognizer({super.debugOwner})
    : super(
        supportedDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      ) {
    onlyAcceptDragOnThreshold = true;
  }

  bool allowLeft = false;
  bool allowRight = false;
  PointerDownEvent? _down;
  bool _horizontal = false;
  bool _accepted = false;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      _down == null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _down = event;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_accepted && event is PointerMoveEvent) {
      final delta = event.position - _down!.position;
      final slop = computeHitSlop(event.kind, gestureSettings);
      if (delta.distance > slop) {
        // Commit to an axis once: vertical and ambiguous diagonals belong to
        // scrolling, even when both axes cross the slop in the same event.
        if (delta.dx.abs() < delta.dy.abs() * 1.25 ||
            (delta.dx < 0 ? !allowLeft : !allowRight)) {
          resolve(GestureDisposition.rejected);
          if (_down != null) rejectGesture(event.pointer);
          return;
        }
        _horizontal = true;
      }
    }
    if (event is PointerCancelEvent) onCancel?.call();
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    _accepted =
        _horizontal &&
        super.hasSufficientGlobalDistanceToAccept(
          pointerDeviceKind,
          deviceTouchSlop,
        );
    return _accepted;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _down = null;
    _horizontal = false;
    _accepted = false;
  }
}
