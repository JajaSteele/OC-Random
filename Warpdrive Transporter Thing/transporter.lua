--[[
To Do:
Make the locking thing re-appear at every energizing, not every activation

]]--


local component = require("component")
local term = require("term")
local event = require("event")
local thread = require("thread")
local gpu = component.gpu
local cb = component.chat_box
local tc = component.warpdriveTransporterCore

local player = ""

local function askCoords()
    cb.say("Please enter the coords: (X Y Z)")
    local coords = {}
    for num in (({event.pull("chat_message", nil, player)})[4]):gmatch("[%-]?%d+") do coords[#coords+1] = num end
    print("Selected: X"..coords[1].." Y"..coords[2].." Z"..coords[3])
    return coords
end

local lockBarBottom = 0

local function changeStatus(text, fg)
    local oldFG = gpu.getForeground()
    local oldx,oldy = term.getCursor()
    term.setCursor(1,1)
    term.write("Status:")
    if fg then gpu.setForeground(fg) end
    term.setCursor(2,2)
    term.clearLine()
    term.setCursor(2,2)
    term.write(text)
    term.setCursor(oldx,oldy)
    gpu.setForeground(oldFG)
end

local function setLockBar(percent, fg)
    local oldFG = gpu.getForeground()
    local oldx,oldy = term.getCursor()
    local mx,my = gpu.getResolution()
    term.setCursor(1,4)
    term.clearLine()
    term.write("Locking: ("..string.format("%.1f%%", percent)..")")
    if fg then gpu.setForeground(fg) end
    term.setCursor(2,5)
    term.clearLine()
    term.setCursor(2,5)
    local length = math.floor((mx-2)*(percent/100))
    for i1=1, length do
        term.write("█")
        local _, curry = term.getCursor()
        lockBarBottom = curry+1
        if i1%(mx-2) == 0 then
            term.setCursor(2, curry+1)
        end
    end
    if percent%1 > 0.75 then
        term.write("▓")
    elseif percent%1 > 0.50 then
        term.write("▒")
    elseif percent%1 > 0.25 then
        term.write("░")
    end
    gpu.setForeground(oldFG)
end

local function changeCoreStatus(text, fg)
    local percent = tc.getLockStrength() * 100
    local oldFG = gpu.getForeground()
    local oldx,oldy = term.getCursor()
    term.setCursor(1,7+math.floor(percent/100))
    term.write("Core Status:")
    if fg then gpu.setForeground(fg) end
    term.setCursor(2,8+math.floor(percent/100))
    term.clearLine()
    term.setCursor(2,8+math.floor(percent/100))
    term.write(text)
    term.setCursor(oldx,oldy)
    gpu.setForeground(oldFG)
end

local lock_colors = {
    [75] = "§a",
    [50] = "§e",
    [25] = "§6",
    [0] = "§c"
}

local function lockColor(percent)
    local color = "§c"
    for k,v in pairs(lock_colors) do
        if percent > k then
            color = v
        end
    end
    return color
end

local is_stable = false

term.clear()

gpu.setResolution(80,25)

term.setCursor(1,1)

cb.setName("TPCore")

tc.enable(false)

local running = false

local status_thread = thread.create(function()
    while true do
        if is_stable then
            setLockBar(tc.getLockStrength()*100, 0x55FF55)
        else
            setLockBar(tc.getLockStrength()*100)
        end
        local destination, status = tc.state()
        changeCoreStatus(status)
        os.sleep(0.05)
    end
end)

changeStatus("Awaiting command.")
cb.say("Standby, send 'tpnow' to start procedure.")
while true do
    local msg = {event.pull("chat_message", nil, nil, "tpnow")}
    player = msg[3]
    cb.say("Select Mode: 1. Player, 2. UUID, 3. Coords")

    local mode1 = tonumber(({event.pull("chat_message", nil, player)})[4])
    cb.say("Selected: "..mode1)
    changeStatus("Mode Selected: "..mode1)

    tc.enable(true)
    running = true

    if mode1 == 1 then
        cb.say("Select Mode: 1. Yourself, 2. Other Player")
        local mode_player = tonumber(({event.pull("chat_message", nil, player)})[4])
        if mode_player == 1 then
            tc.remoteLocation(player)
        elseif mode_player == 2 then
            cb.say("Enter player name:")
            local selec_player = ({event.pull("chat_message", nil, player)})[4]
            tc.remoteLocation(selec_player)
        end
    elseif mode1 == 3 then
        local coords = askCoords()
        tc.remoteLocation(coords[1], coords[2], coords[3])
    end

    changeStatus("Locking on "..tc.remoteLocation().." ..")

    cb.say("Locking on "..tc.remoteLocation().." ..")
    tc.lock(true)

    local send_percent = true
    local locklvl = 0

    local stable_lvl = -50

    local already_teleported = false

    while running do
        local bypass_thread = thread.create(function()
            while true do
                local msg = (({event.pull("chat_message", nil, player)})[4]):lower()
                if msg == "forcego" then
                    cb.say("Force-Energizing..")
                    changeStatus("Force-Energizing..", 0xFFFF44)
                    tc.energize(true)
                elseif msg == "stop" then
                    running = false
                    tc.enable(false) 
                    cb.say("§cTeleportation Aborted!")
                    changeStatus("Teleportation Aborted!", 0xFF4444)
                end
            end
        end)

        local stable = 0

        local repeat_prompt = true

        is_stable = false

        local said_relocking = false

        while running do
            local old = locklvl or 0
            locklvl = tc.getLockStrength() * 100

            if locklvl == stable_lvl then
                repeat_prompt = false
                is_stable = true
                break
                said_relocking = false
            else
                if not said_relocking and already_teleported then
                    cb.say("Re-locking..")
                    said_relocking = true
                end
            end

            if math.floor(locklvl)%20 == 0 then
                if send_percent then
                    cb.say("Locking: "..lockColor(locklvl)..math.floor(locklvl).."%")
                    send_percent = false
                end
            else
                send_percent = true
            end

            if old == locklvl then
                stable = stable+1
            else
                stable = 0
            end

            if stable > 10 and stable > 0 and running then
                cb.say("Stable Locking: "..lockColor(locklvl)..string.format("%.1f%%", locklvl))
                changeStatus("Stable Locking Level: "..string.format("%.1f%%", locklvl))
                is_stable = true
                break
            end
            os.sleep(0.1)
        end

        stable_lvl = locklvl

        bypass_thread:kill()
        if running and repeat_prompt then
            cb.say("Send 'GO' to teleport or 'STOP' to abort.")
        elseif running and not repeat_prompt then
            cb.say("Ready.")
        end

        local continue = ({event.pull("chat_message", nil, player)})[4]:lower()
        if continue == "go" then
            cb.say("Energizing..")
            changeStatus("Energizing..", 0x55FF55)
            tc.energize(true)
        elseif continue == "stop" then
            cb.say("§cTeleportation Aborted!")
            changeStatus("Teleportation Aborted!", 0xFF4444)
            tc.enable(false)
            running = false
            break
        end
        event.pull(10, "transporterSuccess")
        cb.say("Cooling Down.. (10s)")
        os.sleep(10)
        already_teleported = true
    end
end