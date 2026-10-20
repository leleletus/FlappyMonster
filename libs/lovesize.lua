--[[
lovesize — MIT License
Copyright (c) 2018 Ricardo Bustamante de Queiroz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
--[[
    lovesize 0.6 by RicardoBusta
    https://github.com/RicardoBusta/
    https://github.com/RicardoBusta/lovesize

    Tested with love 11.0
]]
local lw, lh = 800, 600 -- lovesize target size
local lx, ly = 0, 0 -- translation required to center the game area
local ls = 1 -- scale to fit the game screen to love screen
local lg = love.graphics

local lovesize = {
    -- Set lovesize with the desired width, height and options
    set = function(w, h, options)
        lw = w or lw
        lh = h or lh
        lovesize.resize(lg.getWidth(), lg.getHeight())
    end,
    -- Used to start the lovesize application
    begin = function()
        -- Scissors will keep the game from rendering outside the specified screen. Clean the letterbox before this call.
        lg.push()
        lg.setScissor(lx, ly, lg.getWidth() - 2 * lx, lg.getHeight() - 2 * ly)
        lg.translate(lx, ly)
        lg.scale(ls, ls)
    end,
    -- Used to finish the lovesize application
    finish = function()
        lg.setScissor()
        lg.pop()
    end,
    -- Used to calculate the values used by lovesize
    resize = function(width, height)
        local sx = width / lw
        local sy = height / lh

        -- Check which size scales the most, and add letterbox space to it
        if sx > sy then
            ls = sy
            lx, ly = (width - lw * ls) / 2, 0
        else
            ls = sx
            lx, ly = 0, (height - lh * ls) / 2
        end
    end,
    -- Transforms the x,y coordinates to the game world position
    pos = function(x, y)
        local is = 1 / ls
        return math.floor((x - lx) * is), math.floor((y - ly) * is)
    end,
    -- Checks if the coordinate is inside the screen
    inside = function(x, y)
        return x >= lx and x < lg.getWidth() - lx and y >= ly and y < lg.getHeight() - ly
    end,
    getWidth = function()
        return lw
    end,
    getHeight = function()
        return lh
    end
}

return lovesize
