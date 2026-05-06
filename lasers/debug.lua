local chest = peripheral.wrap("bottom")
local f = fs.open("dump.txt", "w")
for slot, item in pairs(chest.list()) do
    local meta = chest.getItemMeta(slot)
    local display = meta and meta.displayName or "unknown"
    local damage = meta and meta.damage or 0
    local nbt = meta and tostring(meta.nbtHash) or "none"
    f.writeLine(slot .. ": [" .. item.name .. "] | " .. display .. " | dmg=" .. damage .. " | nbt=" .. nbt .. " | x" .. item.count)
end
f.close()
print("Done! Read with: edit dump.txt")