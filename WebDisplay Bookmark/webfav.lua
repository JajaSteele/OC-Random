local event = require("event")
local cp = require("component")
local t = require("term")
local screen = cp.screen
local g = cp.gpu
local fs = cp.filesystem
local fs2 = require("filesystem")
local srz = require("serialization")
local wd = cp.webdisplays
local keyboard = cp.keyboard
local ct = require("computer")

-- Touch Eventt is :  _, address, X1, Y1, Button, Player = event.pull("touch")

if not fs.exists("/home/save/webfavs.txt") then
    if not fs.exists("/home/save") then
        fs2.makeDirectory("/home/save")
    end
    save1 = io.open("/home/save/webfavs.txt", "w")
    save1:write("{}")
    save1:close()
else
    if fs.exists("/home/save/webfavs.txt") then
        save2 = io.open("/home/save/webfavs.txt", "r")
        saveT1 = srz.unserialize(save2:read("*a"))
        save2:close()
    end
end

if saveT1 == nil then
    saveT1 = {}
end

local function swrite(x1,y1,t1,c1,c2)
    oldC1 = g.getForeground()
    oldC2 = g.getBackground()
    g.setForeground(c1)
    g.setBackground(c2)
    g.fill(x1,y1,1,1,t1)
    g.setForeground(oldC1)
    g.setBackground(oldC2)
end

local function swritet(x1,y1,t1,c1,c2)
    oldC1 = g.getForeground()
    oldC2 = g.getBackground()
    oldPos1,oldPos2 = t.getCursor()
    g.setForeground(c1)
    g.setBackground(c2)
    t.setCursor(x1,y1)
    t.write(t1)
    t.setCursor(oldPos1,oldPos2)
    g.setForeground(oldC1)
    g.setBackground(oldC2)
end

local function swrite2(x1,y1,t1)
    g.fill(x1,y1,1,1,t1)
end

local function tmove(x1,y1)
    oldX,oldY = t.getCursor()
    t.setCursor(oldX+x1,oldY+y1)
end

local function clearL()
    baseX,baseY = t.getCursor()
    mX,mY = g.getResolution()
    t.write(string.rep(" ", mX-baseX))
    t.setCursor(baseX,baseY)
end

local function jread()
    v1 = ""
    baseX,baseY = t.getCursor()
    mX,mY = g.getResolution()
    t.write(string.rep(" ", mX-baseX))
    t.setCursor(baseX,baseY)
    t.write("Write the URL to save (or press 1 for clipboard)")
    _, char, code2, player = event.pull("key_down")
    t.setCursor(baseX,baseY)
    clearL()
    if string.char(code2) == "1" or string.char(code2) == "&" then
        t.write("Please Press INSERT or Middle Button")
        v1_,v2_,v3_ = event.pull("clipboard")
        return v3_
    else
        t.setCursor(baseX,baseY)
        if code2 == 8 then
            X1,Y1 = t.getCursor()
            t.setCursor(X1-1,Y1)
            t.write("_ ")
            t.setCursor(X1-1,Y1)
            v1 = string.sub(v1,1,string.len(v1)-1)
        else
            if code2 ~= 0 then
                if code2 ~= 32 then
                    if string.char(code2) ~= " " and string.char(code2) ~= "" then
                        t.write(string.char(code2))
                        t.write("_")
                        tmove(-1,0)
                        v1 = v1..string.char(code2)
                    end
                else
                    t.write(string.char(code2))
                    t.write("_")
                    tmove(-1,0)
                    v1 = v1..string.char(code2)
                end
            end
        end
        t.write("_")
        tmove(-1,0)
        repeat
            _, char, code1, player = event.pull("key_down")
            if code1 == 8 then
                X1,Y1 = t.getCursor()
                if X1 > baseX then
                    t.setCursor(X1-1,Y1)
                    t.write("_ ")
                    t.setCursor(X1-1,Y1)
                    v1 = string.sub(v1,1,string.len(v1)-1)
                end
            else
                if code1 ~= 0 then
                    if code1 ~= 32 then
                        if string.char(code1) ~= " " and string.char(code1) ~= "" then
                            t.write(string.char(code1))
                            t.write("_")
                            tmove(-1,0)
                            v1 = v1..string.char(code1)
                        end
                    else
                        t.write(string.char(code1))
                        t.write("_")
                        tmove(-1,0)
                        v1 = v1..string.char(code1)
                    end
                end
            end
        until code1 == 13
        return string.sub(v1,1,string.len(v1)-1)
    end
end
        

g.setResolution(g.maxResolution())
maxXT, maxYT = g.getResolution()
g.setResolution(maxXT/2,maxYT/2)
maxX, maxY = g.getResolution()
t.clear()

tips = {"You can right click a link to delete rapidly!","You can click here to manually write in URL!"}

currPage = 1

function updateD()
    cP2 = (currPage-1)*21
    for i1=1, maxY-3 do
        if (i1 % 2 == 0) then
            g.setBackground(0x0F0F0F)
        else
            g.setBackground(0x000000)
        end
        g.fill(1,i1,maxX,1," ")
        swrite(3,i1,"+",0xFFFFFF,0x33AA33)
        swrite(1,i1,"-",0xFFFFFF,0xAA3333)
        swrite(6,i1,"E",0xFFFFFF,0xCCBB00)
        swrite2(8,i1,"|")
        t.setCursor(10,i1)
        t.write(i1+cP2)
        t.setCursor(14,i1)
        if saveT1 ~= nil then
            if saveT1["B"..tostring(i1+cP2)] ~= nil then
                old1 = g.getForeground()
                g.setForeground(0xFFFF66)
                t.write(saveT1["B"..tostring(i1+cP2)])
                g.setForeground(old1)
            end
        end
    end
    g.setBackground(0x000000)
    g.setForeground(0x00FFFF)
    g.fill(1,maxY-3,maxX,1,"-")
    g.fill(1,maxY,maxX,1,"-")
    g.setForeground(0xFFFFFF)
    t.setCursor(3,maxY-2)
    t.write("+ = Add URL | - = Delete URL | E = Edit URL | Click URL = Load Bookmark URL")
    t.setCursor(3,maxY-1)
    r1 = math.random(1,#tips)
    t.write("Tip: "..tips[r1])
    swritet(38,maxY-3,"<",0xFFFFFF,0x0000FF)
    swritet(43  ,maxY-3,">",0xFFFFFF,0x0000FF)
    if currPage < 10 then
        swritet(40,maxY-3,currPage.." ",0xFFFFFF,0x0000FF)
    else
        swritet(40,maxY-3,currPage,0xFFFFFF,0x0000FF)
    end
end

updateD()

while true do
    _, address, X1, Y1, Button, Player = event.pull("touch")
    if Y1 < maxY-2 then
        cP2 = (currPage-1)*21
        if fs.exists("/home/save/webfavs.txt") then
            save2 = io.open("/home/save/webfavs.txt", "r")
            saveT1 = srz.unserialize(save2:read("*a"))
            save2:close()
        end
        if X1 == 3 then
            url1 = wd.getURL()
            saveT1["B"..tostring(Y1+cP2)] = url1
            ct.beep(700,0.1)
            updateD()
        end
        if X1 == 1 then
            saveT1["B"..tostring(Y1+cP2)] = nil
            ct.beep(400,0.1)
            updateD()
        end
        if X1 == 6 then
            t.setCursor(13,Y1)
            if (Y1+cP2 % 2 == 0) then
                g.setBackground(0x0F0F0F)
            else
                g.setBackground(0x000000)
            end
            ct.beep(500,0.1)
            ct.beep(500,0.1)
            newURL = jread()
            saveT1["B"..tostring(Y1+cP2)] = newURL
            ct.beep(700,0.1)
            updateD()
        end
        if X1 > 6 and Y1 ~= 22 then
            if Button == 0 then
                if saveT1["B"..tostring(Y1+cP2)] ~= "" and saveT1["B"..tostring(Y1+cP2)] ~= nil then
                    wd.setURL(saveT1["B"..tostring(Y1+cP2)])
                    ct.beep(800,0.2)
                else
                    ct.beep(250,0.1)
                    ct.beep(250,0.1)
                end
            else
                saveT1["B"..tostring(Y1+cP2)] = nil
                ct.beep(400,0.1)
                updateD()
            end
        end
        if Y1 == 22 then
            if X1 == 38 then
                ct.beep(400,0.1)
                if currPage > 1 then
                    currPage = currPage-1
                end
                updateD()
            end
            if X1 == 43 then
                ct.beep(600,0.1)
                currPage = currPage+1
                updateD()
            end
        end
        save3 = io.open("/home/save/webfavs.txt", "w")
        save3:write(srz.serialize(saveT1))
        save3:close()
    end
    if Y1 > maxY-3 then
        t.setCursor(1,maxY-1)
        t.clearLine()
        t.setCursor(1,maxY-2)
        t.clearLine()
        t.setCursor(1,maxY)
        t.clearLine()
        t.setCursor(1,maxY-2)
        t.write("Enter URL to open: ")
        t.setCursor(1,maxY-1)
        t.write("> ")
        url2 = io.read()
        if url2 ~= "" and url2 ~= "\n" then
            wd.setURL(url2)
        end
        t.setCursor(1,maxY-1)
        t.clearLine()
        t.setCursor(1,maxY-2)
        t.clearLine()
        t.setCursor(1,maxY)
        t.clearLine()
        updateD()
    end
end