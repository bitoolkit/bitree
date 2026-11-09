import 'dart:io';

import 'package:bitree/school/learning/eclass_deadlines.dart';
import 'package:bitree/school/learning/lexue_deadlines.dart';
import 'package:bitree/school/network.dart';
import 'package:bitree/school/session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/http.dart';
import 'support/test_app.dart';

void main() {
  test('Eclass course discovery returns stable course references', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.uri.path, '/zy-eclass.bit.edu.cn/api/my-courses');
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"courses":[{"id":20759,"name":"大学物理AⅡ"}]}');
      await request.response.close();
    });

    SchoolSession? session;
    addTearDown(() => session?.close());
    final courses = await HttpOverrides.runWithHttpOverrides(() {
      session = SchoolSession(
        network: SchoolNetwork.campus,
        storage: MemorySchoolStorage(),
      );
      return fetchEclassCourses(session!);
    }, LocalHttpOverrides(server.port));

    expect(courses, hasLength(1));
    expect(courses.single.remoteId, '20759');
    expect(courses.single.name, '大学物理AⅡ');
    expect(
      courses.single.url.toString(),
      'https://zy-eclass.bit.edu.cn/course/20759',
    );
  });

  test('Lexue course discovery keeps course IDs and links', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.uri.path, '/lexue.bit.edu.cn/my/');
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<a href="/course/view.php?id=18553">概率论与数理统计</a>',
      );
      await request.response.close();
    });

    SchoolSession? session;
    addTearDown(() => session?.close());
    final courses = await HttpOverrides.runWithHttpOverrides(() {
      session = SchoolSession(
        network: SchoolNetwork.campus,
        storage: MemorySchoolStorage(),
      );
      return fetchLexueCourses(session!);
    }, LocalHttpOverrides(server.port));

    expect(courses, hasLength(1));
    expect(courses.single.remoteId, '18553');
    expect(courses.single.name, '概率论与数理统计');
    expect(
      courses.single.url.toString(),
      'https://lexue.bit.edu.cn/course/view.php?id=18553',
    );
  });
}
