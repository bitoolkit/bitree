import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bitree/academics/controller.dart';
import 'package:bitree/academics/model.dart';
import 'package:bitree/academics/ui/credit_progress_screen.dart';
import 'package:bitree/academics/ui/exams_screen.dart';
import 'package:bitree/academics/ui/grade_simulation_screen.dart';
import 'package:bitree/academics/ui/grades_screen.dart';
import 'package:bitree/agenda/controller.dart';
import 'package:bitree/agenda/deadline_source.dart';
import 'package:bitree/agenda/model.dart';
import 'package:bitree/agenda/ui/calendar_screen.dart';
import 'package:bitree/app/controller.dart';
import 'package:bitree/app/ui/settings_screen.dart';
import 'package:bitree/app/ui/widget_guide.dart';
import 'package:bitree/classrooms/model.dart';
import 'package:bitree/classrooms/repository.dart';
import 'package:bitree/classrooms/ui/classroom_screen.dart';
import 'package:bitree/core/async/cancelable_request.dart';
import 'package:bitree/mooc/cookie.dart';
import 'package:bitree/mooc/credentials.dart';
import 'package:bitree/mooc/storage.dart';
import 'package:bitree/schedule/model.dart';
import 'package:bitree/schedule/ui/home_screen.dart';
import 'package:bitree/school/service.dart';
import 'package:bitree/school/storage.dart';
import 'package:bitree/school/verification.dart';
import 'package:bitree/ui/app_page.dart';
import 'package:bitree/ui/theme.dart';
import 'package:bitree/wencui/atlas.dart';
import 'package:bitree/wencui/ui/wencui_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/test_app.dart';

const _screenshotSize = Size(1200, 800);
const _mockAccount = '20260001';
final _mockNow = DateTime.utc(2026, 10, 28, 10, 20);
const _outputDirectory = 'docs/screenshots';

final _captureKey = GlobalKey();

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontBytes = await (await _loadScreenshotFont()).readAsBytes();
    for (final family in ['Roboto', 'Noto Sans CJK SC', 'Ahem']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();
    }
    final iconFont = await _loadMaterialIconsFont();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(iconFont.readAsBytes().then(ByteData.sublistView))).load();
    await Directory(_outputDirectory).create(recursive: true);
  });

  testWidgets('generate README screenshots from mock data', (tester) async {
    await _setSurface(tester);

    final home = _ScreenshotController(
      schedule: _schedule(),
      entries: _agendaEntries(),
      academicRecord: _academicRecord(),
      initialWeek: 9,
    );
    await home.initialize();
    await tester.pumpWidget(
      _capture(_app(_MainPreview(controller: home, selected: 0))),
    );
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'timetable.png');

    await tester.pumpWidget(
      _capture(_app(_MainPreview(controller: home, selected: 1))),
    );
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'agenda.png');

    final academics = _ScreenshotController(
      schedule: _schedule(),
      entries: _agendaEntries(),
      academicRecord: _academicRecord(),
      initialWeek: 9,
    );
    await academics.initialize();
    await tester.pumpWidget(
      _capture(_app(GradesScreen(controller: academics))),
    );
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'grades.png');

    final retake = academics.academics.record.grades.firstWhere(
      (grade) => grade.failed,
    );
    await tester.pumpWidget(
      _capture(
        _app(GradeSimulationScreen(controller: academics, retake: retake)),
      ),
    );
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'grade-simulation.png');

    await tester.pumpWidget(
      _capture(_app(CreditProgressScreen(controller: academics))),
    );
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'credits.png');

    final exams = _ScreenshotController(
      schedule: _examSchedule(),
      entries: _examEntries(),
      academicRecord: _academicRecord(),
    );
    await exams.initialize();
    await tester.pumpWidget(_capture(_app(ExamsScreen(controller: exams))));
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'exams.png');

    final classrooms = _ClassroomScreenshotController(
      schedule: _schedule(),
      entries: _agendaEntries(),
      academicRecord: _academicRecord(),
    );
    await classrooms.initialize();
    await tester.pumpWidget(
      _capture(_app(ClassroomScreen(controller: classrooms))),
    );
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'classrooms.png');

    final map = _ScreenshotController(
      schedule: _schedule(),
      entries: _agendaEntries(),
      academicRecord: _academicRecord(),
    );
    await map.initialize();
    await tester.runAsync(WencuiAtlas.load);
    await tester.pumpWidget(
      _capture(_app(WencuiMapScreen(controller: map, initialRoom: 'F704'))),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/wencui/7.jpg'),
        tester.element(find.byType(WencuiMapScreen)),
      ),
    );
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'wencui-map.png');

    final moocStorage = MemoryMoocStorage()
      ..account = MoocAccount(
        id: 'mock-mooc-user',
        name: '理枝同学',
        credentials: MoocCredentials(
          userAgent: 'Mozilla/5.0 (Linux; Android 15) BITree screenshot',
          cookies: [
            MoocCookie('NTESSTUDYSI', 'mock-session')
              ..domain = 'www.icourse163.org'
              ..path = '/'
              ..secure = true,
          ],
        ),
      );
    final mooc = _ScreenshotController(
      schedule: _schedule(),
      entries: _agendaEntries(),
      academicRecord: _academicRecord(),
      moocStorage: moocStorage,
    );
    await mooc.initialize();
    tester.view.physicalSize = const Size(1200, 1000);
    await tester.pumpWidget(
      _capture(
        _app(
          Scaffold(
            body: SettingsScreen(
              controller: mooc,
              checkingForUpdates: false,
              onCheckForUpdates: () {},
            ),
          ),
        ),
      ),
    );
    await _pumpUi(tester);
    await tester.tap(find.text('中国大学MOOC'));
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'mooc-account.png');
    await tester.tap(find.byTooltip('关闭').last);
    await tester.pumpAndSettle();
    tester.view.physicalSize = _screenshotSize;

    final widgetGuide = _ScreenshotController(
      schedule: _schedule(),
      entries: _agendaEntries(),
      academicRecord: _academicRecord(),
      initialWeek: 9,
    );
    await widgetGuide.initialize();
    await tester.pumpWidget(
      _capture(_app(_MainPreview(controller: widgetGuide, selected: 0))),
    );
    await _pumpUi(tester);
    unawaited(showWidgetGuide(tester.element(find.byType(HomeScreen))));
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'widget-guide.png');
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_capture(_app(const _AndroidWidgetMock())));
    await _pumpUi(tester);
    await _captureScreenshot(tester, 'android-widget.png');
  });
}

Future<void> _setSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _screenshotSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _capture(Widget child) =>
    RepaintBoundary(key: _captureKey, child: child);

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: _theme(Brightness.light),
  darkTheme: _theme(Brightness.dark),
  themeMode: ThemeMode.light,
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

ThemeData _theme(Brightness brightness) {
  final theme = bitreeTheme(brightness);
  TextStyle? withFont(TextStyle? style) =>
      style?.copyWith(fontFamily: 'Roboto');
  final segmentedStyle = theme.segmentedButtonTheme.style;
  ButtonStyle? withButtonFont(ButtonStyle? style) => style?.copyWith(
    textStyle: style.textStyle == null
        ? null
        : WidgetStateProperty.resolveWith(
            (states) => withFont(style.textStyle?.resolve(states)),
          ),
  );
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Roboto'),
    appBarTheme: theme.appBarTheme.copyWith(
      titleTextStyle: withFont(theme.appBarTheme.titleTextStyle),
    ),
    listTileTheme: theme.listTileTheme.copyWith(
      titleTextStyle: withFont(theme.listTileTheme.titleTextStyle),
      subtitleTextStyle: withFont(theme.listTileTheme.subtitleTextStyle),
      leadingAndTrailingTextStyle: withFont(
        theme.listTileTheme.leadingAndTrailingTextStyle,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: segmentedStyle?.copyWith(
        textStyle: WidgetStatePropertyAll(
          withFont(segmentedStyle.textStyle?.resolve(const {})),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: withButtonFont(theme.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: withButtonFont(theme.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: withButtonFont(theme.textButtonTheme.style),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: withButtonFont(theme.menuButtonTheme.style),
    ),
    chipTheme: theme.chipTheme.copyWith(
      labelStyle: withFont(theme.chipTheme.labelStyle),
      secondaryLabelStyle: withFont(theme.chipTheme.secondaryLabelStyle),
    ),
  );
}

Future<File> _loadScreenshotFont() async {
  final configured = Platform.environment['BITREE_SCREENSHOT_FONT'];
  if (configured != null && File(configured).existsSync()) {
    return _prepareScreenshotFont(File(configured));
  }
  for (final executable in [
    '/run/current-system/sw/bin/fc-match',
    '/usr/bin/fc-match',
    '/usr/local/bin/fc-match',
    'fc-match',
  ]) {
    try {
      final match = await Process.run(executable, [
        '-f',
        '%{file}',
        'Noto Sans CJK SC',
      ]);
      final path = match.stdout.toString().trim();
      final font = File(path);
      if (match.exitCode == 0 &&
          path.isNotEmpty &&
          font.existsSync() &&
          _isCjkFontPath(path)) {
        return await _prepareScreenshotFont(font);
      }
    } on ProcessException {
      continue;
    }
  }
  throw StateError(
    'No CJK screenshot font found. Set BITREE_SCREENSHOT_FONT to a '
    'Noto Sans CJK font file.',
  );
}

bool _isCjkFontPath(String path) => RegExp(
  r'noto.*cjk|sourcehan|wqy|wenquanyi|pingfang|microsoft.?yahei',
  caseSensitive: false,
).hasMatch(path);

Future<File> _prepareScreenshotFont(File source) async {
  if (!source.path.toLowerCase().endsWith('.ttc')) return source;
  final data = await source.readAsBytes();
  if (String.fromCharCodes(data.take(4)) != 'ttcf') {
    throw FormatException('${source.path} is not a TrueType collection');
  }
  final faceOffset = _findTtcFace(data, 'Noto Sans CJK SC');
  final output = File(
    '${Directory.systemTemp.path}/bitree-readme-screenshots/'
    'NotoSansCJK-SC.otf',
  );
  await output.parent.create(recursive: true);
  await output.writeAsBytes(_extractTtcFace(data, faceOffset), flush: true);
  return output;
}

int _findTtcFace(Uint8List data, String family) {
  final count = _u32(data, 8);
  final available = <String>[];
  for (var index = 0; index < count; index++) {
    final offset = _u32(data, 12 + index * 4);
    final families = _faceFamilies(data, offset);
    available.addAll(families);
    if (families.any((name) => name.contains(family))) return offset;
  }
  throw StateError('Font face "$family" not found in ${available.join(', ')}');
}

Iterable<String> _faceFamilies(Uint8List data, int tableOffset) sync* {
  final count = _u16(data, tableOffset + 4);
  for (var index = 0; index < count; index++) {
    final record = tableOffset + 12 + index * 16;
    if (String.fromCharCodes(data.sublist(record, record + 4)) != 'name') {
      continue;
    }
    final table = _u32(data, record + 8);
    final nameCount = _u16(data, table + 2);
    final strings = table + _u16(data, table + 4);
    for (var item = 0; item < nameCount; item++) {
      final name = table + 6 + item * 12;
      final platform = _u16(data, name);
      final nameId = _u16(data, name + 6);
      if (nameId != 1) continue;
      final length = _u16(data, name + 8);
      final offset = _u16(data, name + 10);
      final raw = data.sublist(strings + offset, strings + offset + length);
      yield platform == 0 || platform == 3
          ? _decodeUtf16Be(raw)
          : String.fromCharCodes(raw);
    }
    return;
  }
}

String _decodeUtf16Be(List<int> bytes) => String.fromCharCodes([
  for (var index = 0; index + 1 < bytes.length; index += 2)
    (bytes[index] << 8) | bytes[index + 1],
]);

Uint8List _extractTtcFace(Uint8List data, int tableOffset) {
  final count = _u16(data, tableOffset + 4);
  final tables = <({List<int> tag, int checksum, int offset, int length})>[];
  var cursor = 12 + count * 16;
  for (var index = 0; index < count; index++) {
    final record = tableOffset + 12 + index * 16;
    final length = _u32(data, record + 12);
    cursor = (cursor + 3) & ~3;
    tables.add((
      tag: data.sublist(record, record + 4),
      checksum: _u32(data, record + 4),
      offset: cursor,
      length: length,
    ));
    cursor += length;
  }

  final output = Uint8List(cursor);
  output.setRange(0, 12, data.sublist(tableOffset, tableOffset + 12));
  final view = ByteData.sublistView(output);
  for (var index = 0; index < tables.length; index++) {
    final table = tables[index];
    final record = 12 + index * 16;
    output.setRange(record, record + 4, table.tag);
    view.setUint32(record + 4, table.checksum, Endian.big);
    view.setUint32(record + 8, table.offset, Endian.big);
    view.setUint32(record + 12, table.length, Endian.big);
  }
  for (var index = 0; index < count; index++) {
    final source = tableOffset + 12 + index * 16;
    final target = tables[index];
    final from = _u32(data, source + 8);
    output.setRange(
      target.offset,
      target.offset + target.length,
      data.sublist(from, from + target.length),
    );
  }
  return output;
}

int _u16(Uint8List data, int offset) =>
    ByteData.sublistView(data).getUint16(offset, Endian.big);

int _u32(Uint8List data, int offset) =>
    ByteData.sublistView(data).getUint32(offset, Endian.big);

Future<File> _loadMaterialIconsFont() async {
  final flutterRoot = await _flutterRoot();
  final file = File.fromUri(
    flutterRoot.resolve(
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ),
  );
  if (!file.existsSync()) {
    throw StateError('Material Icons font not found at ${file.path}');
  }
  return file;
}

Future<Uri> _flutterRoot() async {
  final config = File('.dart_tool/package_config.json');
  final packages =
      (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
  final flutter = packages.cast<Map>().firstWhere(
    (item) => item['name'] == 'flutter',
  );
  return config.absolute.uri
      .resolve('${flutter['rootUri']}/')
      .resolve('../../');
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _captureScreenshot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 200));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('Could not encode $name');
    await File('$_outputDirectory/$name').writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
  });
}

class _MainPreview extends StatelessWidget {
  const _MainPreview({required this.controller, required this.selected});

  final AppController controller;
  final int selected;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: selected == 0
        ? HomeScreen(controller: controller, now: _mockNow, active: false)
        : ListenableBuilder(
            listenable: controller.agenda,
            builder: (context, _) =>
                _AgendaPreview(controller: controller, now: _mockNow),
          ),
    bottomNavigationBar: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
              selectedIndex: selected,
              onDestinationSelected: (_) {},
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: '日程',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: '工具',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: '设置',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _AgendaPreview extends StatelessWidget {
  const _AgendaPreview({required this.controller, required this.now});

  final AppController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) =>
      CalendarScreen(controller: controller, now: now, active: false);
}

class _ScreenshotController extends AppController {
  factory _ScreenshotController({
    SemesterSchedule? schedule,
    List<SemesterSchedule> schedules = const [],
    List<AgendaEntry> entries = const [],
    AcademicRecord academicRecord = const AcademicRecord(),
    MoocStorage? moocStorage,
    int? initialWeek,
  }) {
    final academicStore = MemoryAcademicStore();
    academicStore.accounts[_mockAccount] = academicRecord;
    final controller = _ScreenshotController._(
      schedule: schedule,
      schedules: schedules,
      entries: entries,
      academicStore: academicStore,
      moocStorage: moocStorage,
      initialWeek: initialWeek,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  _ScreenshotController._({
    required SemesterSchedule? schedule,
    required List<SemesterSchedule> schedules,
    required List<AgendaEntry> entries,
    required MemoryAcademicStore academicStore,
    required MoocStorage? moocStorage,
    required this.initialWeek,
  }) : super(
         store: MemoryScheduleStore(schedules: schedules, selected: schedule),
         school: SchoolService(),
         schoolStorage: MemorySchoolStorage(
           credentials: const SchoolCredentials(
             username: _mockAccount,
             password: 'mock-password',
           ),
         ),
         preferences: MemoryPreferences(),
         agenda: AgendaController(MemoryAgendaStore(entries)),
         academics: AcademicController(academicStore),
         moocStorage: moocStorage ?? MemoryMoocStorage(),
       );

  final int? initialWeek;

  @override
  Future<void> initialize() async {
    await super.initialize();
    if (initialWeek case final week?) timetable.selectWeek(week);
  }
}

class _ClassroomScreenshotController extends _ScreenshotController {
  factory _ClassroomScreenshotController({
    required SemesterSchedule schedule,
    required List<AgendaEntry> entries,
    required AcademicRecord academicRecord,
  }) {
    final academicStore = MemoryAcademicStore();
    academicStore.accounts[_mockAccount] = academicRecord;
    final controller = _ClassroomScreenshotController._(
      schedule: schedule,
      entries: entries,
      academicStore: academicStore,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  _ClassroomScreenshotController._({
    required SemesterSchedule schedule,
    required super.entries,
    required super.academicStore,
  }) : super._(
         schedule: schedule,
         schedules: [schedule],
         moocStorage: MemoryMoocStorage(),
         initialWeek: null,
       );

  late final _MockClassroomRepository _mockClassrooms =
      _MockClassroomRepository(school);

  @override
  ClassroomRepository get classrooms => _mockClassrooms;
}

class _MockClassroomRepository extends ClassroomRepository {
  _MockClassroomRepository(super.school);

  static const _buildings = [
    SchoolBuilding(code: 'wca', name: '文萃楼A', campusCode: 'lx'),
    SchoolBuilding(code: 'wcb', name: '文萃楼B', campusCode: 'lx'),
    SchoolBuilding(code: 'zhj', name: '综合教学楼A', campusCode: 'lx'),
    SchoolBuilding(code: 'lkj', name: '理科教学楼', campusCode: 'lx'),
  ];

  @override
  Future<ClassroomDirectory?> directory({
    required VerifySchoolLogin verify,
    bool refresh = false,
    CancellationToken? cancellation,
  }) async => const ClassroomDirectory(
    campuses: [SchoolCampus(code: 'lx', name: '良乡校区')],
    buildings: _buildings,
  );

  @override
  Future<List<BuildingOccupancy>?> occupancy({
    required List<SchoolBuilding> buildings,
    required DateTime date,
    required VerifySchoolLogin verify,
    bool refresh = false,
    CancellationToken? cancellation,
  }) async => [
    BuildingOccupancy(
      building: _buildings[0],
      rooms: const [
        ClassroomOccupancy(name: 'A101', busySections: {1, 2, 6, 7, 8}),
        ClassroomOccupancy(name: 'A105', busySections: {3, 4, 5, 9, 10}),
        ClassroomOccupancy(name: 'A201', busySections: {1, 2, 3, 4}),
        ClassroomOccupancy(name: 'A305', busySections: {6, 7, 11, 12, 13}),
      ],
    ),
    BuildingOccupancy(
      building: _buildings[1],
      rooms: const [
        ClassroomOccupancy(name: 'B101', busySections: {1, 6, 7, 8}),
        ClassroomOccupancy(name: 'B203', busySections: {3, 4, 5, 11, 12}),
        ClassroomOccupancy(name: 'B305', busySections: {2, 3, 8, 9}),
      ],
    ),
    BuildingOccupancy(
      building: _buildings[2],
      rooms: const [
        ClassroomOccupancy(name: 'A201', busySections: {1, 2, 3, 4, 11}),
        ClassroomOccupancy(name: 'B103', busySections: {5, 6, 7, 8}),
        ClassroomOccupancy(name: 'B206', busySections: {9, 10, 12, 13}),
      ],
    ),
    BuildingOccupancy(
      building: _buildings[3],
      rooms: const [
        ClassroomOccupancy(name: '105', busySections: {1, 2, 3, 4, 5}),
        ClassroomOccupancy(name: '204', busySections: {6, 7, 8}),
        ClassroomOccupancy(name: '306', busySections: {11, 12, 13}),
      ],
    ),
  ];
}

SemesterSchedule _schedule() => SemesterSchedule(
  term: '2026-2027-1',
  firstMonday: DateTime.utc(2026, 8, 31),
  courses: [
    _course('高等数学 B（I）', 1, 1, 2, '综教A201', weeks: _weeks(1, 16)),
    _course('线性代数', 1, 3, 4, '综教B203', weeks: _weeks(1, 16)),
    _course('大学物理（I）', 1, 6, 7, '理科教学楼105', weeks: _weeks(1, 16)),
    _course('工程训练', 1, 11, 13, '工程训练中心102', weeks: _weeks(2, 14)),
    _course('程序设计基础', 2, 1, 2, '综教A305', weeks: _weeks(1, 16)),
    _course('数据结构', 2, 3, 4, '综教B103', weeks: _weeks(1, 16)),
    _course('大学英语', 2, 6, 7, '文萃楼B201', weeks: _weeks(1, 16)),
    _course('体育（III）', 2, 9, 10, '南区操场', weeks: _weeks(1, 16)),
    _course('概率论与数理统计', 3, 1, 2, '理科教学楼204', weeks: _weeks(1, 16)),
    _course('数字信号处理', 3, 3, 4, '综教A201', weeks: _weeks(1, 16)),
    _course('马克思主义基本原理', 3, 8, 9, '文萃楼C201', weeks: _weeks(1, 16)),
    _course('操作系统', 4, 1, 2, '文萃楼F704', weeks: _weeks(1, 16)),
    _course('数据结构实验', 4, 6, 7, '综合教学楼B205', weeks: _weeks(2, 15)),
    _course('大学物理实验', 4, 11, 12, '物理实验中心203', weeks: _weeks(3, 15)),
    _course('计算机网络', 5, 3, 4, '综教B203', weeks: _weeks(1, 16)),
    _course('形势与政策', 5, 6, 7, '文萃楼A305', weeks: _weeks(1, 12)),
  ],
  firstWeek: 1,
  lastWeek: 18,
);

SemesterSchedule _examSchedule() => SemesterSchedule(
  term: '2026-2027-1',
  firstMonday: DateTime.utc(2026, 8, 31),
  courses: [
    _course('数字信号处理', 3, 3, 4, '综教A201', weeks: [10]),
  ],
  firstWeek: 1,
  lastWeek: 18,
);

Course _course(
  String name,
  int weekday,
  int startSection,
  int endSection,
  String room, {
  required List<int> weeks,
}) => Course(
  id: name,
  name: name,
  teacher: '示例教师',
  room: room,
  campus: '良乡校区',
  weekday: weekday,
  startSection: startSection,
  endSection: endSection,
  weeks: weeks,
);

List<int> _weeks(int first, int last) => [
  for (var week = first; week <= last; week++) week,
];

List<AgendaEntry> _agendaEntries() => [
  AgendaEntry(
    id: 'deadline-ds',
    title: '数据结构实验报告',
    kind: AgendaKind.deadline,
    startsAt: DateTime.utc(2026, 10, 28, 23, 59),
    term: '2026-2027-1',
    local: false,
    source: DeadlineSource.lexue,
    course: '数据结构',
    notes: '提交实验报告和测试截图。',
  ),
  AgendaEntry(
    id: 'event-discussion',
    title: '小组项目讨论',
    kind: AgendaKind.event,
    startsAt: DateTime.utc(2026, 10, 28, 14),
    endsAt: DateTime.utc(2026, 10, 28, 16),
    location: '文萃楼C201',
    notes: '确认分工，整理原型。',
  ),
  AgendaEntry(
    id: 'deadline-linear',
    title: '线性代数第 5 章作业',
    kind: AgendaKind.deadline,
    startsAt: DateTime.utc(2026, 10, 29, 20),
    term: '2026-2027-1',
    local: false,
    source: DeadlineSource.eclass,
    course: '线性代数',
  ),
  AgendaEntry(
    id: 'event-club',
    title: '摄影社例会',
    kind: AgendaKind.event,
    startsAt: DateTime.utc(2026, 10, 29, 19),
    endsAt: DateTime.utc(2026, 10, 29, 20, 30),
    location: '文博中心 204',
  ),
  AgendaEntry(
    id: 'deadline-mooc',
    title: 'MOOC 单元测验',
    kind: AgendaKind.deadline,
    startsAt: DateTime.utc(2026, 10, 30, 22),
    term: '2026-2027-1',
    local: false,
    source: DeadlineSource.mooc,
    course: 'Python 程序设计',
  ),
  AgendaEntry(
    id: 'event-lab',
    title: '物理实验',
    kind: AgendaKind.event,
    startsAt: DateTime.utc(2026, 10, 30, 13, 20),
    endsAt: DateTime.utc(2026, 10, 30, 15),
    location: '物理实验中心203',
  ),
  AgendaEntry(
    id: 'deadline-physics',
    title: '预习报告：迈克尔逊干涉仪',
    kind: AgendaKind.deadline,
    startsAt: DateTime.utc(2026, 10, 31, 13, 20),
    term: '2026-2027-1',
    local: false,
    course: '大学物理实验',
  ),
  AgendaEntry(
    id: 'event-meeting',
    title: '班级班会',
    kind: AgendaKind.event,
    startsAt: DateTime.utc(2026, 10, 31, 18, 30),
    endsAt: DateTime.utc(2026, 10, 31, 19, 30),
    location: '文萃楼A105',
  ),
];

List<AgendaEntry> _examEntries() => [
  AgendaEntry(
    id: 'exam-dsp',
    title: '数字信号处理期中考试',
    kind: AgendaKind.exam,
    startsAt: DateTime.utc(2026, 11, 4, 9, 55),
    endsAt: DateTime.utc(2026, 11, 4, 11, 30),
    term: '2026-2027-1',
    location: '综教A201',
    local: false,
    notes: '闭卷考试，可携带计算器。',
  ),
  AgendaEntry(
    id: 'exam-signal',
    title: '信号与系统补考',
    kind: AgendaKind.exam,
    startsAt: DateTime.utc(2026, 11, 4, 10, 45),
    endsAt: DateTime.utc(2026, 11, 4, 12),
    term: '2026-2027-1',
    location: '综教B203',
    local: false,
  ),
  AgendaEntry(
    id: 'exam-calculus',
    title: '高等数学 B（I）期末考试',
    kind: AgendaKind.exam,
    startsAt: DateTime.utc(2026, 11, 11, 9),
    endsAt: DateTime.utc(2026, 11, 11, 11),
    term: '2026-2027-1',
    location: '综合教学楼A201',
    local: false,
  ),
];

AcademicRecord _academicRecord() => AcademicRecord(
  grades: [
    _grade('高等数学 B（I）', 'MATH101', '2025-2026-2', 5, '86', '必修', '数学与自然科学'),
    _grade('线性代数', 'MATH102', '2025-2026-2', 3, '91', '必修', '数学与自然科学'),
    _grade('大学物理（I）', 'PHYS101', '2025-2026-2', 4, '55', '必修', '数学与自然科学'),
    _grade('程序设计基础', 'CS101', '2025-2026-2', 3, '93', '必修', '专业基础'),
    _grade('大学英语', 'ENG101', '2025-2026-2', 2, '优秀', '必修', '通识课程'),
    _grade('数据结构', 'CS201', '2026-2027-1', 4, '88', '必修', '专业基础'),
    _grade('数字信号处理', 'EE201', '2026-2027-1', 3, '84', '必修', '专业课程'),
    _grade('马克思主义基本原理', 'MARX201', '2026-2027-1', 3, '良好', '必修', '通识课程'),
    _grade('体育（III）', 'PE301', '2026-2027-1', 1, '合格', '必修', '通识课程'),
    _grade('人工智能导论', 'AI101', '2026-2027-1', 2, '95', '选修', '专业课程'),
    _grade('摄影基础', 'ART101', '2025-2026-2', 2, '良', '校公选', '通识课程'),
  ],
  plan: const StudyPlan(
    major: '计算机科学与技术',
    year: '2024级',
    requiredCredits: 165,
    completedCredits: 96.5,
  ),
  gradesUpdatedAt: DateTime.utc(2026, 10, 30, 3, 20),
  planUpdatedAt: DateTime.utc(2026, 10, 30, 3, 22),
  targetCredits: 165,
  categoryTargets: const {
    '通识课程': 48,
    '数学与自然科学': 36,
    '专业基础': 36,
    '专业课程': 30,
    '实践环节': 15,
  },
);

CourseGrade _grade(
  String name,
  String number,
  String term,
  double credits,
  String result,
  String attribute,
  String category,
) => CourseGrade(
  id: number,
  number: number,
  name: name,
  term: term,
  credits: credits,
  result: result,
  attribute: attribute,
  category: category,
);

class _AndroidWidgetMock extends StatelessWidget {
  const _AndroidWidgetMock();

  static const _courseColors = [
    (Color(0xFFD7EFEF), Color(0xFF285E61)),
    (Color(0xFFF6EAC5), Color(0xFF705623)),
    (Color(0xFFF7E0D1), Color(0xFF79442C)),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE7DED2), Color(0xFFC8B5A6), Color(0xFF8EA9A4)],
            ),
          ),
        ),
        const Positioned(
          top: -180,
          right: -120,
          child: _WallpaperOrb(size: 520, color: Color(0x66FFF6EC)),
        ),
        const Positioned(
          bottom: -160,
          left: -100,
          child: _WallpaperOrb(size: 460, color: Color(0x55755545)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(80, 90, 80, 54),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '桌面日程表',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF2E2825),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '单列与双列布局，课程、DDL、活动和考试放在同一张卡片里。',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: const Color(0xA62E2825)),
              ),
              const Spacer(),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WidgetCard(wide: false),
                  SizedBox(width: 40),
                  _WidgetCard(wide: true),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.smartphone_rounded,
                    color: Color(0xB32E2825),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '模拟示意 · 数据为 Mock · 实际尺寸由桌面网格决定',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xB32E2825)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WallpaperOrb extends StatelessWidget {
  const _WallpaperOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({required this.wide});

  final bool wide;

  static const _entries = [
    ('高等数学 B（I）', '08:00  综教A201', 0),
    ('数据结构', '09:55  综教B103', 1),
    ('大学物理（I）', '13:20  理科教学楼105', 2),
    ('DDL 实验报告', '23:59  数据结构', 1),
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: wide ? 612 : 292,
    height: 292,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: const Color(0xFFFDFCFB),
      borderRadius: BorderRadius.circular(40),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 40,
          offset: Offset(0, 16),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '今天周三',
                style: TextStyle(
                  color: Color(0xFF242424),
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_entries.length}项',
              style: const TextStyle(
                color: Color(0xFFA85E3E),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: wide ? 2 : 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 8,
              mainAxisExtent: 100,
            ),
            itemCount: wide ? _entries.length : 2,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final colors = _AndroidWidgetMock._courseColors[entry.$3];
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.$1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.$2,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.$2.withValues(alpha: 0.8),
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
