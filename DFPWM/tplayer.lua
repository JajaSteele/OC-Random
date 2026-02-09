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

local mods = {}
local widgets = {}
local gl
if component.isAvailable("glasses") then
    gl = component.glasses
    gl.setTerminalName("Tape Player")
end

local trans
if component.isAvailable("transposer") then
    trans = component.transposer
end

term.clear()

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

local tape_display_list = {}
local function sortTapeList(useIDs)
    if useIDs then
        table.sort(tape_display_list, function(a,b)
            --print(a.id,b.id)
            return a.id < b.id
        end)
    else
        table.sort(tape_display_list, function(a,b)
            if a.data.album and not b.data.album then
                --print("Sorted from having album")
                return true
            elseif not a.data.album and b.data.album then
                --print("Sorted from NOT having album")
                return false
            elseif a.data.artist and not b.data.artist then
                --print("Sorted from having artist")
                return true
            elseif not a.data.artist and b.data.artist then
                --print("Sorted from NOT having artist")
                return false
            else
                --print(a.data.label, b.data.label)
                return a.data.label:lower() < b.data.label:lower()
            end
        end)
    end
end

local sort_by_id = false

local tape_list = {}
local trans_side = {}
local function scanTapes(verbose)
    tape_list = {}
    tape_display_list = {}

    if verbose then
        print("Extracting current tape")
    end
    trans.transferItem(trans_side.drive, trans_side.storage, 1, 1)

    if verbose then
        print("Scanning storage slots")
    end
    local storage_inv = trans.getAllStacks(trans_side.storage).getAll()
    local count = 0
    for slot, data in pairs(storage_inv) do
        if data.name == "computronics:tape" then
            count = count + 1
            local tape_metadata = {}
            trans.transferItem(trans_side.storage, trans_side.drive, 1, slot, 1)
            local label = tape.getLabel():gsub("§%w", "")
            tape_metadata.label = label
            tape_metadata.slot = slot

            local label_parts = {}
            for part in label:gmatch("[^%-]+") do
                part = part:gsub("^%s", "")
                part = part:gsub("%s$", "")
                label_parts[#label_parts+1] = part
            end
            if #label_parts == 3 then
                tape_metadata.artist, tape_metadata.album, tape_metadata.title = table.unpack(label_parts)
            elseif #label_parts == 2 then
                tape_metadata.artist, tape_metadata.title = table.unpack(label_parts)
            elseif #label_parts == 1 then
                tape_metadata.title = table.unpack(label_parts)
            end

            if verbose then
                print("Detected tape: "..tape_metadata.label)
                print("   Artist: "..(tape_metadata.artist or "UNKNOWN"))
                print("   Album: "..(tape_metadata.album or "UNKNOWN"))
                print("   Title: "..(tape_metadata.title or "UNKNOWN"))
            end

            tape_list[#tape_list+1] = tape_metadata
            tape_display_list[#tape_display_list+1] = {
                data=tape_metadata,
                id=#tape_list
            }
            trans.transferItem(trans_side.drive, trans_side.storage, 1, 1, slot)
        end
    end

    if verbose then
        print("Sorting display list")
    end
    sortTapeList(sort_by_id)

    if verbose then
        print("Done!")
        print("Found "..count.." tapes")
    end
end
if trans then
    print("Scanning sides..")
    for i1=0, 5 do
        local name = trans.getInventoryName(i1)
        if name then
            if name:match("tape_reader") then
                trans_side.drive = i1
                print("Found tape drive")
            else
                trans_side.storage = i1
                print("Found storage")
            end
        end
    end

    if trans_side.drive and trans_side.storage then
        scanTapes(true)
    else
        trans = nil
    end
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

local first_exit = true
local function quit(err)
    for k,v in pairs(threads) do
        print("quitting thread "..k)
        pcall(function ()
            v:kill()
        end)
    end

    if first_exit then
        print("Clearing and exiting GPU buffer")
        gpu.setActiveBuffer(0)
        gpu.freeBuffer(drawBuffer)
        term.clear()
        first_exit = false
    end
    
    if lb then
        print("Clearing lightboard")
        local stat2, err2 = pcall(function ()
            for i1=1, lb_count do
                lb.setActive(i1, false)
                lb.setColor(i1, 0x000000)
            end
        end)
        if not stat2 then
            print("Couldn't clear lightboard: "..err2)
        end
    end

    if gl then
        print("Clearing glasses")
        local stat2, err2 = pcall(function ()
            for k,widget in pairs(widgets) do
                local mods = widget.getModifiers()
                local id = widget.getID()
                if mods then
                    for k,v in pairs(mods) do
                        widget.removeModifier(v[1])
                    end
                end
                widget.removeWidget()
            end
            gl.removeAll()
        end)
        if not stat2 then
            print("Couldn't clear glasses: "..err2)
        end
    end

    if err then
        print(err)
        --error(err)
    else
        print("Program closed")
    end
end

local render_mode = 0

local volume = 1
local speed = 1
local loop = false
local autoscan = false
local autoplay = false
local autoloop = false

local play_history = {}
local playlist_mode = false
local shuffle_mode = false
local current_tape = 1

local scroll = 0

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

local function changeTape(playlist_pos)
    local old_metadata = tape_list[current_tape]
    trans.transferItem(trans_side.drive, trans_side.storage, 1, 1, old_metadata.slot)

    current_tape = playlist_pos

    local new_metadata = tape_list[current_tape]
    trans.transferItem(trans_side.storage, trans_side.drive, 1, new_metadata.slot, 1)
end

threads.render = thread.create(function() 
    local stat, err = pcall(function ()
        while true do
            event.pull("tp_render")

            buttons = {}
            text_boxes = {}
            gpu.setActiveBuffer(drawBuffer)

            term.clear()

            if render_mode == 0 then
                local tape_pos = tape.getPosition()
                
                fill(1,1, width, 3, color.titlebar_bg)
                write(3,2, "Tape Player", color.titlebar_text1, color.titlebar_bg)

                if gl then
                    local txt = "Link Glasses"
                    local lw = write(width-#txt-1, 2, txt, color.dotted_1, color.titlebar_bg)
                    addButton(width-#txt-1, 2, lw, 2, function(ev)
                        local _, id, x, y, b, username = table.unpack(ev)
                        component.computer.beep(800, 0.1)
                        gl.startLinking(username)
                    end)
                end

                local lw = write(3,5, "Scan Content", color.dotted_2)
                addButton(3,5, lw, 5, function()
                    scanContent()
                    event.push("tp_render")
                    event.push("tp_glassrender")
                end)
                local lw2 = write(lw+4, 5, "Autoscan: ", color.dotted_2)
                local lw3 = write(lw2, 5, ((autoscan and "Enabled") or "Disabled"), color.dotted_1)
                addButton(lw2, 5, lw3, 5, function()
                    autoscan = not autoscan
                    event.push("tp_render")
                end)

                if autoscan then
                    lw2 = write(lw3+4, 5, "Autoplay: ", color.dotted_2)
                    lw3 = write(lw2, 5, ((autoplay and "Enabled") or "Disabled"), color.dotted_1)
                    addButton(lw2, 5, lw3, 5, function()
                        autoplay = not autoplay
                        event.push("tp_render")
                    end)
                else
                    autoplay = false
                end

                if autoscan then
                    lw2 = write(lw3+4, 5, "Autoloop: ", color.dotted_2)
                    lw3 = write(lw2, 5, ((autoloop and "Enabled") or "Disabled"), color.dotted_1)
                    addButton(lw2, 5, lw3, 5, function()
                        autoloop = not autoloop
                        event.push("tp_render")
                    end)
                else
                    autoloop = false
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

                local lw = write(3, 10, "Detected Tapes: ", color.text1)
                if trans then
                    local lw = write(lw, 10, #tape_list, color.white)

                    local lw2 = write(lw+3, 10, "Rescan", color.dotted_2)
                    addButton(lw+3, 10, lw2, 10, function()
                        write(lw+3, 10, "Rescan", color.state_warn)
                        scanTapes(false)
                        event.push("tp_render")
                    end)
                    local lw3 = write(lw2+3, 10, "Switch Tape", color.dotted_2)
                    addButton(lw2+3, 10, lw3, 10, function()
                        render_mode = 1
                        scroll = 0
                        event.push("tp_render")
                    end)

                    local lw = write(3, 11, "Playlist Mode: ", color.dotted_2)

                    if not autoscan then
                        write(lw, 11, "Requires Autoscan", color.state_off)
                        playlist_mode = false
                    elseif not autoplay then
                        write(lw, 11, "Requires Autoplay", color.state_off)
                        playlist_mode = false
                    elseif autoloop then
                        write(lw, 11, "Conflicts with Autoloop", color.state_off)
                        playlist_mode = false
                    else
                        lw2 = write(lw, 11, ((playlist_mode and "Enabled") or "Disabled"), color.dotted_1)
                        addButton(lw, 11, lw2, 11, function()
                            playlist_mode = not playlist_mode
                            if playlist_mode then
                                autoplay = true
                                autoscan = true
                                autoloop = false
                                if not tape.isReady() then
                                    local metadata = tape_list[current_tape]
                                    trans.transferItem(trans_side.storage, trans_side.drive, 1, metadata.slot, 1)
                                end
                            end
                            event.push("tp_render")
                        end)

                        if playlist_mode then
                            local lw = write(lw2+5, 11, "Shuffle: ", color.dotted_2)
                            lw2 = write(lw, 11, ((shuffle_mode and "Enabled") or "Disabled"), color.dotted_1)
                            addButton(lw, 11, lw2, 11, function()
                                shuffle_mode = not shuffle_mode
                                event.push("tp_render")
                            end)
                        end
                    end
                else
                    write(lw, 10, "? Missing Transposer", color.state_off)
                end

                if tape_info.detected_quality > 0 then
                    local lw = write(3, 13, "Detected Quality: ", color.dotted_2)
                    if tape_info.detected_quality == 1 then
                        write(lw, 13, "Normal", color.dotted_1)
                    elseif tape_info.detected_quality == 2 then
                        write(lw, 13, "High", color.dotted_1)
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
                    event.push("tp_glassrender")
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
            elseif render_mode == 1 then
                fill(1,1, width, 3, color.titlebar_bg)
                write(3,2, "Tape Selector", color.titlebar_text1, color.titlebar_bg)
                
                local back_text = "Cancel"
                local back_x = (width-#back_text)-1
                local lw = write(back_x, 2, back_text, color.state_off, color.titlebar_bg)
                addButton(back_x, 2, lw, 2, function()
                    render_mode = 0
                    event.push("tp_render")
                end)

                local lw = write(3, 4, "Sort Mode: ", color.dotted_2)
                local lw2 = write(lw, 4, (sort_by_id and "ID") or "Name", color.dotted_1)
                addButton(lw,4,lw2,4, function()
                    sort_by_id = not sort_by_id
                    sortTapeList(sort_by_id)
                    scroll = 0
                    event.push("tp_render")
                end)
                
                local x_offset = #tostring(#tape_list)+2
                for i1=1, height-5 do
                    local tape_pos = i1+scroll
                    local tape_data = tape_display_list[tape_pos]
                    local write_y = 4+i1
                    if tape_data then
                        local tape_id = tape_data.id
                        local tape_metadata = tape_data.data
                        write(2, write_y, tostring(tape_id), color.state_warn)
                        local lw = write(3+x_offset, write_y, tape_metadata.label, color.text1)
                        addButton(3+x_offset, write_y, lw, write_y, function()
                            changeTape(tape_id)
                            render_mode = 0
                            event.push("tp_render")
                        end)
                    end
                end
            end

            gpu.bitblt(0, 1,1, width, height, drawBuffer, 1, 1)
            gpu.setActiveBuffer(0)
        end
    end)
    if not stat then
        quit(err or "")
    end
end)

local glass_ready = false
local gl_timebar_width = 175
if gl then
    threads.glass = thread.create(function()
        local stat, err = pcall(function ()
            while true do
                local ev = event.pull()
                if ev == "tp_glassrender" then
                    if glass_ready then
                        local content_time
                        local tape_pos = tape.getPosition()

                        if tape_info.has_info then
                            widgets.timepos_1.modifiers()[mods.timepos_transl].set(-math.floor(gl_timebar_width/2)+((gl_timebar_width-1)*clamp(tape_pos/tape_info.content, 0, 1)), -65, 55)
                            widgets.timebar_4.setSize(gl_timebar_width*clamp(tape_pos/tape_info.content, 0, 1), 3)
                            content_time = secondsToDuration((tape_info.content/6000)/speed)
                        else
                            widgets.timepos_1.modifiers()[mods.timepos_transl].set(-math.floor(gl_timebar_width/2)+((gl_timebar_width-1)*clamp(tape_pos/tape_info.size, 0, 1)), -65, 55)
                            widgets.timebar_4.setSize(gl_timebar_width*clamp(tape_pos/tape_info.size, 0, 1), 3)
                            content_time = secondsToDuration((tape_info.size/6000)/speed)
                        end

                        local elapsed_time = secondsToDuration((tape_pos/6000)/speed)
                        local time_string = ""..elapsed_time.." / "..content_time..""

                        widgets.timetext1.setText(time_string)
                        widgets.timetext2.setText(time_string)

                        widgets.title1.setText(tape_info.label:gsub("§%w", ""))
                        widgets.title2.setText(tape_info.label:gsub("§%w", ""))
                    end
                elseif ev == "tp_glassform" then
                    glass_ready = false
                    for k,widget in pairs(widgets) do
                        local mods = widget.getModifiers()
                        local id = widget.getID()
                        if mods then
                            for k,v in pairs(mods) do
                                widget.removeModifier(v[1])
                            end
                        end
                        widget.removeWidget()
                    end
                    gl.removeAll()
                    local tape_pos = tape.getPosition()

                    widgets.bg_1 = gl.addBox2D()
                    widgets.bg_1.setSize(11, gl_timebar_width)
                    widgets.bg_1.addColor(0.05,0.05,0.1,1)
                    widgets.bg_1.addColor(0,0,0,0)
                    widgets.bg_1.addAutoTranslation(50, 100)
                    widgets.bg_1.addRotation(270, 0, 0, 1)
                    widgets.bg_1.addTranslation(65, -math.floor(gl_timebar_width/2), 40)


                    widgets.timebar_1 = gl.addBox2D()
                    widgets.timebar_1.addAutoTranslation(50, 100)
                    widgets.timebar_1.addTranslation(-math.floor(gl_timebar_width/2), -65, 50)
                    widgets.timebar_1.setSize(gl_timebar_width, 3)
                    widgets.timebar_1.addColor(0,0,0.1,1)
                    widgets.timebar_1.addColor(0,0,0.1,1)

                    widgets.timebar_2 = gl.addBox2D()
                    widgets.timebar_2.addAutoTranslation(50, 100)
                    widgets.timebar_2.addTranslation(-math.floor(gl_timebar_width/2), -66, 45)
                    widgets.timebar_2.setSize(gl_timebar_width, 5)
                    widgets.timebar_2.addColor(0.1,0.1,0.2,1)
                    widgets.timebar_2.addColor(0.1,0.1,0.2,1)

                    widgets.timebar_3 = gl.addBox2D()
                    widgets.timebar_3.addAutoTranslation(50, 100)
                    widgets.timebar_3.addTranslation(-math.floor(gl_timebar_width/2)-1, -65, 45)
                    widgets.timebar_3.setSize(gl_timebar_width+2, 3)
                    widgets.timebar_3.addColor(0.1,0.1,0.2,1)
                    widgets.timebar_3.addColor(0.1,0.1,0.2,1)

                    widgets.timepos_1 = gl.addBox2D()
                    widgets.timepos_1.addAutoTranslation(50, 100)
                    if tape_info.has_info then
                        mods.timepos_transl = widgets.timepos_1.addTranslation(-math.floor(gl_timebar_width/2)+((gl_timebar_width-1)*clamp(tape_pos/tape_info.content, 0, 1)), -65, 55)
                    else
                        mods.timepos_transl = widgets.timepos_1.addTranslation(-math.floor(gl_timebar_width/2)+((gl_timebar_width-1)*clamp(tape_pos/tape_info.size, 0, 1)), -65, 55)
                    end
                    widgets.timepos_1.setSize(1, 3)
                    widgets.timepos_1.addColor(1,1,1,1)
                    widgets.timepos_1.addColor(1,1,1,1)

                    widgets.timebar_4 = gl.addBox2D()
                    widgets.timebar_4.addAutoTranslation(50, 100)
                    widgets.timebar_4.addTranslation(-math.floor(gl_timebar_width/2), -65, 50)
                    if tape_info.has_info then
                        widgets.timebar_4.setSize(gl_timebar_width*clamp(tape_pos/tape_info.content, 0, 1), 3)
                    else
                        widgets.timebar_4.setSize(gl_timebar_width*clamp(tape_pos/tape_info.size, 0, 1), 3)
                    end
                    widgets.timebar_4.addColor(1,0,0.1,1)
                    widgets.timebar_4.addColor(0,0,1.1,1)

                    widgets.title1 = gl.addText2D()
                    widgets.title1.addAutoTranslation(50, 100)
                    widgets.title1.addTranslation(0, -82, 50)
                    widgets.title1.addScale(0.8,0.8,1)
                    widgets.title1.setHorizontalAlign("center")
                    widgets.title1.addColor(0.25,0.75,1,1)
                    widgets.title1.setText(tape_info.label:gsub("§%w", ""))

                    widgets.title2 = gl.addText2D()
                    widgets.title2.addAutoTranslation(50, 100)
                    widgets.title2.addTranslation(0, -82, 45)
                    widgets.title2.addTranslation(1, 1, 0)
                    widgets.title2.addScale(0.8,0.8,1)
                    widgets.title2.setHorizontalAlign("center")
                    widgets.title2.addColor(0,0.125,0.25,1)
                    widgets.title2.setText(tape_info.label:gsub("§%w", ""))

                    local content_time

                    if tape_info.has_info then
                        content_time = secondsToDuration((tape_info.content/6000)/speed)
                    else
                        content_time = secondsToDuration((tape_info.size/6000)/speed)
                    end

                    local elapsed_time = secondsToDuration((tape_pos/6000)/speed)
                    local time_string = ""..elapsed_time.." / "..content_time..""
                    
                    widgets.timetext1 = gl.addText2D()
                    widgets.timetext1.addAutoTranslation(50, 100)
                    widgets.timetext1.addTranslation(0, -74, 50)
                    widgets.timetext1.addScale(0.75,0.75,1)
                    widgets.timetext1.setHorizontalAlign("center")
                    widgets.timetext1.addColor(0.375,0.375,0.75,1)
                    widgets.timetext1.setText(time_string)

                    widgets.timetext2 = gl.addText2D()
                    widgets.timetext2.addAutoTranslation(50, 100)
                    widgets.timetext2.addTranslation(0, -74, 45)
                    widgets.timetext2.addTranslation(0.75, 0.75, 0)
                    widgets.timetext2.addScale(0.75,0.75,1)
                    widgets.timetext2.setHorizontalAlign("center")
                    widgets.timetext2.addColor(0.0625,0.0625,0.125,1)
                    widgets.timetext2.setText(time_string)

                    glass_ready = true
                end
            end
        end)
        if not stat then    
            quit(err or "")
        end 
    end)
end

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
                        if tape_pos > math.min(tape_info.content+(9000*speed), tape_info.size-2) then
                            if loop then
                                tape.seek(-tape.getSize())
                                if tape.getState() ~= "PLAYING" then
                                    tape.play()
                                end
                            else
                                tape.stop()
                            end

                            if playlist_mode then
                                play_history[#play_history+1] = current_tape
                                if #play_history > math.min(10, (#tape_list)-1) then
                                    table.remove(play_history, 1)
                                end
                                if shuffle_mode then
                                    local random
                                    while true do
                                        random = math.random(1, #tape_list)
                                        local is_okay = true
                                        for k,v in pairs(play_history) do
                                            if v == random then
                                                is_okay = false
                                                break
                                            end
                                        end
                                        if is_okay then
                                            break
                                        end
                                    end
                                    changeTape(random)
                                else
                                    local new_tape = current_tape+1
                                    if new_tape > #tape_list then
                                        new_tape = 1
                                    end

                                    changeTape(new_tape)
                                end
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
                    end
                    if autoloop then
                        loop = true
                    end
                    redraw = true
                end
                if redraw then
                    event.push("tp_render")
                    event.push("tp_lightboard")
                    event.push("tp_glassrender")
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
            elseif ev[1] == "scroll" then
                if render_mode == 1 then
                    scroll = clamp(scroll-(ev[5]*3), 0, #tape_list)
                    event.push("tp_render")
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
event.push("tp_glassform")

local stat, err = pcall(function ()
    thread.waitForAll(threads_only)
end)

quit(err)