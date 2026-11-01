import 'dart:convert';

import '../classrooms/model.dart';
import '../core/json.dart';
import '../schedule/model.dart';
import 'session.dart';

Future<ClassroomDirectory> fetchClassroomDirectory(
  SchoolSession session,
) async {
  await _openClassroomApp(session, 'kxjasbyMobile');

  final campuses = _rows(
    await session.json(
      'modules/jxllb/ggzdpx.do?dicCode=48682&SFSY=1&order=%2BDM',
      app: 'kxjasbyMobile',
    ),
    'ggzdpx',
  );
  final buildings = _rows(
    await session.json('modules/jxllb/cxjxl.do', app: 'kxjasbyMobile'),
    'cxjxl',
  );

  return ClassroomDirectory(
    campuses: [
      for (final row in campuses)
        SchoolCampus(
          code: jsonStringField(row, 'DM'),
          name: jsonStringField(row, 'MC'),
        ),
    ],
    buildings: [
      for (final row in buildings)
        if (jsonStringField(row, 'JXLMC').trim() != '文萃楼')
          SchoolBuilding(
            code: jsonStringField(row, 'JXLDM'),
            name: jsonStringField(row, 'JXLMC'),
            campusCode: jsonStringFieldOrNull(row, 'XXXQDM'),
          ),
    ],
  );
}

Future<List<BuildingOccupancy>> fetchClassroomOccupancy(
  SchoolSession session, {
  required List<SchoolBuilding> buildings,
  required DateTime date,
}) async {
  await _openClassroomApp(session, 'kxjas');

  // Use the school's calendar, independently of the user's local timetable.
  final current = await _query(session, 'dqxnxqcx');
  final termRows = [
    for (final row in jsonListField(current, 'rows'))
      jsonObject(row, 'dqxnxqcx.rows[]'),
  ];
  if (termRows.isEmpty) throw const FormatException('学校未返回当前学期');
  final term = termRows.first;
  final day = await _query(session, 'rqzhzcjc', {
    'RQ': dateText(date),
    'XN': jsonScalarField(term, 'XNDM'),
    'XQ': jsonScalarField(term, 'XQDM'),
  });

  final form = {
    'XNXQDM': jsonStringField(term, 'DM'),
    'ZC': jsonScalarField(day, 'ZC'),
    'XQ': jsonScalarField(day, 'XQJ'),
    'RQ': dateText(date),
  };

  final result = <BuildingOccupancy>[];
  for (final building in buildings) {
    result.add(
      BuildingOccupancy(
        building: building,
        rooms: await _buildingOccupancy(session, building.code, form),
      ),
    );
  }
  return result;
}

Future<List<ClassroomOccupancy>> _buildingOccupancy(
  SchoolSession session,
  String buildingCode,
  Map<String, String> date,
) async {
  const pageSize = 50;
  final form = {
    ...date,
    'querySetting': jsonEncode([
      {
        'name': 'JXLDM',
        'caption': '教学楼代码',
        'builder': 'equal',
        'linkOpt': 'AND',
        'value': buildingCode,
      },
    ]),
    '*order': '+JASMC',
    'pageSize': '$pageSize',
  };
  final rooms = <ClassroomOccupancy>[];
  var page = 1;
  while (true) {
    final response = await _query(session, 'cxjsqk', {
      ...form,
      'pageNumber': '$page',
    });
    final rows = [
      for (final row in jsonListField(response, 'rows'))
        jsonObject(row, 'cxjsqk.rows[]'),
    ];
    for (final row in rows) {
      rooms.add(
        ClassroomOccupancy(
          name: jsonStringField(row, 'JASMC'),
          busySections: {
            for (var section = 1; section <= sectionTimes.length; section++)
              // Each entry describes a booking; 1_ marks an occupied section.
              if ((row['JC$section']?.toString() ?? '')
                  .split(',')
                  .any((booking) => booking.startsWith('1_')))
                section,
          },
        ),
      );
    }
    final total = int.tryParse(response['totalSize'].toString());
    if (total == null) {
      throw const FormatException('教室查询结果缺少有效总数');
    }
    if (page * pageSize >= total) return rooms;
    page++;
  }
}

Future<void> _openClassroomApp(SchoolSession session, String app) async {
  await session.request(session.network.app, stopAtLogin: true);
  await session.request(
    session.network.endpoint(
      'api/getAppConfig/wdkbby-5959167891382285.do',
      app: 'funauthapp',
    ),
    stopAtLogin: true,
  );
  await session.request(
    session.network.timetableTranslations,
    stopAtLogin: true,
  );
  await session.request(
    session.network.endpoint('*default/index.do', app: app),
    stopAtLogin: true,
  );
}

Future<Map<String, dynamic>> _query(
  SchoolSession session,
  String name, [
  Map<String, String> form = const {},
]) async {
  final response = await session.json(
    'modules/kxjas/$name.do',
    app: 'kxjas',
    form: form,
  );
  return jsonObjectField(jsonObjectField(response, 'datas'), name);
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> response, String name) {
  final result = jsonObjectField(jsonObjectField(response, 'datas'), name);
  return [
    for (final row in jsonListField(result, 'rows'))
      jsonObject(row, '$name.rows[]'),
  ];
}
