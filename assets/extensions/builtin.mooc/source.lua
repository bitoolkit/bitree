local operations = {}

local function forward(name)
  return function(ctx, query)
    return ctx.base.call(name, query)
  end
end

for _, name in ipairs({ "courses.list", "courses.resolve", "deadlines.read" }) do
  operations[name] = forward(name)
end

return { operations = operations }
