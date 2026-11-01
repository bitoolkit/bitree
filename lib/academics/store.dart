import '../core/json.dart';
import '../core/storage/json_file.dart';
import 'model.dart';

class AcademicStore {
  final _file = const JsonFile('academics.json');

  Future<Map<String, dynamic>> _accounts() async =>
      await _file.read((value) => jsonObject(value, '学业数据')) ?? {};

  Future<AcademicRecord> read(String account) async =>
      await _file.read((value) {
        final saved = jsonObject(value, '学业数据')[account];
        return saved == null
            ? const AcademicRecord()
            : AcademicRecord.fromJson(jsonObject(saved, account));
      }) ??
      const AcademicRecord();

  Future<void> write(String account, AcademicRecord record) async {
    final accounts = await _accounts();
    accounts[account] = record.toJson();
    await _file.write(accounts);
  }
}
