-- src/story/Campaigns.lua
-- Las CAMPAÑAS con partidas (la historia de Aventura y la campaña Flappy), como descriptores: lo que la pantalla de
-- PARTIDAS (src/states/story/StorySlotState.lua) y CONTINUAR (src/states/menu/TitleState.lua) necesitan saber de cada
-- una, para que las dos usen el mismo código (golden rule 2).
--   id, saves (SLOTS, load, write, delete, modtime), run (src/story/RunCore.lua + lo suyo), worlds (count, get, nodes)
--   map           estado de su mapa
--   back          { estado, args } al que vuelve ATRÁS desde las partidas
--   difficulties  ids de src/core/Difficulty.lua que se ofrecen al crear una partida (en orden)
--   unlocked()    las dificultades desbloqueadas (globales) → { [id] = true }
--   title         clave de idioma del rótulo de las partidas
--   worldName(W)  nombre del mundo / zona
--   scene(W)      ventana de la etiqueta del cartucho (assets/images/ui/menus/cart_labels.png; 'new' si no tiene)
--   shards(d)     fragmentos que lleva la partida, total (nil = la campaña no tiene)
--   slotDesc(s)   la línea de abajo con un cartucho elegido
--   introFilm     película al crear una partida (nil = ninguna)
--   newHint, emptyDesc  claves de idioma del cartucho vacío y de su línea de abajo
local L = require 'src/core/Lang'

local Campaigns = {}
local cache = {}

local DEF = {
    story = function()
        local Save, Shards = require 'src/story/Save', require 'src/story/Shards'
        return {
            id = 'story', saves = Save, run = require 'src/story/Run', worlds = require 'src/story/Worlds',
            map = 'story_map', back = { 'adv_mode_select', { selected = 2 } },   -- (2 = HISTORIA: el TUTORIAL es el 1)
            difficulties = require('src/core/Difficulty').ORDER,
            unlocked = function() return Save.global().unlocked end,
            title = 'story.title',
            worldName = function(W) return L('story.world.' .. W.id) end,
            scene = function(W) return W.id end,
            shards = function(d) return Shards.count(d) end,
            slotDesc = function(s) return L('story.slot_desc', { world = s.world, shards = s.shards, total = s.shardsTotal }) end,
            introFilm = 'intro', newHint = 'story.slot_new_hint', emptyDesc = 'story.slot_empty',
        }
    end,
    flappy = function()
        local FlappySave = require 'src/flappy/FlappySave'
        return {
            id = 'flappy', saves = FlappySave, run = require 'src/flappy/FlappyRun', worlds = require 'src/flappy/Zones',
            map = 'flappy_map', back = { 'flappy_campaign', { select = 'campaign' } },
            difficulties = FlappySave.DIFFICULTIES,
            unlocked = function() return {} end,
            title = 'flappy.slots_title',
            worldName = function(W) return L('flappy.zone.' .. W.id) end,
            scene = function() return 'new' end,                -- (la ventana del Valle llega con el arte del Plan 5)
            slotDesc = function(s) return L('flappy.slot_desc', { zone = s.world }) end,
            newHint = 'flappy.slot_new_hint', emptyDesc = 'flappy.slot_empty',
        }
    end,
}
Campaigns.IDS = { 'flappy', 'story' }

function Campaigns.get(id)
    id = DEF[id] and id or 'story'
    cache[id] = cache[id] or DEF[id]()
    return cache[id]
end

return Campaigns
