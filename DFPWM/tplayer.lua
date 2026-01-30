local component = require("component")
local event = require("event")
local thread = require("thread")
local kb = require("keyboard")

local term = require("term")
local screen = component.screen
local gpu = component.gpu
local tape = component.tape_drive

local lb
local lb_count
local lb_active
if component.isAvailable("light_board") then
    lb = component.light_board
    lb_count = lb.light_count
    lb_active = true
end

local function clamp(x,min,max) if x > max then return max elseif x < min then return min else return x end end

local function DEBUG(...)
    if component.isAvailable("chat_box") then
        component.chat_box.setName("DEBUG")
        local txt = ""
        for k,v in ipairs({...}) do
            txt = txt .. tostring(v) .. "    "
        end
        component.chat_box.say(tostring(txt))
    end
end

local function rgbToHex(r,g,b)
    local rgb = (math.floor(r) * 0x10000) + (math.floor(g) * 0x100) + math.floor(b)
    return tonumber("0x"..string.format("%06x", rgb))
end

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
    titlebar_bg=0x222222,
    titlebar_text1 = 0xCCCCCC,
    text1 = 0xAAAAAA,
    dotted_1 = 0x595959,
    dotted_2 = 0x424242,
    white = 0xFFFFFF,
    black = 0x000000,
    state_off = 0xFF5555,
    state_on = 0x66FF55,
    state_warn = 0xFFBB55,
    tape_empty = 0x440000,
    tape_content = 0x553311,
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

local function quit(err)
    for k,v in pairs(threads) do
        print("quitting thread "..k)
        pcall(function ()
            v:kill()
        end)
    end

    gpu.setActiveBuffer(0)
    gpu.freeBuffer(drawBuffer)
    term.clear()
    if err then
        print(err)
        --error(err)
    else
        print("Program closed")
    end
end

local volume = 1
local speed = 1
local loop = false
local autoscan = false
local autoplay = false

local lb_tick = 0

tape.setVolume(volume)
tape.setSpeed(speed)

local tape_info = {
    has_info=false,
    label="No Tape",
    size=0,
    content=0,
    detected_quality=0
}

local function scanContent()
    local old_pos = tape.getPosition()
    local was_playing = tape.getState()
    
    if tape.isReady() then
        lb_active = false
        tape.stop()
        tape.seek(tape.getSize())
        local searcher_amount = tape.getSize()/16
        while true do
            tape.seek(-(searcher_amount+1))
            --print(tape.getPosition(), searcher_amount)
            local tape_pos = tape.getPosition()
            local lw = write(3,7, "Content Size: ", color.text1, color.black, true)
            write(lw, 7, tape_pos.." ("..searcher_amount..")", color.state_warn)

            fill(2, height-2, width-1, height-2, color.black, color.dotted_2, "┉")
            write(clamp(1+((width-2)*(tape_pos/tape_info.size)), 2, width-1), height-2, "|", color.titlebar_text1)

            if lb then
                lb_tick = (lb_tick+32)%180
                for i1=1, lb_count do
                    local r = math.sin(math.rad((lb_tick+(i1*16))%180))*128
                    local g = 255
                    local b = 64 + (math.sin(math.rad((lb_tick+(i1*16))%180))*127)

                    lb.setActive(i1, true)
                    lb.setColor(i1, rgbToHex(r, g, b))
                end
            end

            local byte = string.byte(tape.read(1))
            if byte ~= 0 and byte ~= 170 then
                if searcher_amount == 1 then
                    tape_info.content = tape.getPosition()
                    break
                else
                    tape.seek(searcher_amount)
                    searcher_amount = math.ceil(searcher_amount/2)
                end
            end
        end

        tape_info.has_info = true

        tape.seek(-tape.getSize())
        tape.seek(old_pos)

        if was_playing == "PLAYING" then
            tape.play()
        end
        lb_active = true
        event.push("tp_lightboard")
    else
        tape_info.has_info = false
    end
end

threads.render = thread.create(function() 
    local stat, err = pcall(function ()
        while true do
            event.pull("tp_render")

            buttons = {}
            text_boxes = {}
            gpu.setActiveBuffer(drawBuffer)

            term.clear()

            local tape_pos = tape.getPosition()
            
            fill(1,1, width, 3, color.titlebar_bg)
            write(3,2, "Tape Player", color.titlebar_text1, color.titlebar_bg)

            local lw = write(3,5, "Scan Content", color.dotted_2)
            addButton(3,5, lw, 5, function()
                scanContent()
                event.push("tp_render")
            end)
            local lw2 = write(lw+5, 5, "Autoscan: ", color.dotted_2)
            local lw3 = write(lw2, 5, ((autoscan and "Enabled") or "Disabled"), color.dotted_1)
            addButton(lw2, 5, lw3, 5, function()
                autoscan = not autoscan
                event.push("tp_render")
            end)

            if autoscan then
                local lw2 = write(lw3+5, 5, "Autoplay: ", color.dotted_2)
                local lw3 = write(lw2, 5, ((autoplay and "Enabled") or "Disabled"), color.dotted_1)
                addButton(lw2, 5, lw3, 5, function()
                    autoplay = not autoplay
                    event.push("tp_render")
                end)
            else
                autoplay = false
            end

            
            local lw = write(3,6, "Label: ", color.text1)
            write(lw, 6, tape_info.label:gsub("§%w", ""), color.white)

            local lw = write(3,7, "Content Size: ", color.text1)
            if tape_info.content == 0 then
                write(lw, 7, "Scan Required", color.state_off)
            else
                write(lw, 7, bytesToString(tape_info.content), color.white)
            end

            local lw = write(3,8, "Max Size: ", color.text1)
            write(lw, 8, bytesToString(tape_info.size), color.white)

            if tape_info.detected_quality > 0 then
                local lw = write(3, 10, "Detected Quality: ", color.dotted_2)
                if tape_info.detected_quality == 1 then
                    write(lw, 10, "Normal", color.dotted_1)
                elseif tape_info.detected_quality == 2 then
                    write(lw, 10, "High", color.dotted_1)
                end
            end

            local lw = write(2, height-6, "Volume: ", color.text1, color.black)
            write(lw, height-6, string.format("%.0f%%", volume*100), color.white)
            fill(2, height-5, math.floor(width/2)-1, height-5, color.black, color.state_off, "━")
            fill(2, height-5, getSliderPos(volume, 2, math.floor(width/2)-1), height-5, color.black, color.state_on, "━")
            addButton(2, height-5, math.floor(width/2)-1, height-5, function(ev)
                local _, _, x, y, b = table.unpack(ev)
                if b == 0 then
                    volume = getSliderOutput(x, 2, math.floor(width/2)-1, 0, 1)
                else
                    volume = 1
                end
                tape.setVolume(volume)
                event.push("tp_render")
            end)

            local lw = write(math.ceil(width/2)+2, height-6, "Speed: ", color.text1, color.black)
            write(lw, height-6, string.format("%.0f%%", (speed*100)/((tape_info.detected_quality == 2 and 2) or 1)), color.white)
            fill(math.ceil(width/2)+2, height-5, width-1, height-5, color.black, color.state_off, "━")
            fill(math.ceil(width/2)+2, height-5, getSliderPos((speed-0.25)/1.75, math.ceil(width/2)+2, width-1), height-5, color.black, color.state_on, "━")
            addButton(math.ceil(width/2)+2, height-5, width-1, height-5, function(ev)
            local _, _, x, y, b = table.unpack(ev)
                if b == 0 then
                    speed = getSliderOutput(x, math.ceil(width/2)+2, width-1, 0.25, 2)
                else
                    speed = 1
                end
                tape.setSpeed(speed)
                event.push("tp_render")
            end)

            local lw = write(2, height-3, "State: ", color.text1)
            write(lw, height-3, tape.getState(), color.white)

            -- Seek bar
            
            if tape.isReady() then
                fill(2, height-2, width-1, height-2, color.black, color.tape_empty, "━")
                if tape_info.has_info then
                    fill(2, height-2, math.floor(1+((width-2)*(tape_info.content/tape_info.size))), height-2, color.black, color.tape_content, "━")
                end
                write(clamp(1+((width-2)*(tape_pos/tape_info.size)), 2, width-1), height-2, "|", color.titlebar_text1)
            else
                fill(2, height-2, width-1, height-2, color.black, color.dotted_2, "┉")
            end

            addButton(2, height-2, width-1, height-2, function(ev)
                local _, _, x, y, b = table.unpack(ev)

                local estimated_pos = math.ceil(clamp(tape_info.size*((x-1)/(width-2)), 0, tape_info.size))
                tape.seek(estimated_pos-tape.getPosition())

                event.push("tp_render")
            end)

            local lw = write(2, height-1, "Rewind", color.state_warn)
            addButton(2, height-1, lw, height-1, function()
                tape.seek(-tape.getSize())
                event.push("tp_render")
            end)

            local lw = write(lw+1, height-1, "Play", color.state_on)
            addButton(2, height-1, lw, height-1, function()
                tape.play()
            end)

            local lw = write(lw+1, height-1, "Stop", color.state_off)
            addButton(2, height-1, lw, height-1, function()
                tape.stop()
            end)

            local lw = write(lw+3, height-1, "Loop: ", color.text1)
            if tape_info.has_info then
                local lw2 = write(lw, height-1, ((loop and "Enabled") or "Disabled"), color.white)
                addButton(lw, height-1, lw2, height-1, function()
                    loop = not loop
                    event.push("tp_render")
                end)
            else
                write(lw, height-1, "Scan Required", color.state_off)
                loop = false
            end
            
            local content_time

            if tape_info.has_info then
                content_time = secondsToDuration((tape_info.content/6000)/speed)
            else
                content_time = secondsToDuration((tape_info.size/6000)/speed)
            end
            local elapsed_time = secondsToDuration((tape_pos/6000)/speed)

            local time_string = "("..elapsed_time.."/"..content_time..")"

            local lw = write(width-(#time_string), height-1, time_string, color.dotted_1)

            gpu.bitblt(0, 1,1, width, height, drawBuffer, 1, 1)
            gpu.setActiveBuffer(0)
        end
    end)
    if not stat then
        quit(err or "")
    end
end)

if lb then
    threads.lightboard = thread.create(
        function ()
            local stat, err = pcall(function ()
                while true do
                    event.pull("tp_lightboard")
                    if lb_active then
                        if tape.isReady() then
                            local state = tape.getState()
                            if state == "STOPPED" then
                                for i1 = 1, lb.light_count do
                                    lb.setActive(i1, true)
                                    lb.setColor(i1, 0x770000)
                                end
                            elseif state == "PLAYING" then
                                while tape.getState() == "PLAYING" do
                                    local bar_pos
                                    if tape_info.has_info then
                                        bar_pos = math.floor(lb_count*(tape.getPosition()/tape_info.content))
                                    else
                                        bar_pos = math.floor(lb_count*(tape.getPosition()/tape_info.size))
                                    end
                                    lb_tick = (lb_tick+2)%180
                                    for i1=1, lb_count do
                                        local r = clamp(math.sin(math.rad((lb_tick+(i1*6))%180))*255, 0, 255)
                                        local g = clamp(128-(math.sin(math.rad((lb_tick+(i1*6))%180))*128), 0, 255)
                                        local b = clamp(255-(math.sin(math.rad((lb_tick+(i1*6))%180))*92), 0, 255)

                                        if i1 > bar_pos then
                                            r = r/8
                                            g = g/8
                                            b = b/8
                                        elseif i1 == bar_pos then
                                            r = clamp(r+64, 0, 255)
                                            g = g+64
                                            b = clamp(b+64, 0, 255)
                                        end
                                        lb.setActive(i1, true)
                                        lb.setColor(i1, rgbToHex(r, g, b))
                                    end
                                    os.sleep(0.05)
                                end
                            elseif state == "FORWARDING" then
                                while tape.getState() == "FORWARDING"do
                                    for i1=1, lb_count do
                                        local res = (i1-lb_tick)%7
                                        if res == 2 then
                                            lb.setColor(i1, 0xffc800)
                                        elseif res == 1 then
                                            lb.setColor(i1, 0xe38400)
                                        elseif res == 0 then
                                            lb.setColor(i1, 0xc23a00)
                                        else
                                            lb.setColor(i1, 0x771700)
                                        end
                                    end
                                    lb_tick = (lb_tick+1)%7
                                    os.sleep(0.05)
                                end
                            elseif state == "REWINDING" then
                                while tape.getState() == "REWINDING"do
                                    for i1=1, lb_count do
                                        local res = (i1+lb_tick)%7
                                        if res == 0 then
                                            lb.setColor(i1, 0xffc800)
                                        elseif res == 1 then
                                            lb.setColor(i1, 0xe38400)
                                        elseif res == 2 then
                                            lb.setColor(i1, 0xc23a00)
                                        else
                                            lb.setColor(i1, 0x771700)
                                        end
                                    end
                                    lb_tick = (lb_tick+1)%7
                                    os.sleep(0.05)
                                end
                            end
                        else
                            for i1 = 1, lb.light_count do
                                lb.setActive(i1, false)
                            end
                        end
                    end
                end
            end)
            if not stat then
                quit(err or "")
            end
        end
    )
end

threads.tapewatcher = thread.create(
    function ()
        local stat, err = pcall(function ()
            local old_state = ""
            local old_pos = 0
            while true do
                local redraw = false
                local tape_state = tape.getState()
                local tape_pos = tape.getPosition()

                if tape_state ~= old_state then
                    redraw = true
                end
                old_state = tape_state

                if tape_pos ~= old_pos then
                    if tape_info.has_info then
                        if tape_pos > tape_info.content then
                            if loop then
                                tape.seek(-tape.getSize())
                            else
                                tape.stop()
                            end
                        end
                    end
                    redraw = true
                end
                old_pos = tape_pos
                
                local new_label = (tape.getLabel() or "No Tape")
                if new_label ~= tape_info.label then
                    tape_info.label = new_label
                    local label_color = tape_info.label:match("§(%w)")
                    if label_color == "6" then
                        tape_info.detected_quality = 2
                        speed = 2
                        tape.setSpeed(speed)
                    elseif label_color == "7" then 
                        tape_info.detected_quality = 1
                        speed = 1
                        tape.setSpeed(speed)
                    else
                        tape_info.detected_quality = 0
                    end
                    tape_info.has_info = false
                    tape_info.content = 0
                    redraw = true
                end
                
                local new_size = tape.getSize() or 0
                if new_size ~= tape_info.size then
                    tape_info.size = new_size
                    tape_info.has_info = false
                    tape_info.content = 0
                    redraw = true
                end

                if autoscan and tape.isReady() and not tape_info.has_info then
                    scanContent()
                    tape.seek(-tape.getSize())
                    if autoplay then
                        tape.play()
                        loop = true
                    end
                    redraw = true
                end
                if redraw then
                    event.push("tp_render")
                    event.push("tp_lightboard")
                end
                os.sleep(0.5)
            end
        end)
        if not stat then
            quit(err or "")
        end
    end
)

local eventThread = thread.create(function ()
    local stat, err = pcall(function ()
        while true do
            local ev = {event.pull()}
            if ev[1] == "interrupted" then
                quit()
                break
            elseif ev[1] == "touch" then
                local _, _, x, y, b = table.unpack(ev)
                DEBUG("touch coords",x,y)

                for k, button in pairs(buttons) do
                    DEBUG("button coords",button.coords.x1, button.coords.y1, button.coords.x2, button.coords.y2)
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
                                        DEBUG("char", char)
                                        current_input = current_input..char
                                    else
                                        DEBUG("key", key_code)
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
                                            DEBUG("char", char)
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
event.push("tp_render")

local stat, err = pcall(function ()
    thread.waitForAll(threads_only)
end)

quit(err)