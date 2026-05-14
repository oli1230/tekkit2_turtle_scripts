-- Try to wrap the peripheral to the left
local p = peripheral.wrap("left")

if p == nil then
    print("No peripheral found on the left!")
else
    print("Found peripheral: " .. peripheral.getType("left"))
    
    -- Find first item in turtle's inventory
    local slot = nil
    for i = 1, 16 do
        if turtle.getItemCount(i) > 0 then
            slot = i
            break
        end
    end
    
    if slot == nil then
        print("Turtle inventory is empty!")
    else
        turtle.select(slot)
        -- Drop into the peripheral (works for most inventory peripherals)
        turtle.dropLeft(1)
        print("Dropped 1 item from slot " .. slot .. " into peripheral.")
    end
end