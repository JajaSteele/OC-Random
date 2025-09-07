local component = require("component")
local term = require("term")
local event = require("event")
local g = component.gpu

local function hex_to_rgb(hex)
    local r = (hex >> 16) & 0xFF
    local g = (hex >> 8) & 0xFF
    local b = hex & 0xFF
    return r, g, b
end

local function rgb_to_hex(r, g, b)
    return (r << 16) | (g << 8) | b
end

local function desaturate(hex, factor)
    local r, g, b = hex_to_rgb(hex)

    -- Simple grayscale (average)
    local gray = math.floor((r + g + b) / 3 + 0.5)

    -- Blend toward gray
    r = math.floor(r + (gray - r) * factor + 0.5)
    g = math.floor(g + (gray - g) * factor + 0.5)
    b = math.floor(b + (gray - b) * factor + 0.5)

    return rgb_to_hex(r, g, b)
end

local function write(x,y, text, fg, bg)
    local old_x, old_y = term.getCursor()

    local old_fg = g.getForeground()
    local old_bg = g.getBackground()

    if fg then
        g.setForeground(fg)
    end
    if bg then
        g.setBackground(bg)
    end

    term.setCursor(x,y)
    term.write(text)
    local new_x, new_y = term.getCursor()
    term.setCursor(old_x, old_y)

    g.setForeground(old_fg)
    g.setBackground(old_bg)
    return new_x, new_y
end

local function fill(x,y, x2,y2, bg, fg, char)
    local old_fg = g.getForeground()
    local old_bg = g.getBackground()

    if fg then
        g.setForeground(fg)
    end
    if bg then
        g.setBackground(bg)
    end

    g.fill(x,y, (x2-x)+1, (y2-y)+1, char or " ")

    g.setForeground(old_fg)
    g.setBackground(old_bg)
end

local comp_list = component.list()

local comp_data = {}
for k, v in pairs(comp_list) do
    comp_data[v] = component[v]
end

local width,height = g.getResolution()

local current = comp_data
local current_history = {}
local display_path = {}

local clickmap = {}

local color_map = {
    table = 0x662288,
    ["function"] = 0x885522,
    number = 0x116611,
    string = 0x224466,
    boolean = 0x882233
}


local scroll = 0

while true do
    fill(1,1, width, 3, 0xBBBBBB)
    fill(1,4,width,height, 0x959595)
    local last_path_x, last_path_y = 2,2
    last_path_x, last_path_y = write(last_path_x,last_path_y, "Current: ", 0x454545, 0xBBBBBB)
    for k,v in ipairs(display_path) do
        last_path_x, last_path_y = write(last_path_x,last_path_y, v, 0x454578, 0xBBBBBB)
        if k ~= #display_path then
            last_path_x, last_path_y = write(last_path_x,last_path_y, "/", 0x000033, 0xBBBBBB)
        end
    end
    local pos = 0
    clickmap = {}
    local current_sorted = {}
    for k,v in pairs(current) do
        current_sorted[#current_sorted+1] = {
            key=k,  
            value=v
        }
    end
    table.sort(current_sorted, function (a, b)
        return a.key < b.key
    end)
    for sort_k,sort_v in ipairs(current_sorted) do
        local v = sort_v.value
        local k = sort_v.key
        local last_x,last_y = write(3, 5+pos, k, 0x222222, 0x959595)
        local last_x,last_y = write(last_x+1, last_y, type(v), 0x454545, 0x959595)
        if type(v) == "table" then
            if type((getmetatable(v) or {}).__call) == "function" then
                clickmap[last_y] = {
                    type="setCurrentFunc",
                    value=v,
                    display=k
                }
                write(last_x+1, last_y, "(Function)", color_map["function"], 0x959595)
            else
                clickmap[last_y] = {
                    type="setCurrent",
                    value=v,
                    display=k
                }
                local count = 0
                for _ in pairs(v) do
                    count=count+1
                end
                write(last_x+1, last_y, "("..count..")", color_map.table, 0x959595)
            end
        elseif type(v) == "number" then
            write(last_x+1, last_y, "("..v..")", color_map.number, 0x959595)
        elseif type(v) == "string" then
            write(last_x+1, last_y, "("..v..")", color_map.string, 0x959595)
        elseif type(v) == "boolean" then
            write(last_x+1, last_y, "("..(v and "True" or "False")..")", color_map.boolean, 0x959595)
        end
        pos = pos+1
        if pos > height-6 then
            break
        end
    end
    local ev_data = {event.pull()}

    if ev_data[1] == "touch" then
        local name, addr, click_x, click_y, click_b, user = table.unpack(ev_data)
        local click = clickmap[click_y]
        if click_b == 0 then
            if click then
                if click.type == "setCurrent" and click.value then
                    current_history[#current_history+1] = current
                    current = click.value
                    display_path[#display_path+1] = click.display
                elseif click.type == "setCurrentFunc" and click.value then
                    current_history[#current_history+1] = current
                    local func_data = {pcall(click.value)}
                    if func_data[1] then
                        table.remove(func_data, 1)
                        current = func_data
                    else
                        component.computer.beep(100, 0.125)
                        current = {
                            func_data[2],
                            "THIS IS NOT WHAT THE FUNCTION RETURNED",
                            "THIS ONLY EXISTS TO SHOW THE ERROR",
                        }
                    end
                    display_path[#display_path+1] = click.display.."()"
                end
            end
        elseif click_b == 1 then
            if #current_history > 0 then
                current = table.remove(current_history, #current_history)
                table.remove(display_path, #display_path)
            else
                component.computer.beep(100, 0.125)
            end
        end
    end
end