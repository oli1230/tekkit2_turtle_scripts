local p = peripheral.wrap("left")
local mod = p.getModuleInSlot(1)
if mod then
    for k, v in pairs(mod) do
        print(tostring(k) .. " = " .. tostring(v))
    end
else
    print("No module in slot 1")
end