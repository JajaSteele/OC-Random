local components = component.list()
local function getComp(filter_name)
    for address, name in pairs(components) do
        if name == filter_name then
            return component.proxy(address)
        end
    end
end
local function spaceValue(amount)
    local formatted = tostring(amount)
    local k
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
        if (k==0) then
            break
        end
    end
    return formatted
end

local gpu = getComp("gpu")
local screen = getComp("screen")
local internet = getComp("internet")

local log_lines = {}

gpu.bind(screen.address)

local width, height = gpu.maxResolution()
local ratio_x, ratio_y = screen.getAspectRatio()
local ratio = ratio_x/ratio_y
height = math.min(width,height,25)
width = math.min(math.floor(height*ratio)*2, width)

gpu.setResolution(width, height)
gpu.fill(1,1,width,height," ")

local file_list = {}
local cb = getComp("chat_box")

local function buildList(fs, path)
    local list = fs.list(path)
    if list == nil or #list == 0 then
        file_list[#file_list+1] = path
    end
    for k, obj in pairs(list or {}) do
        if fs.isDirectory(path.."/"..obj) then
            if path:sub(-1,-1) == "/" then
                path = path:match("(.+)/")
            end
            buildList(fs, path.."/"..obj)
            if cb then
                cb.say(path.."/"..obj)
            end
        else
            if path:sub(-1,-1) ~= "/" then
                path = path.."/"
            end
            file_list[#file_list+1] = path..obj
            if cb then
                cb.say(path..obj)
            end
        end
    end
end

local stages = {
    "Disk Selection",
    "Disk Confirmation",
    "Copying OS Files",
    "Installing 'notedial'",
}

local install_disk = component.proxy(computer.getBootAddress())
if not install_disk.isReadOnly() then
    install_disk.setLabel("NdT Installer")
end

local selected_disk
local stage = 1

local function copyToDrive(path,fs_tar)
    local source_path = path
    local tar_path = path:match("/OS(.+)")

    local last_path = "/"
    for dir in tar_path:gmatch("(.+)/") do
        fs_tar.makeDirectory(last_path..dir)
        last_path = last_path..dir.."/"
    end

    local source_io = install_disk.open(source_path, "r")
    local target_io = fs_tar.open(tar_path, "w")

    while true do
        local chunk = install_disk.read(source_io, 2048)
        if cb then
            cb.say(chunk)
        end
        if chunk then
            fs_tar.write(target_io, chunk)
        else
            break
        end
    end

    install_disk.close(source_io)
    fs_tar.close(target_io)
end

local function setStage(num)
    stage = num
    computer.pushSignal("render1")
end
local function setState(txt)
    gpu.fill(1,height,width,height," ")
    gpu.set(1,height,txt)
end

local disk_list = {}
for k,v in pairs(components) do
    if v == "filesystem" then
        local drive = component.proxy(k)
        local label = drive.getLabel()
        if label ~= "tmpfs" then
            disk_list[#disk_list+1] = {
                address = k,
                label = label,
                size = drive.spaceTotal(),
                used = drive.spaceUsed()
            }
        end
    end
end

local touch_map = {}

gpu.set(1,1, "Welcome to the automatic notedial installer")
setState("Scanning installation disk..")

buildList(install_disk, "/OS")
computer.beep(900, 0.25)

while true do
    local ev = {computer.pullSignal()}
    gpu.fill(1,2,width,2," ")
    gpu.set(1,2,stages[stage] or "Unknown Stage")
    
    if stage == 1 then
        gpu.fill(1,4,width,height-4," ")
        for i1=1, height-5 do
            local drive = disk_list[i1]
            if drive then
                gpu.set(3, 3+i1, drive.address:sub(1,3).." ("..(drive.label or "No Name")..") | Free Space: "..spaceValue((drive.size)-(drive.used)).." B")
                touch_map[3+i1] = drive.address
            end
        end
        if ev[1] == "touch" then
            local _, _, x, y, b = table.unpack(ev)
            local disk_address = touch_map[y]
            if disk_address then
                selected_disk = component.proxy(disk_address)
                setStage(2)
            end
        end
    elseif stage == 2 then
        gpu.fill(1,5,width,height-5," ")
        
        touch_map = {
            [7] = "yes",
            [8] = "no"
        }
        gpu.set(1,4, "Selected: "..selected_disk.address)
        gpu.set(1,5, "Space: "..spaceValue(selected_disk.spaceUsed()).." B / "..spaceValue(selected_disk.spaceTotal()).." B")
        gpu.set(1,6, "Confirm?")
        gpu.set(3,7, "Yes")
        gpu.set(3,8, "No")
        if ev[1] == "touch" then
            local _, _, x, y, b = table.unpack(ev)
            local choice = touch_map[y]
            if choice then
                if choice == "yes" then
                    setStage(3)
                elseif choice == "no" then
                    setStage(1)
                end
            end
        end
    elseif stage == 3 then
        while true do
            local curr_file = file_list[1]
            if not curr_file then
                break
            end
            setState(curr_file)
            copyToDrive(curr_file, selected_disk)
            table.remove(file_list, 1)
        end
        computer.beep(900, 0.25)
        setStage(4)
    elseif stage == 4 then
        local req = internet.request("https://raw.githubusercontent.com/JajaSteele/OC-Random/refs/heads/main/StargateStuff/notedial_touch.lua")
        setState("Requesting file from github")
        repeat

        until req.finishConnect()
        local rcode, rmsg, rhead = req.response()
        local size = tonumber(rhead["Content-Length"][1])

        local notedial_io = selected_disk.open("/home/notedial_touch.lua", "w")

        setState("Downloading file (0 B / "..spaceValue(size).." B)")
        local count = 0
        while true do
            local chunk, reason = req.read(size)
            if not chunk then
                if reason then
                    selected_disk.close(notedial_io)
                    setState("ERROR! "..reason)
                else
                    selected_disk.close(notedial_io)
                    setState("Download finished")
                end
                break
            elseif #chunk > 0 then
                count = count+#chunk
                selected_disk.write(notedial_io, chunk)
            end
            setState("Downloading file ("..spaceValue(count).." B / "..spaceValue(size).." B)")
        end
        computer.beep(900, 0.25)

        setState("Enabling auto-boot")
        local shrc_io = selected_disk.open("/home/.shrc", "w")
        selected_disk.write(shrc_io, "notedial_touch.lua")
        selected_disk.close(shrc_io)

        setStage(5)
    elseif stage == 5 then
        computer.setBootAddress(selected_disk.address)
        computer.shutdown(true)
    end
end