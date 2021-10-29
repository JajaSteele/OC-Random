local cp = require("component")
local sg = cp.stargate

function waitState(x1,t1)
    repeat
        local state1,chevron1,direction1 = sg.stargateState()
        os.sleep(0.1)
    until state1 == x1
    os.sleep(t1)
end

while true do
    local state,chevron,direction = sg.stargateState()
    if state == "Dialling" then
        sg.closeIris()
        print("Connection Detected!\nAddress: "..sg.remoteAddress().."\nDirection: "..direction)
        waitState("Connected",0.01)
        print("Dialling Completed.")
        os.sleep(2.25)
        sg.openIris()
        waitState("Idle",0.01)
        print("Connection Ended.")
        sg.closeIris()
    end
end