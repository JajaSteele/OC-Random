local component = require("component")
local keypads = component.list("os_keypad")
local event = require("event")
local fs = require("filesystem")
local computer = require("computer")
local srz = require("serialization")
local t = require("term")
local rs = component.redstone
local sides = require("sides")
local colors = require("colors")

local config

local function clear()
    t.clear()
    t.setCursor(1,1)
end


local function mk(method,arg1,arg2,arg3,arg4,arg5,arg6)
    for k,v in pairs(keypads) do
        component.proxy(k)[method](arg1,arg2,arg3,arg4,arg5,arg6)
    end
end

if fs.exists("/home/config/keypad.txt") then
    file1 = io.open("/home/config/keypad.txt","r")
    config = srz.unserialize(file1:read("*a"))
    file1:close()
else
    print("No Config! Starting configuration util..")
    fs.makeDirectory("/home/config")
    file2 = io.open("/home/config/keypad.txt","w")
    local newConfig = {}
    print("Enter new code:")
    newConfig["code"] = io.read()
    clear()

    print("Redstone Side:")
    newConfig["side"] = io.read()
    clear()

    print("Redstone Time: (seconds)")
    newConfig["delay"] = tonumber(io.read())
    clear()
    
    print("Enable Launch-On-Startup? y/n")
    if io.read() == "y" then
        file3 = io.open("/home/.shrc","w")
        file3:write("/home/keypad.lua")
        file3:close()
    end
    
    config = newConfig
    file2:write(srz.serialize(newConfig))
    file2:close()
end

    

mk("setKey",{
    "1","2","3",
    "4","5","6",
    "7","8","9",
    "X","0","V",
})
enteredCode = ""
while true do
    mk("setDisplay",string.rep("*",enteredCode:len()),0xF)
    _, _, _, key = event.pull("keypad")
    if key:gsub("%D","") ~= "" then
        enteredCode = enteredCode..key
    elseif key == "X" then
        enteredCode = enteredCode:sub(1,enteredCode:len()-1)
    elseif key == "V" then
        if enteredCode == config["code"] then
            mk("setDisplay","GRANTED",0xA)
            computer.beep(500,0.25)
            rs.setBundledOutput(sides[config["side"]],colors.lime,255)
            os.sleep(config["delay"])
            rs.setBundledOutput(sides[config["side"]],colors.lime,0)
        else
            mk("setDisplay","DENIED",0xC)
            computer.beep(375,0.25)
            rs.setBundledOutput(sides[config["side"]],colors.red,255)
            os.sleep(config["delay"])
            rs.setBundledOutput(sides[config["side"]],colors.red,0)
        end
        enteredCode = ""
    end
end