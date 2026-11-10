-- src/ui/CameraLook.lua
-- MIRAR ARRIBA / ABAJO (0.5.187, el usuario: «un jugador no sabe qué hay arriba o abajo en un salto a ciegas; como en
-- Sonic 1, al mantener agacharse un rato la cámara baja UN POCO para ver lo de debajo, sin exagerar; lo mismo con
-- arriba»). Quieto en el suelo y manteniendo AGACHARSE (o ARRIBA: la acción `grab`) `HOLD` s, la cámara se desliza
-- `LOOK` (una parte de la pantalla) hacia ese lado; al soltar o moverse, vuelve. Solo es la cámara (nada de la
-- simulación): la usan igual un jugador (AdventureState:updateCamera) y el cliente online (su jugador predicho).
--   local dy = CameraLook.offset(st, pa, dt, enabled)   st = una tabla del estado (guarda el tiempo y el desplazamiento)
local CameraLook = {}

CameraLook.HOLD  = 0.6          -- s manteniendo el botón antes de que la cámara se mueva
CameraLook.LOOK  = 0.28         -- × el alto de la pantalla: cuánto se asoma (un poco, sin exagerar)
CameraLook.EASE  = 5            -- 1/s: lo que tarda en llegar / volver (suave)
CameraLook.STILL = 20           -- px/s: más rápido que esto ya no está "quieto"

-- ¿Qué lado pide? +1 abajo (agachado), -1 arriba (ARRIBA mantenido), 0 nada
local function wants(pa)
    if not pa or pa.dying or pa.alive == false or not pa.onGround then return 0 end
    if math.abs(pa.vx or 0) > CameraLook.STILL then return 0 end
    if pa.gulped or pa.frozen or (pa.ctrlLockT or 0) > 0 or (pa.stunT or 0) > 0 then return 0 end
    if pa.crouching and Input.down('crouch') then return 1 end
    if not pa.crouching and Input.down('grab') then return -1 end
    return 0
end

function CameraLook.offset(st, pa, dt, enabled)
    local dir = enabled and wants(pa) or 0
    if dir ~= 0 and dir == st.dir then st.holdT = (st.holdT or 0) + dt else st.holdT = 0 end
    st.dir = dir
    local target = (dir ~= 0 and st.holdT >= CameraLook.HOLD) and dir * WINDOW_H * CameraLook.LOOK or 0
    st.dy = (st.dy or 0) + (target - (st.dy or 0)) * math.min(1, CameraLook.EASE * dt)
    if math.abs(st.dy) < 0.5 and target == 0 then st.dy = 0 end
    return st.dy
end

-- Al reaparecer, al cambiar de escena...: sin desplazamiento
function CameraLook.reset(st) st.holdT, st.dir, st.dy = 0, 0, 0 end

return CameraLook
