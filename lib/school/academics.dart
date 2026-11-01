import 'dart:convert';

import 'package:html/parser.dart' as html;

import '../academics/model.dart';
import '../core/json.dart';
import 'network.dart';
import 'session.dart';

Future<List<CourseGrade>> fetchSchoolGrades(SchoolSession session) async {
  final url = session.network.route(
    SchoolNetwork.recordsService.resolve('jsxsd/kscj/cjcx_list'),
  );
  final response = await session.request(
    url,
    form: {'kksj': '', 'kcxz': '', 'kcmc': '', 'xsfs': 'all'},
    headers: {'Origin': url.origin},
    stopAtLogin: true,
  );
  final table = html.parse(response.text).querySelector('#dataList');
  if (table == null) throw const FormatException('成绩页面中没有成绩列表');

  return [
    for (final row in table.querySelectorAll('tr').skip(1))
      if (row.querySelectorAll('td') case final cells when cells.length >= 12)
        CourseGrade(
          id: jsonEncode([
            cells[1].text.trim(),
            cells[2].text.trim(),
            cells[3].text.trim(),
            cells[8].text.trim(),
            cells[4].text.trim(),
          ]),
          number: cells[2].text.trim(),
          name: cells[3].text.trim(),
          term: cells[1].text.trim(),
          result: cells[4].text.trim(),
          credits:
              double.tryParse(cells[6].text.trim()) ??
              (throw const FormatException('成绩页面中的学分格式不正确')),
          attribute: cells[10].text.trim(),
          category: cells[11].text.trim(),
          examType: cells[8].text.trim(),
        ),
  ];
}

Future<StudyPlan> fetchStudyPlan(SchoolSession session) async {
  await session.request(session.network.accountPage, stopAtLogin: true);
  await session.request(session.network.accountConfig, stopAtLogin: true);
  final response = await session.json(
    'modules/pyfacxepg/grpyfacx.do',
    app: 'xsfacx',
  );
  final rows = [
    for (final value in jsonListField(
      jsonObjectField(jsonObjectField(response, 'datas'), 'grpyfacx'),
      'rows',
    ))
      jsonObject(value, 'grpyfacx.rows[]'),
  ];
  if (rows.isEmpty) throw const FormatException('学校未返回培养方案');
  final row = rows.first;
  double? credits(Object? value) => value == null || value.toString().isEmpty
      ? null
      : double.tryParse(value.toString()) ??
            (throw const FormatException('培养方案中的学分格式不正确'));

  return StudyPlan(
    major: jsonStringFieldOrNull(row, 'ZYDM_DISPLAY') ?? '',
    year: jsonStringFieldOrNull(row, 'XZNJ_DISPLAY') ?? '',
    requiredCredits: credits(row['ZSYQXF']),
    completedCredits: credits(row['YWCXF']),
  );
}
