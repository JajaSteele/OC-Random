local fs = require("filesystem")
local sides = require("sides")
local ser = require("serialization")
local comp = require("component")
local event = require("event")
local inv = comp.inventory_controller

local dhd = component.dhd
local sg = component.stargate

local symbolTypeNames = {
    [0] = "Milky Way",
    [1] = "Pegasus",
    [2] = "Universe",
}
local symbolIndex = {
    [0] = {
        [0] = "Sculptor",
        [1] = "Scorpius",
        [2] = "Centaurus",
        [3] = "Monoceros",
        [4] = "Point of Origin",
        [5] = "Pegasus",
        [6] = "Andromeda",
        [7] = "Serpens Caput",
        [8] = "Aries",
        [9] = "Libra",
        [10] = "Eridanus",
        [11] = "Leo Minor",
        [12] = "Hydra",
        [13] = "Sagittarius",
        [14] = "Sextans",
        [15] = "Scutum",
        [16] = "Pisces",
        [17] = "Virgo",
        [18] = "Bootes",
        [19] = "Auriga",
        [20] = "Corona Australis",
        [21] = "Gemini",
        [22] = "Leo",
        [23] = "Cetus",
        [24] = "Triangulum",
        [25] = "Aquarius",
        [26] = "Microscopium",
        [27] = "Equuleus",
        [28] = "Crater",
        [29] = "Perseus",
        [30] = "Cancer",
        [31] = "Norma",
        [32] = "Taurus",
        [33] = "Canis Minor",
        [34] = "Capricornus",
        [35] = "Lynx",
        [36] = "Orion",
        [37] = "Piscis Austrinus",
    },
    [1] = {
        [0] = "Danami",
        [1] = "Arami",
        [2] = "Setas",
        [3] = "Aldeni",
        [4] = "Aaxel",
        [5] = "Bydo",
        [6] = "Avoniv",
        [7] = "Ecrumig",
        [8] = "Laylox",
        [9] = "Ca Po",
        [10] = "Alura",
        [11] = "Lenchan",
        [12] = "Acjesis",
        [13] = "Dawnre",
        [14] = "Subido",
        [15] = "Zamilloz",
        [16] = "Recktic",
        [17] = "Robandus",
        [18] = "Unknow1",
        [19] = "Zeo",
        [20] = "Tahnan",
        [21] = "Elenami",
        [22] = "Hamlinto",
        [23] = "Salma",
        [24] = "Abrin",
        [25] = "Poco Re",
        [26] = "Hacemill",
        [27] = "Olavii",
        [28] = "Ramnon",
        [29] = "Unknow2",
        [30] = "Gilltin",
        [31] = "Sibbron",
        [32] = "Amiwill",
        [33] = "Illume",
        [34] = "Sandovi",
        [35] = "Baselai",
        [36] = "Once El",
        [37] = "Roehi",
    },
    [2] = {
        [1] = "Glyph 1",
        [2] = "Glyph 2",
        [3] = "Glyph 3",
        [4] = "Glyph 4",
        [5] = "Glyph 5",
        [6] = "Glyph 6",
        [7] = "Glyph 7",
        [8] = "Glyph 8",
        [9] = "Glyph 9",
        [10] = "Glyph 10",
        [11] = "Glyph 11",
        [12] = "Glyph 12",
        [13] = "Glyph 13",
        [14] = "Glyph 14",
        [15] = "Glyph 15",
        [16] = "Glyph 16",
        [17] = "Glyph 17",
        [18] = "Glyph 18",
        [19] = "Glyph 19",
        [20] = "Glyph 20",
        [21] = "Glyph 21",
        [22] = "Glyph 22",
        [23] = "Glyph 23",
        [24] = "Glyph 24",
        [25] = "Glyph 25",
        [26] = "Glyph 26",
        [27] = "Glyph 27",
        [28] = "Glyph 28",
        [29] = "Glyph 29",
        [30] = "Glyph 30",
        [31] = "Glyph 31",
        [32] = "Glyph 32",
        [33] = "Glyph 33",
        [34] = "Glyph 34",
        [35] = "Glyph 35",
        [36] = "Glyph 36",
    }
}

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

local nbt = require("jjs/nbt")
local def = require("jjs/deflate")

local function engageSymbol(symbol, forceSpin)
    if dhd and not forceSpin then
        dhd.pressButton(symbol)
        os.sleep(0.85)
    else
        sg.engageSymbol(symbol)
        event.pull(10, "stargate_spin_chevron_engaged")
    end
end

local function setIris(close)
    local state = sg.getIrisState()

    if close and (state == "OPENING" or state == "OPENED") then
        sg.toggleIris()
        event.pull(5, "stargate_iris_closed")
        return true
    elseif not close and (state == "CLOSING" or state == "CLOSED") then
        sg.toggleIris()
        event.pull(5, "stargate_iris_opened")
        return true
    end
    return false
end

local function decodeDialed(str)
    local dat = {}
    for symbol in str:gmatch("([%w%s]-), ") do
        dat[#dat+1] = symbol
    end
    return dat
end

local stack = inv.getStackInSlot(sides.top, 1)
if not stack then
    print("No item found\nIt must be in Slot 1 of the inventory above the adapter.")
    return
end
local tag = stack.tag

local out = {}
def.gunzip({input = tag,
        output = function(byte)out[#out+1]=string.char(byte)end,disable_crc=true})

local data = table.concat(out)
local data2 = nbt.decode(data, "plain")

local symbol_type
local selected_address

if stack.name == "jsg:notebook" then
    local selected_num = data2.selected
    selected_address = data2.addressList[selected_num+1][2]
    symbol_type = selected_address.symbolType
elseif stack.name == "jsg:universe_dialer" and data2.mode == 1 then
    local selected_num = data2.selected
    selected_address = data2.saved[selected_num+1]
    symbol_type = selected_address.symbolType
elseif stack.name == "jsg:page_notebook" then
    selected_address = data2.address
    symbol_type = selected_address.symbolType
else
    print("Invalid item to scan!")
    return
end

local raw_address = {}
local i1 = 0
repeat
    local new_symbol = selected_address["symbol"..i1]
    if new_symbol then raw_address[#raw_address+1] = new_symbol end
    i1 = i1+1
until not new_symbol

print("Detected "..(symbolTypeNames[symbol_type] or "UNKNOWN").." address with "..#raw_address.." symbols.")

local full_address = {}
for k,v in ipairs(raw_address) do
    full_address[#full_address+1] = symbolIndex[symbol_type][v]
end
print("Raw Address:")
print(table.concat(raw_address, ", "))
print("Full Address:")
print(table.concat(full_address, ", "))

if #decodeDialed(sg.dialedAddress) > 0 then
    sg.abortDialing()
    os.sleep(3)
end

print("Dialing..")
for k,v in ipairs(full_address) do
    engageSymbol(v)
end
engageSymbol("Point of Origin")

if not setIris(false) then
    os.sleep(1.5)
end

sg.engageGate()

print("Waiting for gate to disconnect..")
while true do
    local ev = {event.pull()}
    if ev[1] == "stargate_wormhole_closed_fully" then
        print("Gate disconnected, closing iris..")
        break
    elseif ev[1] == "stargate_failed" then
        print('Gate failure "'..ev[4]..'", closing iris..')
        os.sleep(3)
        break
    end
end

setIris(true)

print("Goodbye.")

--for line in display:gmatch("(.-)\n") do
--    print(line)
--    event.pull(nil, "key_down")
--end