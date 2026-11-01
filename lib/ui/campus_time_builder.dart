import 'dart:async';

import 'package:flutter/material.dart';

import '../core/time.dart';

/// Refreshes date and time labels while their page is visible.
class CampusTimeBuilder extends StatefulWidget {
  const CampusTimeBuilder({
    super.key,
    required this.active,
    required this.builder,
  });

  final bool active;
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<CampusTimeBuilder> createState() => _CampusTimeBuilderState();
}

class _CampusTimeBuilderState extends State<CampusTimeBuilder>
    with WidgetsBindingObserver {
  DateTime _now = campusNow();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleTick();
  }

  @override
  void didUpdateWidget(covariant CampusTimeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      _now = campusNow();
      _scheduleTick();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      _tick();
    } else {
      _timer?.cancel();
    }
  }

  void _scheduleTick() {
    _timer?.cancel();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!widget.active ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return;
    }
    _timer = Timer(
      const Duration(minutes: 1) -
          Duration(
            seconds: _now.second,
            milliseconds: _now.millisecond,
            microseconds: _now.microsecond,
          ),
      _tick,
    );
  }

  void _tick() {
    setState(() => _now = campusNow());
    _scheduleTick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
