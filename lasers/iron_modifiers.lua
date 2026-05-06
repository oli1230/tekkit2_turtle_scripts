local chest = peripheral.wrap("bottom")
local f = fs.open("dump.txt", "w")
for slot, item in pairs(chest.list()) do
    if item.name == "buildcraftsilicon:plug_gate" then
        local meta = chest.getItemMeta(slot)
        f.writeLine(slot .. ": " .. tostring(meta.displayName) .. " | nbt=" .. tostring(meta.nbtHash))
    end
end
f.close()
print("Done! Read with: edit dump.txt")