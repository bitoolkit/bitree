import '../agenda/deadline_source.dart';

/// Display rules applied by the prelude's `bitree.display` module before any
/// custom `filter(data)` script.
class AutomationRules {
  AutomationRules({
    Map<String, String> courseAliases = const {},
    Set<DeadlineSource> hiddenDeadlineSources = const {},
    String examTitlePrefix = '',
  }) : courseAliases = Map.unmodifiable({
         for (final entry in courseAliases.entries)
           if (entry.key.trim().isNotEmpty &&
               entry.value.trim().isNotEmpty &&
               entry.value.trim() != entry.key)
             entry.key: entry.value.trim(),
       }),
       hiddenDeadlineSources = Set.unmodifiable(hiddenDeadlineSources),
       examTitlePrefix = examTitlePrefix.trim();

  factory AutomationRules.fromJson(Map<String, dynamic> json) {
    final aliases = json['courseAliases'] ?? const <String, dynamic>{};
    if (aliases is! Map<String, dynamic>) {
      throw const FormatException('courseAliases must be an object.');
    }
    final sources = json['hiddenDeadlineSources'] ?? const <dynamic>[];
    if (sources is! List) {
      throw const FormatException('hiddenDeadlineSources must be an array.');
    }
    final prefix = json['examTitlePrefix'] ?? '';
    if (prefix is! String) {
      throw const FormatException('examTitlePrefix must be a string.');
    }
    final hidden = <DeadlineSource>{};
    for (final value in sources) {
      DeadlineSource? source;
      if (value is String) {
        for (final candidate in DeadlineSource.values) {
          if (candidate.name == value) {
            source = candidate;
            break;
          }
        }
      }
      if (source == null) {
        throw const FormatException('Unknown deadline source.');
      }
      hidden.add(source);
    }
    return AutomationRules(
      courseAliases: {
        for (final entry in aliases.entries)
          if (entry.value is String) entry.key: entry.value as String,
      },
      hiddenDeadlineSources: hidden,
      examTitlePrefix: prefix,
    );
  }

  final Map<String, String> courseAliases;
  final Set<DeadlineSource> hiddenDeadlineSources;
  final String examTitlePrefix;

  bool get isEmpty =>
      courseAliases.isEmpty &&
      hiddenDeadlineSources.isEmpty &&
      examTitlePrefix.isEmpty;

  AutomationRules copyWith({
    Map<String, String>? courseAliases,
    Set<DeadlineSource>? hiddenDeadlineSources,
    String? examTitlePrefix,
  }) => AutomationRules(
    courseAliases: courseAliases ?? this.courseAliases,
    hiddenDeadlineSources: hiddenDeadlineSources ?? this.hiddenDeadlineSources,
    examTitlePrefix: examTitlePrefix ?? this.examTitlePrefix,
  );

  Map<String, dynamic> toJson() => {
    if (courseAliases.isNotEmpty) 'courseAliases': courseAliases,
    if (hiddenDeadlineSources.isNotEmpty)
      'hiddenDeadlineSources': [
        for (final source in hiddenDeadlineSources) source.name,
      ],
    if (examTitlePrefix.isNotEmpty) 'examTitlePrefix': examTitlePrefix,
  };
}
