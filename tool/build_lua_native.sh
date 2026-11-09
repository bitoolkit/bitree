#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

DART="${DART:-dart}"
"$DART" run tool/embed_lua.dart

if [[ -n "${LUA_PREFIX:-}" ]]; then
  lua_cflags="-I${LUA_PREFIX}/include"
  lua_libs="-L${LUA_PREFIX}/lib -Wl,-rpath,${LUA_PREFIX}/lib -llua"
elif pkg-config --exists lua5.5 2>/dev/null; then
  lua_cflags="$(pkg-config --cflags lua5.5)"
  lua_libs="$(pkg-config --libs lua5.5)"
else
  echo "Lua 5.5 not found. Set LUA_PREFIX or PKG_CONFIG_PATH." >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin) output="libbitree_lua.dylib" ;;
  MINGW*|MSYS*|CYGWIN*) output="bitree_lua.dll" ;;
  *) output="libbitree_lua.so" ;;
esac

mkdir -p build/native
"${CXX:-c++}" -std=c++17 -O2 -fPIC -shared \
  $lua_cflags \
  packages/bitree_lua/native/bitree_lua_runtime.cpp \
  $lua_libs \
  -o "build/native/${output}"

echo "Built build/native/${output}"
