local json_array_meta = { __jsontype = 'array' }
local json_object_meta = { __jsontype = 'object' }
local rawEncode, rawDecode = dkjson.encode, dkjson.decode

__bitree_json_encode = rawEncode

__bitree_json_decode = function(text)
  local value, position, message = rawDecode(
    text, 1, dkjson.null, json_object_meta, json_array_meta)
  if message ~= nil then error(message, 0) end
  if string.match(string.sub(text, position), '^%s*$') == nil then
    error('JSON 末尾还有内容', 0)
  end
  return value
end

local globals = _G
__bitree_filter = function(data)
  local filter = rawget(globals, 'filter')
  if type(filter) ~= 'function' then
    error('Define function filter(data) and return data.', 0)
  end
  return filter(data)
end

-- Only data-processing libraries are opened by the native runtime.
load = nil
loadfile = nil
dofile = nil
string.dump = nil
print = function() end

local collect = collectgarbage
collectgarbage = function(option, ...)
  if option == nil or option == 'count' or option == 'isrunning' then
    return collect(option, ...)
  end
  error('collectgarbage 只允许查询内存用量', 0)
end
