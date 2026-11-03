import 'dart:convert';

import 'package:bitree/academics/model.dart';
import 'package:flutter_test/flutter_test.dart';

CourseGrade grade(
  String id,
  String result, {
  double credits = 3,
  String term = '2026-2027-1',
  String attribute = '必修',
  String category = '专业课',
}) => CourseGrade(
  id: id,
  number: id,
  name: id,
  term: term,
  credits: credits,
  result: result,
  attribute: attribute,
  category: category,
);

void main() {
  test('Non-percentage results survive import and persistence unchanged', () {
    const results = ['425', '100.5', '-1', '缓考', 'NaN', 'Infinity'];
    final record = AcademicRecord(
      grades: [
        grade('percent', '85'),
        for (final result in results) grade(result, result),
      ],
    );
    final restored = AcademicRecord.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );

    expect(restored.grades.map((course) => course.result), ['85', ...results]);
    for (final course in restored.grades.skip(1)) {
      expect(course.score, isNull, reason: course.result);
      expect(course.points, isNull, reason: course.result);
      expect(course.passed, isFalse, reason: course.result);
      expect(course.failed, isFalse, reason: course.result);
    }
    expect(restored.stats.gpa, 3.6);
    expect(restored.stats.averageScore, 85);
    expect(restored.stats.gpaCredits, 3);
    expect(restored.stats.earnedCredits, 3);
  });

  test('Only percentage scores and graded results contribute to GPA', () {
    final stats = AcademicStats([
      grade('zero', '0', credits: 1),
      grade('full', '100', credits: 1),
      grade('graded', '良好', credits: 1),
      grade('pass-fail', '合格', credits: 1),
      grade('other', '600', credits: 1),
    ]);

    expect(stats.gpa, closeTo(7.6 / 3, 1e-9));
    expect(stats.averageScore, 50);
    expect(stats.earnedCredits, 3);
    expect(stats.failed.map((course) => course.id), ['zero']);
  });

  test(
    'Score statistics use unique percentage courses and the 80 threshold',
    () {
      final stats = AcademicStats([
        grade('retake', '75', credits: 2),
        grade('retake', '90', credits: 2),
        grade('boundary', '80', credits: 3),
        grade('below', '79', credits: 1),
        grade('pass-fail', '合格', credits: 2),
      ]);

      expect(stats.scoredCourseCount, 3);
      expect(stats.coursesAtLeast80, 2);
      expect(stats.coursesAtLeast80Ratio, closeTo(2 / 3, 1e-9));
    },
  );

  test('Score share handles an empty percentage-course denominator', () {
    final stats = AcademicStats([
      grade('pass-fail', '合格'),
      grade('five-level', '良好'),
    ]);

    expect(stats.scoredCourseCount, 0);
    expect(stats.coursesAtLeast80, 0);
    expect(stats.coursesAtLeast80Ratio, isNull);
  });

  test('Grade scope combines semester, attribute, category, and course', () {
    final math = grade(
      'math',
      '88',
      term: '2026-2027-1',
      attribute: '必修',
      category: '专业课',
    );
    final physics = grade(
      'physics',
      '92',
      term: '2026-2027-2',
      attribute: '必修',
      category: '专业课',
    );
    final elective = grade(
      'elective',
      '85',
      term: '2026-2027-1',
      attribute: '选修',
      category: '通识课',
    );

    const empty = GradeScope();
    expect(empty.matches(math, category: '专业课'), isTrue);

    const scope = GradeScope(
      terms: {'2026-2027-1'},
      attributes: {'必修'},
      categories: {'专业课'},
      courseKeys: {'math'},
    );
    expect(scope.matches(math, category: '专业课'), isTrue);
    expect(scope.matches(physics, category: '专业课'), isFalse);
    expect(scope.matches(elective, category: '通识课'), isFalse);

    final record = AcademicRecord(
      grades: [math],
      categoryOverrides: {'math': '通识课'},
    );
    const categoryScope = GradeScope(categories: {'通识课'});
    expect(record.matchesScope(math, categoryScope), isTrue);
    expect(
      record.matchesScope(math, const GradeScope(categories: {'专业课'})),
      isFalse,
    );
  });
}
