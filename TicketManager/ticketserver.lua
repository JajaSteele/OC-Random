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

local function tprint(t1) 
    oldX,oldY = t.getCursor()
    print(t1)
    newX,newY = t.getCursor()
    t.setCursor(oldX,newY)
end

local function moveCursor(x1,y1)
    oldX,oldY = t.getCursor()
    t.setCursor(oldX+x1,oldY+y1)
end

if io.open("/lib/json.lua","r") == nil then
    print("JSON Lib not found")
    shell.execute("wget https://github.com/rxi/json.lua/raw/master/json.lua /lib/json.lua")
    json = require("json")
else
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
    fileIN:close()
    tprint("New ticket opened by "..ply)
    tprint("Last 4 digits: "..string.sub(id,string.len(id)-3,string.len(id)))
end

function closeTicket(id,ply)
    fileOUT = io.open("/home/data/tickets.txt","r")
    table1 = srz.unserialize(fileOUT:read("*a"))
    fileOUT:close()
    table1[tostring(id)] = nil
    fileIN = io.open("/home/data/tickets.txt","w")
    fileIN:write(srz.serialize(table1))
    fileIN:close()
    tprint("Ticket Closed by "..ply)
    tprint("Last 4 digits: "..string.sub(id,string.len(id)-3,string.len(id)))
end

function checkTicket(id,ply,timestamp)
    fileOUT = io.open("/home/data/tickets.txt","r")
    table1 = srz.unserialize(fileOUT:read("*a"))
    fileOUT:close()

    table1 = table1[tostring(id)]

    if table1 == nil then
        tprint("Warning! Ticket is not found in database, potential pirate detected! Signature: "..ply)
        ct.beep(1300,0.1)
        ct.beep(1300,0.1)
        ct.beep(1300,0.1)
        ct.beep(1300,0.1)
        ct.beep(1300,0.1)
        tprint("DENY | CODE 4")
        return false, "v4"
    end
    
    if ply == table1["player"] then
        v1 = true
    else
        v1 = false
    end
    tprint("Signature Check: "..tostring(v1))
    if not v1 then print("Value: \""..ply.."\" Expected: \""..table1["player"].."\"") end
    if timestamp == table1["timestamp"] then
        v2 = true
    else
        v2 = false
    end
    tprint("Timestamp Check: "..tostring(v2))
    if not v2 then print("Value: \""..timestamp.."\" Expected: \""..table1["timestamp"].."\"") end

    if v1 and v2 then
        return true
    else
        if v1 then
            tprint("DENY | CODE 2")
            return false, "v2"
        end
        if v2 then
            tprint("DENY | CODE 1")
            return false, "v1"
        end
        if not v1 and not v2 then
            tprint("DENY | CODE 3 (1 & 2)")
            return false, "v3"
        end
    end
    tprint("...")
end 

while true do
    local _, _, from, port, _, message = event.pull("modem_message")
    data = srz.unserialize(message)
    action = data["type"]
    ct.beep(1400,0.1)
    ct.beep(1400,0.1)
    tprint("--- Request Received, Type: "..action.." ---")
    moveCursor(6,0)
    if action == "close" then
        closeTicket(data["id"],data["ply"])
    end
    if action == "open" then
        openTicket(data["id"],data["ply"],data["timestamp"])
    end
    if action == "use" then
        result1, result2 = checkTicket(data["id"],data["ply"],data["timestamp"])
        if result1 then
            modem.broadcast(2707,srz.serialize({"ALLOW"}))
            closeTicket(data["id"],data["ply"])
        else
            modem.broadcast(2707,srz.serialize({"DENY",result2}))
        end
    end 
    moveCursor(-6,0)
    print("--- Request Successfully Executed ---\n\n")
end