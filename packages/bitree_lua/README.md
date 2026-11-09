# bitree_lua

This package is the native boundary for source extensions. It pins Lua 5.5.1
and exposes one operation call at a time through `bitree_lua_execute_start`.

The Lua environment lives in `lua/prelude.lua`; JSON uses the vendored,
unmodified `dkjson` 2.7 (`lua/vendor/dkjson.lua`, MIT). `hook/build.dart`
generates a C++ source containing those Lua files and compiles it together
with the vendored Lua sources and `native/bitree_lua_runtime.cpp`.

The C++ bridge opens only the standard libraries needed by source scripts and
removes `io`, `os`, `debug`, `package`, `dofile`, `loadfile`, and `load`.
`require` only resolves the host-provided `bitree.*` modules. URL, encoding,
time conversion and all application data access cross the JSON host callback;
the C layer contains no platform or application logic.

`ctx` carries only the invocation's `config`, `scope`, `source`, `locale` and
`base` entries. Reusable host capabilities are loaded explicitly, for example:

```lua
local http = require("bitree.http")
local json = require("bitree.json")
local data = require("bitree.data")
```

`require("bitree.http").request` yields the Lua coroutine with a JSON request. Dart performs
the HTTP call with `HttpClient`, then resumes the suspended execution through
`bitree_lua_execute_resume`. Several HTTP calls may suspend in one operation.
The transport enforces declared HTTPS origins, strips credential headers from
the script-visible request and response, limits redirects and response size,
and keeps cookies per source instance. If the script is cancelled or reaches
its deadline while waiting, the execution is discarded instead of resumed.

Flutter's native assets toolchain builds and packages the library automatically
for Android, Linux, Windows, macOS, and iOS. The build uses the platform C++
compiler supplied by the Flutter toolchain, so no system Lua installation is
required.

```bash
flutter test --no-pub test/native_lua_test.dart
```

The test always loads the native asset. A missing or broken build hook fails
the test instead of skipping the native runtime.

## Updating Lua

The bundled source is pinned in `third_party/lua/SOURCE.json`. To change
versions, update `version`, `url`, and `sha256` there, then run:

```bash
python3 tool/update_lua.py
```

The updater downloads the pinned official archive, verifies its checksum, and
replaces `src/`. Build hooks and CI never download Lua; they compile only the
committed source.
