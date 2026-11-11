import '../json.dart';

const currentStorageSchemaVersion = 2;

int storageSchemaVersion(Map<String, dynamic> json) {
  final raw = json['schemaVersion'];
  if (raw == null) return 1;
  final version = jsonInt(raw, 'schemaVersion');
  if (version < 1 || version > currentStorageSchemaVersion) {
    throw FormatException('不支持的数据版本：$version');
  }
  return version;
}
