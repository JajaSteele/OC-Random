local cp = require("component")
local sg = cp.stargate
local ct = require("computer")
local colors = require("colors")
local term = require("term")
local g = cp.gpu
local cb = cp.chat_box

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

function cprint(t1)
    colorS1 = false
    colorChange = false
    colorT = ""
    oldX,oldY = term.getCursor()
    for i1=1, string.len(t1) do
        char = string.sub(t1,i1,i1)
        if char == "#" then
            colorS1 = true
            colorChange = false
            colorT = ""
        end
        if colorS1 then
            if char ~= "#" then
                colorT = colorT..char
            end
            if char == " " then
                colorS1 = false
                colorChange = true
            end
        end
        if not colorS1 then
            term.write(char)
        end
        if colorChange then
            colorT = string.gsub(colorT, " ", "")
            g.setForeground(tonumber(colorT))
            colorChange = false
            colorS1 = false
            oldX1,oldY1 = term.getCursor()
            term.setCursor(oldX1-1,oldY1)
        end
    end
    oldX2,oldY2 = term.getCursor()
    term.setCursor(oldX,oldY2+1)
end

cb.setName("JajaSteele Ship")
cb.say("Stargate Address: §b"..sg.localAddress())

while true do
    local state,chevron,direction = sg.stargateState()
    if state == "Dialling" then
        if direction == "Incoming" then
            dirtext = "#0x44FF44 [-->]"
        else
            dirtext = "#0xFF4444 [<--]"
        end
        cprint("#0xFFFFFF [|-|] #0xBBBBBB Connection Detected!\n      Address: "..sg.remoteAddress().."\n      Direction: "..direction.." "..dirtext)
        ct.beep(300,0.1)
        os.sleep(0.15)
        ct.beep(560,0.1)
        os.sleep(0.25)
        ct.beep(800,0.2)
        waitChevr(string.len(sg.remoteAddress())-3,0.1)
        sg.closeIris()
        waitState("Connected",0.01)
        cprint("#0x44FF44 [<->] Connection Opened.")
        os.sleep(2.25)
        sg.openIris()
        waitState("Idle",0.01)
        cprint("#0xFF4444 [>-<] Connection Ended.")
        ct.beep(300,0.2)
        os.sleep(0.15)
        ct.beep(150,0.2)
        os.sleep(0.15)
        ct.beep(50,0.2)
    end
end