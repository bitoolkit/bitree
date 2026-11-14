import '../core/json.dart';
import '../core/storage/json_file.dart';
import '../core/storage/schema.dart';
import 'model.dart';

class AcademicStore {
  final _file = const JsonFile('academics.json');

  ({Map<String, dynamic> accounts, bool legacy}) _decode(Object? value) {
    final document = jsonObject(value, '学业数据');
    final version = storageSchemaVersion(document);
    final accounts = version == 1
        ? (Map<String, dynamic>.of(document)..remove('schemaVersion'))
        : jsonObjectField(document, 'accounts');
    return (accounts: accounts, legacy: version < currentStorageSchemaVersion);
  }

  Future<AcademicRecord> readAndMigrate(String account) async {
    final stored = await _file.read((value) {
      final document = _decode(value);
      final saved = document.accounts[account];
      return (
        record: saved == null
            ? const AcademicRecord()
            : AcademicRecord.fromJson(jsonObject(saved, account)),
        accounts: document.accounts,
        legacy: document.legacy,
      );
    });
    if (stored == null) return const AcademicRecord();
    if (stored.legacy) await _writeAccounts(stored.accounts);
    return stored.record;
  }

  Future<void> write(String account, AcademicRecord record) async {
    final stored = await _file.read(_decode);
    final accounts = stored?.accounts ?? {};
    accounts[account] = record.toJson();
    await _writeAccounts(accounts);
  }

  Future<void> _writeAccounts(Map<String, dynamic> accounts) => _file.write({
    'schemaVersion': currentStorageSchemaVersion,
    'accounts': accounts,
  });
}
