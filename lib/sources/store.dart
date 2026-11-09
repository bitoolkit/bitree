import '../core/json.dart';
import '../core/storage/json_file.dart';
import 'course_selection.dart';
import 'source.dart';

class SourceLibrary {
  const SourceLibrary({
    this.accounts = const [],
    this.instances = const [],
    this.selections = const {},
  });

  final List<SourceAccount> accounts;
  final List<SourceInstance> instances;
  final Map<String, SourceCourseSelection> selections;

  Map<String, Object?> toJson() => {
    'accounts': [for (final account in accounts) account.toJson()],
    'instances': [for (final instance in instances) instance.toJson()],
    'selections': [
      for (final selection in selections.values) selection.toJson(),
    ],
  };
}

class SourceStore {
  const SourceStore();

  final JsonFile _file = const JsonFile('sources.json');

  Future<SourceLibrary> read() async =>
      await _file.read(_decode) ?? const SourceLibrary();

  SourceLibrary _decode(Object? value) {
    final json = jsonObject(value, '数据来源');
    return SourceLibrary(
      accounts: [
        for (final row in jsonListField(json, 'accounts'))
          SourceAccount.fromJson(jsonObject(row, 'accounts[]')),
      ],
      instances: [
        for (final row in jsonListField(json, 'instances'))
          SourceInstance.fromJson(jsonObject(row, 'instances[]')),
      ],
      selections: {
        for (final row in jsonListField(json, 'selections'))
          if (SourceCourseSelection.fromJson(
            jsonObject(row, 'selections[]'),
          ) case final selection)
            selection.sourceInstanceId: selection,
      },
    );
  }

  Future<void> write(SourceLibrary library) => _file.write(library.toJson());

  Future<void> clear() => _file.delete();
}
