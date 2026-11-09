#ifndef BITREE_LUA_H
#define BITREE_LUA_H

#include <stddef.h>

#if defined(_WIN32)
#define BITREE_LUA_API __declspec(dllexport)
#else
#define BITREE_LUA_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// Synchronous host callback used by one Lua execution. `engine` is valid
/// only while the callback is active and can be passed to
/// bitree_lua_call_step. On success return 0 and assign JSON to `result`. On
/// failure return non-zero and assign a JSON error object to `error`. Both
/// strings are allocated with malloc and released by the bridge with free.
typedef int (*BitreeLuaHostCallback)(
    void *engine,
    const char *request_json,
    char **result,
    char **error);

/// Status returned when a suspended execution is waiting for an async host
/// result.
#define BITREE_LUA_YIELDED 2

/// Compiles and inspects a source module without accepting host calls.
/// `required_operations_json` and `base_steps_json` are JSON arrays.
BITREE_LUA_API int bitree_lua_inspect(
    const char *source,
    const char *file_name,
    const char *required_operations_json,
    const char *base_steps_json,
    int timeout_ms,
    char **info_json,
    char **error_json);

/// Executes one source operation. `cancel_flag` may be null; a non-zero value
/// asks the instruction hook to stop execution.
BITREE_LUA_API int bitree_lua_execute(
    const char *source,
    const char *file_name,
    const char *operation,
    const char *query_json,
    const char *context_json,
    BitreeLuaHostCallback host,
    const volatile int *cancel_flag,
    int timeout_ms,
    char **result_json,
    char **error_json);

/// Starts an execution that may suspend at an async host boundary. The
/// returned handle remains valid until completion or
/// bitree_lua_execution_free. Returns 0 when complete, BITREE_LUA_YIELDED
/// when `yield_json` contains the pending request, or -1 on failure.
BITREE_LUA_API int bitree_lua_execute_start(
    const char *source,
    const char *file_name,
    const char *operation,
    const char *query_json,
    const char *context_json,
    BitreeLuaHostCallback host,
    const volatile int *cancel_flag,
    int timeout_ms,
    void **execution,
    char **yield_json,
    char **result_json,
    char **error_json);

/// Resumes a suspended execution with a decoded JSON value or a stable error
/// object. Returns the same status as bitree_lua_execute_start.
BITREE_LUA_API int bitree_lua_execute_resume(
    void *execution,
    const char *value_json,
    const char *error_json,
    char **yield_json,
    char **result_json,
    char **error_json_out);

BITREE_LUA_API void bitree_lua_execution_free(void *execution);

/// Executes a display rule's `filter(data)` entry point.
BITREE_LUA_API int bitree_lua_filter(
    const char *source,
    const char *file_name,
    const char *data_json,
    const volatile int *cancel_flag,
    int timeout_ms,
    char **result_json,
    char **error_json);

/// Calls an overridden step in the currently active execution. Returns 0 and
/// JSON for an override, 2 when the source has no such override, and -1 on
/// failure.
BITREE_LUA_API int bitree_lua_call_step(
    void *engine,
    const char *name,
    const char *args_json,
    char **result_json,
    char **error_json);

BITREE_LUA_API void bitree_lua_free(void *value);

#ifdef __cplusplus
}
#endif

#endif
