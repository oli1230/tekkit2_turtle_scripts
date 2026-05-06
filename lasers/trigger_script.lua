local TURTLE_IDS = { 1, 2, 3, 4, 5, 6, 7 }
local MESSAGE = "restock"
local SIGNAL_SIDE = "left"
local MODEM_SIDE = "top"

rednet.open(MODEM_SIDE)
print("Central computer ready.")
print("Step on pressure plate to trigger restock...")

while true do
    repeat
        sleep(0.5)
    until redstone.getInput(SIGNAL_SIDE)

    print("Triggered! Pinging turtles...")
    for _, id in ipairs(TURTLE_IDS) do
        rednet.send(id, MESSAGE)
        print("  -> Pinged turtle " .. id)
    end
    print("All turtles pinged.")

    repeat
        sleep(0.5)
    until not redstone.getInput(SIGNAL_SIDE)
    print("Ready for next trigger...")
end