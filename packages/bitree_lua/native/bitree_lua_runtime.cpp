#include "bitree_lua.h"

#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"

#include <chrono>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <string>

extern const unsigned char kPrelude[];
extern const size_t kPreludeLength;

namespace {

constexpr size_t kMemoryLimit = 32 * 1024 * 1024;
constexpr size_t kInstructionLimit = 50'000'000;

struct Engine {
  lua_State* lua = nullptr;
  size_t memoryUsed = 0;
  size_t steps = 0;
  std::chrono::steady_clock::time_point deadline;
  const volatile int* cancel = nullptr;
  int encodeRef = LUA_NOREF;
  int decodeRef = LUA_NOREF;
  int filterRef = LUA_NOREF;
  int failureStatus = BITREE_LUA_SCRIPT_ERROR;

  ~Engine() {
    if (lua != nullptr) lua_close(lua);
  }
};

void* allocate(void* user, void* pointer, size_t oldSize, size_t newSize) {
  auto* engine = static_cast<Engine*>(user);
  if (pointer == nullptr) oldSize = 0;
  if (newSize == 0) {
    if (pointer != nullptr) {
      engine->memoryUsed -= oldSize;
      std::free(pointer);
    }
    return nullptr;
  }
  const size_t base = engine->memoryUsed - oldSize;
  if (newSize > kMemoryLimit || base > kMemoryLimit - newSize) return nullptr;
  void* result = std::realloc(pointer, newSize);
  if (result != nullptr) engine->memoryUsed = base + newSize;
  return result;
}

char* duplicate(const std::string& value) {
  auto* result = static_cast<char*>(std::malloc(value.size() + 1));
  if (result != nullptr) std::memcpy(result, value.c_str(), value.size() + 1);
  return result;
}

std::string stackError(lua_State* lua) {
  const char* text = lua_tostring(lua, -1);
  return text == nullptr ? "Lua 执行失败" : text;
}

bool runProtected(Engine& engine, int arguments, int results) {
  const int status = lua_pcallk(engine.lua, arguments, results, 0, 0, nullptr);
  if (status == LUA_ERRMEM) engine.failureStatus = BITREE_LUA_MEMORY_LIMIT;
  return status == LUA_OK;
}

void instructionHook(lua_State* lua, lua_Debug*) {
  auto* engine = *static_cast<Engine**>(lua_getextraspace(lua));
  engine->steps += 5'000;
  if (engine->cancel != nullptr && *engine->cancel != 0) {
    engine->failureStatus = BITREE_LUA_CANCELLED;
    lua_pushliteral(lua, "Lua 执行已取消");
    lua_error(lua);
  }
  if (std::chrono::steady_clock::now() >= engine->deadline) {
    engine->failureStatus = BITREE_LUA_TIMEOUT;
    lua_pushliteral(lua, "Lua 执行超时");
    lua_error(lua);
  }
  if (engine->steps > kInstructionLimit) {
    engine->failureStatus = BITREE_LUA_TIMEOUT;
    lua_pushliteral(lua, "Lua 指令预算已用尽");
    lua_error(lua);
  }
}

bool captureGlobal(Engine& engine, const char* name, int& reference) {
  lua_State* lua = engine.lua;
  lua_getglobal(lua, name);
  if (!lua_isfunction(lua, -1)) return false;
  reference = luaL_ref(lua, LUA_REGISTRYINDEX);
  lua_pushnil(lua);
  lua_setglobal(lua, name);
  return true;
}

// Library setup also runs inside pcall so allocation failures stay recoverable.
int initialize(lua_State* lua) {
  const luaL_Reg libraries[] = {
      {LUA_GNAME, luaopen_base},
      {LUA_TABLIBNAME, luaopen_table},
      {LUA_STRLIBNAME, luaopen_string},
      {LUA_MATHLIBNAME, luaopen_math},
      {LUA_UTF8LIBNAME, luaopen_utf8},
      {nullptr, nullptr},
  };
  for (const auto* library = libraries; library->func != nullptr; ++library) {
    luaL_requiref(lua, library->name, library->func, 1);
    lua_pop(lua, 1);
  }
  if (luaL_loadbufferx(
          lua, reinterpret_cast<const char*>(kPrelude), kPreludeLength,
          "@bitree-prelude.lua", "t") != LUA_OK) {
    return lua_error(lua);
  }
  lua_call(lua, 0, 0);
  return 0;
}

bool openEngine(
    Engine& engine,
    const char* source,
    const char* fileName,
    std::string& failure) {
  engine.lua = lua_newstate(allocate, &engine, 0);
  if (engine.lua == nullptr) {
    engine.failureStatus = BITREE_LUA_MEMORY_LIMIT;
    failure = "无法创建 Lua state";
    return false;
  }
  lua_State* lua = engine.lua;
  *static_cast<Engine**>(lua_getextraspace(lua)) = &engine;
  lua_sethook(lua, instructionHook, LUA_MASKCOUNT, 5'000);
  lua_pushcfunction(lua, initialize);
  if (!runProtected(engine, 0, 0)) {
    failure = stackError(lua);
    return false;
  }
  if (!captureGlobal(engine, "__bitree_json_encode", engine.encodeRef) ||
      !captureGlobal(engine, "__bitree_json_decode", engine.decodeRef) ||
      !captureGlobal(engine, "__bitree_filter", engine.filterRef)) {
    failure = "Lua 预置环境不完整";
    return false;
  }
  const std::string chunkName = std::string("@") + fileName;
  const int status = luaL_loadbufferx(
      lua, source, std::strlen(source), chunkName.c_str(), "t");
  if (status == LUA_ERRMEM) engine.failureStatus = BITREE_LUA_MEMORY_LIMIT;
  if (status != LUA_OK || !runProtected(engine, 0, 0)) {
    failure = stackError(lua);
    return false;
  }
  return true;
}

bool filter(Engine& engine, const char* dataJson, std::string& output) {
  lua_State* lua = engine.lua;
  lua_rawgeti(lua, LUA_REGISTRYINDEX, engine.filterRef);
  lua_rawgeti(lua, LUA_REGISTRYINDEX, engine.decodeRef);
  lua_pushstring(lua, dataJson);
  if (!runProtected(engine, 1, 1) || !runProtected(engine, 1, 1)) return false;
  lua_rawgeti(lua, LUA_REGISTRYINDEX, engine.encodeRef);
  lua_pushvalue(lua, -2);
  if (!runProtected(engine, 1, 1)) return false;
  const char* text = lua_tostring(lua, -1);
  if (text == nullptr) {
    lua_pushliteral(lua, "Lua 结果无法转换为 JSON");
    return false;
  }
  output = text;
  return true;
}

}  // namespace

extern "C" {

BITREE_LUA_API int bitree_lua_filter(
    const char* source,
    const char* fileName,
    const char* dataJson,
    const volatile int* cancelFlag,
    int timeoutMs,
    char** resultJson,
    char** errorText) {
  if (resultJson == nullptr || errorText == nullptr) return BITREE_LUA_SCRIPT_ERROR;
  *resultJson = nullptr;
  *errorText = nullptr;
  if (source == nullptr || fileName == nullptr || dataJson == nullptr) {
    *errorText = duplicate("缺少 Lua 输入");
    return BITREE_LUA_SCRIPT_ERROR;
  }

  Engine engine;
  engine.cancel = cancelFlag;
  engine.deadline = std::chrono::steady_clock::now() +
                    std::chrono::milliseconds(timeoutMs);
  std::string failure;
  std::string output;
  if (!openEngine(engine, source, fileName, failure) ||
      !filter(engine, dataJson, output)) {
    if (failure.empty()) failure = stackError(engine.lua);
    *errorText = duplicate(failure);
    return engine.failureStatus;
  }
  *resultJson = duplicate(output);
  if (*resultJson == nullptr) {
    *errorText = duplicate("无法分配 Lua 结果");
    return BITREE_LUA_MEMORY_LIMIT;
  }
  return 0;
}

BITREE_LUA_API void bitree_lua_free(void* value) {
  std::free(value);
}

}  // extern "C"
