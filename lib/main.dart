import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'academics/controller.dart';
import 'academics/store.dart';
import 'agenda/controller.dart';
import 'agenda/store.dart';
import 'app/controller.dart';
import 'app/ui/app_screen.dart';
import 'core/diagnostics.dart';
import 'l10n/l10n.dart';
import 'schedule/store.dart';
import 'school/service.dart';
import 'school/storage.dart';
import 'ui/theme.dart';
import 'updates/ui/update_check.dart' as updates;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final diagnostics = AppDiagnostics.instance;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    diagnostics.error(
      'Flutter',
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };
  WidgetsBinding.instance.platformDispatcher.onError = (failure, stack) {
    diagnostics.report('未处理的异常', failure, stack);
    return false;
  };
  diagnostics.info('启动 BITree（${Platform.operatingSystem}）');

  final schoolStorage = SchoolStorage();
  final controller = AppController(
    store: ScheduleStore(),
    school: SchoolService(),
    schoolStorage: schoolStorage,
    preferences: SharedPreferencesAsync(),
    agenda: AgendaController(AgendaStore()),
    academics: AcademicController(AcademicStore()),
  );
  runApp(BitreeApp(controller: controller));
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.initialize());
}

class BitreeApp extends StatelessWidget {
  const BitreeApp({
    super.key,
    required this.controller,
    this.updateChecker = updates.checkForUpdates,
  });

  final AppController controller;
  final AppUpdateChecker updateChecker;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.settings]),
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => context.l10n.appName,
        debugShowCheckedModeBanner: false,
        theme: bitreeTheme(
          Brightness.light,
          coursePalette: controller.settings.paletteFor(Brightness.light),
          systemPalette: controller.settings.systemPalette,
        ),
        darkTheme: bitreeTheme(
          Brightness.dark,
          coursePalette: controller.settings.paletteFor(Brightness.dark),
          systemPalette: controller.settings.systemPalette,
        ),
        themeMode: controller.settings.themeMode,
        locale: controller.settings.language.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AppScreen(controller: controller, updateChecker: updateChecker),
      ),
    );
  }
}
