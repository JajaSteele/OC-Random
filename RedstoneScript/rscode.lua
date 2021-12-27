local c = require("component")
local rs = c.redstone
local ev = require("event")
local shell = require("shell")
local colors = require("colors")

t1 = io.open("/home/.shrc","w")
t1:write("rscode.lua")
t1:close()

while true do
    local _, _, side, oldV, newV, colorV = ev.pull("redstone_changed")
    if colorV == nil then
        if oldV == 0 and newV > 0 then
            shell.execute("/home/rs/rsON.lua")
        end
        if oldV > 0 and newV == 0 then
            shell.execute("/home/rs/rsOFF.lua")
        end
    else
        if oldV == 0 and newV > 0 then
            shell.execute("/home/rs/rsON_"..colors[colorV]..".lua")
        end
        if oldV > 0 and newV == 0 then
            shell.execute("/home/rs/rsOFF_"..colors[colorV]..".lua")
        end
    end
end