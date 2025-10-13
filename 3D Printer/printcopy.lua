local fs = require("filesystem")
local comp = require("component")
local inv = comp.inventory_controller
local printer = comp.printer3d

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

local stack = inv.getStackInSlot(1,1)

local out = {}

def.gunzip({input = stack.tag,
        output = function(byte)out[#out+1]=string.char(byte)end,disable_crc=true})
local data = table.concat(out)
local data2 = nbt.decode(data, "plain")

printer.reset()

local shapeOff = data2.stateOff

for k, shapedata in pairs(shapeOff) do
    local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.bounds)
    printer.addShape(x1,y1,16-z1,x2,y2,16-z2,shapedata.texture,false) 
end
local shapeOn = data2.stateOn

for k, shapedata in pairs(shapeOn) do
    local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.bounds)
    printer.addShape(x1,y1,16-z1,x2,y2,16-z2,shapedata.texture,true) 
end

printer.setLightLevel(data2.lightLevel)
printer.setRedstoneEmitter(data2.redstoneLevel)
printer.setCollidable((data2.noclipOff == 0), (data2.noclipOn == 0))
printer.setButtonMode((data2.isButtonMode == 1))

print("Copied "..#shapeOff + #shapeOn.." shapes")
print("States:")

print("  Light Level: "..data2.lightLevel)
if data2.lightLevel > 8 then
    print("    (Can't go higher than 8, craft with glowstone to reach 15)")
end
print("  Redstone Level: "..data2.redstoneLevel)
print("  Collidable: ")
print("    On: "..(1-data2.noclipOn))
print("    Off: "..(1-data2.noclipOff))
print("  Button Mode: "..data2.isButtonMode)

print("Print Count?")
local count = tonumber(io.read())

if count then
    print("Printing "..count.." objects")
    printer.commit(count)
end