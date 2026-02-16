local function getComp(name)
    local list = component.list()
    for k,v in pairs(list) do
        if v == name then
            return component.proxy(k)
        end
    end
end

local update_mode = false
local update_size = 0
local update_curr_size = 0
local update_chunks = {}
while true do
    local ev = {computer.pullSignal()}
    if ev[1] == "modem_message" then
        local mtype = ev[6]
        
        if mtype == "start_update" then
            update_mode = true
            update_chunks = {}
            update_size = ev[7]
        elseif mtype == "update_data" and update_mode then
            update_chunks[ev[7]] = ev[8]
            update_curr_size = update_curr_size + #ev[8]
            if update_curr_size >= update_size then
                update_mode = false
                local eeprom = getComp("eeprom")

                eeprom.set(table.concat(update_chunks))
                computer.shutdown(true)
            end
        end
    end
end