import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design.dart';

typedef AppMenuAnchorBuilder = Widget Function(
  BuildContext context,
  MenuController menu,
  bool isOpen,
);

class AppMenuAnchor extends StatefulWidget {
  const AppMenuAnchor({
    super.key,
    required this.menuChildren,
    this.controller,
    this.childFocusNode,
    this.menuWidth,
    this.style,
    this.onOpen,
    this.onClose,
    this.builder,
    this.child,
  });

  final List<Widget> menuChildren;
  final MenuController? controller;
  final FocusNode? childFocusNode;
  final double? menuWidth;
  final MenuStyle? style;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;
  final AppMenuAnchorBuilder? builder;
  final Widget? child;

  @override
  State<AppMenuAnchor> createState() => _AppMenuAnchorState();
}

class _AppMenuAnchorState extends State<AppMenuAnchor>
    with SingleTickerProviderStateMixin {
  final _internalController = MenuController();
  final _menuFocus = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  late final _animation = AnimationController(vsync: this)
    ..addStatusListener((_) => setState(() {}));

  MenuController get _menu => widget.controller ?? _internalController;
  bool get _isOpen => _menu.isOpen && _animation.isForwardOrCompleted;
  Duration _duration(Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  @override
  void dispose() {
    _animation.dispose();
    _menuFocus.dispose();
    super.dispose();
  }

  void _open(Offset? position, VoidCallback showOverlay) {
    if (!_menu.isOpen) showOverlay();
    _animation.animateTo(
      1,
      duration: _duration(appMenuMotion.duration!),
      curve: appMenuMotion.curve!,
    );
  }

  void _close(VoidCallback hideOverlay) {
    if (_animation.status == AnimationStatus.reverse) return;
    _animation
        .animateBack(
          0,
          duration: _duration(appMenuMotion.reverseDuration!),
          curve: appMenuMotion.reverseCurve!,
        )
        .then((_) {
          if (mounted) hideOverlay();
        });
  }

  @override
  Widget build(BuildContext context) {
    // MenuAnchor's built-in motion cannot be styled. Keep the native anchor
    // lifecycle, but hide its overlay only after the panel reaches zero height.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: RawMenuAnchor(
        controller: _menu,
        childFocusNode: widget.childFocusNode,
        onOpen: widget.onOpen,
        onClose: widget.onClose,
        onOpenRequested: _open,
        onCloseRequested: _close,
        overlayBuilder: _buildOverlay,
        builder: (context, menu, child) =>
            widget.builder?.call(context, menu, _isOpen) ??
            child ??
            const SizedBox.shrink(),
        child: widget.child,
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, RawMenuOverlayInfo info) {
    final theme = Theme.of(context);
    final menuStyle = (widget.style ?? const MenuStyle()).merge(
      MenuTheme.of(context).style,
    );
    final shape = menuStyle.shape?.resolve({}) ?? appControlShape;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => CustomSingleChildLayout(
        delegate: _MenuLayout(
          anchor: info.anchorRect,
          position: info.position,
          alignment: (menuStyle.alignment ?? AlignmentDirectional.bottomStart)
              .resolve(Directionality.of(context)),
          textDirection: Directionality.of(context),
          insets:
              MediaQuery.paddingOf(context) + MediaQuery.viewInsetsOf(context),
          heightFactor: _animation.value,
        ),
        child: ExcludeSemantics(
          excluding: !_isOpen,
          child: IgnorePointer(
            ignoring: !_isOpen,
            child: ExcludeFocus(
              excluding: !_isOpen,
              child: TapRegion(
                groupId: info.tapRegionGroupId,
                onTapOutside: (_) => _menu.close(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth:
                        widget.menuWidth ??
                        menuStyle.minimumSize?.resolve({})?.width ??
                        0,
                    maxWidth: widget.menuWidth ?? double.infinity,
                  ),
                  child: IntrinsicWidth(
                    child: Material(
                      color:
                          menuStyle.backgroundColor?.resolve({}) ??
                          theme.colorScheme.surfaceContainer,
                      surfaceTintColor:
                          menuStyle.surfaceTintColor?.resolve({}) ??
                          Colors.transparent,
                      shadowColor:
                          menuStyle.shadowColor?.resolve({}) ??
                          theme.colorScheme.shadow,
                      elevation: menuStyle.elevation?.resolve({}) ?? 3,
                      shape: shape.copyWith(side: menuStyle.side?.resolve({})),
                      clipBehavior: Clip.antiAlias,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        widthFactor: 1,
                        heightFactor: _animation.value,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: FocusScope(
        node: _menuFocus,
        skipTraversal: true,
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
            SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              overscroll: false,
              physics: const ClampingScrollPhysics(),
            ),
            child: SingleChildScrollView(
              primary: false,
              padding:
                  menuStyle.padding?.resolve({}) ??
                  const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.menuChildren,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({
    required this.anchor,
    required this.position,
    required this.alignment,
    required this.textDirection,
    required this.insets,
    required this.heightFactor,
  });

  final Rect anchor;
  final Offset? position;
  final Alignment alignment;
  final TextDirection textDirection;
  final EdgeInsets insets;
  final double heightFactor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = BoxConstraints.loose(
      insets.deflateSize(constraints.biggest),
    ).deflate(const EdgeInsets.all(8));
    final bounds = insets
        .deflateRect(Offset.zero & constraints.biggest)
        .deflate(8);
    final target = position == null
        ? alignment.withinRect(anchor)
        : anchor.topLeft + position!;
    final above = (position == null ? anchor.top : target.dy) - bounds.top;
    final below = bounds.bottom - target.dy;
    return available.copyWith(
      maxHeight: math.max(above, below).clamp(0.0, available.maxHeight),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bounds = insets.deflateRect(Offset.zero & size).deflate(8);
    final height = heightFactor == 0 ? 0 : childSize.height / heightFactor;
    final target = position == null
        ? alignment.withinRect(anchor)
        : anchor.topLeft + position!;
    final x =
        target.dx -
        (position == null && textDirection == TextDirection.rtl
            ? childSize.width
            : 0);
    var y = target.dy;
    if (y + height > bounds.bottom) {
      y = math.max(
        bounds.top,
        (position == null ? anchor.top : target.dy) - height,
      );
      // Keep the attachment edge fixed for menus opening above their anchor.
      y += height - childSize.height;
    }
    return Offset(
      x.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      y.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      position != oldDelegate.position ||
      alignment != oldDelegate.alignment ||
      textDirection != oldDelegate.textDirection ||
      insets != oldDelegate.insets ||
      heightFactor != oldDelegate.heightFactor;
}

class AppMenuItemButton extends StatelessWidget {
  const AppMenuItemButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.leadingIcon,
    this.trailingIcon,
    this.selected,
    this.style,
    this.autofocus = false,
  }) : assert(selected == null || trailingIcon == null);

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool? selected;
  final ButtonStyle? style;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: MenuItemButton(
      onPressed: onPressed == null
          ? null
          : () {
              MenuController.maybeOf(context)!.close();
              onPressed!();
            },
      closeOnActivate: false,
      leadingIcon: leadingIcon,
      trailingIcon: switch (selected) {
        true => const Icon(Icons.check_rounded, size: 18),
        false => const SizedBox(width: 18),
        null => trailingIcon,
      },
      style: style,
      autofocus: autofocus,
      overflowAxis: Axis.vertical,
      child: child,
    ),
  );
}
