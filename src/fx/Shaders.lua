-- src/fx/Shaders.lua
-- LOS SHADERS del juego, en un registro (0.5.188): cada módulo DEFINE el suyo con un nombre (su código va junto a quien
-- lo usa) y lo PIDE por ese nombre; se compila una sola vez. `Shaders.warm()` los compila todos al arrancar (game.lua):
-- antes cada uno se compilaba la primera vez que hacía falta — en plena partida, un tirón — y el de invertir colores
-- estaba copiado en cinco sitios (el Espejo, el Espejo perseguidor, el mapa, las cinemáticas: Stage y Actor).
--   Shaders.define(name, source)   source = código GLSL o la ruta de un .glsl
--   Shaders.get(name)              → el shader, o nil (sin shaders en esta plataforma, o no compila)
--   Shaders.warm()                 → cuántos compiló
local Shaders = {}

local src, cache = {}, {}

function Shaders.define(name, source)
    if src[name] ~= nil and src[name] ~= source then error('shader ' .. name .. ' definido dos veces con código distinto') end
    src[name] = source
end

function Shaders.get(name)
    local sh = cache[name]
    if sh == nil then
        local s = src[name]
        local ok, res = false, nil
        if s and love.graphics and love.graphics.newShader then ok, res = pcall(love.graphics.newShader, s) end
        if not ok and s then print('[Shaders] ' .. name .. ': ' .. tostring(res)) end
        sh = ok and res or false
        cache[name] = sh
    end
    return sh or nil
end

function Shaders.warm()
    local n = 0
    for name in pairs(src) do
        if cache[name] == nil and Shaders.get(name) then n = n + 1 end
    end
    return n
end

-- Compartido: invierte los colores (conserva el alfa). El reflejo del Espejo, el Espejo perseguidor, el mapa, las
-- cinemáticas
Shaders.define('invert', [[
    vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc) { vec4 p = Texel(t, uv); return vec4(1.0 - p.rgb, p.a) * c; }
]])

return Shaders
