local component = require("component")
local t = require("term")
local gpu = component.gpu
local event = require("event")
local keypad = component.os_keypad
local printer = component.openprinter
local computer = require("computer")

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
        stat = event.pull(0.5,"keypad")
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
    local oldColor = gpu.getForeground()
    local IDColor = false
    for i1=1, text:len() do
        local currX,currY = t.getCursor()
        char = text:sub(i1,i1)
        if char == "\n" then
            t.setCursor(baseX,currY+1)
        else
            if char == "(" then
                gpu.setForeground(0xFF4444)
            elseif text:sub(i1-1,i1-1) == ")" then
                gpu.setForeground(oldColor)
            end
            if char == "#" then
                gpu.setForeground(0x336DFF)
                IDColor = true
            elseif char == " " and IDColor == true then
                gpu.setForeground(oldColor)
                IDColor = false
            end
            t.write(char)
            if char == ")" and i1 == text:len() then
                gpu.setForeground(oldColor)
            end
        end
    end
    t.setCursor(baseX,currY+1)
end

local function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

local function printerWrite(text)
    local text2 = split(text," ")
    local textprint = ""
    for i1=1, #text2 do
        textprint2 = textprint.." "..text2[i1]
        if textprint2:len() <= 30 then
            textprint = textprint2
        else
            printer.writeln(textprint)
            textprint = text2[i1]
        end
    end
    printer.writeln(textprint)
end

local function printerWriteColor(text,color)
    local text2 = split(text," ")
    local textprint = ""
    for i1=1, #text2 do
        textprint2 = textprint.." "..text2[i1]
        if textprint2:len() <= 30 then
            textprint = textprint2
        else
            printer.writeln(textprint)
            textprint = color..text2[i1]
        end
    end
    printer.writeln(textprint)
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
        name="Creeper Cookies",
        count=32,
        price=16
    },
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
        name="Sandwich (Type specified later)",
        count=4,
        price=14
    },
    {
        name="Fried Chicken Bucket",
        count=3,
        price=16
    },
    {
        name="Bolognese Spaghettis",
        count=2,
        price=12
    },
    {
        name="Gourmet Beef Burger",
        count=1,
        price=32
    },
    {
        name="Southern Breakfast",
        count=1,
        price=32
    },
    {
        name="Chocolate Cake",
        count=1,
        price=32
    },
    {
        name="Christmas Cake",
        count=1,
        price=32
    },
    {
        name="Red Velvet Cake",
        count=1,
        price=32
    },
    {
        name="Fruit Juice (Flavor specified later)",
        count=1,
        price=8
    },
    {
        name="Hot Chocolate",
        count=1,
        price=8
    },
    {
        name="Coffee",
        count=1,
        price=8
    },
    {
        name="Ice Cream (Flavor specified later)",
        count=1,
        price=8
    },
}

while true do
    stat, err = pcall(function()
        t.clear()
        gpu.setResolution(14,7)

        makeBox(1,1,14,7,0xBBFFBB)

        waitKeypadInput("▒",{"Press","To","Start"},0xA)

        -- Outside Box

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
        if table_num == "#" then
            keypad.setDisplay("Code?",0xB)
            keypad.setKey({
                "1","2","3",
                "4","5","6",
                "7","8","9",
                "X","0","",
            })
            code = ""
            while true do
                _, _, _, pressed = event.pull("keypad")
                if pressed == "X" then break end
                code = code..pressed
                if code == "270706" then
                    bypass = true
                    return
                end
            end
        end
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
        gpu.setResolution(70,35)
        makeBox(1,1,70,35)
        t.setCursor(3,2)
        print2("Hello! Please select your order\n ")
        for k,v in pairs(menu1) do
            print2("#"..k.." "..v["count"].."x "..v["name"].." Price: "..v["price"].." diamonds.")
        end
        order = {}
        order_price = 0
        while true do
            new_food = ""
            keypad.setKey({
                "1","2","3",
                "4","5","6",
                "7","8","9",
                "X","0","V",
            })
            while true do
                if new_food == "" then
                    keypad.setDisplay("Food ID",0xA)
                else
                    keypad.setDisplay(new_food,0x6)
                end
                _, _, _, food_num = event.pull("keypad")
                if food_num == "V" then
                    break
                elseif food_num == "X" then
                    if new_food:len() > 0 then
                        new_food = new_food:sub(1,new_food:len()-1)
                    else
                        keypad.setDisplay("Exit?",0xC)
                        keypad.setKey({
                            "","","",
                            "X","|","V",
                            "","","",
                            "","","",
                        })
                        _, _, _, confirm = event.pull("keypad")
                        if confirm == "V" then return end
                    end
                else
                    new_food = new_food..food_num
                end
            end
            new_food = tonumber(new_food)
            if new_food == 270706 then
                bypass = true
                return
            end
            if menu1[new_food] ~= nil then
                keypad.setKey({
                    "","","",
                    "","","",
                    "","","",
                    "","","",
                })
                food = menu1[new_food]
                keypad.setDisplay("+"..food["price"].."D",0xA)
                table.insert(order,food["count"].."x "..food["name"])
                order_price = order_price+food["price"]
                qw(3,34,"Added "..order[#order])
                qw(5,35,"Total Price: "..order_price.." diamonds. Order Size: "..#order)
                os.sleep(0.425)
            elseif food_num == "V" then
                keypad.setDisplay("Confirm?",0xC)
                keypad.setKey({
                    "","","",
                    "X","|","V",
                    "","","",
                    "","","",
                })
                _, _, _, confirm = event.pull("keypad")
                if confirm == "V" then break end
            end
        end
        if order[1] ~= nil then
            t.clear()
            gpu.setResolution(70,35)
            makeBox(1,1,70,35)
            t.setCursor(3,2)
            printer.setTitle("Table N°"..table_num.." ID"..math.random(10,99))
            printerWriteColor("§nTable N°"..table_num,"§8")
            printerWriteColor("","§8")
            print2("Order Sent! Preview:")
            for k,v in pairs(order) do
                printerWriteColor("- §8"..v,"§8    ")
                print2("- "..v)
            end
            print2("\nTotal Price: "..order_price.." diamonds.")
            printer.print()
        end
    end)

    if stat then
        if bypass then
            keypad.setKey({
                "Cmd","","",
                "Shd","","",
                "Rst","","",
                "Prt","","",
            })
            keypad.setDisplay("BYPASS",0x6)
            _, _, _, bypass = event.pull("keypad")
            keypad.setDisplay("BYPASSED",0xC)
            if bypass == "Cmd" then
                bypass = true
            elseif bypass == "Shd" then
                computer.shutdown()
            elseif bypass == "Rst" then
                computer.shutdown(1)
            elseif bypass == "Prt" then
                printer.setTitle("§c!BYPASS! §fPRINTER TEST")
                for i1=1, 10 do
                    printer.writeln(tostring(math.random(1,999999999)))
                end
                printer.print()
                computer.shutdown(1)
            end
        else
            waitKeypadInput("▒",{"Press","To","Finish"},0xC)
        end
    end

    t.clear()
    gpu.setResolution(oldX,oldY)

    if bypass then break end

    if not stat then
        printer.setTitle("§cERROR")
        printer.writeln("§c"..err)
        if err == "interrupted" then
            printer.setTitle("§cERROR|ILLEGAL")
            players = component.radar.getPlayers(10)
            printer.writeln("§4§n§l!ILLEGAL TERMINATION!")
            printer.writeln("§cPlayer List:")
            for k,v in pairs(players) do
                printer.writeln("§6  §o-"..v["name"])
            end
        else
            printer.setTitle("§cERROR = "..err)
        end
        printer.print()
        computer.shutdown(1)
    end
end


