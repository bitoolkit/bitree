import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Keeps tab selection and touch or mouse paging on the same animation.
class SwipePager extends StatefulWidget {
  const SwipePager({
    super.key,
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
    required this.onChanged,
  });

  final int index;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onChanged;

  @override
  State<SwipePager> createState() => _SwipePagerState();
}

class _SwipePagerState extends State<SwipePager> with TickerProviderStateMixin {
  TabController? _tabs;
  late int _index;

  Duration get _duration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 260);

  void _createController() {
    _tabs?.dispose();
    _index = widget.index;
    _tabs = TabController(
      initialIndex: _index,
      length: widget.itemCount,
      animationDuration: _duration,
      vsync: this,
    )..addListener(_selectionChanged);
    _tabs!.animation!.addListener(_selectionChanged);
  }

  void _selectionChanged() {
    final tabs = _tabs!;
    final index = tabs.indexIsChanging
        ? tabs.index
        : tabs.animation!.value.round().clamp(0, tabs.length - 1);
    if (_index == index) return;
    _index = index;
    widget.onChanged(index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabs?.animationDuration != _duration) _createController();
  }

  @override
  void didUpdateWidget(covariant SwipePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabs!.length != widget.itemCount) {
      _createController();
    } else if (_index != widget.index) {
      _index = widget.index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabs!.animateTo(widget.index, curve: Curves.easeOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        dragDevices: {...behavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: TabBarView(
        controller: _tabs,
        children: [
          for (var index = 0; index < widget.itemCount; index++)
            Builder(builder: (context) => widget.itemBuilder(context, index)),
        ],
      ),
    );
  }
}
