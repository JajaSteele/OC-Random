local cp = require("component")
local shell = require("shell")
local colors = require("colors")
local cpr = require("computer")
local tm = require("term")
local thread = require("thread")
local g = cp.gpu
h = cp.hologram
geo = cp.geolyzer

args = shell.parse(...)

if args[1] == "clear" then
    for i1=1, 32 do
        for i2=1, 48 do
            for i3=1, 48 do
                h.set(i2,i1,i3, 3)
            end
        end
    end
    for i1=1, 32 do
        for i2=1, 48 do
            for i3=1, 48 do
                h.set(i2,33-i1,i3, 0)
            end
        end
    end
    return
end

h.clear()

i3 = 0
i2 = 0

h.setScale(0.33)
h.setTranslation(0.020,0,0)

h.setPaletteColor(1,1049861)
h.setPaletteColor(2,3355562)
h.setPaletteColor(3,328976)

oldX,oldY = g.maxResolution()
g.setResolution(5,2)
tm.setCursor(1,1)
cpr.beep(300,0.5)



function drawAxis1()
    for i1=1, 48 do
        h.set((48-i1),1,1,3)
        os.sleep(0.000001)
    end
    for i1=1, 48 do
        h.set(48,1,i1+1,1)
        os.sleep(0.000001)
    end
    for i1=1, 48 do
        h.set(48,i1+1,1,2)
        os.sleep(0.000001)
    end
end

function outline2()
    for i1=1, 34 do
        h.set(6+i1,1,8,2)
        h.set(6+i1,3,8,3)
        os.sleep(0.0000000001) 
    end
    --shell.reboot()
    for i1=1, 34 do
        h.set(7+33,1,7+i1,2)
        h.set(7+33,3,7+i1,3)
        os.sleep(0.0000000001)
    end
    for i1=1, 34 do
        h.set(6+(34-i1),1,8+33,2)
        h.set(6+(34-i1),3,8+33,3)
        os.sleep(0.0000000001)
    end
    for i1=1, 34 do
        h.set(6,1,8+(34-i1),0)
        h.set(7,1,8+(34-i1),2)
        h.set(6,3,8+(34-i1),0)
        h.set(7,3,8+(34-i1),3)
        os.sleep(0.0000000001)
    end
end

function outlineClear()
    for i1=1, 34 do
        h.set(6+i1,32,8,0)
        h.set(6+i1,30,8,0)
        os.sleep(0.0000000001) 
    end
    --shell.reboot()
    for i1=1, 34 do
        h.set(7+33,32,7+i1,0)
        h.set(7+33,30,7+i1,0)
        os.sleep(0.0000000001)
    end
    for i1=1, 34 do
        h.set(6+(34-i1),32,8+33,0)
        h.set(6+(34-i1),30,8+33,0)
        os.sleep(0.0000000001)
    end
    for i1=1, 34 do
        h.set(6,32,8+(34-i1),0)
        h.set(7,32,8+(34-i1),0)
        h.set(6,30,8+(34-i1),0)
        h.set(7,30,8+(34-i1),0)
        os.sleep(0.0000000001)
    end
end

function outline1()
    for i1=1, 34 do
        h.set(6+i1,32,8,1)
    end
    --shell.reboot()
    for i1=1, 34 do
        h.set(7+33,32,7+i1,3)
    end
    for i1=1, 34 do
        h.set(6+(34-i1),32,8+33,1)
    end
    for i1=1, 34 do
        h.set(6,32,8+(34-i1),0)
        h.set(7,32,8+(34-i1),3)
    end
end
function outline1_2()
    for i1=1, 34 do
        h.set(6+i1,30,8,1)
    end
    --shell.reboot()
    for i1=1, 34 do
        h.set(7+33,30,7+i1,3)
    end
    for i1=1, 34 do
        h.set(6+(34-i1),30,8+33,1)
    end
    for i1=1, 34 do
        h.set(6,30,8+(34-i1),0)
        h.set(7,30,8+(34-i1),3)
    end
end


outline1()
outline1_2()

for i3=1, 32 do
    for i2=1, 32 do
        scan1 = ""
        scan1 = geo.scan(-16+i2,-16+i3,-8,1,1,32,true)
        tv1 = 0
        tv2 = 0
        for i1 = 1, #scan1 do
            if scan1[i1] ~= 0 then
                c1 = 1
            else
                c1 = 0
            end
            h.set(8+(32-i3),i1,8+(i2),c1)
            h.set(8+(32-i3),31,8+(i2),2)
            h.set(8+16,17,8+16,2)
            h.set(8,1,9,3)
            h.set(8+31,32,8+32,2)
            if scan1[i1] > 0 then
                s1 = i1
            end
            i1 = 1
        end
        tm.setCursor(1,1)
        tm.clearLine()
        tm.write(i2)
        tm.setCursor(3,1)
        tm.write("/32")
        tm.setCursor(1,2)
        tm.clearLine()
        tm.write(i3)
        tm.setCursor(3,2)
        tm.write("/32")
    end
end

cpr.beep(400,0.2)

h.setPaletteColor(1,0xFF4444)
h.setPaletteColor(2,0x44FF44)
h.setPaletteColor(3,0x4444FF)

for i4=1, 30 do
    h.setScale(i4/30)
    h.setTranslation(0.020,i4/35,0)
    os.sleep(0.035)
end 

for i4=1, 15 do
    h.setTranslation(0.020,(30-i4)/45,0)
    os.sleep(0.035)
end 

for i1=1, 32 do
    for i2=1, 32 do
        h.set(7+i1,31,8+i2,0)
        tm.setCursor(1,1)
        tm.clearLine()
        tm.write(i2)
        tm.setCursor(3,1)
        tm.write("/32")
        tm.setCursor(1,2)
        tm.clearLine()
        tm.write(i1)
        tm.setCursor(3,2)
        tm.write("/32")
    end
end


TR1 = thread.create(drawAxis1)
TR2 = thread.create(outlineClear)
TR3 = thread.create(outline2)

thread.waitForAny({TR1,TR2,TR3})

cpr.beep(600,0.1)
os.sleep(0.1)
cpr.beep(600,0.1)

cpr.shutdown(true)