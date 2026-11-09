#include "bitree_lua.h"

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

extern const char kPrelude[];
extern const size_t kPreludeLength;

namespace {

constexpr size_t kDefaultMemoryLimit = 32 * 1024 * 1024;
constexpr size_t kInstructionLimit = 50'000'000;
constexpr const char* kErrorPrefix = "__bitree_error__";

struct MemoryState {
  size_t used = 0;
  size_t limit = kDefaultMemoryLimit;
};

struct ExecutionState {
  size_t steps = 0;
  size_t stepLimit = kInstructionLimit;
  std::chrono::steady_clock::time_point deadline;
  const volatile int* cancel = nullptr;
};

struct Engine {
  lua_State* lua = nullptr;
  lua_State* thread = nullptr;
  lua_State* hostThread = nullptr;
  MemoryState memory;
  ExecutionState execution;
  BitreeLuaHostCallback host = nullptr;
  int moduleRef = LUA_NOREF;
  int encodeRef = LUA_NOREF;
  int decodeRef = LUA_NOREF;
  int contextRef = LUA_NOREF;
  int filterRef = LUA_NOREF;
  int threadRef = LUA_NOREF;
  std::string resumeFailure;
  bool active = false;
  int stepDepth = 0;
};

void* allocate(void* user, void* pointer, size_t oldSize, size_t newSize) {
  auto* memory = static_cast<MemoryState*>(user);
  if (newSize == 0) {
    if (pointer != nullptr) {
      memory->used = memory->used >= oldSize ? memory->used - oldSize : 0;
      std::free(pointer);
    }
    return nullptr;
  }
  const size_t base = memory->used >= oldSize ? memory->used - oldSize : 0;
  if (newSize > memory->limit || base > memory->limit - newSize) {
    return nullptr;
  }
  void* result = std::realloc(pointer, newSize);
  if (result != nullptr) memory->used = base + newSize;
  return result;
}

std::string jsonEscape(const std::string& value) {
  std::string result;
  result.reserve(value.size() + 2);
  result.push_back('"');
  for (const unsigned char byte : value) {
    switch (byte) {
      case '"':
        result += "\\\"";
        break;
      case '\\':
        result += "\\\\";
        break;
      case '\b':
        result += "\\b";
        break;
      case '\f':
        result += "\\f";
        break;
      case '\n':
        result += "\\n";
        break;
      case '\r':
        result += "\\r";
        break;
      case '\t':
        result += "\\t";
        break;
      default:
        if (byte < 0x20) {
          char escaped[7];
          std::snprintf(escaped, sizeof(escaped), "\\u%04x", byte);
          result += escaped;
        } else {
          result.push_back(static_cast<char>(byte));
        }
    }
  }
  result.push_back('"');
  return result;
}

std::string errorJson(const std::string& code, const std::string& message) {
  return "{\"code\":" + jsonEscape(code) + ",\"message\":" +
         jsonEscape(message) + ",\"details\":null}";
}

char* duplicate(const std::string& value) {
  auto* result = static_cast<char*>(std::malloc(value.size() + 1));
  if (result == nullptr) return nullptr;
  std::memcpy(result, value.c_str(), value.size() + 1);
  return result;
}

void setError(char** target, const std::string& value) {
  if (target != nullptr) *target = duplicate(value);
}

std::string stackError(lua_State* lua) {
  const char* text = lua_tostring(lua, -1);
  return text == nullptr ? "Lua 执行失败" : text;
}

std::string normalizeFailure(const std::string& raw) {
  const size_t prefixLength = std::strlen(kErrorPrefix);
  if (raw.compare(0, prefixLength, kErrorPrefix) == 0) {
    const std::string encoded = raw.substr(prefixLength);
    if (!encoded.empty() && encoded.front() == '{') return encoded;
  }
  if (raw.find("not enough memory") != std::string::npos) {
    return errorJson("memory_limit", raw);
  }
  return errorJson("script_error", raw);
}

bool runProtected(lua_State* lua, int arguments, int results) {
  return lua_pcallk(lua, arguments, results, 0, 0, nullptr) == LUA_OK;
}

Engine* engineFrom(lua_State* lua) {
  return *static_cast<Engine**>(lua_getextraspace(lua));
}

bool pushDecodedJson(Engine& engine, lua_State* lua, const char* text) {
  if (engine.decodeRef == LUA_NOREF) {
    lua_pushliteral(lua, "JSON 解码器未初始化");
    return false;
  }
  lua_rawgeti(lua, LUA_REGISTRYINDEX, engine.decodeRef);
  lua_pushstring(lua, text);
  return runProtected(lua, 1, 1);
}

bool encodeValue(
    Engine& engine,
    lua_State* lua,
    int index,
    std::string& output) {
  const int absolute = index < 0 ? lua_gettop(lua) + index + 1 : index;
  lua_rawgeti(lua, LUA_REGISTRYINDEX, engine.encodeRef);
  lua_pushvalue(lua, absolute);
  if (!runProtected(lua, 1, 1)) return false;
  const char* text = lua_tostring(lua, -1);
  if (text == nullptr) {
    lua_pop(lua, 1);
    lua_pushliteral(lua, "Lua 结果无法转换为 JSON");
    return false;
  }
  output = text;
  lua_pop(lua, 1);
  return true;
}

bool decodeArray(
    Engine& engine,
    const char* json,
    std::vector<std::string>& values,
    std::string& failure) {
  lua_State* lua = engine.lua;
  const int top = lua_gettop(lua);
  if (!pushDecodedJson(engine, lua, json)) {
    failure = stackError(lua);
    lua_settop(lua, top);
    return false;
  }
  if (!lua_istable(lua, -1)) {
    failure = "JSON 参数必须是数组";
    lua_settop(lua, top);
    return false;
  }
  const int length = static_cast<int>(lua_rawlen(lua, -1));
  for (int index = 1; index <= length; ++index) {
    lua_rawgeti(lua, -1, index);
    if (!lua_isstring(lua, -1)) {
      failure = "JSON 数组只能包含文本";
      lua_settop(lua, top);
      return false;
    }
    values.emplace_back(lua_tostring(lua, -1));
    lua_pop(lua, 1);
  }
  lua_settop(lua, top);
  return true;
}

std::string arrayJson(const std::vector<std::string>& values) {
  std::string result = "[";
  for (size_t index = 0; index < values.size(); ++index) {
    if (index != 0) result.push_back(',');
    result += jsonEscape(values[index]);
  }
  result.push_back(']');
  return result;
}

// Structured errors carry no source position: the code that happened to be
// running when the budget ran out is not the cause.
void raiseStructured(lua_State* lua, const char* json) {
  lua_pushfstring(lua, "%s%s", kErrorPrefix, json);
  lua_error(lua);
}

void instructionHook(lua_State* lua, lua_Debug*) {
  Engine* engine = engineFrom(lua);
  if (engine == nullptr) return;
  auto& execution = engine->execution;
  execution.steps += 5'000;
  if (execution.cancel != nullptr && *execution.cancel != 0) {
    raiseStructured(
        lua,
        R"({"code":"cancelled","message":"Lua 执行已取消","details":null})");
  }
  if (std::chrono::steady_clock::now() >= execution.deadline) {
    raiseStructured(
        lua,
        R"({"code":"timeout","message":"Lua 执行超时","details":null})");
  }
  if (execution.steps > execution.stepLimit) {
    raiseStructured(
        lua,
        R"({"code":"timeout","message":"Lua 指令预算已用尽","details":null})");
  }
}

bool captureGlobal(Engine& engine, const char* name, int& reference) {
  lua_State* lua = engine.lua;
  lua_getglobal(lua, name);
  if (!lua_isfunction(lua, -1)) {
    lua_pop(lua, 1);
    return false;
  }
  reference = luaL_ref(lua, LUA_REGISTRYINDEX);
  lua_pushnil(lua);
  lua_setglobal(lua, name);
  return true;
}

int resumeAfterHost(lua_State* lua, int, lua_KContext) {
  Engine* engine = engineFrom(lua);
  if (engine == nullptr) return luaL_error(lua, "Lua 运行实例已失效");
  if (!engine->resumeFailure.empty()) {
    const std::string message = kErrorPrefix + engine->resumeFailure;
    lua_pushlstring(lua, message.data(), message.size());
    return lua_error(lua);
  }
  if (lua_gettop(lua) < 1) {
    return luaL_error(lua, "宿主异步结果为空");
  }
  return 1;
}

int hostCall(lua_State* lua) {
  Engine* engine = engineFrom(lua);
  if (engine == nullptr || engine->host == nullptr) {
    return luaL_error(lua, "当前运行没有宿主回调");
  }
  if (!lua_istable(lua, 1)) {
    return luaL_error(lua, "宿主请求必须是 table");
  }
  const int top = lua_gettop(lua);
  bool asyncRequest = false;
  if (engine->thread == lua) {
    lua_getfield(lua, 1, "kind");
    const char* kind = lua_tostring(lua, -1);
    asyncRequest =
        kind != nullptr &&
        (std::strcmp(kind, "http.request") == 0 ||
         std::strcmp(kind, "base.call") == 0 ||
         std::strcmp(kind, "session.cookie") == 0 ||
         std::strcmp(kind, "secrets.get") == 0 ||
         std::strcmp(kind, "secrets.set") == 0 ||
         std::strcmp(kind, "secrets.remove") == 0);
    lua_pop(lua, 1);
  }

  std::string request;
  if (!encodeValue(*engine, lua, 1, request)) {
    const std::string failure = stackError(lua);
    lua_settop(lua, top);
    const std::string normalized = normalizeFailure(failure);
    lua_pushfstring(lua, "%s%s", kErrorPrefix, normalized.c_str());
    return lua_error(lua);
  }
  lua_settop(lua, top);
  if (asyncRequest) {
    lua_pushlstring(lua, request.data(), request.size());
    return lua_yieldk(lua, 1, 0, resumeAfterHost);
  }

  char* result = nullptr;
  char* failure = nullptr;
  int status = 0;
  {
    lua_State* previous = engine->hostThread;
    engine->hostThread = lua;
    status = engine->host(engine, request.c_str(), &result, &failure);
    engine->hostThread = previous;
  }
  if (status != 0) {
    const char* message =
        failure == nullptr ? R"({"code":"script_error","message":"宿主调用失败","details":null})"
                           : failure;
    std::free(result);
    lua_pushfstring(lua, "%s%s", kErrorPrefix, message);
    std::free(failure);
    return lua_error(lua);
  }
  if (result == nullptr) {
    std::free(failure);
    lua_pushfstring(
        lua,
        "%s%s",
        kErrorPrefix,
        R"({"code":"script_error","message":"宿主没有返回结果","details":null})");
    return lua_error(lua);
  }
  const bool decoded = pushDecodedJson(*engine, lua, result);
  std::free(result);
  std::free(failure);
  if (!decoded) {
    const std::string failureText = stackError(lua);
    lua_settop(lua, top);
    const std::string normalized = normalizeFailure(failureText);
    lua_pushfstring(lua, "%s%s", kErrorPrefix, normalized.c_str());
    return lua_error(lua);
  }
  return 1;
}

bool openEngine(
    Engine& engine,
    const char* source,
    const char* fileName,
    const volatile int* cancel,
    int timeoutMs,
    bool expectModule,
    std::string& failure) {
  if (source == nullptr) {
    failure = "缺少 Lua 来源";
    return false;
  }
  engine.execution.cancel = cancel;
  engine.execution.deadline = std::chrono::steady_clock::now() +
                              std::chrono::milliseconds(timeoutMs);
  engine.lua = lua_newstate(allocate, &engine.memory, 0);
  if (engine.lua == nullptr) {
    failure = "无法创建 Lua state";
    return false;
  }
  lua_State* lua = engine.lua;
  *static_cast<Engine**>(lua_getextraspace(lua)) = &engine;
  luaL_openlibs(lua);
  lua_register(lua, "__bitree_host_call", hostCall);
  lua_pushboolean(lua, engine.host != nullptr);
  lua_setglobal(lua, "__bitree_host_available");
  lua_sethook(lua, instructionHook, LUA_MASKCOUNT, 5'000);

  if (luaL_loadbufferx(
          lua, kPrelude, kPreludeLength, "@bitree-prelude.lua", "t") !=
      LUA_OK) {
    failure = stackError(lua);
    return false;
  }
  if (!runProtected(lua, 0, 0)) {
    failure = stackError(lua);
    return false;
  }
  if (!captureGlobal(engine, "__bitree_json_encode", engine.encodeRef) ||
      !captureGlobal(engine, "__bitree_json_decode", engine.decodeRef) ||
      !captureGlobal(engine, "__bitree_make_context", engine.contextRef) ||
      !captureGlobal(engine, "__bitree_filter", engine.filterRef)) {
    failure = "Lua 预置环境不完整";
    return false;
  }

  const std::string chunkName = std::string("@") + fileName;
  if (luaL_loadbufferx(
          lua, source, std::strlen(source), chunkName.c_str(), "t") !=
      LUA_OK) {
    failure = stackError(lua);
    return false;
  }
  if (expectModule) {
    if (!runProtected(lua, 0, 1)) {
      failure = stackError(lua);
      return false;
    }
    if (!lua_istable(lua, -1)) {
      failure = "Lua 来源必须返回一个 table";
      return false;
    }
    engine.moduleRef = luaL_ref(lua, LUA_REGISTRYINDEX);
  } else {
    if (!runProtected(lua, 0, LUA_MULTRET)) {
      failure = stackError(lua);
      return false;
    }
    lua_settop(lua, 0);
  }
  return true;
}

void closeEngine(Engine& engine) {
  if (engine.lua == nullptr) return;
  if (engine.moduleRef != LUA_NOREF) {
    luaL_unref(engine.lua, LUA_REGISTRYINDEX, engine.moduleRef);
  }
  if (engine.encodeRef != LUA_NOREF) {
    luaL_unref(engine.lua, LUA_REGISTRYINDEX, engine.encodeRef);
  }
  if (engine.decodeRef != LUA_NOREF) {
    luaL_unref(engine.lua, LUA_REGISTRYINDEX, engine.decodeRef);
  }
  if (engine.contextRef != LUA_NOREF) {
    luaL_unref(engine.lua, LUA_REGISTRYINDEX, engine.contextRef);
  }
  if (engine.filterRef != LUA_NOREF) {
    luaL_unref(engine.lua, LUA_REGISTRYINDEX, engine.filterRef);
  }
  if (engine.threadRef != LUA_NOREF) {
    luaL_unref(engine.lua, LUA_REGISTRYINDEX, engine.threadRef);
  }
  lua_close(engine.lua);
  engine.lua = nullptr;
  engine.thread = nullptr;
  engine.hostThread = nullptr;
}

bool collectFunctions(
    Engine& engine,
    const char* field,
    bool required,
    std::vector<std::string>& names,
    std::string& failure) {
  lua_State* lua = engine.lua;
  const int top = lua_gettop(lua);
  lua_rawgeti(lua, LUA_REGISTRYINDEX, engine.moduleRef);
  lua_getfield(lua, -1, field);
  if (lua_isnil(lua, -1) && !required) {
    lua_settop(lua, top);
    return true;
  }
  if (!lua_istable(lua, -1)) {
    failure = std::string("Lua 来源缺少 ") + field + " table";
    lua_settop(lua, top);
    return false;
  }
  lua_pushnil(lua);
  while (lua_next(lua, -2) != 0) {
    if (!lua_isstring(lua, -2)) {
      failure = std::string("Lua ") + field + " 必须使用文本键";
      lua_settop(lua, top);
      return false;
    }
    if (!lua_isfunction(lua, -1)) {
      failure = std::string("Lua ") + field + " 必须是具名函数";
      lua_settop(lua, top);
      return false;
    }
    names.emplace_back(lua_tostring(lua, -2));
    lua_pop(lua, 1);
  }
  lua_settop(lua, top);
  return true;
}

bool verifyFunctions(
    const std::vector<std::string>& available,
    const char* field,
    const std::vector<std::string>& required,
    std::string& failure) {
  for (const auto& name : required) {
    if (std::find(available.begin(), available.end(), name) ==
        available.end()) {
      failure = std::string("Lua 来源未实现 ") + field + " " + name;
      return false;
    }
  }
  return true;
}

bool executionStopped(Engine& engine, std::string& failure) {
  if (engine.execution.cancel != nullptr && *engine.execution.cancel != 0) {
    failure = R"({"code":"cancelled","message":"Lua 执行已取消","details":null})";
    return true;
  }
  if (std::chrono::steady_clock::now() >= engine.execution.deadline) {
    failure = R"({"code":"timeout","message":"Lua 执行超时","details":null})";
    return true;
  }
  return false;
}

int finishExecution(
    Engine& engine,
    int status,
    int results,
    char** yieldJson,
    char** resultJson,
    char** errorJsonOut) {
  if (status == LUA_YIELD) {
    if (results != 1 || !lua_isstring(engine.thread, -1)) {
      const std::string failure = "Lua 异步宿主请求格式不正确";
      setError(errorJsonOut, normalizeFailure(failure));
      closeEngine(engine);
      return -1;
    }
    if (yieldJson != nullptr) {
      *yieldJson = duplicate(lua_tostring(engine.thread, -1));
    }
    return BITREE_LUA_YIELDED;
  }

  if (status == LUA_OK) {
    if (results < 1) {
      setError(
          errorJsonOut,
          errorJson("script_error", "Lua 来源没有返回结果"));
      closeEngine(engine);
      return -1;
    }
    lua_pushvalue(engine.thread, -1);
    lua_xmove(engine.thread, engine.lua, 1);
    std::string output;
    if (!encodeValue(engine, engine.lua, -1, output)) {
      const std::string failure = stackError(engine.lua);
      setError(errorJsonOut, normalizeFailure(failure));
      closeEngine(engine);
      return -1;
    }
    if (resultJson == nullptr) {
      setError(
          errorJsonOut,
          errorJson("script_error", "缺少 Lua 结果输出参数"));
      closeEngine(engine);
      return -1;
    }
    *resultJson = duplicate(output);
    closeEngine(engine);
    if (*resultJson == nullptr) {
      setError(errorJsonOut, errorJson("script_error", "无法分配 Lua 结果"));
      return -1;
    }
    return 0;
  }

  const std::string failure = stackError(engine.thread);
  setError(errorJsonOut, normalizeFailure(failure));
  closeEngine(engine);
  return -1;
}

bool beginOperation(
    Engine& engine,
    const char* operation,
    const char* queryJson,
    const char* contextJson,
    std::string& failure) {
  lua_State* lua = engine.lua;
  lua_settop(lua, 0);
  lua_rawgeti(lua, LUA_REGISTRYINDEX, engine.contextRef);
  lua_pushstring(lua, contextJson);
  if (!runProtected(lua, 1, 1)) {
    failure = stackError(lua);
    return false;
  }

  engine.thread = lua_newthread(lua);
  engine.threadRef = luaL_ref(lua, LUA_REGISTRYINDEX);
  *static_cast<Engine**>(lua_getextraspace(engine.thread)) = &engine;
  lua_sethook(engine.thread, instructionHook, LUA_MASKCOUNT, 5'000);
  lua_xmove(lua, engine.thread, 1);

  lua_rawgeti(engine.thread, LUA_REGISTRYINDEX, engine.moduleRef);
  lua_getfield(engine.thread, -1, "operations");
  lua_getfield(engine.thread, -1, operation);
  if (!lua_isfunction(engine.thread, -1)) {
    failure = std::string("Lua 来源未实现 ") + operation;
    return false;
  }
  lua_remove(engine.thread, -2);
  lua_remove(engine.thread, -2);
  lua_insert(engine.thread, -2);
  if (!pushDecodedJson(
          engine,
          engine.thread,
          queryJson)) {
    failure = stackError(engine.thread);
    return false;
  }
  return true;
}

}  // namespace

extern "C" {

BITREE_LUA_API int bitree_lua_inspect(
    const char* source,
    const char* fileName,
    const char* requiredOperationsJson,
    const char* baseStepsJson,
    int timeoutMs,
    char** infoJson,
    char** errorJsonOut) {
  if (infoJson == nullptr || errorJsonOut == nullptr) return -1;
  *infoJson = nullptr;
  *errorJsonOut = nullptr;

  Engine engine;
  std::string failure;
  if (!openEngine(engine, source, fileName, nullptr, timeoutMs, true, failure)) {
    setError(errorJsonOut, normalizeFailure(failure));
    closeEngine(engine);
    return -1;
  }

  std::vector<std::string> operations;
  std::vector<std::string> steps;
  std::vector<std::string> requiredOperations;
  std::vector<std::string> baseSteps;
  bool ok = decodeArray(
                engine,
                requiredOperationsJson,
                requiredOperations,
                failure) &&
            decodeArray(engine, baseStepsJson, baseSteps, failure) &&
            collectFunctions(engine, "operations", true, operations, failure) &&
            collectFunctions(engine, "steps", false, steps, failure) &&
            verifyFunctions(
                operations,
                "operations",
                requiredOperations,
                failure) &&
            verifyFunctions(steps, "steps", baseSteps, failure);
  if (ok) {
    const std::string info =
        "{\"operations\":" + arrayJson(operations) + ",\"steps\":" +
        arrayJson(steps) + "}";
    *infoJson = duplicate(info);
    ok = *infoJson != nullptr;
    if (!ok) failure = "无法分配结果";
  }
  closeEngine(engine);
  if (!ok) {
    setError(errorJsonOut, normalizeFailure(failure));
    return -1;
  }
  return 0;
}

BITREE_LUA_API int bitree_lua_execute_start(
    const char* source,
    const char* fileName,
    const char* operation,
    const char* queryJson,
    const char* contextJson,
    BitreeLuaHostCallback host,
    const volatile int* cancelFlag,
    int timeoutMs,
    void** execution,
    char** yieldJson,
    char** resultJson,
    char** errorJsonOut) {
  if (execution == nullptr || yieldJson == nullptr || resultJson == nullptr ||
      errorJsonOut == nullptr) {
    return -1;
  }
  *execution = nullptr;
  *yieldJson = nullptr;
  *resultJson = nullptr;
  *errorJsonOut = nullptr;

  auto* engine = new Engine();
  engine->host = host;
  std::string failure;
  if (!openEngine(
          *engine,
          source,
          fileName,
          cancelFlag,
          timeoutMs,
          true,
          failure)) {
    setError(errorJsonOut, normalizeFailure(failure));
    closeEngine(*engine);
    delete engine;
    return -1;
  }
  engine->active = true;
  if (!beginOperation(
          *engine,
          operation,
          queryJson,
          contextJson,
          failure)) {
    setError(errorJsonOut, normalizeFailure(failure));
    closeEngine(*engine);
    delete engine;
    return -1;
  }

  int results = 0;
  const int status = lua_resume(engine->thread, nullptr, 2, &results);
  const int outcome = finishExecution(
      *engine,
      status,
      results,
      yieldJson,
      resultJson,
      errorJsonOut);
  if (outcome == BITREE_LUA_YIELDED) {
    *execution = engine;
  } else {
    delete engine;
  }
  return outcome;
}

BITREE_LUA_API int bitree_lua_execute_resume(
    void* execution,
    const char* valueJson,
    const char* errorJsonValue,
    char** yieldJson,
    char** resultJson,
    char** errorJsonOut) {
  if (yieldJson == nullptr || resultJson == nullptr || errorJsonOut == nullptr) {
    return -1;
  }
  *yieldJson = nullptr;
  *resultJson = nullptr;
  *errorJsonOut = nullptr;
  auto* engine = static_cast<Engine*>(execution);
  if (engine == nullptr || engine->lua == nullptr ||
      engine->thread == nullptr) {
    setError(errorJsonOut, errorJson("script_error", "Lua 执行实例已失效"));
    return -1;
  }

  std::string failure;
  if (executionStopped(*engine, failure)) {
    setError(errorJsonOut, failure);
    closeEngine(*engine);
    return -1;
  }

  int arguments = 0;
  engine->resumeFailure = errorJsonValue == nullptr ? "" : errorJsonValue;
  if (errorJsonValue == nullptr) {
    if (!pushDecodedJson(
            *engine,
            engine->lua,
            valueJson)) {
      failure = stackError(engine->lua);
      setError(errorJsonOut, normalizeFailure(failure));
      closeEngine(*engine);
      return -1;
    }
    lua_xmove(engine->lua, engine->thread, 1);
    arguments = 1;
  }

  int results = 0;
  const int status = lua_resume(engine->thread, nullptr, arguments, &results);
  return finishExecution(
      *engine,
      status,
      results,
      yieldJson,
      resultJson,
      errorJsonOut);
}

BITREE_LUA_API void bitree_lua_execution_free(void* execution) {
  auto* engine = static_cast<Engine*>(execution);
  if (engine == nullptr) return;
  closeEngine(*engine);
  delete engine;
}

BITREE_LUA_API int bitree_lua_filter(
    const char* source,
    const char* fileName,
    const char* dataJson,
    const volatile int* cancelFlag,
    int timeoutMs,
    char** resultJson,
    char** errorJsonOut) {
  if (resultJson == nullptr || errorJsonOut == nullptr) return -1;
  *resultJson = nullptr;
  *errorJsonOut = nullptr;

  Engine engine;
  std::string failure;
  if (!openEngine(
          engine,
          source,
          fileName,
          cancelFlag,
          timeoutMs,
          false,
          failure)) {
    setError(errorJsonOut, normalizeFailure(failure));
    closeEngine(engine);
    return -1;
  }
  lua_State* lua = engine.lua;
  engine.active = true;
  lua_rawgeti(lua, LUA_REGISTRYINDEX, engine.filterRef);
  bool ok = true;
  if (!pushDecodedJson(engine, lua, dataJson)) {
    failure = stackError(lua);
    ok = false;
  } else if (!runProtected(lua, 1, 1)) {
    failure = stackError(lua);
    ok = false;
  }

  std::string output;
  if (ok) ok = encodeValue(engine, lua, -1, output);
  if (!ok && failure.empty()) failure = stackError(lua);
  engine.active = false;
  closeEngine(engine);
  if (!ok) {
    setError(errorJsonOut, normalizeFailure(failure));
    return -1;
  }
  *resultJson = duplicate(output);
  if (*resultJson == nullptr) {
    setError(errorJsonOut, errorJson("script_error", "无法分配 Lua 结果"));
    return -1;
  }
  return 0;
}

BITREE_LUA_API int bitree_lua_call_step(
    void* opaque,
    const char* name,
    const char* argsJson,
    char** resultJson,
    char** errorJsonOut) {
  if (resultJson == nullptr || errorJsonOut == nullptr) return -1;
  *resultJson = nullptr;
  *errorJsonOut = nullptr;
  auto* engine = static_cast<Engine*>(opaque);
  if (engine == nullptr || engine->lua == nullptr || !engine->active) {
    setError(errorJsonOut, errorJson("script_error", "Lua 运行实例不活跃"));
    return -1;
  }
  if (engine->stepDepth >= 32) {
    setError(errorJsonOut, errorJson("script_error", "Lua 步骤递归过深"));
    return -1;
  }

  lua_State* lua = engine->hostThread == nullptr ? engine->lua
                                                 : engine->hostThread;
  const int top = lua_gettop(lua);
  lua_rawgeti(lua, LUA_REGISTRYINDEX, engine->moduleRef);
  lua_getfield(lua, -1, "steps");
  if (!lua_istable(lua, -1)) {
    lua_settop(lua, top);
    return 2;
  }
  lua_getfield(lua, -1, name);
  if (!lua_isfunction(lua, -1)) {
    lua_settop(lua, top);
    return 2;
  }
  const int function = lua_gettop(lua);
  if (!pushDecodedJson(
          *engine,
          lua,
          argsJson)) {
    const std::string failure = stackError(lua);
    lua_settop(lua, top);
    setError(errorJsonOut, normalizeFailure(failure));
    return -1;
  }
  if (!lua_istable(lua, -1)) {
    lua_settop(lua, top);
    setError(errorJsonOut, errorJson("script_error", "步骤参数必须是数组"));
    return -1;
  }
  const int argsTable = lua_gettop(lua);
  const int count = static_cast<int>(lua_rawlen(lua, argsTable));
  lua_pushvalue(lua, function);
  for (int index = 1; index <= count; ++index) {
    lua_rawgeti(lua, argsTable, index);
  }
  ++engine->stepDepth;
  const bool called = runProtected(lua, count, 1);
  --engine->stepDepth;
  if (!called) {
    const std::string failure = stackError(lua);
    lua_settop(lua, top);
    setError(errorJsonOut, normalizeFailure(failure));
    return -1;
  }
  std::string output;
  if (!encodeValue(*engine, lua, -1, output)) {
    const std::string failure = stackError(lua);
    lua_settop(lua, top);
    setError(errorJsonOut, normalizeFailure(failure));
    return -1;
  }
  lua_settop(lua, top);
  *resultJson = duplicate(output);
  if (*resultJson == nullptr) {
    setError(errorJsonOut, errorJson("script_error", "无法分配步骤结果"));
    return -1;
  }
  return 0;
}

BITREE_LUA_API void bitree_lua_free(void* value) {
  std::free(value);
}

}  // extern "C"
