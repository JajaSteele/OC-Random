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
local g = cp.glasses
local sg = cp.stargate
local process = require("process")


local args = shell.parse(...)

g.removeAll()

function checkAll(x1,y1,t1)
    result2 = ""
    for k, v in pairs(t1) do
        result1 = checkClick(x1,y1,v)
        if result1 then
            result2 = k
            break
        end
    end
    if result2 ~= "" then
        return result2
    else
        return nil
    end
end

function checkClick(x1,y1,t1)
    if x1 >= t1["minX"] and x1 <= t1["maxX"] and y1 >= t1["minY"] and y1 <= t1["maxY"] then
        return true
    else
        return false
    end
end
    

function addClickTextBox(x1,y1,w,h,text1,name)
    t1 = {}
    b1 = g.addBox2D() --Dial
    b1.setSize(w,h)
    b1.addTranslation(x1,y1,0)
    b1.addColor(0.5,0.75,0.75,0.35)
    b1.addColor(0.75,0.75,0.75,0.25)
    b1t = g.addText2D()
    b1t.setText(text1)
    b1t.addColor(1,1,1,1)
    b1t.addTranslation(x1+4,y1+4,0)

    minX = x1 
    minY = y1
    maxX = (x1+w)-1
    maxY = (y1+h)-1
    
    t1["textHandle"] = b1t
    t1["boxHandle"] = b1
    t1["minX"] = minX
    t1["minY"] = minY
    t1["maxX"] = maxX
    t1["maxY"] = maxY

    if allBoxes == nil then
        allBoxes = {}
    end

    allBoxes[name] = t1

    b1 = nil
    b1t = nil

    return t1
end

function addTextBox(x1,y1,w,h,text1)
    t1 = {}
    b1 = g.addBox2D() --Dial
    b1.setSize(w,h)
    b1.addTranslation(x1,y1,0)
    b1.addColor(0.5,0.75,0.75,0.35)
    b1.addColor(0.75,0.75,0.75,0.25)
    b1t = g.addText2D()
    b1t.setText(text1)
    b1t.addColor(1,1,1,1)
    b1t.addTranslation(x1+4,y1+4,0)

    minX = x1 
    minY = y1
    maxX = (x1+w)-1
    maxY = (y1+h)-1
    
    t1["textHandle"] = b1t
    t1["boxHandle"] = b1
    t1["minX"] = minX
    t1["minY"] = minY
    t1["maxX"] = maxX
    t1["maxY"] = maxY

    b1 = nil
    b1t = nil

    return t1
end

function addClickBox(x1,y1,w,h,name)
    t1 = {}
    b1 = g.addBox2D() --Dial
    b1.setSize(w,h)
    b1.addTranslation(x1,y1,0)
    b1.addColor(0.5,0.75,0.75,0.35)
    b1.addColor(0.75,0.75,0.75,0.25)

    minX = x1 
    minY = y1
    maxX = (x1+w)-1
    maxY = (y1+h)-1
    
    t1["boxHandle"] = b1
    t1["minX"] = minX
    t1["minY"] = minY
    t1["maxX"] = maxX
    t1["maxY"] = maxY

    if allBoxes == nil then
        allBoxes = {}
    end

    allBoxes[name] = t1

    b1 = nil
    b1t = nil

    return t1
end

function addBox(x1,y1,w,h)
    t1 = {}
    b1 = g.addBox2D() --Dial
    b1.setSize(w,h)
    b1.addTranslation(x1,y1,0)
    b1.addColor(0.5,0.75,0.75,0.35)
    b1.addColor(0.75,0.75,0.75,0.25)

    minX = x1 
    minY = y1
    maxX = (x1+w)-1
    maxY = (y1+h)-1
    
    t1["boxHandle"] = b1
    t1["minX"] = minX
    t1["minY"] = minY
    t1["maxX"] = maxX
    t1["maxY"] = maxY

    b1 = nil
    b1t = nil

    return t1
end

function addInputBox(x1,y1,w,h,text1)
    t1 = {}
    b1 = g.addBox2D() --Dial
    b1.setSize(w,h)
    b1.addTranslation(x1,y1,0)
    b1.addColor(0.5,0.75,0.75,0.35)
    b1.addColor(0.75,0.75,0.75,0.25)

    b1t = g.addText2D()
    b1t.setText(text1)
    b1t.addColor(1,1,1,1)
    b1t.addTranslation(x1+4,y1+4,0)
    t1["textHandle"] = b1t

    minX = x1 
    minY = y1
    maxX = (x1+w)-1
    maxY = (y1+h)-1

    input1 = ""

    while true do
        _, _, _, code,char = event.pull("keyboard_interact_overlay")
        if(char:match("%w")) then
            input1 = input1..char
        else
            if code == 14 then
                input1 = string.sub(input1,1,string.len(input1)-1)
            end
            if code == 57 then
                input1 = input1.." "
            end
            if code == 28 then
                break
            end
        end
        b1t.setText(text1..input1)
    end

    
    t1["boxHandle"] = b1
    t1["minX"] = minX
    t1["minY"] = minY
    t1["maxX"] = maxX
    t1["maxY"] = maxY

    b1 = nil
    b1t = nil

    return t1, input1
end

function colorBox(t1,c1R,c1G,c1B,c1A,c2R,c2G,c2B,c2A)
    if c2 == nil then
        t1["boxHandle"].addColor(c1R,c1G,c1B,c1A)
        t1["boxHandle"].addColor(c1R,c1G,c1B,c1A)
    else
        t1["boxHandle"].addColor(c1R,c1G,c1B,c2A)
        t1["boxHandle"].addColor(c2R,c2G,c2B,c2A)
    end
end

function removeBox(table1,name)
    t1 = {}
    for k,v in pairs(table1) do
        if type(v) == "table" then
            v.removeWidget()
        end
    end
    if name ~= nil then
        allBoxes[name] = nil
    end
    return nil
end

if io.open("/boot/999_glassboot.lua","r") ~= nil then
    fs2.remove("/boot/999_glassboot.lua")
end
    

boxDial = addClickTextBox(1,1,50,15,"Dial","Dial")

boxClose2 = addClickTextBox(1,17,50,15,"Close SG","Close")

if io.open("/home/AIScript/save/gates.txt","r") ~= nil then
    boxList2 = addClickTextBox(1,33,50,15,"Dir List","dirlist")
    boxExit1 = addClickTextBox(1,66,50,15,"Exit","exit")
    colorBox(boxExit1,0.75,0.5,0.5,0.35,0.75,0.75,0.75,0.25)
else
    boxExit1 = addClickTextBox(1,49,50,15,"Exit","exit")
    colorBox(boxExit1,0.75,0.5,0.5,0.35,0.75,0.75,0.75,0.25)
end

resX = 640
resY = 353

while true do
    ev1, _, _, X1,Y1 = event.pull("interact_overlay")
    if ev1 == "interact_overlay" then
        boxClick = checkAll(X1,Y1,allBoxes)
        if boxClick then
            if boxClick == "Dial" then
                dialWin = addBox(55,1,200,100)
                dialWinTitle = addTextBox(55,1,200,15,"Manual Dial")
                dialWinTip = addTextBox(55,40,200,15,"(Type \"cancel\" to close)")
                dialWinInput, address1 = addInputBox(55,20,200,15,"Address:")

                if address1 == "cancel" then
                    dialWin = removeBox(dialWin)
                    dialWinTitle = removeBox(dialWinTitle)
                    dialWin = removeBox(dialWinInput)
                    dialWinTip = removeBox(dialWinTip)
                else

                    stat, err = sg.dial(address1)

                    if stat == nil then stat = "nil" end
                    if err == nil then err = "nil" end

                    dialWinTip = removeBox(dialWinTip)

                    if stat then
                        dialWinErr = addTextBox(55,40,200,15,"Dialing Address")
                        colorBox(dialWinErr,0.5,0.75,0.5,0.35,0.75,0.75,0.75,0.25)
                    else
                        if err ~= nil then
                            dialWinErr = addTextBox(55,40,200,15,"ERROR: "..err)
                            colorBox(dialWinErr,0.75,0.5,0.5,0.35,0.75,0.75,0.75,0.25)
                        end
                    end 

                    os.sleep(2)

                    dialWinErr = removeBox(dialWinErr)
                    
                    os.sleep(0.5)

                    dialWin = removeBox(dialWin)
                    dialWinTitle = removeBox(dialWinTitle)
                    dialWin = removeBox(dialWinInput)
                end
            end
            if boxClick == "Close" then
                closeWin = addBox(55,1,100,30)
                closeWinTitle = addTextBox(55,1,100,15,"Confirm?")
                colorBox(closeWinTitle,0.5,0.75,0.75,0.35,0.5,0.75,0.75,0.25)
                closeWinButton = addClickTextBox(55,16,100,15,"Close SG","close_sg")
                while true do
                    local ev1, _, _, X1,Y1 = event.pull("interact_overlay")
                    if ev1 == "interact_overlay" then
                        r1 = checkClick(X1,Y1,closeWinButton)
                        break
                    end
                end
                if r1 then
                    colorBox(closeWinButton,0.5,0.75,0.5,0.35,0.75,0.75,0.75,0.25)
                    os.sleep(0.5)
                    sg.disconnect()
                    closeWin = removeBox(closeWin)
                    closeWinTitle = removeBox(closeWinTitle)
                    closeWinButton = removeBox(closeWinButton)
                else
                    closeWin = removeBox(closeWin)
                    closeWinTitle = removeBox(closeWinTitle)
                    closeWinButton = removeBox(closeWinButton)
                end
            end
            if boxClick == "dirlist" then
                file1 = io.open("/home/AIScript/save/gates.txt","r")
                data1 = srz.unserialize(file1:read("*a"))
                file1:close()
                i1 = 0
                list1 = {}
                for k, v in pairs(data1) do
                    box1 = addClickTextBox(55,16*i1,175,15,k.." > "..v,v)
                    table.insert(list1,box1)
                    box1 = nil
                    i1 = i1+1
                end
                while true do
                    local ev1, _, _, X1,Y1 = event.pull("interact_overlay")
                    if ev1 == "interact_overlay" then
                        r1 = checkAll(X1,Y1,allBoxes)
                        break
                    end
                end
                if r1 then
                    for i2=1, #list1 do
                        removeBox(list1[i2])
                    end
                    stat, err = sg.dial(address1)

                    if stat == nil then stat = "nil" end
                    if err == nil then err = "nil" end

                    if stat then
                        dialWinErr = addTextBox(55,1,200,15,"Successfully Dialing Address")
                        colorBox(dialWinErr,0.5,0.75,0.5,0.35,0.75,0.75,0.75,0.25)
                    else
                        if err ~= nil then
                            dialWinErr = addTextBox(55,1,200,15,"ERROR: "..err)
                            colorBox(dialWinErr,0.75,0.5,0.5,0.35,0.75,0.75,0.75,0.25)
                        end
                    end 

                    os.sleep(2)

                    dialWinErr = removeBox(dialWinErr)

                    os.sleep(0.5)

                else
                    for i2=1, #list1 do
                        removeBox(list1[#list1-(i2-1)])
                        os.sleep(0.05)
                    end
                end
            end
            if boxClick == "exit" then
                cX1 = (640/2)-100
                cY1 = (353/2)-25
                cBox = addBox(cX1,cY1,200,50)
                cBoxTitle = addTextBox(cX1,cY1,200,15,"Confirm the Exit?")

                cBoxYes = addClickTextBox(cX1,cY1+35,50,15,"Yes","yes_c")
                cBoxRb = addClickTextBox((640/2)-25,cY1+35,50,15,"Reboot","rb_c")
                cBoxNo =addClickTextBox(cX1+150,cY1+35,50,15,"No","no_c")

                while true do
                    local ev1, _, _, X1,Y1 = event.pull("interact_overlay")
                    if ev1 == "interact_overlay" then
                        r1 = checkAll(X1,Y1,allBoxes)
                        break
                    end
                end
                if r1 then
                    if r1 == "yes_c" then
                        g.removeAll()
                        ct.shutdown(true)
                        break
                    end
                    if r1 == "no_c" then
                        cBoxYes = removeBox(cBoxYes)
                        cBoxRb = removeBox(cBoxRb)
                        cBoxNo = removeBox(cBoxNo)
                        cBoxTitle = removeBox(cBoxTitle)
                        cBox = removeBox(cBox)
                    end
                    if r1 == "rb_c" then
                        g.removeAll()
                        file1 = io.open("/boot/999_glassboot.lua","w")
                        path1 = shell.resolve(process.info().path)
                        file1:write("local shell = require(\"shell\") local thread = require(\"thread\") shell.execute(\""..path1.."\")")
                        file1:close()
                        ct.shutdown(true)
                        break
                    end
                else
                    cBoxYes = removeBox(cBoxYes)
                    cBoxRb = removeBox(cBoxRb)
                    cBoxNo = removeBox(cBoxNo)
                    cBoxTitle = removeBox(cBoxTitle)
                    cBox = removeBox(cBox)
                end
            end
        end
    end
end