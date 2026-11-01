import 'dart:math' as math;

import '../core/json.dart';

const gpaRulesUrl =
    'https://soe.bit.edu.cn/rcpy/bk/ffa622a7030b45bdadf33415bdffa364.htm';

double gradePoints(double score) => score < 60
    ? 0
    : (10 * (4 - 3 * math.pow(100 - score, 2) / 1600)).round() / 10;

String creditText(double value) {
  final rounded = double.parse(value.toStringAsPrecision(10));
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : '$rounded';
}

class CourseGrade {
  CourseGrade({
    required this.id,
    required this.number,
    required this.name,
    required this.term,
    required this.credits,
    required this.result,
    required this.attribute,
    required this.category,
    this.examType = '',
  }) {
    if (!credits.isFinite || credits < 0) {
      throw const FormatException('课程学分不正确');
    }
  }

  final String id;
  final String number;
  final String name;
  final String term;
  final double credits;
  final String result;
  final String attribute;
  final String category;
  final String examType;

  String get courseKey => number.isEmpty ? name : number;
  double? get score {
    final numeric = double.tryParse(result);
    return numeric != null && numeric.isFinite && numeric >= 0 && numeric <= 100
        ? numeric
        : null;
  }

  double? get points => switch (result) {
    '优秀' => 4,
    '良好' => 3.6,
    '中等' => 2.8,
    '及格' => 1.7,
    '不及格' => 0,
    _ => score == null ? null : gradePoints(score!),
  };

  bool get passed => score != null
      ? score! >= 60
      : const {'优秀', '良好', '中等', '及格', '合格', '通过'}.contains(result);

  bool get failed => score != null
      ? score! < 60
      : const {'不及格', '不合格', '不通过'}.contains(result);

  bool get publicElective =>
      RegExp('校公选|公共选修|公选课|全校性选修').hasMatch('$attribute $category');

  bool get countsForGpa => points != null && !(publicElective && failed);

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'name': name,
    'term': term,
    'credits': credits,
    'result': result,
    'attribute': attribute,
    'category': category,
    'examType': examType,
  };

  factory CourseGrade.fromJson(Map<String, dynamic> json) => CourseGrade(
    id: jsonStringField(json, 'id'),
    number: jsonStringField(json, 'number'),
    name: jsonStringField(json, 'name'),
    term: jsonStringField(json, 'term'),
    credits: jsonDoubleField(json, 'credits'),
    result: jsonStringField(json, 'result'),
    attribute: jsonStringField(json, 'attribute'),
    category: jsonStringField(json, 'category'),
    examType: jsonStringField(json, 'examType'),
  );
}

List<CourseGrade> highestGrades(Iterable<CourseGrade> grades) {
  final best = <String, CourseGrade>{};
  for (final grade in grades) {
    final previous = best[grade.courseKey];
    if (previous == null ||
        (grade.passed && !previous.passed) ||
        (grade.passed == previous.passed &&
            (grade.points ?? -1) > (previous.points ?? -1)) ||
        (grade.points == previous.points &&
            (grade.score ?? -1) > (previous.score ?? -1))) {
      best[grade.courseKey] = grade;
    }
  }
  return best.values.toList();
}

class AcademicStats {
  AcademicStats(Iterable<CourseGrade> grades) : courses = highestGrades(grades);

  final List<CourseGrade> courses;

  double get earnedCredits => courses
      .where((course) => course.passed)
      .fold(0.0, (total, course) => total + course.credits);

  List<CourseGrade> get failed =>
      courses.where((course) => course.failed).toList();

  double get gpaCredits => courses
      .where((course) => course.countsForGpa)
      .fold(0.0, (total, course) => total + course.credits);

  double? get gpa {
    if (gpaCredits == 0) return null;
    return courses
            .where((course) => course.countsForGpa)
            .fold(
              0.0,
              (total, course) => total + course.points! * course.credits,
            ) /
        gpaCredits;
  }

  double? get averageScore {
    final numeric = courses.where((course) => course.score != null);
    final credits = numeric.fold(
      0.0,
      (total, course) => total + course.credits,
    );
    if (credits == 0) return null;
    return numeric.fold(
          0.0,
          (total, course) => total + course.score! * course.credits,
        ) /
        credits;
  }
}

class StudyPlan {
  const StudyPlan({
    required this.major,
    required this.year,
    required this.requiredCredits,
    required this.completedCredits,
  });

  final String major;
  final String year;
  final double? requiredCredits;
  final double? completedCredits;

  Map<String, Object?> toJson() => {
    'major': major,
    'year': year,
    'requiredCredits': requiredCredits,
    'completedCredits': completedCredits,
  };

  factory StudyPlan.fromJson(Map<String, dynamic> json) => StudyPlan(
    major: jsonStringField(json, 'major'),
    year: jsonStringField(json, 'year'),
    requiredCredits: jsonDoubleFieldOrNull(json, 'requiredCredits'),
    completedCredits: jsonDoubleFieldOrNull(json, 'completedCredits'),
  );
}

class AcademicRecord {
  const AcademicRecord({
    this.grades = const [],
    this.plan,
    this.gradesUpdatedAt,
    this.planUpdatedAt,
    this.targetCredits,
    this.categoryTargets = const {},
    this.categoryOverrides = const {},
  });

  final List<CourseGrade> grades;
  final StudyPlan? plan;
  final DateTime? gradesUpdatedAt;
  final DateTime? planUpdatedAt;
  final double? targetCredits;
  final Map<String, double> categoryTargets;
  final Map<String, String> categoryOverrides;

  AcademicStats get stats => AcademicStats(grades);

  String categoryOf(CourseGrade grade) =>
      categoryOverrides[grade.courseKey] ??
      (grade.category.isEmpty ? '未分类' : grade.category);

  AcademicRecord copyWith({
    List<CourseGrade>? grades,
    StudyPlan? plan,
    DateTime? gradesUpdatedAt,
    DateTime? planUpdatedAt,
    Map<String, String>? categoryOverrides,
  }) => AcademicRecord(
    grades: grades ?? this.grades,
    plan: plan ?? this.plan,
    gradesUpdatedAt: gradesUpdatedAt ?? this.gradesUpdatedAt,
    planUpdatedAt: planUpdatedAt ?? this.planUpdatedAt,
    targetCredits: targetCredits,
    categoryTargets: categoryTargets,
    categoryOverrides: categoryOverrides ?? this.categoryOverrides,
  );

  AcademicRecord withCreditTargets({
    required double? total,
    required Map<String, double> categories,
  }) => AcademicRecord(
    grades: grades,
    plan: plan,
    gradesUpdatedAt: gradesUpdatedAt,
    planUpdatedAt: planUpdatedAt,
    targetCredits: total,
    categoryTargets: categories,
    categoryOverrides: categoryOverrides,
  );

  Map<String, Object?> toJson() => {
    'grades': grades.map((grade) => grade.toJson()).toList(),
    'plan': plan?.toJson(),
    'gradesUpdatedAt': gradesUpdatedAt?.toIso8601String(),
    'planUpdatedAt': planUpdatedAt?.toIso8601String(),
    'targetCredits': targetCredits,
    'categoryTargets': categoryTargets,
    'categoryOverrides': categoryOverrides,
  };

  factory AcademicRecord.fromJson(Map<String, dynamic> json) => AcademicRecord(
    grades: [
      for (final row in jsonListField(json, 'grades'))
        CourseGrade.fromJson(jsonObject(row, 'grades[]')),
    ],
    plan: json['plan'] == null
        ? null
        : StudyPlan.fromJson(jsonObjectField(json, 'plan')),
    gradesUpdatedAt: jsonDateTimeOrNull(
      'gradesUpdatedAt',
      json['gradesUpdatedAt'],
    ),
    planUpdatedAt: jsonDateTimeOrNull('planUpdatedAt', json['planUpdatedAt']),
    targetCredits: jsonDoubleFieldOrNull(json, 'targetCredits'),
    categoryTargets: {
      for (final entry in jsonObjectField(json, 'categoryTargets').entries)
        entry.key: jsonDouble(entry.value, 'categoryTargets.${entry.key}'),
    },
    categoryOverrides: {
      for (final entry in jsonObjectField(json, 'categoryOverrides').entries)
        entry.key: jsonString(entry.value, 'categoryOverrides.${entry.key}'),
    },
  );
}

class ProjectedCourse {
  const ProjectedCourse({
    required this.id,
    required this.name,
    required this.credits,
    required this.score,
    this.replaces,
  });

  final String id;
  final String name;
  final double credits;
  final double score;
  final String? replaces;
}

AcademicStats projectGrades(
  Iterable<CourseGrade> grades,
  Iterable<ProjectedCourse> projected, {
  required bool replaceRetakes,
  double? uniformScore,
}) {
  final originals = {for (final grade in grades) grade.courseKey: grade};
  return AcademicStats([
    ...grades,
    for (final course in projected)
      CourseGrade(
        id: course.id,
        number: replaceRetakes ? course.replaces ?? course.id : course.id,
        name: course.name,
        term: '试算',
        credits: course.credits,
        result: (uniformScore ?? course.score).toString(),
        attribute: originals[course.replaces]?.attribute ?? '',
        category: originals[course.replaces]?.category ?? '',
      ),
  ]);
}

int? scoreForTarget(
  Iterable<CourseGrade> grades,
  List<ProjectedCourse> projected, {
  required double target,
  required bool replaceRetakes,
}) {
  if (projected.isEmpty) return null;
  for (var score = 0; score <= 100; score++) {
    final gpa = projectGrades(
      grades,
      projected,
      replaceRetakes: replaceRetakes,
      uniformScore: score.toDouble(),
    ).gpa;
    if (gpa != null && gpa + 1e-9 >= target) return score;
  }
  return null;
}
