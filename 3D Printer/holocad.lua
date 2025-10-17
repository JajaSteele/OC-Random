local fs = require("filesystem")
local component = require("component")
local inv
local holo = component.hologram
local printer = component.printer3d

local ser = require("serialization")
local event = require("event")
local thread = require("thread")
local kb = require("keyboard")
local computer = require("computer")

local save_fs = fs.proxy(computer.getBootAddress())

local disk
local drive
if component.isAvailable("disk_drive") then
    drive = component.disk_drive
    local disk_address = drive.media()
    if disk_address then
        disk = component.proxy(disk_address)
        save_fs = fs.proxy(disk_address)
    end
end

local term = require("term")
local screen = component.screen
local gpu = component.gpu

local glass

local function asyncBeep(freq, duration)
    thread.create(function()
        computer.beep(freq,duration)
    end)
end

local function glassCube(x1,y1,z1, x2, y2, z2, rgba)
    local gshape = glass.addCustom3D()
    gshape.setGLMODE("TRIANGLE_STRIP")
    gshape.setShading("SMOOTH")

    gshape.addColor(table.unpack(rgba))

    local vertices = {
        {x1,y1,z1},
        {x2,y1,z1},
        {x2,y2,z1},
        {x1,y2,z1},
        {x1,y1,z2},
        {x2,y1,z2},
        {x2,y2,z2},
        {x1,y2,z2},
    }
    local strips = {4, 5, 7, 6, 2, 5, 1, 4, 0, 7, 3, 2,   2, 0, 1, 3, 2}

    for k,v in ipairs(strips) do
        local vert = vertices[v+1]
        gshape.addVertex(table.unpack(vert))
    end

    return gshape
end

if component.isAvailable("glasses") then
    glass = component.glasses
    glass.startLinking()
end

local function clamp(x,min,max) if x > max then return max elseif x < min then return min else return x end end

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
    dotted_1 = 0x595959,
    dotted_2 = 0x424242,
    cube_selected = 0xFFFFFF,
    black = 0x000000,
    state_off = 0xFF5555,
    state_on = 0x66FF55,
    state_warn = 0xFFBB55,
}

local width, height = gpu.getResolution()

local selected_cube = 1
local show_state = "Off"
local file_name = ""
local save_exists = save_fs.exists("/.hc_models/"..file_name..".hc")
local floppy_mode = false
if disk then
    floppy_mode = true
end
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
holo.setPaletteColor(3, 0x88BBFF)

local nbt
local def

local enable_nbt_import = false

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

    enable_nbt_import = true
end

local drawBuffer = gpu.allocateBuffer(width, height)

local threads = {}
local buttons = {}
local text_boxes = {}

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

local function addTextBox(x,y, x2, y2, current_input, max_length, pattern_filter, start_func, enter_func, cancel_func, fg, bg)
    text_boxes[#text_boxes+1] = {
        coords={
            x1=x,
            y1=y,
            x2=x2,
            y2=y2
        },
        value=current_input,
        max_length=max_length,
        pattern_filter=pattern_filter,
        start_func=start_func,
        enter_func=enter_func,
        cancel_func=cancel_func,
        foreground=fg,
        background=bg
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
    if glass then
        glass.removeAll()
    end
    if err then
        DEBUG("Error:",err)
        print(err)
        --error(err)
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
                DEBUG("touch coords",x,y)

                for k, button in pairs(buttons) do
                    DEBUG("button coords",button.coords.x1, button.coords.y1, button.coords.x2, button.coords.y2)
                    if x >= button.coords.x1 and y >= button.coords.y1 then
                        if x <= button.coords.x2 and y <= button.coords.y2 then
                            local func = button.func
                            if func then func(b) end
                            break
                        end
                    end
                end

                for k, textbox in pairs(text_boxes) do
                    if x >= textbox.coords.x1 and y >= textbox.coords.y1 then
                        if x <= textbox.coords.x2 and y <= textbox.coords.y2 then
                            if textbox.start_func then textbox.start_func() end

                            local current_input = textbox.value or ""
                            event.push("hc_drawinput")

                            local function displayInput()
                                fill(textbox.coords.x1, textbox.coords.y1, math.max(textbox.coords.x2, textbox.coords.x1+textbox.max_length), textbox.coords.y2, textbox.background)
                                local lw = write(textbox.coords.x1, textbox.coords.y1, current_input, textbox.foreground, textbox.background)
                                write(lw, textbox.coords.y1, "_", 0x777777, textbox.background)
                            end
                            while true do
                                local ev = {event.pull()}
                                if ev[1] == "key_down" then
                                    local _, _, char_code, key_code = table.unpack(ev)
                                    local char = string.char(char_code):match(textbox.pattern_filter)

                                    if char and #current_input < textbox.max_length then
                                        DEBUG("char", char)
                                        current_input = current_input..char
                                    else
                                        DEBUG("key", key_code)
                                        if key_code == kb.keys.back then
                                            current_input = current_input:sub(1,-2)
                                        elseif key_code == kb.keys.enter then
                                            if textbox.enter_func then textbox.enter_func(current_input) end
                                            break
                                        elseif key_code == kb.keys.escape then

                                        end
                                    end
                                    displayInput()
                                elseif ev[1] == "touch" then
                                    if ev[5] == 1 then
                                        if textbox.cancel_func then textbox.cancel_func() end
                                        break
                                    end
                                elseif ev[1] == "hc_drawinput" then
                                    displayInput()
                                end
                            end
                            break
                        end
                    end
                end
            elseif ev[1] == "component_available" then
                if ev[2] == "inventory_controller" then
                    if not enable_nbt_import then
                        enable_nbt_import = true
                        inv = component.inventory_controller
                        event.push("hc_render")
                    end
                end
            elseif ev[1] == "component_unavailable" then
                if ev[2] == "inventory_controller" then
                    if enable_nbt_import then
                        enable_nbt_import = false
                        inv = nil
                        event.push("hc_render")
                    end
                end
            elseif ev[1] == "component_added" then
                if ev[3] == "filesystem" then
                    if drive and drive.media() == ev[2] then
                        if not disk then
                            local disk_addr = drive.media()
                            disk = component.proxy(disk_addr)
                            save_fs = fs.proxy(disk_addr)
                            save_exists = save_fs.exists("/.hc_models/"..file_name..".hc")
                            floppy_mode = true
                            event.push("hc_render")
                        end
                    end
                end
            elseif ev[1] == "component_removed" then
                if ev[3] == "filesystem" then
                    if drive and disk and disk.address == ev[2] then
                        disk = nil
                        save_fs = fs.proxy(computer.getBootAddress())
                        save_exists = save_fs.exists("/.hc_models/"..file_name..".hc")
                        floppy_mode = false
                        event.push("hc_render")
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
            text_boxes = {}
            gpu.setActiveBuffer(drawBuffer)

            fill(1,1,width,3,color.titlebar_bg,nil," ")
            fill(1,4,width,height,color.black,nil," ")
            write(2,2,"HoloCAD", color.titlebar_text1, color.titlebar_bg)

            fill(15, 1, 15, 3, color.titlebar_bg, color.dotted_1, "┆")
            fill(15, 4, 15, height, color.black, color.dotted_2, "┊")
            
            fill(width-42, 1, width-42, 3, color.titlebar_bg, color.dotted_1, "┆")
            fill(width-58, 1, width-58, 3, color.titlebar_bg, color.dotted_1, "┆")

            fill(16, height-5, width, height-5, color.black, color.dotted_2, "┄")

            local lw = write(17, height-4, "Button Mode: ", color.cubes_text1, color.black)
            local lw2 = write(lw, height-4, tostring(object_data.button_mode), (object_data.button_mode and color.state_on) or color.state_off, color.black)
            addButton(lw, height-4, lw2-1, height-4, function()
                object_data.button_mode = not object_data.button_mode
                event.push("hc_render")
            end)

            local lw = write(17, height-3, "Light Level: ", color.cubes_text1, color.black)
            local lw2 = write(lw, height-3, tostring(object_data.light_level), color.cube_selected, color.black)
            addTextBox(lw,height-3,lw2-1,height-3, tostring(object_data.light_level),2,"[%d]", 
                function()
                    fill(lw, height-3, lw2, height-3, color.cube_selected)
                    write(lw, height-3, tostring(object_data.light_level), color.cube_selected, color.black)
                end, 
                function(input) 
                    object_data.light_level = clamp(tonumber(input) or 0, 0, 15)
                    event.push("hc_render")
                end, 
                function()
                    event.push("hc_render")
                end, 
                color.cube_selected, color.black)

            local lw = write(17, height-2, "Redstone Level: ", color.cubes_text1, color.black)
            local lw2 = write(lw, height-2, tostring(object_data.redstone_level), color.cube_selected, color.black)
            addTextBox(lw,height-2,lw2-1,height-2, tostring(object_data.redstone_level),2,"[%d]", 
                function()
                    fill(lw, height-2, lw2, height-2, color.cube_selected)
                    write(lw, height-2, tostring(object_data.redstone_level), color.cube_selected, color.black)
                end, 
                function(input) 
                    object_data.redstone_level = clamp(tonumber(input) or 0, 0, 15)
                    event.push("hc_render")
                end, 
                function()
                    event.push("hc_render")
                end, 
                color.cube_selected, color.black)

            fill(36, height-4, 36, height-2, color.black, color.dotted_2, "┊")

            write(38, height-4, "Noclip per State", color.dotted_2, color.black)

            local lw = write(38, height-3, "Off: ", color.cubes_text1, color.black)
            local lw2 = write(lw, height-3, tostring(object_data.noclip.off), (object_data.noclip.off and color.state_on) or color.state_off, color.black)
            addButton(lw, height-3, lw2-1, height-3, function()
                object_data.noclip.off = not object_data.noclip.off
                event.push("hc_render")
            end)

            local lw = write(38, height-2, "On: ", color.cubes_text1, color.black)
            local lw2 = write(lw, height-2, tostring(object_data.noclip.on), (object_data.noclip.on and color.state_on) or color.state_off, color.black)
            addButton(lw, height-2, lw2-1, height-2, function()
                object_data.noclip.on = not object_data.noclip.on
                event.push("hc_render")
            end)

            fill(16, height-1, width, height-1, color.black, color.dotted_2, "┄")

            local state_text = "[View: "..show_state.."]"
            write(2,5, state_text, (show_state == "Off" and color.state_off) or color.state_on)
            addButton(2,5,2+#state_text,5,function()
                if show_state == "Off" then
                    show_state = "On"
                else
                    show_state = "Off"
                end
                event.push("hc_render")
            end)

            local print_text = "[Print]"
            write(width-7,2, print_text, color.state_on, color.titlebar_bg)
            addButton(width-7,2,width-1,2,function()
                asyncBeep(500,0.05)
                asyncBeep(800,0.075)
                printer.commit()
            end)

            local export_text = "[Export to Printer]"
            write(width-27,2, export_text, color.cube_selected, color.titlebar_bg)
            addButton(width-27,2,width-9,2,function()
                asyncBeep(500,0.1)
                printer.reset()

                for k, shapedata in pairs(object_data.shapes.off) do
                    local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.coords)
                    printer.addShape(x1,y1,z1,x2,y2,z2,shapedata.texture,false) 
                end
                for k, shapedata in pairs(object_data.shapes.on) do
                    local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.coords)
                    printer.addShape(x1,y1,z1,x2,y2,z2,shapedata.texture,true) 
                end

                printer.setLightLevel(object_data.light_level)
                printer.setRedstoneEmitter(object_data.redstone_level)
                printer.setCollidable((not object_data.noclip.off), (not object_data.noclip.on))
                printer.setButtonMode((object_data.button_mode))

                printer.setLabel(file_name)
            end)

            local import_text = "[Import NBT]"
            write(width-40,2, import_text, (enable_nbt_import and color.state_warn) or color.dotted_1, color.titlebar_bg)
            addButton(width-40,2,width-29,2,function()
                if enable_nbt_import and inv then
                    local stack = inv.getStackInSlot(1,1)
                    if stack and stack.name == "opencomputers:print" then
                        if not (nbt and def) then
                            pcall(function()
                                term.clear()
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
                            end)
                            event.queue("hc_render")
                            if not (nbt and def) then
                                asyncBeep(75,0.2)
                                return
                            end
                        end

                        local out = {}
                        def.gunzip({input = stack.tag, output = function(byte)out[#out+1]=string.char(byte)end, disable_crc=true})
                        local data = table.concat(out)
                        local data2 = nbt.decode(data, "plain")

                        object_data.shapes = {
                            on={},
                            off={}
                        }

                        for k, shapedata in pairs(data2.stateOff) do
                            local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.bounds)
                            object_data.shapes.off[#object_data.shapes.off+1] = {
                                texture=shapedata.texture,
                                coords={
                                    x1,
                                    y1,
                                    16-z2,
                                    x2,
                                    y2,
                                    16-z1,
                                }
                            }
                        end

                        for k, shapedata in pairs(data2.stateOn) do
                            local x1, y1, z1, x2, y2, z2 = table.unpack(shapedata.bounds)
                            object_data.shapes.on[#object_data.shapes.on+1] = {
                                texture=shapedata.texture,
                                coords={
                                    x1,
                                    y1,
                                    16-z2,
                                    x2,
                                    y2,
                                    16-z1,
                                }
                            }
                        end

                        object_data.light_level = data2.lightLevel
                        object_data.redstone_level = data2.redstoneLevel
                        object_data.button_mode = (data2.isButtonMode == 1)

                        object_data.noclip.on = data2.noclipOn == 1
                        object_data.noclip.off = data2.noclipOff == 1

                        if data2.label then
                            file_name = data2.label
                            save_exists = save_fs.exists("/.hc_models/"..file_name..".hc")
                        end

                        selected_cube = 1
                        asyncBeep(500,0.05)
                        asyncBeep(500,0.05)
                        event.push("hc_render")
                    else
                        asyncBeep(75,0.2)
                    end
                else
                    asyncBeep(75,0.2)
                end
            end)

            local load_text = "[Load]"
            write(width-49,2, load_text, (save_exists and color.state_on) or color.state_off, color.titlebar_bg)
            addButton(width-49,2,width-44,2,function()
                if #file_name > 0 and save_exists then
                    local file_io = save_fs.open("/.hc_models/"..file_name..".hc", "r")
                    if file_io then
                        local file_data = ""
                        repeat
                            local dat = save_fs.read(file_io, 2048)
                            file_data = file_data..(dat or "")
                        until not dat
                        save_fs.close(file_io)

                        local new_object = ser.unserialize(file_data)

                        object_data = new_object or object_data
                        asyncBeep(500,0.05)
                        asyncBeep(500,0.05)
                        event.push("hc_render")
                    else
                        asyncBeep(75, 0.2)
                    end
                else
                    asyncBeep(75, 0.2)
                end
            end)

            local save_text = "[Save]"
            write(width-56,2, save_text, ((#file_name == 0 or save_fs.isReadOnly()) and color.state_off) or (save_exists and color.state_warn) or color.state_on, color.titlebar_bg)
            addButton(width-56,2,width-51,2,function()
                if #file_name > 0 then
                    if save_fs.isReadOnly() then
                        asyncBeep(75,0.1)
                        return
                    end
                    asyncBeep(500,0.1)
                    if not save_fs.exists("/.hc_models") then
                        save_fs.makeDirectory("/.hc_models")
                    end
                    local file_io = save_fs.open("/.hc_models/"..file_name..".hc", "w")
                    if file_io then
                        save_fs.write(file_io, ser.serialize(object_data))
                        save_fs.close(file_io)
                        save_exists = save_fs.exists("/.hc_models/"..file_name..".hc")
                        event.push("hc_render")
                    else
                        asyncBeep(75, 0.2)
                    end
                end
            end)

            if disk then
                write(width-55, 3, "Floppy Mode", color.dotted_1, color.titlebar_bg)
            end

            if save_fs.isReadOnly() then
                write(width-55, 1, "Read-Only", color.dotted_1, color.titlebar_bg)
            end

            local lw = write(17,2,"Filename: [", color.titlebar_text1, color.titlebar_bg)
            local lw2
            if file_name and #file_name > 0 then
                lw2 = write(lw, 2, file_name, color.cube_selected, color.titlebar_bg)
            else
                lw2 = write(lw, 2, "No Name", color.state_off, color.titlebar_bg)
            end
            write(lw2,2,"]", color.titlebar_text1, color.titlebar_bg)
            addTextBox(lw,2,lw2-1,2,file_name or "",64,"[%w_]", 
                function()
                    fill(lw-1, 2, lw2, 2, color.titlebar_bg)
                    write(lw,2,file_name or "",color.cube_selected, color.titlebar_bg)
                end, 
                function(input) 
                    file_name = input
                    save_exists = save_fs.exists("/.hc_models/"..file_name..".hc")
                    event.push("hc_render")
                end, 
                function()
                    event.push("hc_render")
                end, 
                color.cube_selected, color.titlebar_bg)

            local masscopy_text = "[Copy to "..((show_state == "Off" and "On") or "Off").."]"
            write(2,height-2, masscopy_text, color.state_on, color.black)
            addButton(2,height-2,2+#masscopy_text,height-2,function()
                asyncBeep(500,0.1)
                local from
                local to
                if show_state == "Off" then
                    from = object_data.shapes.off
                    to = object_data.shapes.on
                elseif show_state == "On" then
                    from = object_data.shapes.on
                    to = object_data.shapes.off
                end

                for k, shape in pairs(from) do
                    to[#to+1] = {
                        texture=shape.texture,
                        coords={table.unpack(shape.coords)}
                    }
                end
            end)

            local add_text = "[Add Cube]"
            write(2,height-1, add_text, color.state_on, color.black)
            addButton(2,height-1,2+#add_text,height-1,function()
                asyncBeep(500,0.1)
                if show_state == "Off" then
                    object_data.shapes.off[#object_data.shapes.off+1] = {
                        texture="",
                        coords={
                            0,
                            0,
                            0,
                            1,
                            1,
                            1,
                        }
                    }

                    selected_cube = #object_data.shapes.off
                    event.push("hc_render")
                else
                    object_data.shapes.on[#object_data.shapes.on+1] = {
                        texture="",
                        coords={
                            0,
                            0,
                            0,
                            1,
                            1,
                            1,
                        }
                    }

                    selected_cube = #object_data.shapes.on
                    event.push("hc_render")
                end
            end)

            local shapes
            if show_state == "Off" then
                shapes = object_data.shapes.off
            elseif show_state == "On" then
                shapes = object_data.shapes.on
            end

            holo.setTranslation(1/3, 0.75, 0)
            holo.clear()
            local lx, ly = 2, 7
            if glass then
                glass.removeAll()
            end
            for k, shape in pairs(shapes) do
                local x,y
                local text = "Cube "..k
                local func = function(b)
                    if b == 0 then
                        selected_cube = k
                        event.push("hc_render")
                    elseif b == 1 then
                        asyncBeep(75, 0.1)
                        table.remove(shapes, k)

                        selected_cube = clamp(selected_cube, 1, #shapes)
                        event.push("hc_render")
                    end
                end
                local x1, y1, z1, x2, y2, z2 = table.unpack(shape.coords)
                if selected_cube == k then
                    x,y = write(lx+1,ly, text, color.cube_selected, color.black)
                    addButton(lx,ly, lx+#text-1,ly,func)

                    local lw = write(17, 5, "Texture: [", color.cubes_text1, color.black)
                    local lw2 = write(lw, 5, (#shape.texture > 0 and shape.texture) or "None", color.cube_selected, color.black)
                    addTextBox(lw,5,lw2,5,shape.texture,256,"[%w/_:%-]", 
                    function()
                        fill(lw-1, 5, lw2, 5, color.black)
                        write(lw,5,shape.texture,color.cube_selected, color.black)
                    end, 
                    function(input) 
                        shape.texture = input 
                        event.push("hc_render")
                    end, 
                    function()
                        event.push("hc_render")
                    end, 
                    color.cube_selected, color.black)
                    lw2 = write(lw2, 5, "]", color.cubes_text1, color.black)

                    local dupe_text = "[Duplicate Cube]"
                    write(16,height, dupe_text, color.cube_selected, color.black)
                    addButton(16,height,16+#dupe_text,height,function()
                        shapes[#shapes+1] = {
                            texture=shape.texture,
                            coords={table.unpack(shape.coords)}
                        }
                        selected_cube = #object_data.shapes.off
                        event.push("hc_render")
                    end)

                    local cancel_func = function() event.push("hc_render") end

                    write(17,6, "Coords:", color.cubes_text1, color.black)
                    write(19,7, "Min:", color.cubes_text1, color.black)
                    write(21,8, "X "..x1, color.cube_selected, color.black)
                    addTextBox(23,8,23+1,8, tostring(x1), 2, "%d", nil, function(input) shape.coords[1] = clamp(tonumber(input) or 0, 0, 16) event.push("hc_render") end, cancel_func, color.cube_selected, color.black)
                    write(21,9, "Y "..y1, color.cube_selected, color.black)
                    addTextBox(23,9,23+1,9, tostring(y1), 2, "%d", nil, function(input) shape.coords[2] = clamp(tonumber(input) or 0, 0, 16) event.push("hc_render") end, cancel_func, color.cube_selected, color.black)
                    write(21,10, "Z "..z1, color.cube_selected, color.black)
                    addTextBox(23,10,23+1,10, tostring(z1), 2, "%d", nil, function(input) shape.coords[3] = clamp(tonumber(input) or 0, 0, 16) event.push("hc_render") end, cancel_func, color.cube_selected, color.black)

                    write(19,11, "Max:", color.cubes_text1, color.black)
                    write(21,12, "X "..x2, color.cube_selected, color.black)
                    addTextBox(23,12,23+1,12, tostring(x2), 2, "%d", nil, function(input) shape.coords[4] = clamp(tonumber(input) or 0, 0, 16) event.push("hc_render") end, cancel_func, color.cube_selected, color.black)
                    write(21,13, "Y "..y2, color.cube_selected, color.black)
                    addTextBox(23,13,23+1,13, tostring(y2), 2, "%d", nil, function(input) shape.coords[5] = clamp(tonumber(input) or 0, 0, 16) event.push("hc_render") end, cancel_func, color.cube_selected, color.black)
                    write(21,14, "Z "..z2, color.cube_selected, color.black)
                    addTextBox(23,14,23+1,14, tostring(z2), 2, "%d", nil, function(input) shape.coords[6] = clamp(tonumber(input) or 0, 0, 16) event.push("hc_render") end, cancel_func, color.cube_selected, color.black)
                else
                    x,y = write(lx,ly, text, color.cubes_text1, color.black)
                    addButton(lx,ly, lx+#text-1,ly,func)
                end
                lx, ly = 2, y+1

                for x=x1+1, x2 do
                    for y=y1+1, y2 do
                        for z=z1+1, z2 do
                            holo.set(49-(x+16),y,z+16, ((selected_cube==k) and 2) or ((holo.get(49-(x+16),y,z+16) > 0) and 3) or 1)
                            --print(x,y,z)
                        end
                    end
                end
                
                if glass then
                    glassCube(z1/16, (y1/16)+1, x1/16, z2/16, (y2/16)+1, x2/16, (selected_cube == k and {1, 1, 0.5, 0.8}) or {1, 0.5, 0.5, 0.8})
                end

                if ly >= (height-3)-6 then
                    break
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

local stat, err = pcall(function ()
    thread.waitForAll(threads_only)
end)

quit(err)