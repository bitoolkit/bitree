import 'dart:convert';

/// Receives one complete platform course list and returns the courses to read.
typedef CourseChooser =
    Future<List<PlatformCourse>> Function(List<PlatformCourse> discovered);

/// A course discovered from a platform or added by the user. A manual course
/// survives later discovery results that no longer contain it.
class PlatformCourse {
  PlatformCourse({
    required this.remoteId,
    required this.name,
    this.url,
    this.remoteTermId,
    this.params = const {},
    this.manual = false,
    this.discovered = true,
    this.selected = true,
  }) {
    if (remoteId.trim().isEmpty || name.trim().isEmpty) {
      throw const FormatException('平台课程缺少编号或名称');
    }
    final courseUrl = url;
    if (courseUrl != null &&
        (courseUrl.scheme != 'https' || courseUrl.userInfo.isNotEmpty)) {
      throw const FormatException('平台课程链接必须是无用户信息的 HTTPS 地址');
    }
  }

  factory PlatformCourse.fromJson(Map<String, dynamic> json) => PlatformCourse(
    remoteId: _stringField(json, 'remoteId'),
    name: _stringField(json, 'name'),
    url: _urlField(json, 'url'),
    remoteTermId: _stringFieldOrNull(json, 'remoteTermId'),
    params: _jsonMap(json['params'], 'params'),
    manual: json['manual'] == true,
    discovered: json['discovered'] != false,
    selected: json['selected'] != false,
  );

  final String remoteId;
  final String name;
  final Uri? url;
  final String? remoteTermId;
  final Map<String, dynamic> params;
  final bool manual;
  final bool discovered;
  final bool selected;

  PlatformCourse copyWith({
    String? name,
    Object? url = _unset,
    Object? remoteTermId = _unset,
    Map<String, dynamic>? params,
    bool? manual,
    bool? discovered,
    bool? selected,
  }) => PlatformCourse(
    remoteId: remoteId,
    name: name ?? this.name,
    url: identical(url, _unset) ? this.url : url as Uri?,
    remoteTermId: identical(remoteTermId, _unset)
        ? this.remoteTermId
        : remoteTermId as String?,
    params: params ?? this.params,
    manual: manual ?? this.manual,
    discovered: discovered ?? this.discovered,
    selected: selected ?? this.selected,
  );

  Map<String, Object?> toJson() => {
    'remoteId': remoteId,
    'name': name,
    if (url != null) 'url': url.toString(),
    if (remoteTermId != null) 'remoteTermId': remoteTermId,
    if (params.isNotEmpty) 'params': params,
    if (manual) 'manual': true,
    if (!discovered) 'discovered': false,
    if (!selected) 'selected': false,
  };
}

/// Links a platform course to a saved local timetable row. Both sides keep
/// their own identity, so renaming either course does not break the link.
class CourseLink {
  CourseLink({required this.localCourseId, required this.remoteId}) {
    if (localCourseId.trim().isEmpty || remoteId.trim().isEmpty) {
      throw const FormatException('课程关联缺少本地或平台编号');
    }
  }

  factory CourseLink.fromJson(Map<String, dynamic> json) => CourseLink(
    localCourseId: _stringField(json, 'localCourseId'),
    remoteId: _stringField(json, 'remoteId'),
  );

  final String localCourseId;
  final String remoteId;

  String get key => jsonEncode([localCourseId, remoteId]);

  Map<String, Object?> toJson() => {
    'localCourseId': localCourseId,
    'remoteId': remoteId,
  };
}

/// Course list and local-course links for one source instance. Discovery
/// replaces the automatic part of the list, while manual additions and their
/// selected state survive.
class SourceCourseSelection {
  SourceCourseSelection({
    required this.sourceInstanceId,
    Iterable<PlatformCourse> courses = const [],
    Iterable<CourseLink> links = const [],
  }) : _courses = {
         for (final course in courses) course.remoteId: course,
       },
       _links = {for (final link in links) link.key: link} {
    if (sourceInstanceId.trim().isEmpty) {
      throw const FormatException('课程选择缺少来源实例');
    }
  }

  factory SourceCourseSelection.fromJson(Map<String, dynamic> json) =>
      SourceCourseSelection(
        sourceInstanceId: _stringField(json, 'sourceInstanceId'),
        courses: [
          for (final row in _rows(json['courses'], 'courses'))
            PlatformCourse.fromJson(_jsonMap(row, 'courses[]')),
        ],
        links: [
          for (final row in _rows(json['links'], 'links'))
            CourseLink.fromJson(_jsonMap(row, 'links[]')),
        ],
      );

  final String sourceInstanceId;
  final Map<String, PlatformCourse> _courses;
  final Map<String, CourseLink> _links;

  List<PlatformCourse> get courses => _courses.values.toList()
    ..sort((left, right) {
      final name = left.name.compareTo(right.name);
      return name != 0 ? name : left.remoteId.compareTo(right.remoteId);
    });

  List<PlatformCourse> get selectedCourses => [
    for (final course in courses)
      if (course.selected) course,
  ];

  List<CourseLink> get links => _links.values.toList()
    ..sort((left, right) {
      final local = left.localCourseId.compareTo(right.localCourseId);
      return local != 0 ? local : left.remoteId.compareTo(right.remoteId);
    });

  PlatformCourse? course(String remoteId) => _courses[remoteId];

  /// Applies one complete discovery result. Automatic courses that disappeared
  /// from the list are removed; manually added courses remain.
  void mergeDiscovered(Iterable<PlatformCourse> discovered) {
    final next = <String, PlatformCourse>{};
    for (final incoming in discovered) {
      final existing = _courses[incoming.remoteId];
      next[incoming.remoteId] = incoming.copyWith(
        manual: existing?.manual ?? incoming.manual,
        discovered: true,
        selected: existing?.selected ?? incoming.selected,
      );
    }
    for (final existing in _courses.values) {
      if (existing.manual && !next.containsKey(existing.remoteId)) {
        next[existing.remoteId] = existing;
      }
    }
    _courses
      ..clear()
      ..addAll(next);
    _links.removeWhere((_, link) => !_courses.containsKey(link.remoteId));
  }

  void addManual(PlatformCourse course) {
    final existing = _courses[course.remoteId];
    _courses[course.remoteId] = course.copyWith(
      manual: true,
      discovered: existing?.discovered ?? course.discovered,
      selected: true,
    );
  }

  /// Removes a manual addition without deleting an automatically discovered
  /// course with the same identity.
  void removeManual(String remoteId) {
    final existing = _courses[remoteId];
    if (existing == null || !existing.manual) return;
    if (existing.discovered) {
      _courses[remoteId] = existing.copyWith(manual: false);
    } else {
      _courses.remove(remoteId);
      _links.removeWhere((_, link) => link.remoteId == remoteId);
    }
  }

  void setSelected(String remoteId, bool selected) {
    final existing = _courses[remoteId];
    if (existing == null) throw FormatException('未知的平台课程：$remoteId');
    _courses[remoteId] = existing.copyWith(selected: selected);
  }

  void link({required String localCourseId, required String remoteId}) {
    if (!_courses.containsKey(remoteId)) {
      throw FormatException('未知的平台课程：$remoteId');
    }
    final link = CourseLink(
      localCourseId: localCourseId,
      remoteId: remoteId,
    );
    _links[link.key] = link;
  }

  void unlink({required String localCourseId, required String remoteId}) {
    _links.remove(CourseLink(
      localCourseId: localCourseId,
      remoteId: remoteId,
    ).key);
  }

  void unlinkLocal(String localCourseId) {
    _links.removeWhere((_, link) => link.localCourseId == localCourseId);
  }

  void unlinkRemote(String remoteId) {
    _links.removeWhere((_, link) => link.remoteId == remoteId);
  }

  List<String> remoteIdsForLocal(String localCourseId) => [
    for (final link in links)
      if (link.localCourseId == localCourseId) link.remoteId,
  ];

  List<String> localIdsForRemote(String remoteId) => [
    for (final link in links)
      if (link.remoteId == remoteId) link.localCourseId,
  ];

  Map<String, Object?> toJson() => {
    'sourceInstanceId': sourceInstanceId,
    'courses': [for (final course in courses) course.toJson()],
    'links': [for (final link in links) link.toJson()],
  };
}

const _unset = Object();

String _stringField(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key 缺失');
}

String? _stringFieldOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key 格式不正确');
}

Uri? _urlField(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) {
    final url = Uri.tryParse(value);
    if (url != null) return url;
  }
  throw FormatException('$key 格式不正确');
}

Map<String, dynamic> _jsonMap(Object? value, String field) {
  if (value == null) return const {};
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, dynamic>.from(value);
  }
  throw FormatException('$field 格式不正确');
}

Iterable<Object?> _rows(Object? value, String field) {
  if (value == null) return const [];
  if (value is List) return value;
  throw FormatException('$field 格式不正确');
}
