import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import 'tasks.dart';

({({String id, String name})? user, String? failure}) parseMoocWebUser(
  String source,
) {
  var failure = 'account-script-missing';
  for (final script
      in html_parser
          .parse(source)
          .getElementsByTagName('script')
          .map((element) => element.text)) {
    final assignment = RegExp(
      r'\bwindow\.webUser\s*=\s*\{',
    ).firstMatch(script);
    if (assignment == null) continue;
    failure = 'account-script-unbalanced';
    final object = _balancedObject(script, assignment.end - 1);
    if (object == null) continue;
    // MOOC emits a data object with unquoted property names and JSON strings.
    // Quote only the property names; leave string contents untouched.
    final json = object.replaceAllMapped(
      RegExp(r'"(?:\\.|[^"\\])*"|([a-zA-Z_$][\w$]*)\s*:'),
      (match) => match[1] == null ? match[0]! : '"${match[1]}":',
    );
    try {
      final value = moocMap(jsonDecode(json));
      final id = moocId(value?['id']);
      final name = value?['nickName'] ?? value?['name'];
      if (id != null && name is String && name.trim().isNotEmpty) {
        return (user: (id: id, name: name), failure: null);
      }
      failure = 'account-fields-missing';
    } on FormatException {
      failure = 'account-script-invalid';
      continue;
    }
  }
  return (user: null, failure: failure);
}

String? _balancedObject(String source, int start) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = start; index < source.length; index++) {
    final code = source.codeUnitAt(index);
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (code == 0x5c) {
        escaped = true;
      } else if (code == 0x22) {
        inString = false;
      }
      continue;
    }
    if (code == 0x22) {
      inString = true;
    } else if (code == 0x7b) {
      depth++;
    } else if (code == 0x7d) {
      depth--;
      if (depth == 0) return source.substring(start, index + 1);
    }
  }
  return null;
}
