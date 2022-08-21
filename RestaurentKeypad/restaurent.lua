local component = require("component")
local t = require("term")
local gpu = component.gpu
local event = require("event")
local keypad = component.os_keypad

local function qw(x,y,txt,fg,bg)
    local oldBG = gpu.getBackground()
    local oldFG = gpu.getForeground()

    local ox,oy = t.getCursor()
    t.setCursor(x,y)
    if fg ~= nil then
        gpu.setForeground(fg)
    end
    if bg ~= nil then
        gpu.setBackground(bg)
    end
    t.write(txt)
    t.setCursor(ox,oy)

    gpu.setForeground(oldFG)
    gpu.setBackground(oldBG)
end

local function transition(n,c1,c2,time)
    local oldBG = gpu.getBackground()
    local oldFG = gpu.getForeground()

    for i1=1, n do
        gpu.setBackground(c1)
        t.clear()
        os.sleep(time)
        gpu.setBackground(c2)
        t.clear()
        os.sleep(time)
    end
    gpu.setForeground(oldFG)
    gpu.setBackground(oldBG)
end

local function waitKeypadInput(char,display,color)
    local displayState = 1
    local keyTable = {}
    for i1=1, 12 do
        table.insert(keyTable,char)
    end
    keypad.setKey(keyTable)
    repeat
        keypad.setDisplay(display[displayState],color)
        stat = event.pull(1,"keypad")
        if displayState < #display then
            displayState = displayState+1
        else
            displayState = 1
        end
    until stat
end

local function makeBox(x,y,x1,y1,fg,bg)
    local oldBG = gpu.getBackground()
    local oldFG = gpu.getForeground()

    if fg ~= nil then
        gpu.setForeground(fg)
    end
    if bg ~= nil then
        gpu.setBackground(bg)
        gpu.fill(x+1,y+1,(x+x1)-2,(y+y1)-2," ")
    end

    gpu.fill(x,y,x1,1,"═")
    gpu.fill(x,(y+y1)-1,x1,1,"═")
    gpu.fill(x,y,1,y1,"│")
    gpu.fill((x+x1)-1,y,1,y1,"│")

    qw(x,y,"╒")
    qw((x+x1)-1,y,"╕")
    qw(x,(y+y1)-1,"╘")
    qw((x+x1)-1,(y+y1)-1,"╛")
    gpu.setForeground(oldFG)
    gpu.setBackground(oldBG)
end

local function print2(text)
    local currX,currY = t.getCursor()
    local baseX = currX
    for i1=1, text:len() do
        local currX,currY = t.getCursor()
        if text:sub(i1,i1) == "\n" then
            t.setCursor(baseX,currY+1)
        else
            t.write(text:sub(i1,i1))
        end
    end
    t.setCursor(baseX,currY+1)
end


oldX,oldY = gpu.getResolution()

tables = {
    {x=4,y=2},
    {x=4,y=4},
    {x=4,y=6},
    {x=11,y=2},
    {x=11,y=4},
    {x=11,y=6}
}

menu1 = {
    {
        name="Cooked Potato",
        count=8,
        price=8
    },
    {
        name="Cooked Beef",
        count=4,
        price=10
    },
    {
        name="Bolognese Spaghettis",
        count=2,
        price=12
    }
}

stat, err = pcall(function()
    t.clear()
    gpu.setResolution(14,7)

    -- Outside Box

    waitKeypadInput("▒",{"Press","To","Order"},0xA)

    gpu.fill(1,1,14,1,"═")
    gpu.fill(1,7,14,1,"═")
    gpu.fill(1,1,1,7,"│")
    gpu.fill(14,1,1,7,"│")

    qw(1,1,"╒")
    qw(14,1,"╕")
    qw(1,7,"╘")
    qw(14,7,"╛")

    -- Table Interface

    qw(4,2,"1",0xFFFFFF,0xFF0000) qw(11,2,"4",0xFFFFFF,0xFF0000)

    qw(4,4,"2",0xFFFFFF,0xFF0000) qw(11,4,"5",0xFFFFFF,0xFF0000)

    qw(4,6,"3",0xFFFFFF,0xFF0000) qw(11,6,"6",0xFFFFFF,0xFF0000)

    -- Entrance

    qw(6,7,"    ",0x00FF00)

    -- Carpet
    
    makeBox(7,2,2,6,0xFF4444)

    keypad.setDisplay("Table N°",0xB)
    for i1=1, 6 do
        keypad.setKey({
            "1","|","4",
            "2","#","5",
            "3","|","6",
            "","","",
        })
    end
    _, _, _, table_num = event.pull("keypad")
    table_num = tonumber(table_num)
    if table_num == nil or tablenum == 0 or table_num > 6 then
        keypad.setDisplay("ERROR",0xC)
        transition(2,0xFF0000,0x000000,0.1)
        return
    end
    qw(tables[table_num]["x"],tables[table_num]["y"],tostring(table_num),0xFFFFFF,0x00DD00)
    keypad.setDisplay("Table "..tostring(table_num))
    os.sleep(1)
    transition(2,0x00FF00,0x000000,0.1)
    gpu.setResolution(100,50)
    makeBox(1,1,100,50)
    t.setCursor(3,2)
    print2("Hello! Please select your order\n ")
    for k,v in pairs(menu1) do
        print2("{"..k.."} "..v["count"].."x "..v["name"].." Price: "..v["price"].." diamonds.")
    end
end)

if stat then
    waitKeypadInput("▒",{"Press","To","Exit"},0xC)
    keypad.setDisplay("-----")
end

t.clear()
gpu.setResolution(oldX,oldY)

if not stat then print(err) end