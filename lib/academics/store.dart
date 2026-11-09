import '../core/json.dart';
import '../core/storage/json_file.dart';
import '../core/storage/schema.dart';
import 'model.dart';

class AcademicStore {
  final _file = const JsonFile('academics.json');

  Future<Map<String, dynamic>> _accounts() async {
    final document = await _file.read((value) => _decode(value));
    return document?.accounts ?? {};
  }

  ({Map<String, dynamic> accounts}) _decode(Object? value) {
    final document = jsonObject(value, '学业数据');
    final version = storageSchemaVersion(document);
    final accounts = version == 1
        ? document
        : jsonObjectField(document, 'accounts');
    return (accounts: accounts);
  }

  Future<AcademicRecord> read(String account) async =>
      await _file.read((value) {
        final saved = _decode(value).accounts[account];
        return saved == null
            ? const AcademicRecord()
            : AcademicRecord.fromJson(jsonObject(saved, account));
      }) ??
      const AcademicRecord();

  Future<void> write(String account, AcademicRecord record) async {
    final accounts = await _accounts();
    accounts[account] = record.toJson();
    await _file.write({
      'schemaVersion': currentStorageSchemaVersion,
      'accounts': accounts,
    });
  }
}
