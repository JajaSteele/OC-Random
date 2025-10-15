local fs = require("filesystem")
local component = require("component")
local inv
local holo = component.hologram
local printer = component.printer3d

local ser = require("serialization")
local event = require("event")
local thread = require("thread")
local kb = require("keyboard")

local term = require("term")
local screen = component.screen
local gpu = component.gpu

local function DEBUG(...)
    if component.isAvailable("chat_box") then
        component.chat_box.setName("DEBUG")
        local txt = ""
        for k,v in ipairs({...}) do
            txt = txt .. tostring(v) .. "    "
        end
        component.chat_box.say(tostring(txt))
    end
end

local function write(x,y, text, fg, bg, clearLine)
    local old_x, old_y = term.getCursor()

    local old_fg = gpu.getForeground()
    local old_bg = gpu.getBackground()

    if fg then
        gpu.setForeground(fg)
    end
    if bg then
        gpu.setBackground(bg)
    end

    term.setCursor(x,y)
    if clearLine then
        term.clearLine()
    end
    term.setCursor(x,y)
    term.write(text, false)
    local new_x, new_y = term.getCursor()
    term.setCursor(old_x, old_y)

    gpu.setForeground(old_fg)
    gpu.setBackground(old_bg)
    return new_x, new_y
end

local function fill(x,y, x2,y2, bg, fg, char)
    local old_fg = gpu.getForeground()
    local old_bg = gpu.getBackground()

    if fg then
        gpu.setForeground(fg)
    end
    if bg then
        gpu.setBackground(bg)
    end

    gpu.fill(x,y, (x2-x)+1, (y2-y)+1, char or " ")

    gpu.setForeground(old_fg)
    gpu.setBackground(old_bg)
end

local color = {
    titlebar_bg=0x222222,
    titlebar_text1 = 0xCCCCCC,
    cubes_text1 = 0xAAAAAA,
    cube_selected = 0xFFFFFF,
    black = 0x000000
}

local width, height = gpu.getResolution()

local selected_cube = 1
local show_state = "Off"
local object_data = {
    shapes = {
        on={},
        off={}
    },
    light_level = 0,
    button_mode = false,
    redstone_level = 0,
    noclip = {
        on=false,
        off=false
    }
}

holo.setPaletteColor(1, 0xFF3333)
holo.setPaletteColor(2, 0x33FF33)
holo.setPaletteColor(3, 0x8888FF)

local nbt
local def

if component.isAvailable("inventory_controller") then
    if not fs.isDirectory("/lib/jjs") then
        print("Creating /lib/jjs directory..")
        fs.makeDirectory("/lib/jjs")
    end

    if not fs.exists("/lib/jjs/deflate.lua") then
        os.execute("wget https://raw.githubusercontent.com/JajaSteele/OC-Random/refs/heads/main/NBT%20Reader/deflate.lua /lib/jjs/deflate.lua")
    end
    if not fs.exists("/lib/jjs/nbt.lua") then
        os.execute("wget https://raw.githubusercontent.com/JajaSteele/OC-Random/refs/heads/main/NBT%20Reader/nbt.lua /lib/jjs/nbt.lua")
    end

    nbt = require("jjs/nbt")
    def = require("jjs/deflate")

    inv = component.inventory_controller

    local stack = inv.getStackInSlot(1,1)

    if stack then
        local out = {}

        def.gunzip({input = stack.tag,
                output = function(byte)out[#out+1]=string.char(byte)end,disable_crc=true})
        local data = table.concat(out)
        local data2 = nbt.decode(data, "plain")

        local shapeOff = data2.stateOff

        for k, shapedata in pairs(shapeOff) do
            local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.bounds)
            object_data.shapes.off[#object_data.shapes.off+1] = {
                texture=shapedata.texture,
                coords={
                    x1,
                    y1,
                    z1,
                    x2,
                    y2,
                    z2,
                }
            }
        end
        local shapeOn = data2.stateOn

        for k, shapedata in pairs(shapeOn) do
            local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.bounds)
            object_data.shapes.on[#object_data.shapes.on+1] = {
                texture=shapedata.texture,
                coords={
                    x1,
                    y1,
                    z1,
                    x2,
                    y2,
                    z2,
                }
            }
        end

        object_data.light_level = data2.lightLevel
        object_data.redstone_level = data2.redstoneLevel
        object_data.button_mode = (data2.isButtonMode == 1)

        object_data.noclip.on = data2.noclipOn
        object_data.noclip.off = data2.noclipOff
    end
end

local drawBuffer = gpu.allocateBuffer(width, height)

local threads = {}
local buttons = {}

local function addButton(x,y, x2, y2, func)
    buttons[#buttons+1] = {
        coords={
            x1=x,
            y1=y,
            x2=x2,
            y2=y2
        },
        func=func
    }
end

local function quit(err)
    for k,v in pairs(threads) do
        print("quitting thread "..k)
        pcall(function ()
            v:kill()
        end)
    end

    gpu.setActiveBuffer(0)
    gpu.freeBuffer(drawBuffer)
    term.clear()
    holo.clear()
    if err then
        error()
    else
        print("Program closed")
    end
end

local eventThread = thread.create(function ()
    local stat, err = pcall(function ()
        while true do
            local ev = {event.pull()}
            if ev[1] == "interrupted" then
                quit()
                break
            elseif ev[1] == "touch" then
                local _, _, x, y, b = table.unpack(ev)
                DEBUG(x,y)

                for k, button in pairs(buttons) do
                    DEBUG(button.coords.x1, button.coords.y1, button.coords.x2, button.coords.y2)
                    if x >= button.coords.x1 and y >= button.coords.y1 then
                        if x <= button.coords.x2 and y <= button.coords.y2 then
                            local func = button.func
                            if func then func(b) end
                        end
                    end
                end
            end
        end
    end)
    if not stat then
        quit(err or "")
    end
end)

threads.render = thread.create(function ()
    local stat, err = pcall(function ()
        while true do
            event.pull("hc_render")
            buttons = {}
            gpu.setActiveBuffer(drawBuffer)

            fill(1,1,width,3,color.titlebar_bg,nil," ")
            fill(1,4,width,height,color.black,nil," ")
            write(2,2,"HoloCAD", color.titlebar_text1, color.titlebar_bg)

            fill(15, 4, 15, height, color.black, color.cubes_text1, "┊")
            if show_state == "Off" then
                 
                holo.setTranslation(1/3, 0.75, 0)
                holo.clear()
                local lx, ly = 2, 5
                for k, shape in pairs(object_data.shapes.off) do
                    local x,y
                    local text = "Cube "..k
                    local func = function()
                        selected_cube = k
                        event.push("hc_render")
                    end
                    local x1, y1, z1, x2, y2, z2 = table.unpack(shape.coords)
                    if selected_cube == k then
                        x,y = write(lx+1,ly, text, color.cube_selected, color.black)
                        addButton(lx,ly, lx+#text-1,ly,func)

                        local lw = write(17, 5, "Texture: [", color.cubes_text1, color.black)
                        lw = write(lw, 5, shape.texture, color.cube_selected, color.black)
                        lw = write(lw, 5, "]", color.cubes_text1, color.black)

                        write(17,6, "Coords:", color.cubes_text1, color.black)
                        write(19,7, "Min:", color.cubes_text1, color.black)
                        write(21,8, "X "..x1, color.cube_selected, color.black)
                        write(21,9, "Y "..y1, color.cube_selected, color.black)
                        write(21,10, "Z "..z1, color.cube_selected, color.black)

                        write(19,11, "Max:", color.cubes_text1, color.black)
                        write(21,12, "X "..x2, color.cube_selected, color.black)
                        write(21,13, "Y "..y2, color.cube_selected, color.black)
                        write(21,14, "Z "..z2, color.cube_selected, color.black)
                    else
                        x,y = write(lx,ly, text, color.cubes_text1, color.black)
                        addButton(lx,ly, lx+#text-1,ly,func)
                    end
                    lx, ly = 2, y+1

                    for x=x1+1, x2 do
                        for y=y1+1, y2 do
                            for z=z1+1, z2 do
                                holo.set(x+16,y,z+16, ((selected_cube==k) and 2) or 1)
                                --print(x,y,z)
                            end
                        end
                    end
                end
            end

            gpu.bitblt(0, 1,1, width, height, drawBuffer, 1, 1)
            gpu.setActiveBuffer(0)
        end
    end)
    if not stat then
        quit(err or "")
    end
end)


local threads_only = {}
for k,v in pairs(threads) do
    threads_only[#threads_only+1] = v
end
threads_only[#threads_only+1] = eventThread
event.push("hc_render")
thread.waitForAll(threads_only)