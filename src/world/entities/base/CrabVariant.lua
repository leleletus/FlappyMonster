-- Una VARIANTE del Crabby que solo cambia de ASPECTO (Crabby.SKINS[id]: su carpeta de imágenes, sus pinzas): las dos
-- definiciones de siempre — con pincho y con trampolín — en una ficha del editor con selector. Mismas reglas.
--   return CrabVariant.defs('river', 'Crabby de río', 'crabby_river', 'crabbytramp_river', 'descripción…')
local Entity = require 'src/world/entities/base/Entity'

local V = {}

function V.defs(skin, label, name, trampName, desc, tuning, fields)
    local base  = require 'src/world/entities/types/enemies/crabby'
    local tbase = require 'src/world/entities/types/enemies/crabbytramp'
    local Crabby, TC = base.class, tbase.class
    local D = 'assets/images/enemies/crabby_' .. (skin == 'fortress' and 'fortress' or skin) .. '/'
    local function class(parent)
        local cls = Entity.extend(parent, tuning or {})
        cls.skinId = skin
        for k, v in pairs(fields or {}) do cls[k] = v end          -- (p. ej. topperDy: la tapa encajada en el lomo)
        function cls.sizeImage() Crabby.loadAssets(); return Crabby.SKINS[skin].idle1 end
        return cls
    end
    local function copy(src, over)
        local def = {}
        for k, v in pairs(src) do def[k] = v end
        for k, v in pairs(over) do def[k] = v end
        return def
    end
    local function icon(x, y, s)
        Crabby.loadAssets()
        local body = Crabby.SKINS[skin].idle1
        local k = s / body:getWidth()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(body, x, y + s - body:getHeight() * k, 0, k, k)
    end
    local group = name
    return {
        copy(base, { name = name, label = label .. ' (pincho)', class = class(Crabby), description = desc,
                     variant = { group = group, label = 'Pincho', groupLabel = label, prop = 'Se esconde bajo' },
                     editor = { sprite = D .. 'crab1.png', draw = icon } }),
        copy(tbase, { name = trampName, label = label .. ' (trampolín)', class = class(TC),
                      description = desc .. ' Con trampolín.',
                      variant = { group = group, label = 'Trampolín', groupLabel = label, prop = 'Se esconde bajo' },
                      editor = { sprite = D .. 'crab1.png', draw = icon } }),
    }
end

return V
