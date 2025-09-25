local component = require("component")
local ser = require("serialization")
local def = require("deflate")
local nbt = require("nbt")
local sides = require("sides")

local inv = component.inventory_controller

local stack = inv.getStackInSlot(sides.top, 1)
local tag = stack.tag

local out = {}
def.gunzip({input = tag,
        output = function(byte)out[#out+1]=string.char(byte)end,disable_crc=true})

local data = table.concat(out)
local data2 = nbt.decode(data, "plain")
print(ser.serialize(data2))