local event = require("event")
local thread = require("thread")
local cp = require("component")
local t = require("term")
local screen = cp.screen
local g = cp.gpu
local fs = cp.filesystem
local fs2 = require("filesystem")
local srz = require("serialization")
local tp = cp.transposer
local keyboard = cp.keyboard
local ct = require("computer")
local sides = require("sides")

if true then --Debug Mode
    cb = cp.chat_box
    dbs = true
    cb.say("Debug Mode Enabled!")
else
    dbs = false
end

local function dbc(t1)
    if dbs then
        cb.say(t1)
    end
end

local function sc(t1,t2)
    if t1 == "f" then
        g.setForeground(t2)
    elseif t1 == "b" then
        g.setBackground(t2)
    end
end

local eg_pricelist = {
    minecraft___stone=5
}

while true do
    if io.open("/home/data/pricelist.txt","r") ~= nil then
        pl_file1 = io.open("/home/data/pricelist.txt","r")
        pricelist = srz.unserialize(pl_file1:read("*a"))
        print("readed pricelist: ")
        print(pricelist)
        pl_file1:close()
    else
        print("pricelist file not found")
        if not fs2.isDirectory("/home/data") then
            print("data folder not found")
            fs2.makeDirectory("/home/data")
            print("created data folder")
        end
        pl_file1 = io.open("/home/data/pricelist.txt","w")
        pl_file1:write(srz.serialize(eg_pricelist))
        print("created example pricelist")
        pl_file1:close()

        pl_file2 = io.open("/home/data/pricelist.txt","r")
        pricelist = srz.unserialize(pl_file2:read("*a"))
        print("readed pricelist")
        pl_file2:close()
    end
    os.sleep(1)
    t.clear()
    t.setCursor(1,1)
    print("---Loading Finished---")
    print("Current List:\n")
    for k, v in pairs(pricelist) do
        sc("f",0xFFFFFF) t.write("Name: ") sc("f",0xAAAAAA) t.write(string.gsub(k,"___",":")) sc("f",0xFFFFFF) t.write(" Price: ") sc("f",0xAAAAAA) t.write(v) t.write("\n") sc("f",0xFFFFFF)
    end
    print("\n(A) Add/Edit | (D) Delete | (C) Cancel/Close")

    res1 = string.lower(io.read())

    if res1 == "a" then
        print("Name(id): ")
        res2 = string.gsub(string.lower(io.read()),":","___")
        print("Price: ")
        res3 = tonumber(io.read())

        pl_file3 = io.open("/home/data/pricelist.txt","r")
        pricelist = srz.unserialize(pl_file3:read("*a"))
        pl_file3:close()

        pricelist[res2] = res3

        pl_file4 = io.open("/home/data/pricelist.txt","w")
        pl_file4:write(srz.serialize(pricelist))
        pl_file4:close()
    end
    if res1 == "d" then
        print("Name(id): ")
        res2 = string.gsub(string.lower(io.read()),":","___")

        pl_file3 = io.open("/home/data/pricelist.txt","r")
        pricelist = srz.unserialize(pl_file3:read("*a"))
        pl_file3:close()

        pricelist[res2] = nil

        pl_file4 = io.open("/home/data/pricelist.txt","w")
        pl_file4:write(srz.serialize(pricelist))
        pl_file4:close()
    end
    if res1 == "c" then
        ct.beep(300,0.2)
        os.sleep(1)
        t.clear()
        break
    end
end