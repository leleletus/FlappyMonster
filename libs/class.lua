-- libs/class.lua
-- OOP minimalista para Lua. Basado en rxi/classic.
-- Uso:
--   local MiClase = Class:new()
--   function MiClase:new(args)  ...  end
--   function MiClase:metodo()   ...  end
--   local obj = MiClase:new(args)

local Class = {}
Class.__index = Class

function Class:new(...)
    local o = setmetatable({}, self)
    self.__index = self
    if o.init then o:init(...) end
    return o
end

function Class:extend()
    local cls = {}
    cls.__index = cls
    setmetatable(cls, self)
    return cls
end

function Class:is(klass)
    local mt = getmetatable(self)
    while mt do
        if mt == klass then return true end
        mt = getmetatable(mt)
    end
    return false
end

function Class:__tostring()
    return "Class"
end

return Class