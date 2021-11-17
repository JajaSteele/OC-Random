local event = require("event")
local cp = require("component")
local t = require("term")
local screen = cp.screen
local g = cp.gpu
local fs = cp.filesystem
local fs2 = require("filesystem")
local srz = require("serialization")
local keyboard = cp.keyboard
local ct = require("computer")
local shell = require("shell")
local internet = require("internet")
local modem = cp.modem
local sides = require("sides")

local args = shell.parse(...)

modem.open(2707)

if io.open("/lib/json.lua","r") == nil then
    print("JSON Lib not found")
    shell.execute("wget https://github.com/rxi/json.lua/raw/master/json.lua /lib/json.lua")
    json = require("json")
else
    print("JSON Lib Detected, loading")
    json = require("json")
end

local function getTime(t1)
    local testURL = "https://www.timeapi.io/api/Time/current/zone?timeZone=Europe/Amsterdam"
    local testHeader = {
        ["Content-Type"] = "application/json"
    }
    local url1 = internet.request(testURL,{},testHeader,"GET")

    local result = ""
    for chunk in url1 do result = result..chunk end
    local funcClose = getmetatable(url1.close)["__call"]
    funcClose()
    if t1 == nil then
        return json.decode(result)
    else
        return json.decode(result)[t1]
    end
end

if io.open("/home/data/tickets.txt","r") == nil then
    fs2.makeDirectory("/home/data")
    file1 = io.open("/home/data/tickets.txt","w")
    print(file1)
    file1:write("{}")
    file1:close()
end

function openTicket(id,ply,timestamp)
    fulltime = getTime()
    ftime = timestamp
    fileOUT = io.open("/home/data/tickets.txt","r")
    table1 = srz.unserialize(fileOUT:read("*a"))
    fileOUT:close()
    table1[tostring(id)] = {timestamp=ftime,player=ply}
    fileIN = io.open("/home/data/tickets.txt","w")
    fileIN:write(srz.serialize(table1))
    print(srz.serialize(table1,true))
    fileIN:close()
end

function closeTicket(id)
    fileOUT = io.open("/home/data/tickets.txt","r")
    table1 = srz.unserialize(fileOUT:read("*a"))
    fileOUT:close()
    table1[tostring(id)] = nil
    fileIN = io.open("/home/data/tickets.txt","w")
    fileIN:write(srz.serialize(table1))
    print(srz.serialize(table1,true))
    fileIN:close()
end

function checkTicket(id,ply,timestamp)
    print(id)
    fileOUT = io.open("/home/data/tickets.txt","r")
    table1 = srz.unserialize(fileOUT:read("*a"))
    fileOUT:close()

    table1 = table1[tostring(id)]
    
    if ply == table1["player"] then
        v1 = true
    else
        v1 = false
    end
    print("Player Check: "..tostring(v1))
    if not v1 then print(ply, table1["player"]) end
    if timestamp == table1["timestamp"] then
        v2 = true
    else
        v2 = false
    end
    print("Time Check: "..tostring(v2))
    if not v2 then print(timestamp, table1["timestamp"]) end

    if v1 and v2 then
        return true
    else
        if v1 then
            return false, "v2"
        else
            return false, "v1"
        end
    end
end 

while true do
    local _, _, from, port, _, message = event.pull("modem_message")
    data = srz.unserialize(message)
    print("Request Received: ")
    action = data["type"]
    print(action)
    if action == "close" then
        closeTicket(data["id"])
    end
    if action == "open" then
        openTicket(data["id"],data["ply"],data["timestamp"])
    end
    if action == "use" then
        result1, result2 = checkTicket(data["id"],data["ply"],data["timestamp"])
        if result1 then
            modem.broadcast(2707,srz.serialize({"ALLOW"}))
        else
            modem.broadcast(2707,srz.serialize({"DENY",result2}))
        end
    end 
end