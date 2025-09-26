local component = require("component")
local term = require("term")

local internet = component.internet
local tape = component.tape_drive

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
print("(will double file size, requires x2 playback speed)")
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
print("Tape Size: "..tape_size)
print("File Size: "..size)

if tape_size < size then
    print("WARNING! Tape size is smaller than file size! Song will be cut randomly")
end

tape.seek(-tape_size)

print("Starting download..")
local dl_x, dl_y = term.getCursor()
local w,h = term.gpu().getResolution()
local count = 0
while true do
    local chunk, reason = req.read(size)
    if not chunk then
        if reason then
            print("ERROR! "..reason)
        else
            print("Download finished!")
        end
        break
    elseif count >= tape_size then
        print("WARNING! Reached end of tape!")
        break
    elseif #chunk > 0 then
        count = count+#chunk
        tape.write(chunk)
        local perc = (count/size)
        term.setCursor(1, dl_y)
        term.clearLine()
        term.write(string.format("Progress: %.1f%%", perc*100))
        term.setCursor(1, dl_y+1)
        term.clearLine()
        term.write("["..string.rep("█", math.floor((w-2)*(perc))))
        local decimal = (w-2)*(perc) - math.floor((w-2)*(perc))
        term.write(getDlFooter(decimal))
        term.setCursor(w, dl_y+1)
        term.write("]")
        --print(string.format("%.1f%%", (count/size)*100))
    else
        os.sleep()
    end
end

tape.seek(-tape_size)