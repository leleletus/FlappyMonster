-- src/world/entities/base/NetList.lua
-- Listas PLANAS en el estado propio de una entidad (`netExtra` / `netApplyExtra`): n, y luego n grupos de `stride`
-- números. Antes cada jefe llevaba su copia de readList (Bola de Nieve, Mega Gummy, Escarabajo, Cangrejo del Ritmo,
-- Pez Globo).
--   local list, nextK = NetList.read(b, k, stride)   b[k] = n (no número → 0); list = { {v1..vstride}, ... }
local NetList = {}

function NetList.read(b, k, stride)
    local n = type(b[k]) == 'number' and b[k] or 0
    local list = {}
    for i = 0, n - 1 do
        local e = {}
        for j = 1, stride do e[j] = b[k + 1 + i * stride + j - 1] end
        list[#list + 1] = e
    end
    return list, k + 1 + n * stride
end

return NetList
