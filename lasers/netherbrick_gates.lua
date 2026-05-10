local STACK = 64
local TARGET_STACKS = 1
local TARGET = TARGET_STACKS * STACK
local WAIT_MISSING = 5
local WAIT_TABLE_FULL = 120
local MAX_RETRIES = 3
local MAX_CYCLES = 3
local TABLE_SLOTS = 12

local chest = peripheral.wrap("bottom")
local above = peripheral.wrap("top")
local above_name = peripheral.getName(above)
local CHIPSET = "buildcraftsilicon:redstone_chipset"
local GATE = "buildcraftsilicon:plug_gate"

local GATE_HASHES = {
    NB_OR_BASE    = "a198236e641734c124bf683ccb2090ac",
    NB_AND_BASE   = "6bdced001f5a15511abba6fc71e8e077",
    NB_OR_QUARTZ  = "4a45b1dfa638ae23bdbac52d8f8cf0ec",
    NB_OR_DIAMOND = "ca1fb5a0db11361af7739b5188418a27",
    NB_OR_LAPIS   = "bcc6bda130bd842550bd587d8947a291",
    NB_AND_QUARTZ  = "771997efcd84c7abdbcfe5ba16efa14a",
    NB_AND_DIAMOND = "b0b23a4ed9951036855ef76f732524b6",
    NB_AND_LAPIS   = "3aa178a63db23875244cb07e3d2b2537",
}

local items = {
    { name = "NB OR Quartz Gate",   type = "gate", nbt = GATE_HASHES.NB_OR_QUARTZ,  ingredients = {
        { id = GATE,    nbt = GATE_HASHES.NB_OR_BASE, qty = 1 },
        { id = CHIPSET, damage = 3, qty = 1 },
    }},
    { name = "NB OR Diamond Gate",  type = "gate", nbt = GATE_HASHES.NB_OR_DIAMOND, ingredients = {
        { id = GATE,    nbt = GATE_HASHES.NB_OR_BASE, qty = 1 },
        { id = CHIPSET, damage = 4, qty = 1 },
    }},
    { name = "NB OR Lapis Gate",    type = "gate", nbt = GATE_HASHES.NB_OR_LAPIS,   ingredients = {
        { id = GATE,    nbt = GATE_HASHES.NB_OR_BASE, qty = 1 },
        { id = "minecraft:dye", damage = 4, qty = 1 },
    }},
    { name = "NB AND Quartz Gate",  type = "gate", nbt = GATE_HASHES.NB_AND_QUARTZ, ingredients = {
        { id = GATE,    nbt = GATE_HASHES.NB_AND_BASE, qty = 1 },
        { id = CHIPSET, damage = 3, qty = 1 },
    }},
    { name = "NB AND Diamond Gate", type = "gate", nbt = GATE_HASHES.NB_AND_DIAMOND, ingredients = {
        { id = GATE,    nbt = GATE_HASHES.NB_AND_BASE, qty = 1 },
        { id = CHIPSET, damage = 4, qty = 1 },
    }},
    { name = "NB AND Lapis Gate",   type = "gate", nbt = GATE_HASHES.NB_AND_LAPIS,  ingredients = {
        { id = GATE,    nbt = GATE_HASHES.NB_AND_BASE, qty = 1 },
        { id = "minecraft:dye", damage = 4, qty = 1 },
    }},
}

local function matchesIngredient(meta, ing)
    if meta.name ~= ing.id then return false end
    if ing.nbt then
        return tostring(meta.nbtHash) == ing.nbt
    else
        return meta.damage == (ing.damage or 0)
    end
end

local function getIngKey(ing)
    if ing.nbt then
        return ing.id .. ":nbt:" .. ing.nbt
    else
        return ing.id .. ":" .. (ing.damage or 0)
    end
end

local function countItemIn(periph, ing)
    local total = 0
    for slot, item in pairs(periph.list()) do
        if item.name == ing.id then
            local meta = periph.getItemMeta(slot)
            if meta and matchesIngredient(meta, ing) then
                total = total + item.count
            end
        end
    end
    return total
end

local function countOutputs()
    local counts = {}
    for _, item in ipairs(items) do counts[item.name] = 0 end
    for slot, item in pairs(chest.list()) do
        if item.name == GATE then
            local meta = chest.getItemMeta(slot)
            for _, it in ipairs(items) do
                if it.type == "gate" and meta and tostring(meta.nbtHash) == it.nbt then
                    counts[it.name] = counts[it.name] + item.count
                end
            end
        end
    end
    return counts
end

local function isFullyStocked(counts)
    for _, item in ipairs(items) do
        if (counts[item.name] or 0) < TARGET then
            return false
        end
    end
    return true
end

local function getAvailableTableSlots()
    local used = 0
    for _ in pairs(above.list()) do used = used + 1 end
    return TABLE_SLOTS - used
end

local function findSlot(ing)
    for slot, item in pairs(chest.list()) do
        if item.name == ing.id then
            local meta = chest.getItemMeta(slot)
            if meta and matchesIngredient(meta, ing) then
                return slot
            end
        end
    end
    return nil
end

local function dumpTurtleInventory()
    for i = 1, 16 do
        if turtle.getItemDetail(i) then
            turtle.select(i)
            turtle.dropDown()
        end
    end
end

local function emptyAssemblyTable()
    for slot, item in pairs(above.list()) do
        above.pushItems(peripheral.getName(chest), slot, item.count)
    end
end

function runCycle()
    emptyAssemblyTable()
    local counts = countOutputs()
    if isFullyStocked(counts) then
        print("Already fully stocked, nothing to do.")
        return true
    end

    print("--- Checking stock ---")
    local missingRetries = 0

    for _, item in ipairs(items) do
        local have = counts[item.name] or 0
        print(item.name .. ": " .. have .. "/" .. TARGET)

        if have < TARGET then
            local slotsNeeded = #item.ingredients
            local availableSlots = getAvailableTableSlots()

            if slotsNeeded > availableSlots then
                print("  -> Not enough table slots for " .. item.name .. " (need " .. slotsNeeded .. " have " .. availableSlots .. "), stopping cycle.")
                break
            end

            local canPush = true
            local pushQtys = {}
            for _, ing in ipairs(item.ingredients) do
                local qty = ing.qty or 1
                local available = countItemIn(chest, ing)
                if available == 0 then
                    canPush = false
                    missingRetries = missingRetries + 1
                    print("  -> No " .. ing.id .. " available (" .. missingRetries .. "/" .. MAX_RETRIES .. ")")
                    if missingRetries >= MAX_RETRIES then
                        print("  -> Too many missing ingredient failures, stopping.")
                        return false
                    end
                    sleep(WAIT_MISSING)
                    break
                end
                local setsNeeded = TARGET - have
                local toPush = math.min(setsNeeded * qty, available, STACK)
                pushQtys[getIngKey(ing)] = { ing = ing, qty = toPush }
            end

            if canPush then
                for _, entry in pairs(pushQtys) do
                    local remaining = entry.qty
                    while remaining > 0 do
                        local slot = findSlot(entry.ing)
                        if slot then
                            local toPush = math.min(remaining, STACK)
                            print("  -> Pushing " .. toPush .. "x " .. entry.ing.id)
                            chest.pushItems(above_name, slot, toPush)
                            remaining = remaining - toPush
                        else
                            print("  -> Could not find " .. entry.ing.id .. " in chest!")
                            break
                        end
                    end
                end
                missingRetries = 0
            end
        end
    end

    -- Monitor for returning items
    print("Monitoring for returning items...")
    local clearCount = 0
    repeat
        sleep(7)
        local hasOutput = false
        for i = 1, 16 do
            local detail = turtle.getItemDetail(i)
            if detail and detail.name == GATE then
                hasOutput = true
                break
            end
        end
        if hasOutput then
            print("Items returning, dumping and resetting timer...")
            dumpTurtleInventory()
            clearCount = 0
        else
            clearCount = clearCount + 1
            print("Clear check " .. clearCount .. "/3")
            dumpTurtleInventory()
        end
    until clearCount >= 3

    local finalCounts = countOutputs()
    return isFullyStocked(finalCounts)
end

-- Main loop
rednet.open("right")
print("Turtle ID: " .. os.getComputerID())
print("Listening for rednet trigger...")

while true do
    local senderID, message = rednet.receive()
    print("Triggered by ID " .. senderID .. ": " .. tostring(message))

    local cycleCount = 0
    local fullyStocked = false
    repeat
        cycleCount = cycleCount + 1
        print("--- Cycle " .. cycleCount .. "/" .. MAX_CYCLES .. " ---")
        fullyStocked = runCycle()
        if not fullyStocked and cycleCount < MAX_CYCLES then
            print("Not fully stocked, running another cycle...")
        end
    until fullyStocked or cycleCount >= MAX_CYCLES

    if fullyStocked then
        print("Fully stocked after " .. cycleCount .. " cycle(s).")
    else
        print("Max cycles reached, some items may still be low.")
    end

    print("Listening again...")
end