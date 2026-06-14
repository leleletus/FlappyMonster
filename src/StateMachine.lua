-- src/StateMachine.lua
local Class = require 'libs/class'

local StateMachine = Class:new()

function StateMachine:new(states)
    local o = setmetatable({}, self)
    self.__index = self
    o.states = states or {}
    o.stack  = {}   -- pila de estados activos
    return o
end

-- ── Helpers internos ──────────────────────────────────────────────────────────
function StateMachine:_top()
    return self.stack[#self.stack]
end

-- ── API pública ───────────────────────────────────────────────────────────────

-- Reemplaza toda la pila con un nuevo estado (transición normal)
function StateMachine:change(name, args)
    assert(self.states[name], "Estado desconocido: " .. tostring(name))
    -- Sale de todos los estados actuales
    for i = #self.stack, 1, -1 do
        if self.stack[i].exit then self.stack[i]:exit() end
    end
    self.stack = {}
    local state = self.states[name]()
    if state.enter then state:enter(args) end
    table.insert(self.stack, state)
end

-- Apila un nuevo estado encima (el de abajo queda pausado pero vivo)
function StateMachine:push(name, args)
    assert(self.states[name], "Estado desconocido: " .. tostring(name))
    local top = self:_top()
    if top and top.pause then top:pause() end
    local state = self.states[name]()
    if state.enter then state:enter(args) end
    table.insert(self.stack, state)
end

-- Elimina el estado del tope y reactiva el anterior
function StateMachine:pop()
    local top = self:_top()
    if top then
        if top.exit then top:exit() end
        table.remove(self.stack)
    end
    local newTop = self:_top()
    if newTop and newTop.resume then newTop:resume() end
end

-- Update: solo el estado del tope
function StateMachine:update(dt)
    local top = self:_top()
    if top and top.update then top:update(dt) end
end

-- Render: todos los estados de abajo hacia arriba
-- Los estados del fondo pueden declarar render() normalmente;
-- el substate encima dibuja su overlay después.
function StateMachine:render()
    for _, state in ipairs(self.stack) do
        if state.render then state:render() end
    end
end

return StateMachine
