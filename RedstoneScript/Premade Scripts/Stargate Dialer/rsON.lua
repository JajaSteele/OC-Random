local c = require("component")
local sg = c.stargate

local function waitState(name,timeout)
    print("<=====>\nWaiting for state \""..name.."\" \nWith timeout of "..timeout.."s")
    if timeout then
        to1 = 0
        while to1 < timeout do
            state, chevrons, direction = sg.stargateState()
            if state ~= name then
                os.sleep(0.1)
            else
                print("Done!\n>=====<")
                return true
            end
            to1 = to1+0.1
        end
        if to1 > timeout then print("Failed from timeout!\nLast State: "..state.."\n>=====<") return false, "Timed-Out" end
    else
        while true do
            local state, chevrons, direction = sg.stargateState()
            if state == name then
                print("Done!\n>=====<")
                break
            else
                os.sleep(0.1)
            end
        end
    end
end

if io.open("/home/autodial.txt","r") == nil then
    print("Hello User! To use this program, you need to:\n1. install rscode.lua\n2. Put this file in home/rs/rsON.lua\n3. Then once this is done, create a file at home/autodial.txt\n4. And finally put the stargate address in there!")
    return
else
    dial1file = io.open("/home/autodial.txt","r")
    dial1 = dial1file:read("*a")
    dial1file:close()
    print("Loaded config.\nAddress: "..dial1)
end

if sg.stargateState() ~= "Connected" then
    sg.dial(dial1)
    sg.closeIris()

    if waitState("Connected",60) then
        sg.openIris()
    end
else
    sg.closeIris()
    os.sleep(4)

    sg.disconnect()

    waitState("Idle",10)

    os.sleep(1.5)

    sg.openIris()
end