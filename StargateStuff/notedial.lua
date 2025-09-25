local stat, err = pcall(function ()
    local nbt = require("nbt")
    local deflate = require("deflate")
end)

if not stat then
    print("Missing libraries")
    os.execute("wget https://raw.githubusercontent.com/JajaSteele/OC-Random/refs/heads/main/NBT%20Reader/deflate.lua /lib/jjs/deflate.lua")
    os.execute("wget https://raw.githubusercontent.com/JajaSteele/OC-Random/refs/heads/main/NBT%20Reader/nbt.lua /lib/jjs/nbt.lua")
end