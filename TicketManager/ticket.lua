local event = require("event")
local cp = require("component")
local t = require("term")
local screen = cp.screen
local g = cp.gpu
local fs = cp.filesystem
local fs2 = require("filesystem")
local srz = require("serialization")
local pr = cp.openprinter
local keyboard = cp.keyboard
local ct = require("computer")
local shell = require("shell")
local internet = require("internet")
local sides = require("sides")
local tr = cp.transposer

local modem = cp.modem

local args = shell.parse(...)

ogX,ogY = g.getResolution()

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

if io.open("/home/data/ticketside.txt","r") == nil then
    if args[1] ~= "setside" then
        print("Warning, no sides configured, use \"ticket.lua setside <input side (hopper or chest)> <shredder side> <printer side> <output side (chest/hopper)>\" to configure")
    end
    fs2.makeDirectory("/home/data")
else
    file1 = io.open("/home/data/ticketside.txt","r")
    sideC = srz.unserialize(file1:read("*a"))

    in1 = sides[sideC["input"]]
    shred1 = sides[sideC["shredder"]]
    print1 = sides[sideC["printer"]]
    out1 = sides[sideC["output"]]

    file1:close()
end

if args[1] == "setside" then
    if args[2] and args[3] and args[4] then
        file1 = io.open("/home/data/ticketside.txt","w")
        in1 = args[2]
        shred1 = args[3]
        print1 = args[4]
        out1 = args[5]

        data1 = srz.serialize({
            input= in1,
            shredder = shred1,
            printer = print1,
            output = out1
        })

        file1:write(data1)
        file1:close()
    else
        print("Syntax: \nticket.lua setside <input side (hopper or chest)> <shredder side> <printer side> <output side (chest/hopper)>")
    end
end

if args[1] == "new" then
    print("Hello, Please Click the screen once!")

    _, _, _, _, _, name1 = event.pull("touch")

    ID = string.format("%.0f", os.time())..string.format("%.0f", os.clock()*100)

    pr.writeln("Ticket Owner: "..name1)
    pr.writeln("Ticket ID: "..ID)
    pr.writeln("")
    pr.writeln("Single-Use",0xDD0000)
    pr.writeln("")

    fulltime = getTime()
    ftime = fulltime["hour"].."h"..fulltime["minute"].." ("..fulltime["seconds"].."s)"

    pr.writeln("Print Timestamp: "..ftime)

    ct.beep(800,0.1)
    ct.beep(900,0.1)
    os.sleep(0.1)
    ct.beep(1300,0.2)

    pr.print()

    data1 = srz.serialize({type="open",ply=name1,id=tonumber(ID),timestamp=ftime})

    modem.broadcast(2707,data1)
end

if args[1] == "copy" then
    print("Hello, Please Click the screen once!")

    _, _, _, _, _, name1 = event.pull("touch")

    line1 = pr.scanLine(0)
    line2 = pr.scanLine(1)
    line5 = pr.scanLine(5)

    line1c = string.len(line1)
    line2c = string.len(line2)
    line5c = string.len(line5)


    name = string.sub(pr.scanLine(0),15,line1c-11)
    id = string.sub(pr.scanLine(1),12,line2c-11)
    timestamp = string.sub(pr.scanLine(5),18,line5c-11)

    print(name,id)


    pr.writeln("Ticket Owner: "..name)
    pr.writeln("Ticket ID: "..id)
    pr.writeln("")
    pr.writeln("Single-Use (COPY FOR ARCHIVE)",0xDD0000)
    pr.writeln("")
    pr.writeln("Print Timestamp: "..timestamp.."(OG)")
    fulltime = getTime()
    ftime = fulltime["hour"].."h"..fulltime["minute"].." ("..fulltime["seconds"].."s)"
    pr.writeln("Copy Timestamp: "..ftime)


    ct.beep(800,0.1)
    ct.beep(900,0.1)
    os.sleep(0.1)
    ct.beep(1300,0.2)

    pr.print()
end

if args[1] == "use" then

    if tr.getStackInSlot(in1,1) then
        if tr.getStackInSlot(in1,1)["name"] == "openprinter:printed_page" and tr.getStackInSlot(print1,1) == nil then
            tr.transferItem(in1,print1)
        else
            print("Warning, item is not a ticket, emptied into output")
            tr.transferItem(in1,out1)
            return
        end
    else
        print("Warning, input is empty")
        return
    end

    print("Hello, Please Click the screen once!")

    _, _, _, _, _, name1 = event.pull("touch")

    line1 = pr.scanLine(0)
    line2 = pr.scanLine(1)
    line5 = pr.scanLine(5)

    line1c = string.len(line1)
    line2c = string.len(line2)
    line5c = string.len(line5)


    name = string.sub(pr.scanLine(0),15,line1c-11)
    id = string.sub(pr.scanLine(1),12,line2c-11)
    timestamp = string.sub(pr.scanLine(5),18,line5c-11)

    data1 = {
        type="use",
        ply=name1,
        id=tonumber(ID),
        timestamp=ftime
    }

    modem.broadcast(2707,srz.serialize(data1))

    local _, _, from, port, _, message = event.pull("modem_message")
    
    local dataresult = srz.unserialize(message)

    if dataresult[1] == "ALLOW" then
        print("ACCEPTED")
        ct.beep(1000,0.1)
        ct.beep(1150,0.1)
        os.sleep(0.1)
        ct.beep(1400,0.2)
        tr.transferItem(print1,shred1)
    else
        if dataresult[2] == "v1" then error = "You're not Ticket's Owner" end
        if dataresult[2] == "v2" then error = "Wrong Timestamp!" end
        print("REFUSED : "..error)
    end
end
