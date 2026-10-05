-- Crabby DE LA FORTALEZA: el MISMO Crabby (y el mismo Crabby trampolín) con chapa de acero y remaches:
-- assets/images/crabby_fortress/ (tools/ui/make_variant_skins.py --apply; opción A "Acero" elegida por el usuario).
-- Es un ASPECTO del Crabby (Crabby.SKINS.fortress): mismas reglas, mismos tamaños.
local Entity  = require 'src/world/entities/Entity'
local base    = require 'src/world/entities/types/crabby'
local tbase   = require 'src/world/entities/types/crabbytramp'
local Crabby, TC = base.class, tbase.class
local D = 'assets/images/crabby_fortress/'

local Fort = Entity.extend(Crabby, { debugColor = { 0.7, 0.75, 0.8 } })
Fort.skinId = 'fortress'
local FortTramp = Entity.extend(TC, { debugColor = { 0.7, 0.75, 0.8 } })
FortTramp.skinId = 'fortress'

local function copy(src, over)
    local def = {}
    for k, v in pairs(src) do def[k] = v end
    for k, v in pairs(over) do def[k] = v end
    return def
end
local function icon(x, y, s)
    Crabby.loadAssets()
    local body = Crabby.SKINS.fortress.idle1
    local k = s / 16
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(body, x, y + s - body:getHeight() * k, 0, k, k)
end

return {
    copy(base, { name = 'crabby_fortress', label = 'Crabby de la fortaleza (pincho)', class = Fort,
                 description = 'Crabby de acero para la isla de la fortaleza: igual que el Crabby.',
                 variant = { group = 'crabby_fortress', label = 'Pincho', groupLabel = 'Crabby de la fortaleza', prop = 'Se esconde bajo' },
                 editor = { sprite = D .. 'crab1.png', draw = icon } }),
    copy(tbase, { name = 'crabbytramp_fortress', label = 'Crabby de la fortaleza (trampolín)', class = FortTramp,
                  description = 'Crabby trampolín de acero para la isla de la fortaleza.',
                  variant = { group = 'crabby_fortress', label = 'Trampolín', groupLabel = 'Crabby de la fortaleza', prop = 'Se esconde bajo' },
                  editor = { sprite = D .. 'crab1.png', draw = icon } }),
}
