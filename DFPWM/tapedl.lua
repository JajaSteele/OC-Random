local component = require("component")

local internet = component.internet
local tape = component.tape_drive

print("Enter youtube ID:")
local id = io.read()

local tape_size = tape.getSize()

local req = internet.request("http://jajasteele.mooo.com:7277/?vidid="..id.."&hq=true")
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

local count = 0
while true do
    local chunk, reason = req.read(size)
    if not chunk then
        break
    elseif count >= tape_size then
        print("WARNING! Reached end of tape!")
        break
    elseif #chunk > 0 then
        count = count+#chunk
        tape.write(chunk)
        print(string.format("%.1f%%", (count/size)*100))
    else
        
    end
end

tape.seek(-tape_size)