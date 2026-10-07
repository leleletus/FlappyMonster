-- src/story/BonusMatch.lua
-- PARTIDA BONUS del modo historia: una arena de Rey de la Colina contra el BOT (src/ai/Bot.lua), dentro de
-- AdventureState (`args.bonus = { onEnd = function(result) end }`). Reglas:
--   * dura `BonusMatch.TIME` s (60); estar en una zona de puntos da puntos (src/world/PointAreas.lua), a ti
--     y al bot por separado; gana quien tenga más al acabar el tiempo (empate = no ganas);
--   * según la dificultad el bot es más o menos hostil y en Xtra extremo son DOS (cuenta el mejor de los dos);
--   * el bot es INMORTAL (los golpes le llegan, no muere) y te echa de la zona a ground pounds (te lanza lejos);
--     tu ground pound cerca de él también lo empuja a él;
--   * aquí tus vidas no cuentan: caer o morir solo te hace perder tiempo (vidas de sobra, no vuelven a la aventura).
-- Lo que AdventureState le pide: BonusMatch.new(state, opts), :update(dt), :players(), :award(pa, pts),
-- :render(camX, camY), :renderHud(); `state.bonus.over` = ha terminado.
local Bot = require 'src/ai/Bot'
local BotNav = require 'src/ai/BotNav'
local PlayerAdventure = require 'src/entities/PlayerAdventure'
local OnlinePlayer = require 'src/entities/OnlinePlayer'
local Interactions = require 'src/world/entities/Interactions'
local Difficulty = require 'src/Difficulty'
local PixelFont = require 'src/ui/PixelFont'
local L = require 'src/Lang'

local BonusMatch = {}
BonusMatch.__index = BonusMatch

BonusMatch.END_T = 3.2                   -- s del cartel final antes de volver
BonusMatch.BOT_COLOR = { 1, 0.35, 0.3 }
BonusMatch.BOT_COLORS = { { 1, 0.35, 0.3 }, { 0.75, 0.4, 1 } }

BonusMatch.TIME = 60                     -- s (el usuario: más se hace largo; el online tiene su propio tiempo)

function BonusMatch.new(state, opts)
    local level = state.level
    local name = state.levelPath:match('([^/]+)%.json$')
    local nav = BotNav.load(name, level)
    if not nav or nav.stale then nav = BotNav.build(level) end          -- (sin archivo o nivel cambiado: se hace ahora)
    local sx, sy = level:getSpawnPx()
    local self = setmetatable({
        state = state, level = level, opts = opts or {},
        time = BonusMatch.TIME, t = 0, over = false, endT = 0, botScore = 0, bots = {},
    }, BonusMatch)
    -- La dificultad decide lo HOSTIL que es (src/Difficulty.lua: botRest, botChase) y cuántos son (Xtra extremo: 2).
    -- El primero sale del otro lado de la arena (en espejo); el segundo, del centro.
    local n = math.max(1, math.floor(Difficulty.k('botCount')))
    for i = 1, n do
        local col = (i == 1) and (level.tileW - (level.playerStart[1] or 2) + 1) or math.floor(level.tileW / 2)
        local bx, by = level:findGround(col)
        local pa = PlayerAdventure:new(bx or (sx + TILE_PX), by or sy)
        pa.spawnX, pa.spawnY = pa.x, pa.y
        pa.facing = -1
        local bot = Bot.new(pa, nav, { firstDelay = 1.5 + (i - 1) * 1.2, attackCd = Bot.ATTACK_CD * Difficulty.k('botRest'),
                                       chase = Difficulty.k('botChase', Bot.CHASE_R) })
        bot.score = 0
        bot.view = OnlinePlayer:new('bot' .. i, L('story.bonus.bot') .. (n > 1 and (' ' .. i) or ''), BonusMatch.BOT_COLORS[i] or BonusMatch.BOT_COLOR)
        self.bots[i] = bot
    end
    self.bot = self.bots[1]
    -- (el bonus no gasta las vidas de la aventura ni puede acabar en Game Over: por dentro lleva 99 para que morir solo
    -- sea reaparecer; el contador de vidas NO se dibuja en el bonus — AdventureState —, antes salía "x99")
    state.player.lives = 99
    return self
end

function BonusMatch:players()
    local list = {}
    if not self.state.player.dying then list[#list + 1] = self.state.player end
    for _, b in ipairs(self.bots) do list[#list + 1] = b.pa end
    return list
end

-- Puntos de una zona: al jugador (true) o a un bot (la marca a batir es la del MEJOR bot)
function BonusMatch:award(pa, pts)
    for _, b in ipairs(self.bots) do
        if pa == b.pa then
            b.score = b.score + pts
            self.botScore = math.max(self.botScore, b.score)
            return false
        end
    end
    return true
end

function BonusMatch:left() return math.max(0, self.time - self.t) end

function BonusMatch:update(dt)
    local st, bot = self.state, self.bot
    if self.over then
        self.endT = self.endT + dt
        if self.endT >= BonusMatch.END_T and not self.sent then
            self.sent = true
            if self.opts.onEnd then
                local s = st.stats or {}
                self.opts.onEnd({ won = self.won, score = st.score, botScore = self.botScore, zoneT = s.zoneT, time = self.time,
                                  deaths = s.deaths, items = s.items, itemsTotal = s.itemsTotal })
            end
        end
        return
    end
    self.t = self.t + dt
    local player = st.player
    for _, bot in ipairs(self.bots) do
        bot:step(dt, self.level, player)
        Interactions.run(bot.pa, st.enemies, {})                   -- (los enemigos le pegan y lo empujan; no muere)
        if not player.dying and bot:push(player) then Sound.play('gpImpact') end
        -- tu ground pound cerca de él: lo empujas tú
        if player.gpLanded and not player.dying then
            local dx, dy = bot.pa.x - player.x, bot.pa.y - player.y
            if math.abs(dx) < Bot.PUSH_R * TILE_PX and math.abs(dy) < 1.3 * TILE_PX then
                bot.pa:launch(((dx < 0) and -1 or 1) * Bot.PUSH_VX * 0.8, Bot.PUSH_VY)
                bot.pa.stunT = math.max(bot.pa.stunT or 0, 0.6)
                Sound.play('stunned')
            end
        end
    end
    if self:left() <= 0 then
        self.over, self.won = true, st.score > self.botScore
        -- (se acabó: el jugador queda CONGELADO — sin control e invulnerable — hasta salir; antes seguía
        -- moviéndose y hasta podía morir con el cartel del resultado en pantalla)
        st.player.forceFrozen = true
        Sound.stopMusic()
        Sound.play(self.won and 'fanfare' or 'dies2')
    end
end

function BonusMatch:render(camX, camY)
    for i, bot in ipairs(self.bots) do
        local pa, v = bot.pa, bot.view
        v:applyData({ x = pa.x, y = pa.y, facing = pa.facing, frame = pa.frame, dying = false,
                      stunned = (pa.stunT or 0) > 0, hurt = (pa.hurtT or 0) > 0, invuln = pa:isInvulnerable(),
                      squashed = (pa.squashT or 0) > 0, iced = (pa.iceT or 0) > 0,
                      color = BonusMatch.BOT_COLORS[i] or BonusMatch.BOT_COLOR })
        v:render(camX, camY)
    end
end

function BonusMatch:renderHud()
    local st = self.state
    local secs = self:left()
    local clock = string.format('%d:%02d', math.floor(secs / 60), math.floor(secs) % 60)
    local you, bot = L('story.bonus.you') .. ' ' .. st.score, L('story.bonus.bot') .. ' ' .. self.botScore
    local s = 4
    local gap = 36
    local w = PixelFont.width(you, s) + gap + PixelFont.width(clock, s) + gap + PixelFont.width(bot, s)
    local x, y = math.floor((WINDOW_W - w) / 2), 96
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle('fill', x - 14, y - 10, w + 28, PixelFont.height(s) + 20)
    local lead = st.score - self.botScore
    PixelFont.shadow(you, x, y, s, 1, (lead >= 0) and { 1, 0.95, 0.2 } or { 1, 1, 1 })
    x = x + PixelFont.width(you, s) + gap
    local urgent = secs <= 10 and math.floor(secs * 4) % 2 == 0
    PixelFont.shadow(clock, x, y, s, 1, urgent and { 1, 0.3, 0.25 } or { 1, 1, 1 })
    x = x + PixelFont.width(clock, s) + gap
    PixelFont.shadow(bot, x, y, s, 1, (lead < 0) and BonusMatch.BOT_COLOR or { 1, 1, 1 })
    if self.over then
        local msg = L(self.won and 'story.bonus.win' or 'story.bonus.lose')
        local ms = 8
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle('fill', 0, WINDOW_H / 2 - 70, WINDOW_W, 140)
        PixelFont.shadow(msg, math.floor((WINDOW_W - PixelFont.width(msg, ms)) / 2), math.floor(WINDOW_H / 2 - PixelFont.height(ms) / 2),
                         ms, 1, self.won and { 1, 0.9, 0.25 } or { 1, 0.4, 0.35 })
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return BonusMatch
