local event = require("event")
local cp = require("component")
local sides = require("sides")
local colors = require("colors")
local rs = cp.redstone

local rd = cp.os_rolldoorcontroller

while true do
    _ = event.pull("redstone_changed")
    if rs.getBundledInput(sides.down,colors.white) > 0 then rd.open() else rd.close() end
end