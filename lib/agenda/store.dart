import '../core/json.dart';
import '../core/platform/desktop_widget.dart';
import '../core/storage/json_file.dart';
import 'model.dart';

class AgendaStore {
  final _file = const JsonFile('agenda.json');

  Future<List<AgendaEntry>> read() async =>
      await _file.read(
        (value) => [
          for (final row in jsonList(value, '日程'))
            AgendaEntry.fromJson(jsonObject(row, '日程[]')),
        ],
      ) ??
      const [];

  Future<void> write(List<AgendaEntry> entries) async {
    await _file.write(entries.map((entry) => entry.toJson()).toList());
    refreshDesktopWidget();
  }
}
