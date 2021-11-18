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
local sides = require("sides")
local data = cp.data
local rs = cp.redstone

cb = cp.chat_box

local args = shell.parse(...)

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

    sideT = {
        u="up",
        d="down",
        l="left",
        r="right",
        f="front",
        b="back"
    }

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
            paintB(1,1,7,1,0x555555)
            ct.beep(500,0.2)
            os.sleep(0.2)
            clearLine(1,1)
            file1:write(sideT[string.lower(char)])
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


if io.open("/home/config/keypad.txt","r") ~= nil then 
    file1=io.open("/home/config/keypad.txt","r")
    currcode1 = data.decode64(file1:read("*a"))
    file1:close()
end
if io.open("/home/config/keypad2.txt","r") ~= nil then 
    file1=io.open("/home/config/keypad2.txt","r")
    side1 = file1:read("*a")
    file1:close()
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
        if in1 == currcode1 then
            paintB(1,1,7,1,0x44FF44)
            ct.beep(1000,0.2)
            ct.beep(1200,0.2)
            os.sleep(0.2)
            rs.setOutput(sides[side1],15)
            os.sleep(1)
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
            currcode1 = data.decode64(file1:read("*a"))
            file1:close()
        end
        if io.open("/home/config/keypad2.txt","r") ~= nil then 
            file1=io.open("/home/config/keypad2.txt","r")
            side1 = file1:read("*a")
            file1:close()
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

maxX,maxY = g.maxResolution()
g.setResolution(maxX,maxY)
t.clear()