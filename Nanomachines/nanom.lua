local component = require("component")
local m = component.modem
local g = component.gpu
local sr = require("serialization")
local event = require("event")
local term = require("term")

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

function combinations(n, k, start, combo, result)
    if #combo == k then
        table.insert(result, {table.unpack(combo)})
        return
    end

    for i = start, n do
        table.insert(combo, i)
        combinations(n, k, i + 1, combo, result)
        table.remove(combo)
    end
end

-- Generate all boolean combinations of length n with between min_k and max_k true
function generate_boolean_combinations(n, min_k, max_k)
    local result = {}
    for k = min_k, max_k do
        local combos = {}
        combinations(n, k, 1, {}, combos)
        for _, combo in ipairs(combos) do
            local bools = {}
            for i = 1, n do
                bools[i] = false
            end
            for _, idx in ipairs(combo) do
                bools[idx] = true
            end
            table.insert(result, bools)
        end
    end
    return result
end

local function fetchEffects(effects)
    local real_effects = {}
        for t, e in effects:gmatch("[{]?(.-)%.(.-)[,}]") do
            real_effects[#real_effects+1] = t.."."..e
        end
    return real_effects
end

term.clear()
term.setCursor(1,1)

m.open(2)

m.broadcast(1, "nanomachines", "setResponsePort", 2)
print(event.pull(nil, "modem_message"))

m.broadcast(1, "nanomachines", "getTotalInputCount")
local _, _, _, _, _, _, _, totalInputs = event.pull(nil, "modem_message", nil, nil, 2, nil, "nanomachines")
m.broadcast(1, "nanomachines", "getMaxActiveInputs")
local _, _, _, _, _, _, _, maxActive = event.pull(nil, "modem_message", nil, nil, 2, nil, "nanomachines")

print("Total inputs: "..totalInputs)
print("Max active: "..maxActive)

m.broadcast(1, "nanomachines", "getActiveEffects")
print("1")
local _, _, _, _, _, _, _, currEffects = event.pull(nil, "modem_message", nil, nil, 2, nil, "nanomachines")
print("2")
currEffects = fetchEffects(currEffects)
if currEffects and #currEffects > -1 then
    print("Effects detected!")
    print("Clearing nanomachine inputs..")
    for i1=1, totalInputs do
        term.write(i1)
        m.broadcast(1, "nanomachines", "setInput", i1, false)
        term.write(".")
        event.pull(nil, "modem_message", nil, nil, 2, nil, "nanomachines", "input")
        term.write(".")
    end
    print("\nCleared")
end
print("3")

local proc_time = nil

local max_input_length = #tostring(totalInputs)

local input_poses = {
}
for i1=0, maxActive do
    input_poses[#input_poses+1] = 1 + totalInputs + 3 + (max_input_length*i1) + i1
end
local effect_pos = 1 + totalInputs + 3 + (maxActive*max_input_length) + (maxActive-1) + 3

local width,height = g.getResolution()

print("4")

local results = generate_boolean_combinations(totalInputs, 1, maxActive)
print("Total combinations:", #results)

local found_effects = {}
local separate_effects = {}
local effects_count = 0

local old_state = {}
for i1=1, 18 do
    old_state[#old_state+1] = false
end

local new_timer = os.time()*(1000/60/60)
local old_timer = new_timer

print("5")

local stat, err = pcall(function()
    for i = 1, #results do
        old_timer = new_timer
        new_timer = os.time()*(1000/60/60)
        proc_time = new_timer-old_timer

        g.fill(1,1, width, 2, " ")
        g.fill(1,3, width, 1, "═")
        write(1,1, "Nanomachines Auto-Tester")
        local last_x, last_y = write(1,2, "Progress: "..string.format("%.1f%%", ((i-1)/#results)*100).." ("..(i-1).."/"..#results..")", 0xBBBBBB)
        last_x, last_y = write(last_x+1, 2, " - Effects: "..effects_count, 0xBBBBBB)
        if proc_time then
            write(last_x+1, 2, " | ETA: "..string.format("%.0fs", ((#results-i)*proc_time)/20))
        end
        local diff_state = {}
        for j = 1, #results[i] do
            if results[i][j] ~= old_state[j] then
                diff_state[#diff_state+1] = {
                    num=j,
                    state=results[i][j]
                }
            end
        end
        if #diff_state > 0 then
            local solid_state = ""
            for k,v in ipairs(results[i]) do
                if v then
                    g.setForeground(0xFFFFFF)
                    term.write("1")
                else
                    if v ~= old_state[k] then
                        g.setForeground(0xBB7777)
                    else
                        g.setForeground(0x777777)
                    end
                    term.write("0")
                end
            end
            g.setForeground(0xFFFFFF)
            term.write(" | ")
            local input_count = 0
            for k,v in ipairs(diff_state) do
                input_count = input_count+1
                if v.state then
                    g.setForeground(0x00FF00)
                else
                    g.setForeground(0xFF0000)
                end
                term.setCursor(input_poses[input_count], ({term.getCursor()})[2])
                term.write(v.num.." ")
                m.broadcast(1, "nanomachines", "setInput", v.num, v.state)
                event.pull(nil, "modem_message", nil, nil, 2, nil, "nanomachines", "input")
                old_state[v.num] = v.state
            end
            m.broadcast(1, "nanomachines", "getActiveEffects")
            local _, _, _, _, _, _, _, effects = event.pull(nil, "modem_message", nil, nil, 2, nil, "nanomachines", "effects")
            local real_effects = fetchEffects(effects)
            term.setCursor(effect_pos-3, ({term.getCursor()})[2])
            g.setForeground(0xFFFFFF)
            term.write(" | ")
            term.write("("..#(real_effects or {})..") ")
            if real_effects and #real_effects > 0 then
                local solid_state = ""
                for k,v in ipairs(old_state) do
                    solid_state = solid_state .. (v and "1" or "0")
                end
                found_effects[#found_effects+1] = {
                    effects = table.concat(real_effects, "+"),
                    address = solid_state
                }
            end
            for k,v in ipairs(real_effects) do
                if separate_effects[v] then
                    separate_effects[v] = separate_effects[v] + 1
                    g.setForeground(0x777777)
                    term.write(v)
                    if k ~= #real_effects then
                        term.write(" + ")
                    end
                else
                    separate_effects[v] = 1
                    effects_count = effects_count + 1
                    g.setForeground(0x77BB77)
                    term.write(v)
                    if k ~= #real_effects then
                        term.write(" + ")
                    end
                    component.computer.beep(400, 0.1)
                end
            end
            g.setForeground(0xFFFFFF)
            term.write("\n")
        end
    end
end)

print("")
g.setForeground(0xFFFFFF)
print("Effects found: "..effects_count)

for k,v in pairs(separate_effects) do
    print("• "..k.." (x"..v..")")
end