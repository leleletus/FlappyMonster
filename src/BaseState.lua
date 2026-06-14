-- src/BaseState.lua
-- Clase base para todos los estados. Implementa métodos vacíos
-- para que los estados hijos sólo sobreescriban lo que necesitan.

local Class = require 'libs/class'
local BaseState = Class:new()

function BaseState:enter(args) end
function BaseState:exit()      end
function BaseState:update(dt)  end
function BaseState:render()    end

return BaseState
