import 'dart:async';

import 'package:flutter/material.dart';

import '../../agenda/controller.dart';
import '../../agenda/ui/calendar_screen.dart';
import '../../core/diagnostics.dart';
import '../../l10n/l10n.dart';
import '../../schedule/ui/home_screen.dart';
import '../../ui/app_notice.dart';
import '../../ui/app_page.dart';
import '../../ui/campus_time_builder.dart';
import '../../updates/ui/update_check.dart';
import '../controller.dart';
import 'settings_screen.dart';
import 'tools_screen.dart';

class AppScreen extends StatefulWidget {
  const AppScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppScreen> createState() => _AppScreenState();
}

class _AppScreenState extends State<AppScreen> {
  int _tab = 0;
  bool _checkingUpdates = false;
  bool _started = false;
  late final StreamSubscription<String> _errors;

  @override
  void initState() {
    super.initState();
    _errors = AppDiagnostics.instance.messages.listen((message) {
      if (mounted) showAppNotice(context, message);
    });
    widget.controller.addListener(_onReady);
    _onReady();
  }

  void _onReady() {
    if (_started || !widget.controller.ready) return;
    _started = true;
    widget.controller.removeListener(_onReady);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_restoreAccount());
    });
  }

  Future<void> _restoreAccount() async {
    await widget.controller.school.restoreAccount();
    if (mounted) await _checkUpdates(silent: true);
  }

  @override
  void dispose() {
    _errors.cancel();
    widget.controller.removeListener(_onReady);
    super.dispose();
  }

  Future<void> _checkUpdates({bool silent = false}) async {
    if (_checkingUpdates) return;
    setState(() => _checkingUpdates = true);

    try {
      await checkForUpdates(context, silent: silent);
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      CampusTimeBuilder(active: true, builder: _build);

  Widget _build(BuildContext context, DateTime now) {
    final l10n = context.l10n;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: _tab,
            children: [
              HomeScreen(
                controller: widget.controller,
                now: now,
                active: _tab == 0,
              ),
              CalendarScreen(
                controller: widget.controller,
                now: now,
                active: _tab == 1,
              ),
              ToolsScreen(controller: widget.controller),
              SettingsScreen(
                controller: widget.controller,
                checkingForUpdates: _checkingUpdates,
                onCheckForUpdates: () => _checkUpdates(),
              ),
            ],
          ),
          ListenableBuilder(
            listenable: Listenable.merge([
              widget.controller.school,
              widget.controller.sync,
            ]),
            builder: (context, _) =>
                widget.controller.school.busy || widget.controller.sync.busy
                ? Positioned(
                    top: MediaQuery.paddingOf(context).top,
                    left: 0,
                    right: 0,
                    child: const LinearProgressIndicator(minHeight: 3),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: NavigationBar(
                height: appNavigationBarHeight(context),
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                selectedIndex: _tab,
                onDestinationSelected: (value) => setState(() => _tab = value),
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: l10n.navHome,
                  ),
                  NavigationDestination(
                    icon: _AgendaNavigationIcon(
                      agenda: widget.controller.agenda,
                      now: now,
                      icon: Icons.calendar_month_outlined,
                    ),
                    selectedIcon: _AgendaNavigationIcon(
                      agenda: widget.controller.agenda,
                      now: now,
                      icon: Icons.calendar_month_rounded,
                    ),
                    label: l10n.navAgenda,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: l10n.navTools,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: l10n.navSettings,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendaNavigationIcon extends StatelessWidget {
  const _AgendaNavigationIcon({
    required this.agenda,
    required this.now,
    required this.icon,
  });
  final AgendaController agenda;
  final DateTime now;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: agenda,
    builder: (context, _) {
      final l10n = context.l10n;
      final count = agenda.ready ? agenda.pendingOn(now, now: now).length : 0;
      final scheme = Theme.of(context).colorScheme;
      return Semantics(
        label: count > 0
            ? '${l10n.today} ${l10n.agendaReminderCount(count)}'
            : null,
        excludeSemantics: true,
        child: Badge.count(
          count: count,
          isLabelVisible: count > 0,
          backgroundColor: scheme.primary,
          textColor: scheme.onPrimary,
          child: Icon(icon),
        ),
      );
    },
  );
}
