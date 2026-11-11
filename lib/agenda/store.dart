import '../core/json.dart';
import '../core/platform/desktop_widget.dart';
import '../core/storage/json_file.dart';
import '../core/storage/schema.dart';
import 'model.dart';

class AgendaStore {
  final _file = const JsonFile('agenda.json');

  Future<List<AgendaEntry>> readAndMigrate() async {
    final stored = await _file.read(
      (value) => (entries: _decode(value), legacy: value is List),
    );
    if (stored == null) return const [];
    if (stored.legacy) await write(stored.entries);
    return stored.entries;
  }

  List<AgendaEntry> _decode(Object? value) {
    final rows = value is List
        ? jsonList(value, '日程')
        : _documentRows(jsonObject(value, '日程'));
    return [
      for (final row in rows) AgendaEntry.fromJson(jsonObject(row, '日程[]')),
    ];
  }

  List<dynamic> _documentRows(Map<String, dynamic> document) {
    final version = storageSchemaVersion(document);
    if (version != currentStorageSchemaVersion) {
      throw const FormatException('日程数据版本不正确');
    }
    return jsonListField(document, 'entries');
  }

  Future<void> write(List<AgendaEntry> entries) async {
    await _file.write({
      'schemaVersion': currentStorageSchemaVersion,
      'entries': entries.map((entry) => entry.toJson()).toList(),
    });
    refreshDesktopWidget();
  }
}
