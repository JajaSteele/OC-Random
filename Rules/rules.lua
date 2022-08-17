local component = require("component")
local term = require("term")
local gpu = component.gpu
local rs = component.redstone
local ct = require("computer")
local event = require("event")

local function slowprint(t)
    for i1=1, t:len() do
        term.write(t:sub(i1,i1))
        os.sleep()
    end
end

local function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

rules = [[
Welcome to Jaja Steele's Minecraft server!

-=-=-=Rules=-=-=-

1. No griefing.
2. Be respectful to other players. (No stealing, insulting, no racism/homophobia or anything similar)
3. No duping using glitches.
4. Please do not spam OpenComputers's disks if not useful, it floods the server files.

-=-=-=Rules=-=-=-
]]

term.clear()

while true do

    _, _, _, oldSignal, newSignal = event.pull("redstone_changed")

    newX = 0
    newY = 0

    for k, v in pairs(split(rules,"\n")) do
        newY = newY+1
        newX2 = 0
        for i1=1, v:len() do
            term.write(v:sub(i1,i1))
            newX2 = newX2+1
        end
        if newX2 > newX then newX = newX2 end
    end

    term.clear()

    if newSignal > 0 and oldSignal == 0 then

        ct.beep(600,0.1)
        os.sleep(0.05)
        ct.beep(700,0.2)

        gpu.setResolution(newX,newY)

        term.clear()
        term.setCursor(1,1)

        slowprint(rules)
    end
end