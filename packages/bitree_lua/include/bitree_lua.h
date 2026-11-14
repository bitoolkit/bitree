#ifndef BITREE_LUA_H
#define BITREE_LUA_H

#if defined(_WIN32)
#define BITREE_LUA_API __declspec(dllexport)
#else
#define BITREE_LUA_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

enum BitreeLuaStatus {
  BITREE_LUA_OK = 0,
  BITREE_LUA_SCRIPT_ERROR = 1,
  BITREE_LUA_CANCELLED = 2,
  BITREE_LUA_TIMEOUT = 3,
  BITREE_LUA_MEMORY_LIMIT = 4,
};

/// Runs filter(data) in a fresh state without host callbacks. Returns a
/// BitreeLuaStatus. Result JSON and error text are malloc-owned UTF-8 strings;
/// release them with bitree_lua_free.
BITREE_LUA_API int bitree_lua_filter(
    const char *source,
    const char *file_name,
    const char *data_json,
    const volatile int *cancel_flag,
    int timeout_ms,
    char **result_json,
    char **error_text);

BITREE_LUA_API void bitree_lua_free(void *value);

#ifdef __cplusplus
}
#endif

#endif
