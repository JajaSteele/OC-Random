local component = require("component")
local event = require("event")
local term = require("term")
local thread = require("thread")

local geo = component.geolyzer
local glass = component.glasses
local gpu = component.gpu

local function write(x,y, text, fg, bg, clearLine)
    local old_x, old_y = term.getCursor()

    local old_fg = gpu.getForeground()
    local old_bg = gpu.getBackground()

    if fg then
        gpu.setForeground(fg)
    end
    if bg then
        gpu.setBackground(bg)
    end

    term.setCursor(x,y)
    if clearLine then
        term.clearLine()
    end
    term.setCursor(x,y)
    term.write(text, false)
    local new_x, new_y = term.getCursor()
    term.setCursor(old_x, old_y)

    gpu.setForeground(old_fg)
    gpu.setBackground(old_bg)
    return new_x, new_y
end

local function fill(x,y, x2,y2, bg, fg, char)
    local old_fg = gpu.getForeground()
    local old_bg = gpu.getBackground()

    if fg then
        gpu.setForeground(fg)
    end
    if bg then
        gpu.setBackground(bg)
    end

    gpu.fill(x,y, (x2-x)+1, (y2-y)+1, char or " ")

    gpu.setForeground(old_fg)
    gpu.setBackground(old_bg)
end

local function clamp(x,min,max) if x > max then return max elseif x < min then return min else return x end end

local function getSliderOutput(curr_x, x1, x2, min, max)
    local percent = (curr_x-x1)/(x2-x1)
    return clamp(min + percent * (max - min), min, max)
end

local function getSliderPos(value, x1, x2)
    return clamp(x1 + value * (x2 - x1), x1, x2)
end

local function secondsToDuration(seconds)
    local sec = math.floor(seconds%60)
    local min = math.floor((seconds/60)%60)
    local hour = math.floor(min/60)

    local output = string.format("%.0f:%02d", min, sec)
    if hour > 0 then
        output = string.format("%.0f", hour)..output
    end

    return output
end

local function bytesToString(bytes)
    if bytes > 1000000 then
        return string.format("%.2f MB", bytes/1000000)
    elseif bytes > 1000 then
        return string.format("%.2f KB", bytes/1000)
    else
        return string.format("%.2f B", bytes)
    end
end

local color = {
    white=0xFFFFFF,
    orange=0xFFCC33,
    magenta=0xCC66CC,
    lightblue=0x6699FF,
    yellow=0xFFFF33,
    lime=0x33CC33,
    pink=0xFF6699,
    gray=0x333333,
    lightgray=0xCCCCCC,
    cyan=0x336699,
    purple=0x9933CC,
    blue=0x333399,
    brown=0x663300,
    green=0x336600,
    red=0xFF3333,
    black=0x000000,
}

local threads = {}

local buttons = {}
local text_boxes = {}

local function addButton(x,y, x2, y2, func)
    buttons[#buttons+1] = {
        coords={
            x1=x,
            y1=y,
            x2=x2,
            y2=y2
        },
        func=func
    }
end

local function addTextBox(x,y, x2, y2, current_input, max_length, pattern_filter, start_func, enter_func, cancel_func, fg, bg)
    text_boxes[#text_boxes+1] = {
        coords={
            x1=x,
            y1=y,
            x2=x2,
            y2=y2
        },
        value=current_input,
        max_length=max_length,
        pattern_filter=pattern_filter,
        start_func=start_func,
        enter_func=enter_func,
        cancel_func=cancel_func,
        foreground=fg,
        background=bg
    }
end

local maxwidth, maxheight = gpu.maxResolution()
gpu.setResolution(1, 1)
os.sleep(0.1)
gpu.setResolution(math.min(maxwidth, 80), math.min(maxheight, 25))
local width, height = gpu.getResolution()
event.pull("screen_resized")
term.getViewport()

local drawBuffer = gpu.allocateBuffer(width, height)

local first_exit = true
local function quit(err)
    for k,v in pairs(threads) do
        print("quitting thread "..k)
        pcall(function ()
            v:kill()
        end)
    end

    if first_exit then
        gpu.setActiveBuffer(0)
        gpu.freeBuffer(drawBuffer)
        term.clear()
        first_exit = false
    end

    if err then
        print(err)
        --error(err)
    else
        print("Program closed")
    end
end

local full_data = {}

local range = 32
local min_hardness = 0
local max_hardness = 100

local min_found = 100
local max_found = 0

local scan_count = 0

threads.render = thread.create(function() 
    local stat, err = pcall(function ()
        while true do
            event.pull("gg_render")

            buttons = {}
            text_boxes = {}
            gpu.setActiveBuffer(drawBuffer)

            term.clear()

            fill(1,1, width, 3, color.gray)
            write(3,2, "GeoGlasses", color.lightblue, color.gray)

            local lw = write(2, 5, "Scan", color.gray)
            addButton(2, 5, lw, 5, function(ev)
                local _, id, x, y, b, username = table.unpack(ev)

                local pos = glass.getUserPosition(username)

                full_data = {}
                min_found = 100
                max_found = 0
                scan_count = 0

                for x=-range, range do
                    local x_pos = math.floor(pos.x)+x
                    if not full_data[x_pos] then full_data[x_pos] = {} end
                    for z=-range, range do
                        local z_pos = math.floor(pos.z)+z
                        write(2, 5, string.format("Scan: %.1f%%", ((x+range)/(range*2))*100), color.orange, color.black, true)
                        write(2, 6, "DO NOT MOVE", color.red, color.black)
                        if not full_data[x_pos][z_pos] then full_data[x_pos][z_pos] = {} end
                        local dat = geo.scan(x,z, -32, 1, 1, 32)
                        local new_dat = {}
                        for y, hardness in pairs(dat) do
                            local y_pos = math.floor(pos.y)+(y-32)
                            new_dat[y_pos] = hardness
                            if hardness > max_found then
                                max_found = hardness
                            end
                            if hardness < min_found then
                                min_found = hardness
                            end
                            scan_count = scan_count+1
                        end
                        full_data[x_pos][z_pos] = new_dat
                    end
                end
                event.push("gg_render")
            end)

            local lw2 = write(lw+3, 5, "Render", color.gray)
            addButton(lw+3, 5, lw2, 5, function()
                write(lw+3, 5, "Rendering", color.orange, color.black, true)
                event.push("gg_drawglass")
            end)

            local lw = write(2, 7, "Radius: ", color.lightgray)
            write(lw, 7, range, color.white)
            fill(2,8,width-1,8, color.black, color.gray, "┉")
            fill(2, 8, 1+((width-2)*(range/32)), 8, color.black, color.orange, "━")
            addButton(2, 8, width-1, 8, function(ev)
                local _, _, x, y, b = table.unpack(ev)
                local new_range = math.floor(getSliderOutput(x, 2, width-1, 0, 32))
                range = new_range
                event.push("gg_render")
            end)

            local lw = write(2, 10, "Min Hardness: ", color.lightgray)
            write(lw, 10, min_hardness, color.white)
            fill(2,11,width-1,11, color.black, color.gray, "┉")
            fill(2, 11, 1+((width-2)*(min_hardness/100)), 11, color.black, color.orange, "━")
            addButton(2, 11, width-1, 11, function(ev)
                local _, _, x, y, b = table.unpack(ev)
                local new_min = math.floor(getSliderOutput(x, 2, width-1, 0, 100))
                min_hardness = new_min
                event.push("gg_render")
            end)

            local lw = write(2, 12, "Min Hardness: ", color.lightgray)
            write(lw, 12, max_hardness, color.white)
            fill(2,13,width-1,13, color.black, color.gray, "┉")
            fill(2, 13, 1+((width-2)*(max_hardness/100)), 13, color.black, color.orange, "━")
            addButton(2, 13, width-1, 13, function(ev)
                local _, _, x, y, b = table.unpack(ev)
                local new_max = math.floor(getSliderOutput(x, 2, width-1, 0, 100))
                max_hardness = new_max
                event.push("gg_render")
            end)

            local lw = write(2, 15, "Min/Max from scan: ", color.lightgray)
            write(lw, 15, string.format("%d/%d", math.floor(min_found+0.5), math.floor(max_found+0.5)), color.white)

            gpu.bitblt(0, 1,1, width, height, drawBuffer, 1, 1)
            gpu.setActiveBuffer(0)
        end
    end)
    if not stat then
        quit(err or "")
    end
end)

threads.glass_render = thread.create(function()
    local stat, err = pcall(function()
        while true do
            event.pull("gg_drawglass")

            glass.removeAll()
            glass.setRenderPosition("absolute")
            
            local scale_change = 1/16
            for x,z_list in pairs(full_data) do
                for z, y_list in pairs(z_list) do
                    for y, hardness in pairs(y_list) do
                        if hardness > min_hardness and hardness < max_hardness then
                            local new_cube = glass.addCube3D()
                            new_cube.addTranslation(x-(scale_change/2),y-(scale_change/2),z-(scale_change/2))
                            new_cube.setVisibleThroughObjects(true)
                            new_cube.addColor(1,1,1, 0.75)
                            new_cube.addScale(1 + scale_change, 1 + scale_change, 1 + scale_change)
                        end
                    end
                    os.sleep()
                end
            end
        end
    end)
    if not stat then
        quit(err or "")
    end
end)

local eventThread = thread.create(function ()
    local stat, err = pcall(function ()
        while true do
            local ev = {event.pull()}
            if ev[1] == "interrupted" then
                quit()
                break
            elseif ev[1] == "tablet_use" then
                local block_dat = ev[2]
                local hardness = block_dat.hardness
                local dx = range - 0
                local dy = 32 - 0
                local dz = range - 0
                local max_dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                local noise = max_dist*(1/33)*2
                min_hardness = hardness-noise
                max_hardness = hardness+noise
                event.push("gg_render")
            elseif ev[1] == "touch" then
                local _, _, x, y, b = table.unpack(ev)

                for k, button in pairs(buttons) do
                    if x >= button.coords.x1 and y >= button.coords.y1 then
                        if x <= button.coords.x2 and y <= button.coords.y2 then
                            local func = button.func
                            if func then func(ev) end
                            break
                        end
                    end
                end

                for k, textbox in pairs(text_boxes) do
                    if x >= textbox.coords.x1 and y >= textbox.coords.y1 then
                        if x <= textbox.coords.x2 and y <= textbox.coords.y2 then
                            if textbox.start_func then textbox.start_func() end

                            local current_input = textbox.value or ""
                            event.push("hc_drawinput")

                            local function displayInput()
                                fill(textbox.coords.x1, textbox.coords.y1, math.max(textbox.coords.x2, textbox.coords.x1+textbox.max_length), textbox.coords.y2, textbox.background)
                                local lw = write(textbox.coords.x1, textbox.coords.y1, current_input, textbox.foreground, textbox.background)
                                write(lw, textbox.coords.y1, "_", 0x777777, textbox.background)
                            end
                            while true do
                                local ev = {event.pull()}
                                if ev[1] == "key_down" then
                                    local _, _, char_code, key_code = table.unpack(ev)
                                    local char = string.char(char_code):match(textbox.pattern_filter)

                                    if char and #current_input < textbox.max_length then
                                        current_input = current_input..char
                                    else
                                        if key_code == kb.keys.back then
                                            current_input = current_input:sub(1,-2)
                                        elseif key_code == kb.keys.enter then
                                            if textbox.enter_func then textbox.enter_func(current_input) end
                                            break
                                        elseif key_code == kb.keys.escape then

                                        end
                                    end
                                    displayInput()
                                elseif ev[1] == "touch" then
                                    if ev[5] == 1 then
                                        if textbox.cancel_func then textbox.cancel_func() end
                                        break
                                    end
                                elseif ev[1] == "clipboard" then
                                    for char in ev[3]:gmatch(textbox.pattern_filter) do
                                        if #current_input < textbox.max_length then
                                            current_input = current_input..char
                                        else
                                            break
                                        end
                                    end
                                    displayInput()
                                elseif ev[1] == "hc_drawinput" then
                                    displayInput()
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
    if not stat then
        quit(err or "")
    end
end)

local threads_only = {}
for k,v in pairs(threads) do
    threads_only[#threads_only+1] = v
end
threads_only[#threads_only+1] = eventThread
event.push("gg_render")

local stat, err = pcall(function ()
    thread.waitForAll(threads_only)
end)

quit(err)