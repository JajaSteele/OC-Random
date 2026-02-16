local pc = require("computer")
local component = require("component")
local term = require("term")
local event = require("event")
local tunnel = component.tunnel

local boot_address = pc.getBootAddress()

local fs = component.proxy(boot_address)

local home_list = fs.list("/home")

local files = {}
for k,v in pairs(home_list) do
    if not v:match(".+/") then
        files[#files+1] = v
    end
end

table.sort(files)

term.clear()
os.sleep(1)
term.setCursor(1,1)
print("Detected files:")
print("")
for k,v in ipairs(files) do
    print(v)
end
print("")
print("Enter file name:")
local file = io.read()

print("Click anywhere to send update through linked card.")

while true do
    event.pull("touch")
    local file_io = io.open(file, "rb")
    if file_io then
        pc.beep(600, 0.05)
        print("Reading file..")
        local file_data = file_io:read("*a")
        file_io:close()
        print("Done")
        
        print("Sending to eeprom..")
        tunnel.send("start_update", #file_data)
        local pos = 1
        for i1 = 1, #file_data, 2048 do
            local chunk = file_data:sub(i1, i1 + 2048 - 1)
            tunnel.send("update_data", pos, chunk)
            pos = pos + 1
        end

        print("Done")
        pc.beep(1100, 0.025)
        pc.beep(1500, 0.025)
        os.sleep(0.05)
        pc.beep(2000, 0.05)
    else
        print("Couldn't open file '"..file.."'")
        pc.beep(100, 0.5)
    end
end