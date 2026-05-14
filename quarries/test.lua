local p = peripheral.wrap("left")

if p == nil then
    print("No peripheral found on the left!")
else
    print("Found peripheral: " .. peripheral.getType("left"))
    
    -- List available methods on this peripheral
    local methods = peripheral.getMethods("left")
    for _, method in ipairs(methods) do
        print(method)
    end
end