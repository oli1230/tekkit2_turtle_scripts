local p = peripheral.wrap("left")

-- Try commandHelp first
print("=== commandHelp ===")
local help = p.commandHelp()
if type(help) == "table" then
    for k, v in pairs(help) do
        print(tostring(k) .. " = " .. tostring(v))
    end
else
    print(tostring(help))
end