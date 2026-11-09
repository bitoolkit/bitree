# bitree_lua

This package is the native boundary for source extensions. It pins Lua 5.5.1
and exposes one operation call at a time through `bitree_lua_execute`.

The Lua environment lives in `lua/prelude.lua`; JSON uses the vendored,
unmodified `dkjson` 2.7 (`lua/vendor/dkjson.lua`, MIT). `tool/embed_lua.dart`
bundles those files into the generated `native/prelude.inc` before compiling,
so the Lua sources remain separately maintainable without adding a runtime
file lookup.

The C++ bridge opens only the standard libraries needed by source scripts and
removes `io`, `os`, `debug`, `package`, `dofile`, `loadfile`, and `load`.
`require` only resolves the host-provided `bitree.*` modules. URL, encoding,
time conversion and all application data access cross the JSON host callback;
the C layer contains no platform or application logic.

`ctx.http.request` yields the Lua coroutine with a JSON request. Dart performs
the HTTP call with `HttpClient`, then resumes the suspended execution through
`bitree_lua_execute_resume`. Several HTTP calls may suspend in one operation.
The transport enforces declared HTTPS origins, strips credential headers from
the script-visible request and response, limits redirects and response size,
and keeps cookies per source instance. If the script is cancelled or reaches
its deadline while waiting, the execution is discarded instead of resumed.

Build the Linux test library from the repository root:

```bash
LUA_PREFIX=/path/to/lua-5.5.1 tool/build_lua_native.sh
```

`dart` must be on `PATH` (or set `DART=/path/to/dart`) to regenerate the
embedded prelude.

The Dart loader looks at `BITREE_LUA_LIBRARY`, then `build/native/libbitree_lua.so`.
