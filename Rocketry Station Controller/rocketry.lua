local component = require("component")
local term = require("term")
local event = require("event")
local thread = require("thread")
local gpu = component.gpu

local warp = component.warpcontroller
local gravity = component.gravitycontroller
local spin = component.orientationcontroller
local altitude = component.altitudecontroller

local function concat_format(t,separator,format)
    local text = ""
    local start = true
    for k,v in ipairs(t) do
        if start then
            text = string.format(format, v)
            start = false
        else
            text = text..separator..string.format(format, v)
        end
    end
    return text
end

local data = {
    warp = {
        curr = warp.currentPlanet(),
        dest = warp.getDestination()
    },
    alt = {
        curr = altitude.currentAltitude(),
        tar = nil
    },
    rot = {
        raw = {spin.currentRotation()},
        deg = {},
        vel = {spin.currentVelocity()},
        deg_target = {0,0,0},
        rot_error = 0
    },
    grav = {
        curr = gravity.currentGravity(),
        tar = nil
    } 
}

thread.create(function()
    local score = 0
    local old_grav
    local new_grav
    for i1=1, 10 do
        old_grav = new_grav or gravity.currentGravity()
        new_grav = gravity.currentGravity()
        if old_grav == new_grav then
            score = score+1
        end
        os.sleep(0.1)
    end
    if score == 10 then
        data.grav.tar = new_grav
    end
end)

thread.create(function()
    local score = 0
    local old_alt
    local new_alt
    for i1=1, 10 do
        old_alt = new_alt or altitude.currentAltitude()
        new_alt = altitude.currentAltitude()
        if old_alt == new_alt then
            score = score+1
        end
        os.sleep(0.1)
    end
    if score == 10 then
        data.alt.tar = new_alt
    end
end)


local button_data = {}

local function clamp(n,min,max)
    return math.min(math.max(n, min), max)
end


local function equal(a,b, margin)
    return ((a >= b-margin) and (a <= b+margin))
end


local function updateData()
    data.warp.curr = warp.currentPlanet()
    data.warp.dest = warp.getDestination()
    
    data.alt.curr = altitude.currentAltitude()

    data.rot.raw = {spin.currentRotation()}
    data.rot.deg = {}
    data.rot.vel = {spin.currentVelocity()}

    data.grav.curr = gravity.currentGravity()
end

local input_enabled = false

local is_warping = false

local warp_failed = 0
local warp_error = ""

local is_rotating = false

local warp_dest = 0

local rotation_thread

local function startInput(txt, pattern, prefill, max_len)
    input_enabled = true
    gpu.setBackground(0x999999)
    gpu.fill(1,23, 80, 3, " ")
    gpu.setForeground(0x666666)
    term.setCursor(2,23)
    term.write(txt or "Input:")
    gpu.setForeground(0x000000)
    term.setCursor(3, 24)
    term.write(">")
    local input = prefill or ""
    if prefill then
        term.setCursor(5,24)
        gpu.setBackground(0x999999)
        gpu.setForeground(0x000000)
        term.write(input)
    end
    while true do
        local deleted = 0
        _, _, char, code = event.pull("key_down")
        if code == 14 and input:len() > 0 then
            if char == 127 then
                local oldlen = input:len()
                input = input:gsub("[%w%p]+[%s]?$", "")
                local newlen = input:len()
                deleted = oldlen-newlen
            else
                input = input:sub(1, input:len()-1)
                deleted = deleted+1
            end
        elseif code == 28 then
            break
        elseif input:len() < (max_len or math.huge) then
            input = input..(string.char(char):match(pattern or "[%w%s%p]") or "")
        end
        term.setCursor(5,24)
        gpu.setBackground(0x999999)
        gpu.setForeground(0x000000)
        term.write(input..string.rep(" ", deleted))
    end
    input_enabled = false
    return input
end

local old_res = {gpu.maxResolution()}
local old_fg = gpu.getForeground()
local old_bg = gpu.getBackground()

local function drawMain()
    gpu.setBackground(0xCCCCCC)
    gpu.setForeground(0x333333)

    gpu.setResolution(80,25)

    if input_enabled then
        gpu.fill(1,1, 80, 22, " ")
        gpu.setBackground(0xCCCCCC)
    else
        gpu.fill(1,1, 80, 25, " ")
    end

    term.setCursor(1,1)

    term.write("Station Controller by JJS")

    gpu.setForeground(0xAAAAAA)
    term.write(" (Click here to exit)")

    gpu.setForeground(0x333333)

    term.setCursor(2,3)
    term.write("Warp Controller:")

    if warp_failed > 0 then
        if warp_failed%3 > 0 then
            gpu.setForeground(0xBB1111)
            term.write("    ERROR: "..warp_error)
        end

        warp_failed = warp_failed-1
    end

    term.setCursor(4,4)
    gpu.setBackground(0x222222)
    gpu.setForeground(0xFFFFFF)
    term.write("Current: "..(data.warp.curr or "???").." | Destination: "..(data.warp.dest or "???"))

    button_data.warpstart = {term.getCursor()}

    gpu.setBackground(0xCCCCCC)
    gpu.setForeground(0x447733)
    term.write(" [ WARP ]")
    if component.isAvailable("openprinter") then
        gpu.setForeground(0x4444FF)
        term.write(" [ SAVE ]")
    end
    if is_warping then
        gpu.setForeground(0x4444FF)
        term.write("    CURRENTLY WARPING TO "..warp_dest)
    end
    gpu.setForeground(0x333333)

    term.setCursor(2,6)
    term.write("Altitude Controller:")

    term.setCursor(4,7)
    gpu.setBackground(0x222222)
    gpu.setForeground(0xFFFFFF)
    term.write("Current: "..data.alt.curr)

    if data.alt.tar then
        term.write(" | Target: "..data.alt.tar)
    end

    gpu.setBackground(0xCCCCCC)
    gpu.setForeground(0x333333)

    term.setCursor(2,8)
    term.write("Orientation Controller:")

    term.setCursor(4,9)
    gpu.setBackground(0x222222)
    gpu.setForeground(0xFFFFFF)
    for k,v in ipairs(data.rot.raw) do
        data.rot.deg[k] = (v*360)%360
    end
    term.write("Current Rotation: "..concat_format(data.rot.deg, ", ", "%.1f°"))

    term.setCursor(4,10)
    term.write("Current Velocity: "..concat_format(data.rot.vel, ", ", "%.0f"))

    gpu.setBackground(0xCCCCCC)
    if is_rotating then
        gpu.setForeground(0x4444FF)
        term.write("    AUTO-ROTATING TO "..concat_format(data.rot.deg_target, " ", "%.0f°").." | Error: "..string.format("%.2f°", data.rot.rot_error))
    end
    gpu.setForeground(0x333333)

    term.setCursor(2,12)
    term.write("Gravity Controller:")

    term.setCursor(4,13)
    gpu.setBackground(0x222222)
    gpu.setForeground(0xFFFFFF)
    term.write("Artificial Gravity: "..data.grav.curr)
    if data.grav.tar then
        term.write(" | Target: "..data.grav.tar)
    end

    gpu.setBackground(0xCCCCCC)
    gpu.setForeground(0x333333)

    if component.isAvailable("biomescanner") then
        term.setCursor(2,15)
        term.write("Biome Scanner:")

        term.setCursor(4,16)
        gpu.setBackground(0x222222)
        gpu.setForeground(0xFFFFFF)
        term.write("Available! Click here to scan")
    end
end

local update_thread = thread.create(function()
    while true do
        updateData()
        drawMain()
        os.sleep(0.1)
    end
end)

local click_thread = thread.create(function()
    while true do
        local mx,my = gpu.getResolution()
        _, _, tx, ty, button, _ = event.pull("touch")
        if ty == 1 then
            update_thread:kill()
            click_thread:kill()
            break
        elseif ty == 4 then
            if tx < button_data.warpstart[1] then
                local new_dest = startInput("Destination ID:", "%d")
                if new_dest ~= "" and new_dest ~= "warp" then
                    warp.setDestination(tonumber(new_dest))
                end
            elseif tx < button_data.warpstart[1]+9 then
                local confirm_num = math.random(1000,9999)
                local confirm = startInput("Confirm Warp: Enter these numbers "..string.format("%.0f", confirm_num), "%d")
                if tonumber(confirm) == confirm_num then
                    local stat, err = warp.warp()
                    if stat then
                        is_warping = true
                        warp_dest = warp.getDestination()
                        event.pull("warpFinished")
                        is_warping = false
                    else
                        warp_error = (err or "UNKNOWN")
                        warp_failed = 20
                    end
                end
            elseif tx < button_data.warpstart[1]+9+9 and component.isAvailable("openprinter") then
                local printer = component.openprinter
                local title = startInput("Title? (Optional)", "[%p%s%w]")
                local mode = tonumber(startInput("What do you want to save? (1. Curr. Plan. | 2. Dest. Plan. | 3. Full)", "%d", nil, 1))
                if mode then
                    if mode < 3 then
                        local info = startInput("Additional Info? (Optional)", "[%p%s%w]")
                        printer.clear()
                        if title ~= "" then
                            printer.setTitle(title)
                        else
                            printer.setTitle("§6Saved ID")
                        end
                        printer.writeln("§l§nSaved ID")
                        if mode == 1 then
                            printer.writeln("  "..tostring(data.warp.curr))
                        elseif mode == 2 then
                            printer.writeln("  "..tostring(data.warp.dest))
                        end
                        printer.writeln("§l§nAdditional Info:")
                        if info ~= "" then
                            printer.writeln(info)
                        else
                            printer.writeln("§oNo Info")
                        end
                        printer.print()
                    else
                        printer.clear()
                        if title ~= "" then
                            printer.setTitle(title)
                        else
                            printer.setTitle("§6Saved DATA")
                        end
                        printer.writeln("§l§nSaved DATA")
                        printer.writeln("§lwarp.curr §r§8"..data.warp.curr or "???")
                        printer.writeln("§lwarp.dest §r§8"..data.warp.dest or "???")
                        printer.writeln("§lalt.curr §r§8"..data.alt.curr or "???")
                        printer.writeln("§lrot.raw §r§8")
                        printer.writeln("  §8"..(concat_format(data.rot.raw, ", ", "%.3f") or "???"))
                        printer.writeln("§lrot.deg §r§8")
                        printer.writeln("  §8"..(concat_format(data.rot.deg, ", ", "%.1f°") or "???"))
                        printer.writeln("§lrot.vel §r§8"..(concat_format(data.rot.vel, ", ", "%.0f") or "???"))
                        printer.writeln("§lrot.deg_target §r§8")
                        printer.writeln("  §8"..(concat_format(data.rot.deg_target, ", ", "%.1f°") or "???"))
                        printer.writeln("§lrot.rot_error §r§8"..(data.rot.rot_error or "???"))
                        printer.writeln("§lgrav.curr §r§8"..(data.grav.curr or "???"))
                        printer.writeln("§lgrav.tar §r§8"..(data.grav.tar or "???"))
                        printer.print()
                    end
                end
            end
        elseif ty == 7 then
            local new_alt = clamp(tonumber(startInput("Target Altitude: (1100 - 38100)", "%d", tostring(data.alt.curr))), 1100, 38100)
            altitude.setTargetAltitude(new_alt)
            data.alt.tar = new_alt
        elseif ty == 9 then
            local new_rot = startInput("Target Rotation: (X(?) Y(Yaw) Z(Useless))", "[%d%s]")
            data.rot.deg_target = {}
            for num in new_rot:gmatch("[%-]?%d+") do data.rot.deg_target[#data.rot.deg_target+1] = num end
            if #data.rot.deg_target == 3 then
                is_rotating = true
                local stable = 0
                while true do
                    local curr_rot = {}
                    for k,v in ipairs({spin.currentRotation()}) do
                        curr_rot[k] = (v*360)%360
                    end
                    local velocity_x = clamp((data.rot.deg_target[1]-curr_rot[1])*10, -60, 60)
                    local velocity_y = clamp((data.rot.deg_target[2]-curr_rot[2])*10, -60, 60)
                    local velocity_z = clamp((data.rot.deg_target[3]-curr_rot[3])*10, -60, 60)
                    data.rot.rot_error = math.abs(data.rot.deg_target[1]-curr_rot[1]) + math.abs(data.rot.deg_target[2]-curr_rot[2]) + math.abs(data.rot.deg_target[3]-curr_rot[3])
                    spin.setTargetVelocity(velocity_x, velocity_y, velocity_z)
                    os.sleep()
                    if equal(velocity_x/10, 0, 0.15) and equal(velocity_y/10, 0, 0.15) and equal(velocity_z/10, 0, 0.15) then
                        stable = stable+1
                        if stable > 10 then
                            is_rotating = false
                            break
                        end
                    else
                        stable = 0
                    end
                end
            end
            is_rotating = false
            spin.setTargetVelocity(0, 0, 0)
        elseif ty == 10 then
            local new_vel = startInput("Target Velocity: (X(?) Y(Yaw) Z(Useless))", "[%d%s]")
            local new_vel_t = {}
            for num in new_vel:gmatch("[%-]?%d+") do new_vel_t[#new_vel_t+1] = tonumber(num) end
            if #new_vel_t == 3 then
                spin.setTargetVelocity(new_vel_t[1], new_vel_t[2], new_vel_t[3])
            end
        elseif ty == 13 then
            local new_grav = clamp(tonumber(startInput("Target Gravity (10 - 100)", "%d")), 10, 100)
            gravity.setTargetGravity(new_grav)
            data.grav.tar = new_grav
        elseif ty == 16 and component.isAvailable("biomescanner") then
            local biome = component.biomescanner
            update_thread:suspend()
            os.sleep()
            gpu.setBackground(0xCCCCCC)
            gpu.setForeground(0x333333)
            term.clear()
            term.write("Biome Scanner Mode")
            gpu.setForeground(0xAAAAAA)
            term.write(" (Click here to exit)")
            local biome_scroll = 0
            while true do
                gpu.setBackground(0xCCCCCC)
                gpu.setForeground(0xFFFFFF)

                local biome_list = {biome.scan(true)}
                for i1=1, my-3 do
                    local text = biome_list[i1+biome_scroll]
                    term.setCursor(3,2+i1)
                    if (i1+biome_scroll)%4 < 2 then
                        gpu.setBackground(0x333333)
                    else
                        gpu.setBackground(0x222222)
                    end
                    if text then
                        term.write(" "..text..string.rep(" ", mx-text:len()-6))
                    else
                        term.write(" "..string.rep(" ", mx-6))
                    end
                end

                gpu.setBackground(0x999999)
                gpu.setForeground(0x888888)
                gpu.fill(mx, 4, 1, my-5, "░")

                gpu.setForeground(0x555555)
                gpu.set(mx, 4+((my-5)*biome_scroll/(#biome_list-(my-7))), "▓")

                event_name, _, tx, ty, dir = event.pull()
                if event_name == "scroll" and #biome_list > (my-7) then
                    biome_scroll = clamp(biome_scroll-(dir*3), 0, #biome_list-(my-3))
                elseif (event_name == "touch" or event_name == "drag") and tx == mx and #biome_list > (my-7)  then
                    biome_scroll = math.floor(clamp(#biome_list*((ty-3)/(my)), 0, #biome_list-(my-3)))
                elseif event_name == "touch" and ty == 1 and tx < mx/2 then
                    break
                end
            end
            update_thread:resume()
        end
        os.sleep(0.1)
    end
end)

thread.waitForAll({click_thread, update_thread})

term.clear()

click_thread:kill()
update_thread:kill()

gpu.setResolution(old_res[1], old_res[2])
gpu.setForeground(old_fg)
gpu.setBackground(old_bg)

term.clear()

print("Thanks for using JJS's Station Controller!")