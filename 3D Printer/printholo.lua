local fs = require("filesystem")
local comp = require("component")
local inv = comp.inventory_controller
local holo = comp.hologram

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

holo.clear()
holo.setTranslation(1/3, 0.75, 0)

local shapeOff = data2.stateOff

holo.setPaletteColor(1, 0xFF8888)
holo.setPaletteColor(2, 0x88FF88)
holo.setPaletteColor(3, 0x8888FF)
local color = 1

for k, shapedata in pairs(shapeOff) do
    local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.bounds)
    for x=x1+1, x2 do
        for y=y1+1, y2 do
            for z=z1+1, z2 do
                holo.set(x+16,y,z+16,color)
            end
        end
    end
    color = ((color+1)%3)+1
    print(color)
end
local shapeOn = data2.stateOn

for k, shapedata in pairs(shapeOn) do
    local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.bounds)
    for x=x1+1, x2 do
        for y=y1+1, y2 do
            for z=z1+1, z2 do
                holo.set(x+16,y,z+16,color)
            end
        end
    end
    color = ((color+1)%3)+1
    print(color)
end