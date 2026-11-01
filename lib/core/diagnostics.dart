import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'async/serial_queue.dart';
import 'error_message.dart';

class AppDiagnostics {
  AppDiagnostics._();

  static final instance = AppDiagnostics._();
  static const _version = String.fromEnvironment(
    'BITREE_VERSION',
    defaultValue: 'local',
  );

  final _messages = StreamController<String>.broadcast();
  Future<Directory>? _directory;
  final _accessQueue = SerialQueue();

  Stream<String> get messages => _messages.stream;

  void notice(String message) => _messages.add(message);

  void report(
    String operation,
    Object failure,
    StackTrace stack, {
    String? message,
  }) {
    error(operation, failure, stack);
    _messages.add(
      message ??
          (failure is Error
              ? '$operation失败，可在设置中查看日志。'
              : errorMessage(failure)),
    );
  }

  void error(String operation, Object failure, StackTrace stack) {
    // FormatException.toString() can include the response body or saved JSON.
    final detail = failure is FormatException ? failure.message : '$failure';
    _append('ERROR', '$operation: ${failure.runtimeType}: $detail\n$stack');
  }

  void info(String message) => _append('INFO', message);

  Future<T> _access<T>(Future<T> Function() operation) =>
      _accessQueue.run(operation);

  void _append(String level, String message) {
    final now = DateTime.now();
    final text = _redact(
      '${now.toUtc().toIso8601String()} [$level] [$_version] $message\n',
    );
    unawaited(
      _access(() async {
        final directory = await _getDirectory();
        await _retainedFiles(directory);
        final date = now.toIso8601String().substring(0, 10);
        await File('${directory.path}/bitree-$date.log')
            .writeAsString(text, mode: FileMode.append, flush: true);
      }).catchError((Object failure, StackTrace stack) {
        // A logging failure must not interrupt the operation being diagnosed.
        developer.log(
          '无法写入本地日志',
          name: 'BITree',
          error: failure,
          stackTrace: stack,
        );
      }),
    );
  }

  Future<Directory> _getDirectory() => _directory ??= () async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/logs').create(recursive: true);
  }();

  Future<List<File>> _retainedFiles(Directory directory) async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day - 6);
    final files = <File>[];
    await for (final entry in directory.list()) {
      if (entry is! File) continue;
      final match = RegExp(r'^bitree-(\d{4}-\d{2}-\d{2})\.log$')
          .firstMatch(entry.uri.pathSegments.last);
      if (match == null) continue;
      if (DateTime.parse(match[1]!).isBefore(firstDay)) {
        await entry.delete();
      } else {
        files.add(entry);
      }
    }
    return files..sort((a, b) => a.path.compareTo(b.path));
  }

  Future<String> recentLines() => _access(() async {
    final lines = Queue<String>();
    for (final file in await _retainedFiles(await _getDirectory())) {
      await for (final line
          in file
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        lines.addLast(line);
        if (lines.length > 100) lines.removeFirst();
      }
    }
    return lines.join('\n');
  });

  Future<Uint8List> export() => _access(() async {
    final text = StringBuffer('BITree $_version 日志\n');
    text.writeln('运行环境：${Platform.version}');
    text.writeln('导出时间：${DateTime.now().toUtc().toIso8601String()}\n');
    for (final file in await _retainedFiles(await _getDirectory())) {
      text.writeln(await file.readAsString());
    }
    return Uint8List.fromList(utf8.encode(text.toString()));
  });

  String _redact(String text) => text
      .replaceAllMapped(RegExp(r'''https?://[^\s<>"')]+'''), (match) {
        final uri = Uri.tryParse(match[0]!);
        if (uri == null) return '[网址已隐藏]';
        return '${uri.scheme}://${uri.host}${uri.path}';
      })
      .replaceAllMapped(
        RegExp(r'(/findCaptchaCount/)[^\s/?]+'),
        (match) => '${match[1]}[已隐藏]',
      )
      .replaceAllMapped(
        RegExp(
          r'''((?:cookie|set-cookie|authorization)["']?\s*[:=]\s*)[^\r\n]+''',
          caseSensitive: false,
        ),
        (match) => '${match[1]}[已隐藏]',
      )
      .replaceAllMapped(
        RegExp(
          r'''((?:password|passwd|api[_-]?key|token|ticket|sesskey|username|execution|captcha_code|captcha_payload|risk_payload|密码|学号)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)''',
          caseSensitive: false,
        ),
        (match) => '${match[1]}[已隐藏]',
      );
}
