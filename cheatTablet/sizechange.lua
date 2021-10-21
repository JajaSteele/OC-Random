local event = require("event")
local cp = require("component")
local t = require("term")
local g = cp.gpu
local keyboard = cp.keyboard
local ct = require("computer")
local shell = require("shell")
local screen = cp.screen
local db = cp.debug

if cp.isAvailable("glasses") then
    gs = cp.glasses
    gs.startLinking()
    gsON = true
    gs.removeAll()
else
    gsON = false
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

local function jread2(xv1)
    v1 = ""
    baseX,baseY = t.getCursor()
    mX,mY = g.getResolution()
    t.write(string.rep(" ", mX-baseX))
    t.setCursor(baseX,baseY)
    clearL()
    t.write(xv1)
    t.setCursor(baseX,baseY)
    _, char, code2, player = event.pull("key_down")
    clearL()    
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


local function jread(xv1)
    v1 = ""
    baseX,baseY = t.getCursor()
    mX,mY = g.getResolution()
    t.write(string.rep(" ", mX-baseX))
    t.setCursor(baseX,baseY)
    t.write(xv1)
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

local function rgbtohex(rgb)
	local hexadecimal = '0X'

	for key, value in pairs(rgb) do
		local hex = ''

		while(value > 0)do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index) .. hex			
		end

		if(string.len(hex) == 0)then
			hex = '00'

		elseif(string.len(hex) == 1)then
			hex = '0' .. hex
		end

		hexadecimal = hexadecimal .. hex
	end

	return tonumber(hexadecimal)
end

local function twrite(x1,y1,t1)
    oldX, oldY = t.getCursor()
    t.setCursor(x1,y1)
    t.write(t1)
    t.setCursor(oldX, oldY)
end

local function cPrint(t1)
    oldX1, oldY1 = t.getCursor()
    oldY2 = oldY1
    rm1 = false
    os1 = 0
    for i1=1, string.len(t1) do
        if string.sub(t1,i1,i1+1) == "%n" then
            oldY2 = oldY2+1
            t.setCursor(oldX1,oldY2)
            rm1 = true
            os1 = 0
        end
        t.write(string.sub(t1,i1,i1))
        if rm1 == true and os1 ~= 2 then
            tmove(-1,0)
            os1 = os1+1
        else
            rm1 = false
        end
    end
end

local function errorBox(x1,x2,t1,t2)
    oldX, oldY = t.getCursor()
    oldColor = g.getForeground()
    g.setForeground(0xFF4444)
    g.fill(1,x1,maxX,x2+2," ")
    g.fill(1,x1,maxX,1,"-")
    g.fill(1,x1+(x2+1),maxX,1,"-")
    g.fill(string.len(t1)+3,x1,1,x2+2,"|")
    g.setForeground(0xFFFF44)
    twrite(2,x1+1,t1)
    t.setCursor(string.len(t1)+5,x1+1)
    cPrint(t2)
    g.setForeground(oldColor)
    t.setCursor(oldX,oldY)
end

local function drawBox(x1,x2,t1,t2)
    oldX, oldY = t.getCursor()
    g.fill(1,x1,maxX,1,"-")
    g.fill(1,x1+(x2+1),maxX,1,"-")
    g.fill(string.len(t1)+3,x1,1,x2+2,"|")
    twrite(2,x1+1,t1)
    t.setCursor(string.len(t1)+5,x1+1)
    cPrint(t2)
    t.setCursor(oldX,oldY)
end

function updateG()
    t.clear()
    g.setBackground(0x555555)
    g.fill(1,3,maxX*size,1,"=")
    g.fill(8,3,1,1,"|")
    t.setCursor((maxX*size),3)
    t.write("|")
    g.setBackground(0x000000)
    twrite(1,1,"Size Change:")
    g.fill(1,2,maxX,1,"-")
    g.fill(1,4,maxX,1,"-")
    g.fill(8,2,1,1,"|")
    g.fill(8,4,1,1,"|")
    g.fill(1,3,7,1," ")
    twrite(2,3,string.format("%.0f", size*100).."%")
    g.fill(1,5,maxX,1,"-")
    g.fill(1,7,maxX,1,"-")
    twrite(2,6,"Give Item")
    g.fill(12,5,1,3,"|")
    g.fill(1,8,maxX,1,"-")
    g.fill(1,10,maxX,1,"-")
    twrite(2,9,"WorldEdit")
    g.fill(12,8,1,3,"|")
    drawBox(11,1,"WE Selection","Pos1 X"..WEx.." Y"..WEy.." Z"..WEz.." | Pos2 X"..WEx1.." Y"..WEy1.." Z"..WEz1)
end

size = 1

maxX,maxY = g.getResolution()

Player = "JajaSteele"

t.clear()

X1 = maxX

WEx = 0
WEy = 0
WEz = 0

WEx1 = 0
WEy1 = 0
WEz1 = 0

if gsON then
    title1 = gs.addText2D()
    title2 = gs.addText2D()
    title3 = gs.addText2D()
    sizeW1 = gs.addText2D()

    title1.addTranslation(2,2,2)
    title1.setText("--- WorldEdit Pos ---")

    title2.addTranslation(2,32,2)
    title2.setText("--- WorldEdit Placer ---")

    title3.addTranslation(2,94,2)
    title3.setText("--- Size Changer ---")
    sizeW1.addTranslation(2,104,2)
    sizeW1.setText("100%")
end
updateG()

while true do
    _,_, X1,Y1, Button, Player = event.pull("touch")
    if Y1 == 3 then
        size = X1/maxX
        if size < 0.1 then size = 0.1 end
        size2 = 1-size
        db.runCommand("/sizechange "..Player.." "..size.." pymtech:pym_particles")
        sizeW1.setText(tostring(size*100).."%")
        sizeW1.addColor(1,size,size)
    end
    if Y1 == 6 then
        t.setCursor(14,6)
        item = jread("Type Item ID Here (or press \"1\" for clipboard)")
        t.setCursor(14,6)
        clearL()
        count1 = jread2("Type Item Count Here")
        t.setCursor(14,6)
        clearL()
        meta1 = jread2("Type Metadata Here")
        t.setCursor(14,6)
        clearL()
        nbt1 = jread("Optional NBT data (2x Enter to ignore and \"1\" for clipboard)")
        t.setCursor(14,6)
        V1_,V2_ = db.runCommand("/give "..Player.." "..item.." "..count1.." "..meta1.." "..nbt1)
        swritet(14,6,V2_,0xFF3333,0x000000)
        os.sleep(2)
    end
    if Y1 == 9 then
        if gsON then
            currX = tonumber(string.format("%.0f", db.getX()))
            currY = tonumber(string.format("%.0f", db.getY()))
            currZ = tonumber(string.format("%.0f", db.getZ()))

            title2.setText("--- WorldEdit Placer --- (Running)")

            if b1t ~= nil then
                b1t.removeWidget()
            end
            if b2t ~= nil then
                b2t.removeWidget()
            end
            if b3t ~= nil then
                b3t.removeWidget()
            end

            b1t = gs.addText2D()
            b2t = gs.addText2D()
            b3t = gs.addText2D()

            b1t.addTranslation(2,42,2)
            b2t.addTranslation(2,52,2)
            b3t.addTranslation(2,62,2)
        end
        t.setCursor(14,9)
        t.write("")
        cmd1 = jread("Enter WorldEdit Command(without //):")
        if cmd1 == nil then cmd1 = "set" end
        if gsON then
            b1t.setText("Last Selected CMD: //"..cmd1)
        end
        t.setCursor(14,9)
        clearL()
        t.write("Select Block (hold right click on block)")
        _, tb1 = event.pull("tablet_use")
        ct.beep(400,0.2)
        t.setCursor(14,9)
        clearL()
        x1 = tb1.posX
        y1 = tb1.posY
        z1 = tb1.posZ
        x2,y2,z2 = x1+448,y1,z1+448
        print(x2,y2,z2)
        os.sleep(0.15)
        world1 = db.getWorld()
        blockID1 = world1.getBlockState(x2,y2,z2)
        blockID2 = string.gsub(blockID1,"%-","_")
        s1,s2 = string.find(blockID2,"%[")
        if s1 ~= nil then
            ct.beep(550,0.1)
            blockID2 = string.sub(blockID2,1,s1-1)
        end
        blockMeta = world1.getMetadata(x2,y2,z2)
        if gsON then
            b2t.setText("Last Selected Block: ID: "..blockID2.." | Meta: "..blockMeta)
        end
        t.setCursor(14,9)
        clearL()
        v1, v2 = db.runCommand("//"..cmd1.." "..blockID2..":"..blockMeta)
        if gsON then
            b3t.setText("Last Executed CMD: \"".."//"..cmd1.." "..blockID2..":"..blockMeta.."\"")
        end
        t.setCursor(14,9)
        clearL()
        t.write(v2)
        if v1 ~= 2 then
            errorBox(11,2,"Return:","X"..x2.." Y"..y2.." Z"..z2.." | Stored Block ID: "..blockID2..":"..blockMeta.." %nCMD: \"//"..cmd1.."\"")
            if gsON and v1 == 0 then
                b4t = gs.addText2D()
                b4t.addTranslation(2,74,2)
                b5t = gs.addText2D()
                b5t.addTranslation(2,84,2)
                b4t.setText("Return: X"..x2.." Y"..y2.." Z"..z2.." | Stored Block ID: "..blockID2..":"..blockMeta)
                b4t.addColor(1,0.4,0.4)
                b5t.setText("CMD: \"//"..cmd1.."\"")
                b5t.addColor(1,0.4,0.4)
            end
            ct.beep(300,0.5)
            _,_, X1,Y1, Button, Player = event.pull("touch")
            ct.beep(675,0.05)
            ct.beep(675,0.05)
            title2.setText("--- WorldEdit Placer ---")
            if gsON and v1 == 0 then
                b4t.removeWidget()
                b5t.removeWidget()
            end
        end
    end
    if Y1 == 12 then
        if gsON then
            title1.setText("--- WorldEdit Pos --- (Running)")

            currX = tonumber(string.format("%.0f", db.getX()))
            currY = tonumber(string.format("%.0f", db.getY()))
            currZ = tonumber(string.format("%.0f", db.getZ()))

            if p1t ~= nil then
                p1t.removeWidget()
            end
            if p2t ~= nil then
                p2t.removeWidget()
            end

            p1t = gs.addText2D()
            p2t = gs.addText2D()

            p1t.addTranslation(2,12,2)
            p2t.addTranslation(2,22,2)
        end
        t.setCursor(17,12)
        clearL()
        t.write("Hold R-Click on Pos1")
        _, tb1 = event.pull("tablet_use")
        ct.beep(600,0.1)
        t.setCursor(17,12)
        clearL()
        x1 = tb1.posX
        y1 = tb1.posY
        z1 = tb1.posZ
        x2,y2,z2 = x1+448,y1,z1+448
        print(x2,y2,z2)
        WEx = x2
        WEy = y2
        WEz = z2
        p1t.setText("Pos1: X "..WEx.." | Y "..WEy.." | Z "..WEz)
        t.setCursor(17,12)
        clearL()
        t.write("Hold R-Click on Pos2")
        _, tb1 = event.pull("tablet_use")
        ct.beep(600,0.1)
        t.setCursor(17,12)
        clearL()
        x1 = tb1.posX
        y1 = tb1.posY
        z1 = tb1.posZ
        x2,y2,z2 = x1+448,y1,z1+448
        print(x2,y2,z2)
        WEx1 = x2
        WEy1 = y2
        WEz1 = z2
        p2t.setText("Pos2: X "..WEx1.." | Y "..WEy1.." | Z "..WEz1)

        db.runCommand("//pos1 "..WEx..","..WEy..","..WEz)
        db.runCommand("//pos2 "..WEx1..","..WEy1..","..WEz1)

        ct.beep(700,0.1)
        ct.beep(725,0.2)
        if gsON then
            title1.setText("--- WorldEdit Pos ---")
        end
    end
    updateG()
end


