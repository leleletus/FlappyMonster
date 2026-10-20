-- tools/tests/lib/garbage_profile.lua — BASURA POR FUNCIÓN (docs/testing/performance.md): envuelve las funciones de
-- los módulos de src/ ya cargados y cuenta los KB de Lua que crea cada una SIN contar las que llama. El envoltorio no
-- crea nada (las devoluciones pasan por varargs). Hay que medir con el recolector PARADO (si no, sus pasadas
-- restan). Lo usan el arnés perf (GARB=1) y el servidor (FM_PERF=2).
--   local G = require 'tools/tests/lib/garbage_profile'
--   G.wrap()                 envuelve (una vez)
--   G.reset()                pone a cero
--   G.top(n, per)            → { {nombre, KB / per}, ... } las n que más crean
local G = {}
local garb, stack = {}, {}
local wrapped = false

function G.wrap()
    if wrapped then return end
    wrapped = true
    local seen = {}
    local function wrapTable(t, prefix)
        if seen[t] then return end
        seen[t] = true
        for k, f in pairs(t) do
            if type(f) == 'function' and type(k) == 'string' then
                local key = prefix .. k
                local function finish(c0, ...)
                    local used = collectgarbage('count') - c0
                    local child = stack[#stack]
                    stack[#stack] = nil
                    garb[key] = (garb[key] or 0) + used - child
                    if #stack > 0 then stack[#stack] = stack[#stack] + used end
                    return ...
                end
                t[k] = function(...)
                    stack[#stack + 1] = 0
                    return finish(collectgarbage('count'), f(...))
                end
            end
        end
    end
    for name, m in pairs(package.loaded) do
        if type(name) == 'string' and name:match('^src/') and type(m) == 'table' then
            local short = name:match('[^/]+$')
            wrapTable(m, short .. '.')
            local mt = getmetatable(m)
            if mt and type(mt.__index) == 'table' then wrapTable(mt.__index, short .. ':') end
        end
    end
end

function G.reset() garb = {} end

function G.top(n, per)
    local l = {}
    for k, v in pairs(garb) do l[#l + 1] = { k, v / (per or 1) } end
    table.sort(l, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(n, #l) do out[i] = l[i] end
    return out
end

return G
