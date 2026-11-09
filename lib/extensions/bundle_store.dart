import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'download.dart';
import 'package.dart';

class ExtensionBundleStore {
  const ExtensionBundleStore();

  Future<ExtensionPackage> write(ExtensionBundle bundle) async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/extensions/${bundle.manifest.id}');
    await root.create(recursive: true);
    final pending = Directory(
      '${root.path}/.${bundle.manifest.version}.pending',
    );
    if (await pending.exists()) await pending.delete(recursive: true);
    await pending.create(recursive: true);
    try {
      await File('${pending.path}/manifest.json').writeAsString(
        jsonEncode(bundle.manifest.toJson()),
        flush: true,
      );
      for (final entry in bundle.sources.entries) {
        final file = File('${pending.path}/${entry.key}');
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.value, flush: true);
      }
      final target = Directory(
        '${root.path}/${bundle.manifest.version}',
      );
      final backup = Directory(
        '${root.path}/.${bundle.manifest.version}.previous',
      );
      if (await backup.exists()) await backup.delete(recursive: true);
      if (await target.exists()) await target.rename(backup.path);
      try {
        await pending.rename(target.path);
      } catch (_) {
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
      if (await backup.exists()) await backup.delete(recursive: true);
      return ExtensionPackage(
        manifest: bundle.manifest,
        location: target.path,
        managed: true,
      );
    } catch (_) {
      if (await pending.exists()) await pending.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> remove(ExtensionPackage package) async {
    if (!package.managed) return;
    final support = await getApplicationSupportDirectory();
    final root = Directory(
      '${support.path}/extensions/${package.manifest.id}',
    ).absolute.path;
    final location = Directory(package.location).absolute.path;
    if (location != root && !location.startsWith('$root/')) {
      throw const FormatException('扩展包安装位置不在应用管理目录内');
    }
    final directory = Directory(location);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
