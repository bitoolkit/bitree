import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final generated = input.outputDirectory.resolve('prelude_data.cpp');
    Directory.fromUri(input.outputDirectory).createSync(recursive: true);
    _writePrelude(input.packageRoot, generated);
    output.dependencies.addAll([
      input.packageRoot.resolve('lua/prelude.lua'),
      input.packageRoot.resolve('lua/vendor/dkjson.lua'),
    ]);

    final luaDirectory = Directory.fromUri(
      input.packageRoot.resolve('third_party/lua/src'),
    );
    final luaSources =
        luaDirectory
            .listSync()
            .whereType<File>()
            .map((file) => file.path)
            .where((path) {
              final name = File(path).uri.pathSegments.last;
              return name.endsWith('.c') && name != 'lua.c' && name != 'luac.c';
            })
            .toList()
          ..sort();
    final builder = CBuilder.library(
      name: 'bitree_lua',
      assetName: 'native_lua_bindings.dart',
      sources: [
        input.packageRoot.resolve('native/bitree_lua_runtime.cpp').toFilePath(),
        generated.toFilePath(),
        ...luaSources,
      ],
      includes: [
        input.packageRoot.resolve('include').toFilePath(),
        luaDirectory.path,
      ],
      language: Language.cpp,
      std: 'c++17',
      cppLinkStdLib: input.config.code.targetOS == OS.android
          ? 'c++_static'
          : null,
    );
    await builder.run(
      input: input,
      output: output,
      logger: Logger('bitree_lua'),
    );
  });
}

void _writePrelude(Uri packageRoot, Uri output) {
  final prelude = File.fromUri(packageRoot.resolve('lua/prelude.lua'))
      .readAsStringSync();
  final dkjson = File.fromUri(packageRoot.resolve('lua/vendor/dkjson.lua'))
      .readAsStringSync();
  final source =
      '''
local dkjson = (function()
$dkjson
end)()

$prelude''';
  const delimiter = 'BTLUA';
  if (source.contains(')$delimiter"')) {
    throw StateError('Lua source contains the raw string delimiter.');
  }
  final generated =
      '''
#include <cstddef>

extern const char kPrelude[];
extern const size_t kPreludeLength;

const char kPrelude[] = R"$delimiter(
$source
)$delimiter";
const size_t kPreludeLength = sizeof(kPrelude) - 1;
''';
  final file = File.fromUri(output);
  if (!file.existsSync() || file.readAsStringSync() != generated) {
    file.writeAsStringSync(generated);
  }
}
