local c = require("component")
local rs = c.redstone
local ev = require("event")
local shell = require("shell")

t1 = io.open("/home/.shrc","w")
t1:write("rscode.lua")
t1:close()

while true do
    local _, _, side, oldV, newV = ev.pull("redstone_changed")

    if oldV == 0 and newV > 0 then
        shell.execute("/home/rs/rsON.lua")
    end
    if oldV > 0 and newV == 0 then
        shell.execute("/home/rs/rsOFF.lua")
    end
end