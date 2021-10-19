local t = require("term")
local cp = require("component")
local rs = cp.redstone
local sides = require("sides")
local cpt = require("computer")

currSign = rs.getOutput(sides.back)

if currSign > 0 then
    print("Switching to Screen")
    os.sleep(0.5)
    rs.setOutput(sides.back,0)
    cpt.shutdown(true)
end
if currSign == 0 then
    print("Switching to Terminal")
    os.sleep(0.5)
    rs.setOutput(sides.back,15)
    cpt.shutdown(true)
end