import '../core/json.dart';
import '../core/storage/json_file.dart';
import 'package.dart';

class ExtensionLibrary {
  const ExtensionLibrary({this.packages = const []});

  final List<ExtensionPackage> packages;

  Map<String, Object?> toJson() => {
    'packages': [for (final package in packages) package.toJson()],
  };
}

class ExtensionStore {
  const ExtensionStore();

  final JsonFile _file = const JsonFile('extensions.json');

  Future<ExtensionLibrary> read() async =>
      await _file.read(_decode) ?? const ExtensionLibrary();

  ExtensionLibrary _decode(Object? value) {
    final json = jsonObject(value, '扩展');
    return ExtensionLibrary(
      packages: [
        for (final row in jsonListField(json, 'packages'))
          ExtensionPackage.fromJson(jsonObject(row, 'packages[]')),
      ],
    );
  }

  Future<void> write(ExtensionLibrary library) => _file.write(library.toJson());

  Future<void> clear() => _file.delete();
}
