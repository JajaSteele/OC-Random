local comp = require("component")
local computer = require("computer")

local path = debug.getinfo(2, "S").source:gsub("^=", "")
local small_address = path:match("/mnt/(.-)/.+")

local filesystems = comp.list("filesystem")

print("")
print("Found:")
local disk
for k,v in pairs(filesystems) do
    if k:match(small_address) then
        print(k)
        disk = comp.proxy(k)
    end
end

computer.setBootAddress(disk.address)
computer.shutdown(true)