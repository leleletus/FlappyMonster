-- src/flappy/Shops.lua
-- Las TIENDAS de los mapas de zona de la campaña Flappy (docs/design/powerups.md § Shops on the world maps), como datos:
-- lo que vende la tienda de cada zona y a qué precio, en puntos del MONEDERO (FlappyRun.buy). Clave = id de la zona
-- (src/flappy/Zones.lua; va en las partidas: nunca se renombra). Las zonas de más adelante venden los power-ups más
-- raros; los precios, altos para que las jaulas sigan valiendo la pena. La pantalla: src/states/flappy/FlappyShopState.lua
local Shops = {}

Shops.LIST = {
    -- 1 El Valle de los Pilares (Plan 5b): lo básico
    valle = { { id = 'shield', price = 300 }, { id = 'heart', price = 400 }, { id = 'magnet_points', price = 250 } },
}

-- Lo que vende la tienda de la zona z (su índice en Zones) → { { id, price }, ... } (vacía si no tiene)
function Shops.forZone(z)
    local Z = require('src/flappy/Zones').get(z)
    return (Z and Shops.LIST[Z.id]) or {}
end

return Shops
