local component = require("component")
local term = require("term")

local internet = component.internet
local tape = component.tape_drive
local gpu = component.gpu

local function clamp(x,min,max) if x > max then return max elseif x < min then return min else return x end end

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

term.clear()

print("Enter Youtube ID:")
local id = io.read()

print("High Quality Mode? (y/n):")
local hq = io.read()
if hq == "true" or hq == "y" or hq == "1" or hq == "" then
    hq = true
else
    hq = false
end

local tape_size = tape.getSize()

local req = internet.request("http://jajasteele.mooo.com:7277/?vidid="..id.."&hq="..tostring(hq))
print("Requesting DFPWM..")
repeat
    os.sleep(0.5)
until req.finishConnect()
print("Response received")
local rcode, rmsg, rhead = req.response()
local size = tonumber(rhead["Content-Length"][1])
print(rcode, rmsg)

tape.seek(-tape.getSize())
tape.write(string.rep(string.char(0), tape.getSize()))
tape.seek(-tape.getSize())


local chunk_size = 6000*10
if hq then
    chunk_size = chunk_size*2
end

tape.seek(chunk_size)
local start_pos = tape.getPosition()

tape.play()

term.clear()
local quit = false

local w,h = term.gpu().getResolution()

local count = 0
local stat, err = pcall(function ()
    while true do
        local next_data = ""
        local next_size = math.min(size-count, chunk_size)
        repeat
            local chunk, reason = req.read(next_size-#next_data)
            if not chunk then
                print("No more chunks! Waiting for end of song..")
                return
            else
                if #chunk > 0 then
                    next_data = next_data..chunk
                    write(1,1, "Gathered: "..bytesToString(#next_data).."/"..bytesToString(next_size), 0xFFFFFF, 0x000000, true)
                end
            end
        until #next_data == chunk_size
        count = count+next_size

        write(1, 6, "("..secondsToDuration((count/6000)/((hq and 2) or 1)).."/"..secondsToDuration((size/6000)/((hq and 2) or 1))..")")
        
        write(1,2, "Waiting for timing", 0xFFFFFF, 0x000000, true)
        local sleepcount = 0
        while true do
            local pos = tape.getPosition()
            sleepcount = sleepcount + 1
            if sleepcount > 5 then
                os.sleep()
                sleepcount = 0
            end
            if pos >= start_pos + chunk_size then
                tape.seek(start_pos-tape.getPosition())
                tape.write(next_data)
                tape.seek(start_pos-tape.getPosition())
                write(1,2, "Writing "..bytesToString(chunk_size).." of data at pos "..pos, 0xFFFFFF, 0x000000, true)
                break
            end
        end
    end
end)

while true do
    local pos = tape.getPosition()
    os.sleep()
    if pos >= start_pos+chunk_size then
        tape.stop()
        component.computer.beep(600, 0.2)
        break
    end
end