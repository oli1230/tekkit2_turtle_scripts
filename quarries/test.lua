local p = peripheral.wrap("left")

local parts = p.listParts()
for k, v in pairs(parts) do
    if type(v) == "table" then
        print("Slot " .. k .. ":")
        for k2, v2 in pairs(v) do
            print("  " .. tostring(k2) .. " = " .. tostring(v2))
        end
    else
        print(k, v)
    end
end