local cp = require("component")
local sg = cp.stargate
local ct = require("computer")

function waitState(x1,t1)
    repeat
        local state1,chevron1,direction1 = sg.stargateState()
        os.sleep(0.1)
    until state1 == x1
    os.sleep(t1)
end

function waitChevr(x1,t1)
    repeat
        local state1,chevron1,direction1 = sg.stargateState()
        os.sleep(0.1)
    until chevron1 == x1
    os.sleep(t1)
end

while true do
    local state,chevron,direction = sg.stargateState()
    if state == "Dialling" then
        sg.closeIris()
        print("Connection Detected!\nAddress: "..sg.remoteAddress().."\nDirection: "..direction)
        ct.beep(300,0.1)
        os.sleep(0.15)
        ct.beep(560,0.1)
        os.sleep(0.25)
        ct.beep(800,0.2)
        waitChevr(string.len(sg.remoteAddress())-3,0.1)
        sg.openIris()
        waitState("Connected",0.01)
        print("Dialling Completed.")
        os.sleep(2.25)
        waitState("Idle",0.01)
        print("Connection Ended.")
        ct.beep(150,0.5)
        sg.closeIris()
        os.sleep(4)
        ct.beep(300,0.2)
        os.sleep(0.15)
        ct.beep(150,0.2)
        os.sleep(0.15)
        ct.beep(50,0.2)
    end
end