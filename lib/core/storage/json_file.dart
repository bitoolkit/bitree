import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class JsonFile {
  const JsonFile(this.name);

  final String name;

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);

    return File('${directory.path}/$name');
  }

  Future<T?> read<T extends Object>(T Function(Object?) decode) async {
    final file = await _file();
    if (!await file.exists()) return null;

    final text = await file.readAsString();
    try {
      return decode(jsonDecode(text));
    } on FormatException catch (failure) {
      throw FormatException('$name 内容损坏：${failure.message}');
    }
  }

  Future<void> write(Object value) async {
    final file = await _file();
    final pending = File('${file.path}.pending');

    await pending.writeAsString(jsonEncode(value), flush: true);
    await pending.rename(file.path);
  }

  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
