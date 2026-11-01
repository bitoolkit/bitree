Map<String, dynamic> jsonObject(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map && value.keys.every((key) => key is String)) {
    return Map<String, dynamic>.from(value);
  }
  throw FormatException('$field 格式不正确');
}

List<dynamic> jsonList(Object? value, String field) {
  if (value is List) return value;
  throw FormatException('$field 格式不正确');
}

String jsonString(Object? value, String field) {
  if (value is String) return value;
  throw FormatException('$field 格式不正确');
}

String jsonScalarString(Object? value, String field) {
  if (value is String) return value;
  if (value is num) return value.toString();
  throw FormatException('$field 格式不正确');
}

String? jsonStringOrNull(Object? value, String field) =>
    value == null ? null : jsonString(value, field);

bool jsonBool(Object? value, String field, {bool? fallback}) {
  if (value is bool) return value;
  if (value == null && fallback != null) return fallback;
  throw FormatException('$field 格式不正确');
}

int jsonInt(Object? value, String field) {
  if (value is int) return value;
  throw FormatException('$field 格式不正确');
}

int? jsonIntOrNull(Object? value, String field) =>
    value == null ? null : jsonInt(value, field);

double jsonDouble(Object? value, String field) {
  if (value is num) return value.toDouble();
  throw FormatException('$field 格式不正确');
}

double? jsonDoubleOrNull(Object? value, String field) {
  if (value == null) return null;
  return jsonDouble(value, field);
}

DateTime jsonDateTime(String field, Object? value) {
  final text = jsonString(value, field);
  final parsed = DateTime.tryParse(text);
  if (parsed == null) throw FormatException('$field 时间格式不正确');
  return parsed;
}

DateTime? jsonDateTimeOrNull(String field, Object? value) =>
    value == null ? null : jsonDateTime(field, value);

Map<String, dynamic> jsonObjectField(Map<String, dynamic> json, String key) =>
    jsonObject(json[key], key);

List<dynamic> jsonListField(Map<String, dynamic> json, String key) =>
    jsonList(json[key], key);

String jsonStringField(Map<String, dynamic> json, String key) =>
    jsonString(json[key], key);

String jsonScalarField(Map<String, dynamic> json, String key) =>
    jsonScalarString(json[key], key);

String? jsonStringFieldOrNull(Map<String, dynamic> json, String key) =>
    jsonStringOrNull(json[key], key);

bool jsonBoolField(Map<String, dynamic> json, String key, {bool? fallback}) =>
    jsonBool(json[key], key, fallback: fallback);

int jsonIntField(Map<String, dynamic> json, String key) =>
    jsonInt(json[key], key);

int? jsonIntFieldOrNull(Map<String, dynamic> json, String key) =>
    jsonIntOrNull(json[key], key);

double jsonDoubleField(Map<String, dynamic> json, String key) =>
    jsonDouble(json[key], key);

double? jsonDoubleFieldOrNull(Map<String, dynamic> json, String key) =>
    jsonDoubleOrNull(json[key], key);
