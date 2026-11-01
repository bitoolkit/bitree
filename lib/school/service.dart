import 'dart:convert';

import '../agenda/model.dart';
import '../core/async/read_cache.dart';
import '../core/json.dart';
import '../schedule/model.dart';
import 'exams.dart';
import 'schedule.dart';
import 'session.dart';

class SchoolService {
  final _currentTerms = ReadCache<String, String>(
    maxAge: const Duration(hours: 1),
  );
  final _availableTerms = ReadCache<String, List<String>>(
    maxAge: const Duration(hours: 1),
  );

  Future<({SemesterSchedule schedule, List<String> terms})> synchronize(
    SchoolSession session, {
    required String account,
    String? term,
  }) async {
    await session.request(session.network.app, stopAtLogin: true);
    final selectedTerm = term ?? await _currentTerm(session, account);
    final terms = await _availableTerms.read(account, () async {
      final response = await session.json('modules/jshkcb/xnxqcx.do');
      return _rows(
        response,
        'xnxqcx',
      ).map((row) => jsonStringField(row, 'DM')).toList();
    });
    final calendar = await session.json(
      'wdkbByController/cxzkbrq.do',
      form: {
        'requestParamStr': jsonEncode({'XNXQDM': selectedTerm, 'ZC': '1'}),
      },
    );
    final monday = jsonListField(calendar, 'data')
        .map((row) => jsonObject(row, 'data[]'))
        .where((row) => jsonScalarField(row, 'XQ') == '1')
        .firstOrNull;
    if (monday == null) {
      throw const FormatException('学校日历缺少第一周周一');
    }
    final response = await session.json(
      'modules/xskcb/cxxszhxqkb.do',
      form: {'XNXQDM': selectedTerm},
    );
    return (
      schedule: parseSchoolSchedule(
        term: selectedTerm,
        termStartMonday: jsonDateTime('RQ', monday['RQ']),
        rows: _rows(response, 'cxxszhxqkb'),
      ),
      terms: terms,
    );
  }

  Future<({String term, List<AgendaEntry> exams})> exams(
    SchoolSession session, {
    required String account,
    String? term,
  }) async {
    if (term == null) {
      await session.request(session.network.app, stopAtLogin: true);
      term = await _currentTerm(session, account);
    }
    return fetchSchoolExams(session, term: term);
  }

  Future<String> _currentTerm(SchoolSession session, String account) =>
      _currentTerms.read(account, () async {
        final response = await session.json('modules/jshkcb/dqxnxq.do');
        final rows = _rows(response, 'dqxnxq');
        if (rows.isEmpty) throw const FormatException('学校未返回当前学期');
        return jsonStringField(rows.first, 'DM');
      });

  void clearCache() {
    _currentTerms.clear();
    _availableTerms.clear();
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> response, String key) {
    final app = jsonObjectField(jsonObjectField(response, 'datas'), key);
    return [
      for (final row in jsonListField(app, 'rows'))
        jsonObject(row, '$key.rows[]'),
    ];
  }
}
