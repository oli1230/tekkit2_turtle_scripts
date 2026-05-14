local p = peripheral.wrap("left")

-- Check how many slots/parts the chassis has
local parts = p.listParts()
for k, v in pairs(parts) do
    print(k, v)
end