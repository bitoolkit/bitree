import 'dart:convert';
import 'dart:io';

import 'package:bitree/core/storage/json_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('bitree-json-file-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  });

  tearDown(() => directory.delete(recursive: true));

  test(
    'writes replace an existing file without leaving a pending file',
    () async {
      const file = JsonFile('data.json');
      await file.write({'value': 1});
      await file.write({'value': 2});

      expect(
        await file.read(
          (value) => (value as Map<String, dynamic>)['value'] as int,
        ),
        2,
      );
      expect(File('${directory.path}/data.json').existsSync(), isTrue);
      expect(File('${directory.path}/data.json.pending').existsSync(), isFalse);
    },
  );

  test(
    'a complete pending file is recovered when the main file is missing',
    () async {
      final pending = File('${directory.path}/data.json.pending');
      await pending.writeAsString(jsonEncode({'value': 3}));

      const file = JsonFile('data.json');
      expect(
        await file.read(
          (value) => (value as Map<String, dynamic>)['value'] as int,
        ),
        3,
      );
      expect(File('${directory.path}/data.json').existsSync(), isTrue);
      expect(pending.existsSync(), isFalse);
    },
  );

  test(
    'an uncommitted pending file is ignored while the main file exists',
    () async {
      await File('${directory.path}/data.json')
          .writeAsString(jsonEncode({'value': 1}));
      final pending = File('${directory.path}/data.json.pending');
      await pending.writeAsString(jsonEncode({'value': 2}));

      const file = JsonFile('data.json');
      expect(
        await file.read(
          (value) => (value as Map<String, dynamic>)['value'] as int,
        ),
        1,
      );
      expect(pending.existsSync(), isFalse);
    },
  );

  test(
    'an invalid pending file cannot silently replace the main state',
    () async {
      final pending = File('${directory.path}/data.json.pending');
      await pending.writeAsString('{');

      const file = JsonFile('data.json');
      await expectLater(
        file.read((value) => (value as Map<String, dynamic>)['value'] as int),
        throwsFormatException,
      );
    },
  );

  test('delete removes both committed and pending data', () async {
    const file = JsonFile('data.json');
    await file.write({'value': 1});
    await File('${directory.path}/data.json.pending').writeAsString('{}');

    await file.delete();

    expect(File('${directory.path}/data.json').existsSync(), isFalse);
    expect(File('${directory.path}/data.json.pending').existsSync(), isFalse);
    expect(await file.read((value) => value as Object), isNull);
  });
}
