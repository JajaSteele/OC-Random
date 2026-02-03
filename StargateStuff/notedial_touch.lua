local script_version = "1.8"
-- AUTO UPDATE STUFF
local curr_script = debug.getinfo(2, "S").source:gsub("^=", "")
local script_io = io.open(curr_script, "r")
local local_version_line = script_io:read()
script_io:close()

local function getVersionNumbers(first_line)
    local major, minor, patch = first_line:match("local script_version = \"(%d+)%.(%d+)\"")
    return {tonumber(major) or 0, tonumber(minor) or 0}
end
local function getVersion(req)
    for chunk in req do
        local version_line = chunk:match([[local script_version = "%d+%.%d+"]])
        if version_line then
            return version_line
        end
    end
end

local local_version = getVersionNumbers(local_version_line)

print("Local Version: "..string.format("%d.%d", table.unpack(local_version)))
print("Current script path: "..curr_script)

local comp = require("component")

local update_source = "https://raw.githubusercontent.com/JajaSteele/OC-Random/refs/heads/main/StargateStuff/notedial_touch.lua"
if comp.isAvailable("internet") then
    local internet = require("internet")
    local update_request = internet.request(update_source)
    if update_request then
        local script_version = getVersionNumbers(getVersion(update_request))
        print("Remote Version: "..string.format("%d.%d", table.unpack(script_version)))
        if script_version[1] > local_version[1] or (script_version[1] == local_version[1] and script_version[2] > local_version[2]) then
            print("Remote version is newer, updating local")
            os.sleep(0.5)
            local full_update_request = internet.request(update_source)
            if full_update_request then
                local local_io = io.open(curr_script, "w")
                if local_io then
                    for chunk in full_update_request do
                        local_io:write(chunk)
                    end
                    local_io:close()
                    print("Updated local script!")
                    os.sleep(0.5)
                    print("REBOOTING")
                    os.sleep(0.5)
                    require("computer").shutdown(true)
                else
                    print("Couldn't open file '"..curr_script.."'")
                    os.sleep(0.5)
                end
            else
                print("Full update request failed")
                os.sleep(0.5)
            end
        end
    else
        print("Update request failed")
        os.sleep(0.5)
    end
else
    print("No internet card available")
end
-- END OF AUTO UPDATE

local fs = require("filesystem")
local sides = require("sides")
local ser = require("serialization")
local event = require("event")
local thread = require("thread")
local kb = require("keyboard")
local computer = require("computer")
local inv = comp.inventory_controller
local term = require("term")
local screen = comp.screen
local gpu = comp.gpu

local function DEBUG(...)
    if comp.isAvailable("chat_box") then
        comp.chat_box.setName("DEBUG")
        local txt = ""
        for k,v in ipairs({...}) do
            txt = txt .. tostring(v) .. "    "
        end
        comp.chat_box.say(tostring(txt))
    end
end

if not fs.isDirectory("/lib/jjs") then
    print("Creating /lib/jjs directory..")
    fs.makeDirectory("/lib/jjs")
end

if not fs.exists("/lib/jjs/deflate.lua") then
    os.execute("wget https://raw.githubusercontent.com/JajaSteele/OC-Random/refs/heads/main/NBT%20Reader/deflate.lua /lib/jjs/deflate.lua")
end
if not fs.exists("/lib/jjs/nbt.lua") then
    os.execute("wget https://raw.githubusercontent.com/JajaSteele/OC-Random/refs/heads/main/NBT%20Reader/nbt.lua /lib/jjs/nbt.lua")
end

local nbt = require("jjs/nbt")
local def = require("jjs/deflate")

local iris_code = "270706"

local color = {
    topbar = 0x7d8eb0,
    bg1 = 0x99BBFF,
    bgerror = 0xb07d7d,
    bgfeedback = 0x7db0aa,
    text1 = 0x1a1a3c,
    text2 = 0x3e3e65,
    textfeedback = 0x105c2a,
    textfeedback2 = 0x356445,
    texterror = 0x922a2a,
    texterror2 = 0x671414,
    textvalid = 0x3c7d36,
    textbright = 0x1a1a89,
}

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

local dhd
if comp.isAvailable("dhd") then
    dhd = comp.dhd
end

local sg_count = 0
local sg_map = {}
for address, _ in pairs(comp.list("stargate")) do
    sg_map[comp.invoke(address, "getGateType")] = comp.proxy(address)
    sg_count = sg_count+1
end
local sg

local width, height = gpu.maxResolution()
local ratio_x, ratio_y = screen.getAspectRatio()
local ratio = ratio_x/ratio_y
height = math.min(width,height,25)
width = math.min(math.floor(height*ratio)*2, width)

gpu.setResolution(width, height)
event.pull("screen_resized")
term.getViewport()

local symbolTypeToGate = {
    [0] = "MILKYWAY",
    [1] = "PEGASUS",
    [2] = "UNIVERSE",
}

local symbolTypeNames = {
    [0] = "Milky Way",
    [1] = "Pegasus",
    [2] = "Universe",
}
local symbolIndex = {
    [0] = {
        [0] = "Sculptor",
        [1] = "Scorpius",
        [2] = "Centaurus",
        [3] = "Monoceros",
        [4] = "Point of Origin",
        [5] = "Pegasus",
        [6] = "Andromeda",
        [7] = "Serpens Caput",
        [8] = "Aries",
        [9] = "Libra",
        [10] = "Eridanus",
        [11] = "Leo Minor",
        [12] = "Hydra",
        [13] = "Sagittarius",
        [14] = "Sextans",
        [15] = "Scutum",
        [16] = "Pisces",
        [17] = "Virgo",
        [18] = "Bootes",
        [19] = "Auriga",
        [20] = "Corona Australis",
        [21] = "Gemini",
        [22] = "Leo",
        [23] = "Cetus",
        [24] = "Triangulum",
        [25] = "Aquarius",
        [26] = "Microscopium",
        [27] = "Equuleus",
        [28] = "Crater",
        [29] = "Perseus",
        [30] = "Cancer",
        [31] = "Norma",
        [32] = "Taurus",
        [33] = "Canis Minor",
        [34] = "Capricornus",
        [35] = "Lynx",
        [36] = "Orion",
        [37] = "Piscis Austrinus",
    },
    [1] = {
        [0] = "Danami",
        [1] = "Arami",
        [2] = "Setas",
        [3] = "Aldeni",
        [4] = "Aaxel",
        [5] = "Bydo",
        [6] = "Avoniv",
        [7] = "Ecrumig",
        [8] = "Laylox",
        [9] = "Ca Po",
        [10] = "Alura",
        [11] = "Lenchan",
        [12] = "Acjesis",
        [13] = "Dawnre",
        [14] = "Subido",
        [15] = "Zamilloz",
        [16] = "Recktic",
        [17] = "Robandus",
        [18] = "Unknow1",
        [19] = "Zeo",
        [20] = "Tahnan",
        [21] = "Elenami",
        [22] = "Hamlinto",
        [23] = "Salma",
        [24] = "Abrin",
        [25] = "Poco Re",
        [26] = "Hacemill",
        [27] = "Olavii",
        [28] = "Ramnon",
        [29] = "Unknow2",
        [30] = "Gilltin",
        [31] = "Sibbron",
        [32] = "Amiwill",
        [33] = "Illume",
        [34] = "Sandovi",
        [35] = "Baselai",
        [36] = "Once El",
        [37] = "Roehi",
    },
    [2] = {
        [1] = "Glyph 1",
        [2] = "Glyph 2",
        [3] = "Glyph 3",
        [4] = "Glyph 4",
        [5] = "Glyph 5",
        [6] = "Glyph 6",
        [7] = "Glyph 7",
        [8] = "Glyph 8",
        [9] = "Glyph 9",
        [10] = "Glyph 10",
        [11] = "Glyph 11",
        [12] = "Glyph 12",
        [13] = "Glyph 13",
        [14] = "Glyph 14",
        [15] = "Glyph 15",
        [16] = "Glyph 16",
        [17] = "Glyph 17",
        [18] = "Glyph 18",
        [19] = "Glyph 19",
        [20] = "Glyph 20",
        [21] = "Glyph 21",
        [22] = "Glyph 22",
        [23] = "Glyph 23",
        [24] = "Glyph 24",
        [25] = "Glyph 25",
        [26] = "Glyph 26",
        [27] = "Glyph 27",
        [28] = "Glyph 28",
        [29] = "Glyph 29",
        [30] = "Glyph 30",
        [31] = "Glyph 31",
        [32] = "Glyph 32",
        [33] = "Glyph 33",
        [34] = "Glyph 34",
        [35] = "Glyph 35",
        [36] = "Glyph 36",
    }
}

local function engageSymbol(symbol, forceSpin, stargate)
    if dhd and not forceSpin then
        local _, fb = dhd.pressButton(symbol)
        os.sleep(0.85)
        return fb
    else
        (stargate or sg).engageSymbol(symbol)
        event.pull(30, "stargate_spin_chevron_engaged")
        return true
    end
end

local function setIris(close, noWait, stargate)
    local state = (stargate or sg).getIrisState()

    if close and (state == "OPENING" or state == "OPENED") then
        (stargate or sg).toggleIris()
        if not noWait then
            event.pull(5, "stargate_iris_closed")
        end
        return true
    elseif not close and (state == "CLOSING" or state == "CLOSED") then
        (stargate or sg).toggleIris()
        if not noWait then
            event.pull(5, "stargate_iris_opened")
        end
        return true
    end
    return false
end

local function decodeDialed(str)
    local dat = {}
    for symbol in str:gmatch("([%w%s]-), ") do
        dat[#dat+1] = symbol
    end
    return dat
end

local function timeTick()
    return (os.time()*1000/60/60) - 6000
end

local address_display = ""

local symbol_type
local selected_address

local raw_address = {}
local full_address = {}

local last_error = {
    msg = "None",
    time = timeTick(),
    timeout = 0
}

local last_feedback = {
    msg = nil,
    time = timeTick(),
}

local function softError(msg)
    if msg then
        last_error = {
            msg=msg,
            time = timeTick(),
            timeout = 2*15
        }
    else
        last_error = {
            msg="none",
            time = timeTick(),
            timeout = 0
        }
    end
end

local function feedback(msg)
    last_feedback = {
        msg=msg,
        time = timeTick(),
    }
end

local drawBuffer = gpu.allocateBuffer(width, height)

local touch_mode = false
if #screen.getKeyboards() == 0 then
    touch_mode = true
end

local ver_text = "V"..script_version

local no_glyph_upgrade = false

local start_dial = false
local dialing_active = false
local dial_step = 0
local restart_dialing = false

local renderThread
local eventThread
local sgThread

local function errorx(err)
    renderThread:kill()
    sgThread:kill()
    eventThread:kill()

    computer.beep(200,3)

    gpu.setActiveBuffer(0)
    gpu.setResolution(gpu.maxResolution())
    gpu.freeBuffer(drawBuffer)
    term.clear()
    term.setCursor(1,1)

    print(err)
    error(err)
end

local stat, err = pcall(function()
    eventThread = thread.create(function()
        local stat_t, err_t = pcall(function()
            while true do
                local ev = {event.pull()}
                if ev[1] == "stargate_failed" then
                    softError("SG FAIL: "..ev[4])
                    dialing_active = false
                    dial_step = 0
                elseif ev[1] == "touch" then
                    if touch_mode then
                        if not (dialing_active or start_dial) then
                            start_dial = true
                            event.push("jjs_dialing_update")
                        end
                    end
                elseif ev[1] == "key_down" then
                    if ev[4] == kb.keys.enter then
                        if not touch_mode and not (dialing_active or start_dial) then
                            start_dial = true
                            event.push("jjs_dialing_update")
                        end
                    end
                elseif ev[1] == "received_code" then
                    feedback("Opening iris (GDO Code)")
                    local sg = comp.proxy(ev[2])
                    if ev[4] == iris_code then
                        sg.sendMessageToIncoming("Code accepted, opening iris..")
                        setIris(false, false, sg)
                        sg.sendMessageToIncoming("§aIris open!")
                    else
                        sg.sendMessageToIncoming("§cInvalid code!")
                    end
                elseif ev[1] == "stargate_wormhole_closed_fully" then
                    feedback("Closing iris (Wormhole closed)")
                    local sg = comp.proxy(ev[2])
                    setIris(true, true, sg)
                elseif ev[1] == "interrupted" then
                    renderThread:kill()
                    sgThread:kill()
                    eventThread:kill()

                    gpu.setActiveBuffer(0)
                    gpu.setResolution(gpu.maxResolution())
                    gpu.freeBuffer(drawBuffer)
                    term.clear()
                    term.setCursor(1,1)
                    return
                elseif ev[1] == "gpu_bound" then
                    DEBUG("GPU BOUND: "..ev[3])
                    computer.beep(900,0.1)
                    renderThread:suspend()
                    
                    screen = comp.proxy(ev[3])
                    
                    gpu.setResolution(width, height)
                    event.pull(0.25, "screen_resized")
                    DEBUG(term.getViewport())

                    renderThread:resume()
                end
            end
        end)
        if not stat_t then errorx(err_t) end
    end)
    sgThread = thread.create(function()
        local stat_t, err_t = pcall(function()
            while true do
                if not dialing_active and not restart_dialing then
                    event.pull("jjs_dialing_update")
                end
                if start_dial and sg and #raw_address > 0 and #full_address > 0 then
                    start_dial = false
                    dialing_active = true
                    dial_step = 1

                    if #decodeDialed(sg.dialedAddress or "") > 0 then
                        feedback("Clearing gate")
                        if sg.getGateStatus() == "open" then
                            sg.disengageGate()
                        end
                        sg.abortDialing()
                        os.sleep(3.5)
                    end
                end

                local curr_symbol = full_address[dial_step]
                if curr_symbol then
                    feedback("Engaging '"..curr_symbol.."'")
                    if no_glyph_upgrade then
                        if dial_step < 7 then
                            engageSymbol(curr_symbol)
                        else
                            engageSymbol(curr_symbol, true)
                        end
                    else
                        local fb = engageSymbol(curr_symbol)
                        if fb == "dhd_failure_busy" and dial_step <= #full_address then
                            no_glyph_upgrade = true
                            dialing_active = false
                            dial_step = 0
                            restart_dialing = true
                            start_dial = true
                            softError("No glyph crystal, engaging hybrid mode!")
                        end
                    end
                    dial_step = dial_step+1
                elseif dial_step == #raw_address+1 then
                    if symbol_type == 0 then
                        engageSymbol("Point of Origin", no_glyph_upgrade)
                    elseif symbol_type == 1 then
                        engageSymbol("Subido")
                    elseif symbol_type == 2 then
                        engageSymbol("Glyph 17")
                    end
                    dial_step = dial_step+1
                elseif dial_step == #raw_address+2 then
                    feedback("Opening iris (If there is one)")
                    setIris(false)
                    dial_step = dial_step+1
                elseif dial_step == #raw_address+3 then
                    feedback("Engaging gate")
                    os.sleep(1.5)
                    sg.engageGate()
                    sg.sendIrisCode(iris_code)
                    dial_step = dial_step+1
                elseif dial_step == #raw_address+4 then
                    feedback("Waiting for gate to open fully")
                    if sg.getGateStatus() == "open" or sg.getGateStatus() == "unstable" then
                        event.pull(5, "stargate_wormhole_stabilized")
                    end
                    dial_step = dial_step+1
                elseif dial_step == #raw_address+5 then
                    feedback("Waiting for gate to close")
                    if sg.getGateStatus() == "open" or sg.getGateStatus() == "unstable" then
                        event.pull(nil, "stargate_wormhole_closed_fully")
                        setIris(true, true)
                    end
                    dial_step = dial_step+1
                elseif dial_step == #raw_address+6 then
                    feedback("Ready")
                    dialing_active = false
                    dial_step = 0
                    restart_dialing = false
                end
                os.sleep()
            end
        end)
        if not stat_t then errorx(err_t) end
    end)
    renderThread = thread.create(function()
        local stat_t, err_t = pcall(function()
            while true do
                gpu.setActiveBuffer(drawBuffer)
                DEBUG(term.getViewport())
                fill(1,1,width,height, color.bg1)
                fill(1,1,width,4,color.topbar)

                if last_error.timeout > 0 then
                    last_error.timeout = last_error.timeout - 1
                    fill(1,height-2,width,height,color.bgerror)
                    local lw = write(2,height-1, string.format("%.0fs ago", math.floor((timeTick()-last_error.time)/20)), color.texterror2, color.bgerror)
                    lw = write(lw+1,height-1, ">", color.texterror, color.bgerror)
                    write(lw+1,height-1, last_error.msg, color.texterror, color.bgerror)
                else
                    fill(1,height-2,width,height,color.bgfeedback)
                    if last_feedback.msg then
                        local lw = write(2,height-1, string.format("%.0fs ago", math.floor((timeTick()-last_feedback.time)/20)), color.textfeedback, color.bgfeedback)
                        lw = write(lw+1,height-1, ">", color.textfeedback2, color.bgfeedback)
                        write(lw+1,height-1, last_feedback.msg, color.textfeedback2, color.bgfeedback)
                    else
                        write(2,height-1, "No Feedback", color.textfeedback2, color.bgfeedback)
                    end
                end

                write(2,2, "Automatic Note Dialer",color.text1, color.topbar)
                write(width-(#ver_text)-1,2, " V"..script_version, color.textbright, color.topbar)
                local lw = write(2,3, "Available Gates: ", color.text2, color.topbar)
                write(lw,3, tostring(sg_count), color.textbright, color.topbar)
                local stack = inv.getStackInSlot(sides.top, 1)
                if stack then
                    local lw = write(2,6, "Inserted Item: ", color.text2, color.bg1, true)
                    write(lw,6, stack.name:match(".+:(.+)"), color.textbright, color.bg1)

                    if stack.tag then
                        local out = {}
                        def.gunzip({input = stack.tag,
                                output = function(byte)out[#out+1]=string.char(byte)end,disable_crc=true})
                        local data = table.concat(out)
                        local data2 = nbt.decode(data, "plain")

                        if stack.name == "jsg:notebook" then
                            local selected_num = data2.selected
                            selected_address = data2.addressList[selected_num+1][2]
                            if data2.addressList[selected_num+1].display then
                                address_display = data2.addressList[selected_num+1].display.Name
                            else
                                address_display = nil
                            end
                            symbol_type = selected_address.symbolType
                        elseif stack.name == "jsg:universe_dialer" and data2.mode == 1 then
                            local selected_num = data2.selected
                            selected_address = data2.saved[selected_num+1]
                            address_display = selected_address.name
                            symbol_type = selected_address.symbolType
                        elseif stack.name == "jsg:page_notebook" then
                            selected_address = data2.address
                            symbol_type = selected_address.symbolType
                            if data2.display then
                                address_display = data2.display.Name
                            else
                                address_display = nil
                            end
                        else
                            selected_address = nil
                            symbol_type = nil
                            write(2,7, "Invalid Item", color.texterror, color.bg1)
                        end

                        if symbol_type and selected_address then
                            local lw = write(4,8, "Symbol Type: ", color.text2, color.bg1)
                            write(lw,8, (symbolTypeNames[symbol_type] or "UNKNOWN"), color.textbright, color.bg1)

                            raw_address = {}
                            full_address = {}
                            local i1 = 0
                            repeat
                                local new_symbol = selected_address["symbol"..i1]
                                if new_symbol then raw_address[#raw_address+1] = new_symbol end
                                i1 = i1+1
                            until not new_symbol

                            for k,v in ipairs(raw_address) do
                                full_address[#full_address+1] = symbolIndex[symbol_type][v]
                            end

                            local lw = write(4,9, "Symbol Count: ", color.text2, color.bg1)
                            write(lw,9, #raw_address, color.textbright, color.bg1)

                            local lw = write(4,10, "Address: ", color.text2, color.bg1)
                            if address_display and #address_display > 0 then
                                write(lw,10, "("..address_display..")", color.textbright, color.bg1)
                            else
                                write(lw,10, "(No Name)", color.texterror2, color.bg1)
                            end
                            local longest = 0
                            for k,symbol in ipairs(full_address) do
                                if #symbol > longest then
                                    longest = #symbol
                                end
                                write(6,10+k, symbol, color.textbright, color.bg1)
                            end
                            for k,symbol in ipairs(raw_address) do
                                write(6+1+longest,10+k, symbol, color.text2, color.bg1)
                            end

                            sg = sg_map[symbolTypeToGate[symbol_type] or "UNKNOWN"]
                            if sg then
                                write(2,10+#raw_address+2, "Stargate available, ready to dial", color.textvalid, color.bg1)
                                if touch_mode then
                                    write(2,10+#raw_address+3, "Click the screen to start", color.textvalid, color.bg1)
                                else
                                    write(2,10+#raw_address+3, "Press 'Enter' to start", color.textvalid, color.bg1)
                                end
                            else
                                write(2,10+#raw_address+2, "No stargates of type '"..(symbolTypeNames[symbol_type] or "UNKNOWN").."' available!", color.texterror, color.bg1)
                            end
                        end
                    else
                        selected_address = nil
                        symbol_type = nil
                        write(2,7, "Invalid Item", color.texterror, color.bg1)
                    end
                else
                    local lw = write(2,6, "Inserted Item: ", color.text2, color.bg1, true)
                    write(lw,6, "NONE", color.textbright, color.bg1)
                end
                gpu.bitblt(0, 1,1, width, height, drawBuffer, 1, 1)
                gpu.setActiveBuffer(0)
                os.sleep(0.5)
            end
        end)
        if not stat_t then errorx(err_t) end
    end)
    thread.waitForAll({eventThread, renderThread, sgThread})
end)

pcall(function()
    eventThread:kill()
    renderThread:kill()
    sgThread:kill()
end)

--gpu.setActiveBuffer(0)
--gpu.freeBuffer(drawBuffer)
--term.clear()
--term.setCursor(1,1)

if not stat then error(err) end