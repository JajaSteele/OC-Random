local event = require("event")
local cp = require("component")
local t = require("term")
local screen = cp.screen
local g = cp.gpu
local fs = cp.filesystem
local fs2 = require("filesystem")
local srz = require("serialization")
local ct = require("computer")
local shell = require("shell")
local internet = require("internet")
local sides = require("sides")
local data = cp.data
local rs = cp.redstone

local args = shell.parse(...)

if cp.isAvailable("os_rolldoorcontroller") then
    rd = cp.os_rolldoorcontroller
    rd1 = true
else
    rd1 = false
end

local function openrd()
    if rd1 then
        rd.open()
        return true
    else
        return false
    end
end

local function closerd()
    if rd1 then
        rd.close()
        return true
    else
        return false
    end
end

local function writeChar(x1,y1,t1)
    g.fill(x1,y1,1,1,t1)
end

local function writeStr(x1,y1,t1)
    local oldX,oldY = t.getCursor()
    t.setCursor(x1,y1)
    t.write(t1)
    t.setCursor(oldX,oldY)
end

local function clearLine(x1,y1)
    local currX,currY = g.getResolution()
    local oldX,oldY = t.getCursor()
    t.setCursor(x1,y1)
    t.write(string.rep(" ",(currX-oldX)+1))
    t.setCursor(oldX,oldY)
end

local function paintF(x1,y1,x2,y2,c1)
    local currX,currY = g.getResolution()
    local oldX,oldY = t.getCursor()
    oldF = g.getForeground()
    g.setForeground(c1)
    xl = x2 - x1
    yl = y2 - y1
    for i2=1, yl+1 do
        for i1=1, xl+1 do
            i1x = (i1-1) + x1
            i2y = (i2-1) + y1
            char1 = g.get(i1x,i2y)
            g.set(i1x,i2y,char1)
        end
    end
    t.setCursor(oldX,oldY)
    g.setForeground(oldF)
end

local function paintB(x1,y1,x2,y2,c1)
    local currX,currY = g.getResolution()
    local oldX,oldY = t.getCursor()
    oldB = g.getBackground()
    g.setBackground(c1)
    xl = x2 - x1
    yl = y2 - y1
    for i2=1, yl+1 do
        for i1=1, xl+1 do
            i1x = (i1-1) + x1
            i2y = (i2-1) + y1
            char1 = g.get(i1x,i2y)
            g.set(i1x,i2y,char1)
        end
    end
    t.setCursor(oldX,oldY)
    g.setBackground(oldB)
end

local function codeInt(tx1)
    t.clear()

    g.setResolution(7,5)

    writeStr(2,2,"1 2 3")
    writeStr(2,3,"4 5 6")
    writeStr(2,4,"7 8 9")
    writeStr(2,5," 0")
    writeChar(5,5,"v")
    paintF(5,5,5,5,0x44FF44)

    in1 = ""

    writeStr(1,1,tx1)

    while true do
        _,_,X1,Y1,_,ply = event.pull("touch")
        char = g.get(X1,Y1) 
        if tonumber(char) ~= nil then
            in1 = in1..char
            ct.beep(1750,0.1)
        end
        in1L = string.len(in1)
        clearLine(1,1)
        writeStr(1,1,string.rep("*",in1L))
        if in1L == 7 or char == "v" then
            paintB(1,1,7,1,0x555555)
            ct.beep(500,0.2)
            os.sleep(0.2)
            rtn = in1
            in1 = ""
            in1L = string.len(in1)
            clearLine(1,1)
            return rtn
        end
    end
end

local function checkSide1(t1)
    if t1 == "u" then return "up" end
    if t1 == "d" then return "down" end
    if t1 == "l" then return "left" end
    if t1 == "r" then return "right" end
    if t1 == "f" then return "front" end
    if t1 == "b" then return "back" end
end

local function codeChange()
    if io.open("/home/config/keypad.txt","r") ~= nil then 
        file1=io.open("/home/config/keypad.txt","r")
        currcode1 = data.decode64(file1:read("*a"))
        file1:close()
        codein1 = codeInt("OldCode")
        
        if codein1 == currcode1 then
            ct.beep(1000,0.2)
            ct.beep(1200,0.2)
        else

            return
        end
    end
    fs2.makeDirectory("/home/config")
    file1=io.open("/home/config/keypad2.txt","w")

    t.clear()

    g.setResolution(7,5)
    
    writeStr(1,1,"Side")
    writeStr(2,2,"  U")
    writeStr(2,3,"L F R")
    writeStr(2,4,"B D")
    writeStr(2,5,"-----")
    writeChar(6,5,"v")
    paintF(6,5,6,5,0x44FF44)

    in1 = ""

    while true do
        _,_,X1,Y1,_,ply = event.pull("touch")
        char = g.get(X1,Y1) 
        if char ~= " " then
            sideT = {u="up",d="down",l="left",r="right",f="front",b="back"}
            char = string.lower(char)
            paintB(1,1,7,1,0x555555)
            ct.beep(500,0.2)
            os.sleep(0.2)
            clearLine(1,1)

            side1 = checkSide1(char)

            delayout = tonumber(codeInt("Timer"))

            data2 = {}

            data2["side"] = side1
            data2["timer"] = delayout

            file1:write(srz.serialize(data2))
            file1:close()
            break
        end
    end

    t.clear()

    g.setResolution(7,5)

    writeStr(1,1,"NewCode")
    writeStr(2,2,"1 2 3")
    writeStr(2,3,"4 5 6")
    writeStr(2,4,"7 8 9")
    writeStr(2,5," 0")
    writeChar(5,5,"v")
    paintF(5,5,5,5,0x44FF44)

    in1 = ""

    while true do
        _,_,X1,Y1,_,ply = event.pull("touch")
        char = g.get(X1,Y1) 
        if tonumber(char) ~= nil then
            in1 = in1..char
            ct.beep(1750,0.1)
        end
        in1L = string.len(in1)
        clearLine(1,1)
        writeStr(1,1,string.rep("*",in1L))
        if char == "v" or in1L == 7 then
            paintB(1,1,7,1,0x44FFFF)
            ct.beep(150,0.2)
            clearLine(1,1)
            writeStr(1,1,"Saved")
            ct.beep(50,0.2)
            os.sleep(0.2)
            clearLine(1,1)
            fs2.makeDirectory("/home/config")
            file1 = io.open("/home/config/keypad.txt", "w")
            file1:write(data.encode64(in1))
            file1:close()
            in1 = ""
            in1L = string.len(in1)

            maxX,maxY = g.maxResolution()
            g.setResolution(maxX,maxY)
            t.clear()
            return
        end
    end
end

function fsa(t1)
    table.insert(fsHandles,t1)
end

errorCount = 0

fsHandles = {}

errors = {}

while errorCount < 5 do
    stat, err = pcall( function()
        if io.open("/home/config/keypad.txt","r") ~= nil then 
            file1=io.open("/home/config/keypad.txt","r")
            fsa(file1)
            currcode1 = data.decode64(file1:read("*a"))
            file1:close()
        else
            currcode1 = "0000"
        end
        if io.open("/home/config/keypad2.txt","r") ~= nil then 
            file1=io.open("/home/config/keypad2.txt","r")
            fsa(file1)
            data1 = file1:read("*a")
            side1 = srz.unserialize(data1)["side"]
            timer1 = srz.unserialize(data1)["timer"]
            file1:close()
        else
            side1 = "down"
            timer1 = 1
        end
        t.clear()
        g.setResolution(7,5)
        writeStr(2,2,"1 2 3")
        writeStr(2,3,"4 5 6")
        writeStr(2,4,"7 8 9")
        writeStr(2,5,"e 0")
        writeChar(6,5,"v")
        paintF(6,5,6,5,0x44FF44)
        paintF(2,5,2,5,0xFFBB00)
        in1 = ""
        while true do
            _,_,X1,Y1,_,ply = event.pull("touch")
            char = g.get(X1,Y1) 
            if tonumber(char) ~= nil then
                in1 = in1..char
                ct.beep(1750,0.1)
            end
            in1L = string.len(in1)
            clearLine(1,1)
            writeStr(1,1,string.rep("*",in1L))
            if in1L == 7 or char == "v" or in1L == string.len(currcode1) then
                os.sleep(0.2)
                if in1 == "123" then
                    ct.shutdown(true)
                end
                if in1 == currcode1 then
                    paintB(1,1,7,1,0x44FF44)
                    ct.beep(300,0.2)
                    ct.beep(400,0.2)
                    rs.setOutput(sides[side1],15)
                    openrd()
                    os.sleep(timer1)
                    closerd()
                    rs.setOutput(sides[side1],0)
                else
                    paintB(1,1,7,1,0xFF4444)
                    ct.beep(150,0.2)
                    ct.beep(50,0.2)
                    os.sleep(0.2)
                end
                in1 = ""
                in1L = string.len(in1)
                clearLine(1,1)
            end
            if char == "e" then
                ct.beep(300,0.1)
                ct.beep(300,0.1)
                codeChange()
                if io.open("/home/config/keypad.txt","r") ~= nil then 
                    file1=io.open("/home/config/keypad.txt","r")
                    fsa(file1)
                    currcode1 = data.decode64(file1:read("*a"))
                    file1:close()
                end
                if io.open("/home/config/keypad2.txt","r") ~= nil then 
                    file1=io.open("/home/config/keypad2.txt","r")
                    fsa(file1)
                    data1 = file1:read("*a")
                    side1 = srz.unserialize(data1)["side"]
                    timer1 = srz.unserialize(data1)["timer"]
                    file1:close()
                else
                    side1 = "down"
                    timer1 = 1
                end
                t.clear()
                g.setResolution(7,5)
                writeStr(2,2,"1 2 3")
                writeStr(2,3,"4 5 6")
                writeStr(2,4,"7 8 9")
                writeStr(2,5,"e 0")
                writeChar(6,5,"v")
                paintF(6,5,6,5,0x44FF44)
                paintF(2,5,2,5,0xFFBB00)
            end
        end
    end)
    maxX,maxY = g.maxResolution()
    g.setResolution(maxX,maxY)
    g.setBackground(0x0000FF)
    g.fill(1,1,maxX,maxY," ")
    t.setCursor(1,1)
    if err then
        if string.len(err) < maxX then
            g.setResolution(string.len(err),2)
        end
        if string.len(err) > maxX then
            g.setResolution(string.len(err),6)
        end
        t.setCursor(1,1)
        t.write(err)
        t.setCursor(1,2)
        t.write("This is the error n°"..(errorCount+1).."/5")
        table.insert(errors,err)
        errorCount = errorCount+1
    end
    ct.beep(300,0.1)
    ct.beep(50,0.2)
    g.setBackground(0x000000)
    os.sleep(5)
end

ct.beep(700,0.1)
ct.beep(700,0.1)
ct.beep(700,0.1)

maxX,maxY = g.maxResolution()
g.setResolution(maxX,maxY)
t.clear()
t.setCursor(1,1)
print("Too Many Errors! Program closed\nLast Errors:")

for i3=1, #errors do
    print("n°"..i3,errors[i3])
end

print("\n\nDebugger Dump:")

print("Closing all FS-Handles..")

for i1=1, #fsHandles do
    _, err2 = pcall(function()
        print("Closing ",fsHandles[i1])
        fsHandles[i1]:close()
        print("Done!")
    end)
    os.sleep(0.05)
    if err2 then
        print("N°"..i1.." Result: ERROR="..err2)
    else
        print("N°"..i1.." Result: Successfull")
    end
end

function exists(t1,t2)
    res1 = false
    for k, _ in pairs(t1) do
        if k == t2 then
            res1 = true
        end
    end
    return res1
end

ct.beep(900,0.1)
os.sleep(2)

g.fill(1,3+#errors,maxX,maxY," ")

t.setCursor(1,2+#errors)

print("\n=== Config File N°1 === (/home/config/keypad.txt)")
if io.open("/home/config/keypad.txt","r") ~= nil then
    file1db = io.open("/home/config/keypad.txt","r")
    if file1db ~= nil then
        print(file1db)
        print(file1db:read("*a"))
        file1db:close()
    else
        print("Error! Unable to open config file 1")
    end
else
    print("Config file 1 is not found!")
end
print("=== End of Debug1 ===")

print("\n=== Config File N°2 === (/home/config/keypad2.txt)")
if io.open("/home/config/keypad2.txt","r") ~= nil then
    file2db = io.open("/home/config/keypad2.txt","r")
    if file2db ~= nil then
        print(file2db)
        data2db = file2db:read("*a")
        t1 = srz.unserialize(data2db)
        print(srz.serialize(t1,true))
        file2db:close()
        if not exists(t1,"timer") or not exists(t1,"side") then
            print("Warning! File corrupted, deleting..")
            fs2.remove("/home/config/keypad2.txt")
            print("Done.")
        end
    else
        print("Error! Unable to open config file 2")
    end
else
    print("Config file 2 is not found!")
end

print("=== End of Debug2 ===\n")
print("====== End of Debugger Dumping ======")


