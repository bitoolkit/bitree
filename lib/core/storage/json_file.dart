import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class JsonFile {
  const JsonFile(this.name);

  final String name;

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);

    return File(p.join(directory.path, name));
  }

  Future<T?> read<T extends Object>(T Function(Object?) decode) async {
    final file = await _file();
    final pending = File('${file.path}.pending');
    if (!await file.exists()) {
      if (!await pending.exists()) return null;
      final recovered = _decode(await pending.readAsString(), decode);
      await pending.rename(file.path);
      return recovered;
    }
    if (await pending.exists()) await pending.delete();

    final text = await file.readAsString();
    return _decode(text, decode);
  }

  T? _decode<T extends Object>(String text, T Function(Object?) decode) {
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
    final pending = File('${file.path}.pending');
    if (await pending.exists()) await pending.delete();
  }
}
