local component = require("component")
local term = require("term")
local event = require("event")
local thread = require("thread")
local kb = require("keyboard")
local internet = require("internet")

local screen = component.screen
local gpu = component.gpu
local tape = component.tape_drive
local trans = component.transposer

local dl_bar_end = {
    {c="▉", t=0},
    {c="▊", t=0},
    {c="▋", t=0},
    {c="▌", t=0},
    {c="▍", t=0},
    {c="▎", t=0},
    {c="▏", t=0},
}
local diff = 1/(#dl_bar_end+1)
for k,v in ipairs(dl_bar_end) do
    v.t = diff*(#dl_bar_end-(k-1))
end
local function getDlFooter(decimal)
    for k,v in ipairs(dl_bar_end) do
        if v.t <= decimal then
            return v.c
        end
    end
    return ""
end

local function clamp(x,min,max) if x > max then return max elseif x < min then return min else return x end end

local tape_sizes = {
    2,
    4,
    6,
    8,
    16,
    32,
    64,
    128
}

local tape_metas = {
    5,
    0,
    6,
    1,
    2,
    3,
    4,
    8
}

local trans_side = {}
print("Scanning sides..")
for i1=0, 5 do
    local name = trans.getInventoryName(i1)
    if name then
        if name:match("tape_reader") then
            trans_side.drive = i1
            print("Found tape drive")
        elseif name:match("interface") then
            trans_side.interface = i1
            print("Found ME interface")
        end
    end
end

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

    if err then
        print(err)
        --error(err)
    else
        print("Program closed")
    end
end

local logs = {}
local function log(text, fg, bg)
    table.insert(logs, 1, {
        text = text,
        fg = fg,
        bg = bg
    })
    if #logs > 64 then
        table.remove(logs, #logs)
    end
end

local downloading = false
local curr_dl = 0
local url_list = {}
local scroll = 0
local render_mode = 0

threads.render = thread.create(function() 
    local stat, err = pcall(function ()
        while true do
            event.pull("tmdl_render")

            buttons = {}
            text_boxes = {}
            gpu.setActiveBuffer(drawBuffer)

            term.clear()

            fill(1,1, width, 3, color.titlebar_bg)
            write(3,2, "Mass Tape Downloader", color.titlebar_text1, color.titlebar_bg)

            if downloading then
                local txt = "Stop"
                local sw = width-#txt-1
                local lw = write(sw, 2, txt, color.state_off, color.titlebar_bg)
                addButton(sw, 2, lw, 2, function()
                    downloading = false
                    event.push("tmdl_render")
                end)
            else
                local txt = "Start"
                local sw = width-#txt-1
                local lw = write(sw, 2, txt, color.state_on, color.titlebar_bg)
                addButton(sw, 2, lw, 2, function()
                    downloading = true
                    if curr_dl == 0 then
                        curr_dl = 1
                    end
                    event.push("tmdl_render")
                    event.push("tmdl_start_download")
                end)
            end

            if render_mode == 0 then
                local x_offset = #tostring(#url_list)+2
                for i1=1, height-5 do
                    local url_pos = i1+scroll
                    local url_data = url_list[url_pos]
                    local write_y = 4+i1
                    if url_data then
                        write(2, write_y, tostring(url_pos), color.state_warn)
                        if curr_dl == url_pos then
                            local lw = write(3+x_offset, write_y, url_data.label, color.state_on)
                        else
                            local lw = write(3+x_offset, write_y, url_data.label, color.text1)
                            if not downloading then
                                addButton(3+x_offset, write_y, lw, write_y, function(ev)
                                    local _, _, x, y, b = table.unpack(ev)
                                    if b == 1 then
                                        table.remove(url_list, url_pos)
                                        component.computer.beep(100, 0.1)
                                        event.push("tmdl_render")
                                    end
                                end)
                            end
                        end
                    end
                end

                write(3, height, "Paste a Youtube URL to add it", color.dotted_1)
            else
                write(3, height, "Viewing download logs", color.dotted_1)
            end

            gpu.bitblt(0, 1,1, width, height, drawBuffer, 1, 1)
            gpu.setActiveBuffer(0)
        end
    end)
    if not stat then
        quit(err or "")
    end
end)

threads.downloader = thread.create(function()
    local stat, err = pcall(function ()
        while true do
            if not downloading then
                event.pull("tmdl_start_download")
            else
                if curr_dl > #url_list then
                    downloading = false
                    curr_dl = 0
                    event.push("tmdl_render")
                else
                    local curr_url = url_list[curr_dl]
                    log("Requesting "..curr_dl.." ("..curr_url.youtube_id..")", color.text1)
                    local req = internet.request("http://jajasteele.mooo.com:7277/?vidid="..curr_url.youtube_id.."&hq=true")
                    if req then
                        log("Waiting for request", color.text1)
                        repeat
                            os.sleep(0.5)
                        until req.finishConnect()
                        local mt = getmetatable(req)
                        local code, message, headers = mt.__index.response()
                        local file_size = tonumber(headers["Content-Length"][1])
                        local size_needed
                        for k, v in ipairs(tape_sizes) do
                            if v*60 >= (file_size/6000) then
                                log("Cassette size required: "..v.." minutes", color.text1)
                                size_needed = tape_metas[k]
                                break
                            end
                        end

                        if size_needed then
                            local slot_needed
                            local repeats = 0
                            log("Pulling required cassette into drive", color.text1)
                            while true do
                                local found = false
                                for k, item in pairs(trans.getAllStacks(trans_side.interface).getAll()) do
                                    if item.damage == size_needed then
                                        found = true
                                        slot_needed = k
                                        break
                                    end
                                end
                                if found or repeats > 5 then
                                    break
                                else
                                    repeats = repeats + 1
                                    os.sleep(5)
                                end
                            end

                            if slot_needed then
                                trans.transferItem(trans_side.interface, trans_side.drive, 1, slot_needed, 1)
                                local tape_size = tape.getSize()
                                tape.seek(-tape_size)
                                log("Wiping cassette", color.text1)
                                tape.write(string.rep(string.char(0), tape_size))
                                tape.seek(-tape_size)

                                log("Writing to cassette", color.text1)
                                for chunk in req do
                                    tape.write(chunk)
                                end

                                tape.seek(-tape_size)
                                log("Labelling cassette", color.text1)
                                tape.setLabel("§6"..curr_url.label)

                                log("Ejecting cassette", color.text1)
                                trans.transferItem(trans_side.drive, trans_side.interface, 1, 1)

                                os.sleep(0.5)

                                curr_dl = curr_dl+1
                                event.push("tmdl_render")
                            end
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
                scroll = clamp(scroll-ev[5], 0, #url_list)
                event.push("tmdl_render")
            elseif ev[1] == "clipboard" then
                local _, _, paste, username = table.unpack(ev)
                local youtube_id = paste:match("%?v=([%w_%-]+)") or paste:match("shorts/([%w_%-]+)") or paste:match("youtu%.be/([%w_%-]+)")
                if youtube_id then
                    local lw = write(3, 4, "New Tape Label: ", color.text1)
                    local textbox = {
                        coords={
                            x1=lw,
                            y1=4,
                            x2=lw,
                            y2=4
                        },
                        value="",
                        max_length=width-lw,
                        pattern_filter="[^%c]",
                        start_func=nil,
                        enter_func=function(txt)
                            url_list[#url_list+1] = {
                                youtube_id = youtube_id,
                                label = txt
                            }
                            event.push("tmdl_render")
                        end,
                        cancel_func=function(txt)
                            event.push("tmdl_render")
                        end,
                        foreground=color.white,
                        background=color.black
                    }

                    local current_input = textbox.value or ""
                    event.push("tmdl_renderinput")

                    local function displayInput()
                        write(3, 4, "New Tape Label: ", color.text1)
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
                                    DEBUG("Exiting Input box")
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
                        elseif ev[1] == "tmdl_renderinput" then
                            displayInput()
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
event.push("tmdl_render")

local stat, err = pcall(function ()
    thread.waitForAll(threads_only)
end)

quit(err)