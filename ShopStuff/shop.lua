local event = require("event")
local thread = require("thread")
local cp = require("component")
local t = require("term")
local screen = cp.screen
local g = cp.gpu
local fs = cp.filesystem
local fs2 = require("filesystem")
local srz = require("serialization")
local tp = cp.transposer
local ct = require("computer")
local sides = require("sides")
local shell = require("shell")

local args = shell.parse(...)

if args[1] == "debug" then --Debug Mode
    cb = cp.chat_box
    dbs = true
    cb.say("Debug Mode Enabled!")
else
    dbs = false
end

stat, err = pcall(function()

    local function fstext(t1)
        g.setResolution(string.len(t1),1)
        t.setCursor(1,1)
        t.write(t1)
    end

    local function getres(v1)
        select(v1,g.getResolution())
    end

    local function dbc(t1)
        if dbs then
            cb.say(t1)
        end
    end

    local function getInvAmount(s1)
        inv_amount = 0
        for i1=1, tp.getInventorySize(s1) do
            inv_amount = inv_amount+tp.getSlotStackSize(s1,i1)
        end
        return inv_amount
    end

    local function writetxt(x1,y1,t1)
        oldX1,oldY1 = t.getCursor()
        t.setCursor(x1,y1)
        t.write(t1)
        t.setCursor(oldX1,oldY1)
    end

    local function rst_color()
        g.setForeground(0xFFFFFF)
        g.setBackground(0x000000)
    end

    local function reset_res(m1,m2)
        local maxX,maxY = g.maxResolution()
        g.setResolution(maxX*m1,maxY*m2)
    end

    local eg_pricelist = {
        minecraft___stone=5
    }

    if io.open("/home/data/pricelist.txt","r") ~= nil then
        pl_file1 = io.open("/home/data/pricelist.txt","r")
        pricelist = srz.unserialize(pl_file1:read("*a"))
        pl_file1:close()
    else
        dbc("pricelist file not found")
        if not fs2.isDirectory("/home/data") then
            dbc("data folder not found")
            fs2.makeDirectory("/home/data")
            dbc("created data folder")
        end
        pl_file1 = io.open("/home/data/pricelist.txt","w")
        pl_file1:write(srz.serialize(eg_pricelist))
        dbc("created example pricelist")
        pl_file1:close()

        pl_file2 = io.open("/home/data/pricelist.txt","r")
        pricelist = srz.unserialize(pl_file2:read("*a"))
        dbc("readed pricelist")
        pl_file2:close()
    end

    fstext("Welcome to the market! Insert coins to start")

    while tp.getSlotStackSize(sides.south,1) < 1 do
        os.sleep(0.05)
    end

    t.clear()
    g.setResolution(24,3)
    t.setCursor(1,1)
    t.write("Credits Amount: ")
    writetxt(1,2,"(Kinda slow to update)")
    writetxt(1,3,"Click screen to confirm")

    oldX , oldY = t.getCursor()

    state1 = 0

    handle1 = thread.create(function()
        event.pull("touch")
        ct.beep(600,0.05)
        ct.beep(600,0.05)
        ct.beep(800,0.1)
        state1 = 0
    end)

    state1 = 1

    while state1 == 1 do
        t.setCursor(oldX,oldY)
        amount1 = getInvAmount(sides.south)
        t.write(amount1..string.rep(" ",4-string.len(tostring(amount1))))
        os.sleep(0.05)
    end

    handle1:kill()

    t.clear()

    g.setResolution(80,28)

    local resx1, resy1 = g.getResolution()
    
    for i1=1, resy1 do
        if (i1 % 2 == 0) then
            g.setBackground(0x000000)
        else
            g.setBackground(0x111111)
        end
        g.fill(1,i1,resx1,1," ")
    end

    g.setForeground(0x000000)
    g.setBackground(0xDDDDDD)
    g.fill(1,1,resx1,1," ")

    maxLabel1 = 0

    inventory1 = {}
    for i1=1, tp.getInventorySize(sides.north) do
        i2 = i1+1
        local stack = tp.getStackInSlot(sides.north,i1)
        local resx1, resy1 = g.getResolution()
        g.setForeground(0x000000)
        g.setBackground(0xDDDDDD)
        t.setCursor(1,1)
        t.write(" Stock | Name")

        if i1 > resy1-1 then
            break
        end
        t.setCursor(2,i2)
        local char,fg,bg = g.get(1,i2)
        if stack ~= nil then
            g.setBackground(bg)
            g.setForeground(0xAAAAAA)
            t.write("x")
            t.write(stack["size"])

            t.setCursor(8,i2)
            g.setForeground(0xFFFFFF)
            t.write("| ")
            t.write(stack["label"])
            if string.len(stack["label"]) > maxLabel1 then
                maxLabel1 = string.len(stack["label"])
            end
            inventory1[string.gsub(stack["name"],":","___")] = i1
        else
            g.setForeground(0x666666)
            g.setBackground(bg)
            t.write("-----")
            g.setForeground(0xFFFFFF)
            t.write(" | ")
        end
    end

    for k,v in pairs(inventory1) do
        dbc(k.." Slot: "..v)
    end

    dbc(tostring(maxLabel1))

    for i1=1, tp.getInventorySize(sides.north) do
        i2 = i1+1
        t.setCursor(11+maxLabel1,i2)
        t.write("|")
        
        local char,fg,bg = g.get(1,i2)
        local stack = tp.getStackInSlot(sides.north,i1)
        local resx1, resy1 = g.getResolution()
        g.setBackground(0xdddddd)
        g.setForeground(0x000000)
        t.setCursor(11+maxLabel1,1)
        t.write("| Price ")

        if i1 > resy1-1 then
            break
        end

        g.setForeground(0xFFFFFF)
        g.setBackground(bg)
        t.setCursor(11+maxLabel1,i2)
        t.write("| ")
        
        if stack ~= nil then
            if pricelist[string.gsub(stack["name"],":","___")] ~= nil then
                price = pricelist[string.gsub(stack["name"],":","___")].." Credits"
            else
                price = " "
            end
        else
            price = " "
        end

        t.write(price)
    end

    for i1=1, tp.getInventorySize(sides.north) do
        g.setBackground(0xdddddd)
        g.setForeground(0x000000)
        t.setCursor(11+maxLabel1+12,1)
        t.write("| Purchasing")

        i2 = i1+1

        local char,fg,bg = g.get(1,i2)
        local stack = tp.getStackInSlot(sides.north,i1)
        local resx1, resy1 = g.getResolution()

        g.setForeground(0xFFFFFF)
        g.setBackground(bg)
        t.setCursor(11+maxLabel1+12,i2)
        t.write("| ")
        g.setForeground(0xAAAAAA)
        t.write("x")
        t.write("0")
        g.setForeground(0xFFFFFF)
    end

    g.setResolution(80,33)

    g.fill(1,29,80,1,"=")

    amount2 = 0

    for i1=1, (getInvAmount(sides.south)/64)+1 do
        amount2 = amount2+tp.transferItem(sides.south,sides.east)
    end

    used_amount1 = 0

    cart1 = {}

    while true do
        t.setCursor(1,30)
        amount3 = 0
        for k,v in pairs(cart1) do
            if v ~= nil then
                amount3 = amount3+v
            end
        end
        t.write("Available Credits: "..(amount2-used_amount1).."     \n")
        t.write("Total Price: "..used_amount1.."     \n")
        t.write("Items in cart: "..amount3.."     \n")
        g.setForeground(0x00FF33)
        t.write("Click here to purchase (or cancel if empty cart)")
        g.setForeground(0xFFFFFF)

        _, _, t_x1, t_y1, t_b1, t_pl1 = event.pull("touch")

        dbc("Clicked")

        if t_y1 == 33 then
            if cart1 ~= nil then
                ct.beep(800,0.05)
                ct.beep(800,0.05)
                ct.beep(800,0.05)
                for k,v in pairs(cart1) do
                    if v > 0 then
                        amount4 = tp.transferItem(sides.north,sides.up,v,inventory1[k])
                        tp.transferItem(sides.east,sides.down,amount4*pricelist[k])
                    end
                end
                res2 = 0
                for i1=1, tp.getInventorySize(sides.east) do
                    res1 = tp.transferItem(sides.east,sides.top)
                    if res1 == 0 then
                        res2 = res2+1
                    end
                    if res2 == 3 then
                        break
                    end
                end
                res2 = 0
                for i1=1, tp.getInventorySize(sides.south) do
                    res1 = tp.transferItem(sides.south,sides.top)
                    if res1 == 0 then
                        res2 = res2+1
                    end
                    if res2 == 3 then
                        break
                    end
                end
                ct.beep(500,0.05)
                break
            end
        end

        if (t_y1-1) <= tp.getInventorySize(sides.north) and (t_y1-1) ~= 0 then
            stack = tp.getStackInSlot(sides.north,t_y1-1)
            dbc("Valid Stack")
        else
            stack = nil
            dbc("Out of Bound")
        end

        if stack ~= nil then
            dbc("Stack isn't nil")
            if t_b1 == 0 then
                dbc("Left Click")
                if pricelist[string.gsub(stack["name"],":","___")] <= amount2-used_amount1 then
                    item_name1 = string.gsub(stack["name"],":","___")
                    if cart1[item_name1] == nil then
                        cart1[item_name1] = 0
                    end
                    cart1[item_name1] = cart1[item_name1]+1
                    local char,fg,bg = g.get(11+maxLabel1+14,t_y1)
                    g.setBackground(bg)
                    t.setCursor(11+maxLabel1+12,t_y1)
                    t.write("| ")
                    g.setForeground(fg)
                    t.write("x"..cart1[item_name1])
                    rst_color()
                    used_amount1 = (used_amount1+pricelist[string.gsub(stack["name"],":","___")])
                    ct.beep(800,0.05)
                else
                    ct.beep(100,0.2)
                end
            end
            if t_b1 == 1 then
                dbc("Right Click")
                if pricelist[string.gsub(stack["name"],":","___")] <= used_amount1 then
                    item_name1 = string.gsub(stack["name"],":","___")
                    if cart1[item_name1] ~= nil then
                        if cart1[item_name1] > 0 then
                            used_amount1 = (used_amount1-pricelist[string.gsub(stack["name"],":","___")])
                            cart1[item_name1] = cart1[item_name1]-1
                            local char,fg,bg = g.get(11+maxLabel1+14,t_y1)
                            g.setBackground(bg)
                            t.setCursor(11+maxLabel1+12,t_y1)
                            t.write("| ")
                            g.setForeground(fg)
                            t.write("x"..cart1[item_name1])
                            rst_color()
                            ct.beep(200,0.05)
                        else
                            ct.beep(100,0.2)
                        end
                    else
                        ct.beep(100,0.2)
                    end
                else
                    ct.beep(100,0.2)
                end
            end
        end
    end

    os.sleep(0.5)
    ct.shutdown(true)
    
end)

g.setResolution(g.maxResolution())

if not stat then
    t.clear()
    t.setCursor(1,1)
    print(err)
    if err == "interrupted" then
        ct.beep(500,0.25)
        component = require("component")
        gpu = component.gpu
        gpu.setResolution(38,1)
        term = require("term")
        term.setCursor(1,1)
        term.write("Do not terminate this program dumbass")
        os.sleep(2)
        ct.shutdown(true)
    end
end