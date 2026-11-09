local raw_host_call = __bitree_host_call
local host_available = __bitree_host_available == true
__bitree_host_call = nil
__bitree_host_available = nil

local function fail(message)
  error(message, 0)
end

local json_array_meta = { __jsontype = 'array' }
local json_object_meta = { __jsontype = 'object' }
local json = dkjson
local rawEncode, rawDecode = dkjson.encode, dkjson.decode

local function encodeJson(value)
  local ok, result = pcall(rawEncode, value)
  if not ok then fail(result) end
  return result
end

local function decodeJson(text)
  local value, position, message = rawDecode(
    text, 1, json.null, json_object_meta, json_array_meta)
  if message ~= nil then fail(message) end
  if string.match(string.sub(text, position), '^%s*$') == nil then
    fail('JSON 末尾还有内容')
  end
  return value
end

json.encode = encodeJson
json.decode = decodeJson
json.array = function(...)
  return setmetatable({ ... }, json_array_meta)
end
json.object = function(value)
  return setmetatable(value or {}, json_object_meta)
end

__bitree_json_encode = json.encode
__bitree_json_decode = json.decode

local function hostArgs(...)
  local args = json.array()
  for index = 1, select('#', ...) do args[index] = select(index, ...) end
  return args
end

local function hostRequest(kind, name, ...)
  return { kind = kind, name = name, args = hostArgs(...) }
end

local function hostCall(request)
  if not host_available then
    fail('当前运行不支持宿主能力')
  end
  return raw_host_call(request)
end

local time = {}
time.localDateTime = function(date, clock)
  return hostCall(hostRequest('time.localDateTime', nil, date, clock))
end
time.addDays = function(date, amount)
  return hostCall(hostRequest('time.addDays', nil, date, amount))
end
time.format = function(value)
  return tostring(value)
end
time.parse = function(value)
  return hostCall(hostRequest('time.parse', nil, value))
end

local url = {}
url.parse = function(value)
  return hostCall(hostRequest('url.parse', nil, value))
end
url.resolve = function(base, reference)
  return hostCall(hostRequest('url.resolve', nil, base, reference))
end
url.encodeQuery = function(query)
  return hostCall(hostRequest('url.encodeQuery', nil, query))
end

local encoding = {}
encoding.base64Encode = function(value)
  return hostCall(hostRequest('encoding.base64Encode', nil, value))
end
encoding.base64Decode = function(value)
  return hostCall(hostRequest('encoding.base64Decode', nil, value))
end
encoding.utf8Encode = function(value)
  return hostCall(hostRequest('encoding.utf8Encode', nil, value))
end
encoding.utf8Decode = function(value)
  return hostCall(hostRequest('encoding.utf8Decode', nil, value))
end

local function makeContext(raw)
  raw = decodeJson(raw)
  local ctx = {
    config = raw.config or {},
    scope = raw.scope or {},
    source = raw.source or {},
    locale = raw.locale or 'zh',
    json = json,
    time = time,
    url = url,
    encoding = encoding,
  }
  ctx.storage = {
    get = function(key)
      return hostCall(hostRequest('storage.get', nil, key))
    end,
    set = function(key, value)
      return hostCall(hostRequest('storage.set', nil, key, value))
    end,
    remove = function(key)
      return hostCall(hostRequest('storage.remove', nil, key))
    end,
  }
  ctx.log = {
    info = function(message)
      return hostCall(hostRequest('log', nil, 'info', tostring(message)))
    end,
    warn = function(message)
      return hostCall(hostRequest('log', nil, 'warn', tostring(message)))
    end,
    error = function(message)
      return hostCall(hostRequest('log', nil, 'error', tostring(message)))
    end,
  }
  ctx.checkCancelled = function()
    return hostCall(hostRequest('cancel', nil))
  end
  ctx.fail = function(code, message, details)
    error('__bitree_error__' .. encodeJson({
      code = tostring(code),
      message = tostring(message),
      details = details or json.null,
    }), 0)
  end
  local contextView = {
    config = ctx.config,
    scope = ctx.scope,
    source = ctx.source,
    locale = ctx.locale,
  }
  ctx.data = {}
  for _, name in ipairs(raw.data or {}) do
    local dataName = name
    ctx.data[dataName] = function(query)
      return hostCall(hostRequest('data', dataName, query or json.object()))
    end
  end
  ctx.base = {
    call = function(name, query)
      return hostCall(hostRequest(
        'base.call', tostring(name), query or json.object()))
    end,
    steps = {},
  }
  for _, name in ipairs(raw.steps or {}) do
    local stepName = name
    ctx.base.steps[stepName] = function(...)
      local args = hostArgs(...)
      if args[1] == ctx then args[1] = contextView end
      return hostCall({ kind = 'step', name = stepName, args = args })
    end
  end
  ctx.http = {
    request = function(request)
      if type(request) ~= 'table' then
        fail('HTTP 请求必须是 table')
      end
      local raw = hostCall(hostRequest('http.request', nil, request))
      local body = raw.body or ''
      return {
        status = raw.status,
        url = raw.url,
        headers = raw.headers or {},
        text = function() return body end,
        bytes = function() return raw.bytes or {} end,
        json = function() return decodeJson(body) end,
      }
    end,
  }
  return ctx
end

__bitree_make_context = makeContext

local loaded_modules = package.loaded
loaded_modules['bitree.json'] = json
loaded_modules['bitree.time'] = time
loaded_modules['bitree.url'] = url
loaded_modules['bitree.encoding'] = encoding

local display = {}

function display.renameCourses(data, aliases)
  for _, course in ipairs(data.courses or {}) do
    course.name = aliases[course.name] or course.name
  end
  for _, name in ipairs({ 'deadlines', 'events', 'exams' }) do
    for _, entry in ipairs(data[name] or {}) do
      entry.course = aliases[entry.course] or entry.course
    end
  end
  return data
end

function display.hideDeadlines(data, sources)
  local hidden = {}
  for _, source in ipairs(sources) do hidden[source] = true end
  local kept = json.array()
  for _, ddl in ipairs(data.deadlines or {}) do
    if not hidden[ddl.source] then kept[#kept + 1] = ddl end
  end
  data.deadlines = kept
  return data
end

function display.prefixExams(data, prefix)
  for _, exam in ipairs(data.exams or {}) do
    exam.title = prefix .. exam.title
  end
  return data
end

function display.apply(data, rules)
  if rules.courseAliases then display.renameCourses(data, rules.courseAliases) end
  if rules.hiddenDeadlineSources then
    display.hideDeadlines(data, rules.hiddenDeadlineSources)
  end
  if rules.examTitlePrefix then display.prefixExams(data, rules.examTitlePrefix) end
  return data
end

loaded_modules['bitree.display'] = display

local globals = _G

-- Display rules run first; a user script then receives their result.
__bitree_filter = function(payload)
  local data = payload.data
  if payload.rules ~= nil then data = display.apply(data, payload.rules) end
  if payload.script then
    local filter = rawget(globals, 'filter')
    if type(filter) ~= 'function' then
      fail('Define function filter(data) and return data.')
    end
    data = filter(data)
  end
  return data
end

local function safeRequire(name)
  if type(name) ~= 'string' or string.sub(name, 1, 7) ~= 'bitree.' then
    fail('只能加载宿主提供的 bitree.* 模块')
  end
  local module = loaded_modules[name]
  if module == nil then fail('找不到模块 ' .. name) end
  return module
end

require = safeRequire
package = nil
io = nil
os = nil
debug = nil
dofile = nil
loadfile = nil
load = nil
string.dump = nil
print = function() end

local collect = collectgarbage
collectgarbage = function(option, ...)
  if option == nil or option == 'count' or option == 'isrunning' then
    return collect(option, ...)
  end
  fail('collectgarbage 只允许查询内存用量')
end
