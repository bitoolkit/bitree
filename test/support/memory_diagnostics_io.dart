import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A test-only file system for diagnostics. Completion clock tests run in a
/// FakeAsync zone: real disk IO queued there can outlive its retired zone and
/// strand the shared log queue. Immediate memory futures keep failures visible
/// without making the state-machine tests depend on native disk/plugin work.
final class MemoryDiagnosticsIo extends IOOverrides {
  final _files = <String, List<int>>{};

  @override
  Directory createDirectory(String path) => _Directory(this, path);

  @override
  File createFile(String path) => _File(this, path);
}

class _Directory extends Fake implements Directory {
  _Directory(this.owner, this.path);

  final MemoryDiagnosticsIo owner;
  @override
  final String path;

  @override
  Future<Directory> create({bool recursive = false}) async => this;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream<FileSystemEntity>.fromIterable([
    for (final file in owner._files.keys.toList())
      if (file.startsWith('$path/')) _File(owner, file),
  ]);
}

class _File extends Fake implements File {
  _File(this.owner, this.path);

  final MemoryDiagnosticsIo owner;
  @override
  final String path;
  @override
  Uri get uri => Uri.file(path);

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    final bytes = encoding.encode(contents);
    owner._files[path] = [
      if (mode == FileMode.append) ...(owner._files[path] ?? <int>[]),
      ...bytes,
    ];
    return this;
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      Stream<List<int>>.value(
        List<int>.of(owner._files[path] ?? <int>[]).sublist(start ?? 0, end),
      );

  @override
  Future<String> readAsString({Encoding encoding = utf8}) async =>
      encoding.decode(owner._files[path] ?? <int>[]);

  @override
  Future<File> delete({bool recursive = false}) async {
    owner._files.remove(path);
    return this;
  }
}
