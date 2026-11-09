import 'dart:convert';

import 'package:flutter/services.dart';

import 'package.dart';

class BundledExtensionPackage {
  BundledExtensionPackage({required this.manifest, required this.sources});

  final ExtensionManifest manifest;
  final Map<String, String> sources;
}

abstract interface class BundledExtensionLoader {
  Future<List<BundledExtensionPackage>> load();
}

class NoBundledExtensions implements BundledExtensionLoader {
  const NoBundledExtensions();

  @override
  Future<List<BundledExtensionPackage>> load() async => const [];
}

class AssetBundledExtensions implements BundledExtensionLoader {
  AssetBundledExtensions({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const _directories = [
    'builtin.lexue',
    'builtin.eclass',
    'builtin.mooc',
  ];

  final AssetBundle _bundle;

  @override
  Future<List<BundledExtensionPackage>> load() async {
    final packages = <BundledExtensionPackage>[];
    for (final directory in _directories) {
      final root = 'assets/extensions/$directory';
      final manifest = ExtensionManifest.parse(
        jsonDecode(await _bundle.loadString('$root/manifest.json')),
      );
      packages.add(
        BundledExtensionPackage(
          manifest: manifest,
          sources: {
            for (final source in manifest.sources)
              source.entry: await _bundle.loadString('$root/${source.entry}'),
          },
        ),
      );
    }
    return packages;
  }
}
