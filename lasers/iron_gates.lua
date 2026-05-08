local STACK = 64
local TARGET_STACKS = 3
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
    IRON_AND_LAPIS   = "4a7ef16feee1e22c2c98b1e5a6a67239",
    IRON_AND_QUARTZ  = "40f3c33bdafdda6bcf4ecb60bf451752",
    IRON_AND_DIAMOND = "6747c6260d21f2c31ed264c27a57661f",
    IRON_OR_LAPIS    = "f45720bca0931a75d8df948549a6b1d7",
    IRON_OR_QUARTZ   = "216fb9d7f0aa94de34506fc95560b918",
    IRON_OR_DIAMOND  = "807febf6dbe8e1180ea3e780c8fca533",
}

local BASE_GATE_HASHES = {
    IRON_AND = "0993b49a53e60ff0925e37f4e35b9fff",
    IRON_OR  = "788f4ef4b727910d0eaf5291d11963ed",
}

local items = {
    { name = "Redstone Chipset",     type = "chipset", damage = 0, ingredients = {
        { id = "minecraft:redstone", damage = 0, qty = 1 },
    }},
    { name = "Iron AND Lapis Gate",   type = "gate", nbt = GATE_HASHES.IRON_AND_LAPIS,   ingredients = {
        { id = GATE,    nbt = BASE_GATE_HASHES.IRON_AND, qty = 1 },
        { id = "minecraft:dye", damage = 4, qty = 1 },
    }},
    { name = "Iron AND Quartz Gate",  type = "gate", nbt = GATE_HASHES.IRON_AND_QUARTZ,  ingredients = {
        { id = GATE,    nbt = BASE_GATE_HASHES.IRON_AND, qty = 1 },
        { id = CHIPSET, damage = 3, qty = 1 },
    }},
    { name = "Iron AND Diamond Gate", type = "gate", nbt = GATE_HASHES.IRON_AND_DIAMOND, ingredients = {
        { id = GATE,    nbt = BASE_GATE_HASHES.IRON_AND, qty = 1 },
        { id = CHIPSET, damage = 4, qty = 1 },
    }},
    { name = "Iron OR Lapis Gate",   type = "gate", nbt = GATE_HASHES.IRON_OR_LAPIS,   ingredients = {
        { id = GATE,    nbt = BASE_GATE_HASHES.IRON_OR, qty = 1 },
        { id = "minecraft:dye", damage = 4, qty = 1 },
    }},
    { name = "Iron OR Quartz Gate",  type = "gate", nbt = GATE_HASHES.IRON_OR_QUARTZ,  ingredients = {
        { id = GATE,    nbt = BASE_GATE_HASHES.IRON_OR, qty = 1 },
        { id = CHIPSET, damage = 3, qty = 1 },
    }},
    { name = "Iron OR Diamond Gate", type = "gate", nbt = GATE_HASHES.IRON_OR_DIAMOND, ingredients = {
        { id = GATE,    nbt = BASE_GATE_HASHES.IRON_OR, qty = 1 },
        { id = CHIPSET, damage = 4, qty = 1 },
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
        if item.name == CHIPSET then
            local meta = chest.getItemMeta(slot)
            for _, it in ipairs(items) do
                if it.type == "chipset" and meta and meta.damage == it.damage then
                    counts[it.name] = counts[it.name] + item.count
                end
            end
        elseif item.name == GATE then
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

local function getTableIngredients()
    local inTable = {}
    for slot, item in pairs(above.list()) do
        local meta = above.getItemMeta(slot)
        local key
        if meta and meta.nbtHash then
            key = item.name .. ":nbt:" .. tostring(meta.nbtHash)
        else
            key = item.name .. ":" .. (meta and meta.damage or 0)
        end
        inTable[key] = (inTable[key] or 0) + item.count
    end
    return inTable
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

local function runCycle()
    local counts = countOutputs()
    if isFullyStocked(counts) then
        print("Already fully stocked, nothing to do.")
        return true
    end

    print("--- Checking stock ---")
    local missingRetries = 0
    local inTable = getTableIngredients()
    local ingDefs = {}
    local totalNeeded = {}

    -- First pass: calculate how many sets of each item we need and can make
    local itemSets = {}
    for _, item in ipairs(items) do
        local have = counts[item.name] or 0
        local need = TARGET - have
        print(item.name .. ": " .. have .. "/" .. TARGET)

        if need > 0 then
            local sets = need
            local canPush = true

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
                local possibleSets = math.floor(available / qty)
                sets = math.min(sets, possibleSets)
            end

            if canPush then
                itemSets[item.name] = sets
            end
        end
    end

    -- Second pass: sum ALL ingredient requirements across ALL items
    for _, item in ipairs(items) do
        local sets = itemSets[item.name] or 0
        if sets > 0 then
            for _, ing in ipairs(item.ingredients) do
                local qty = ing.qty or 1
                local key = getIngKey(ing)
                totalNeeded[key] = (totalNeeded[key] or 0) + (sets * qty)
                ingDefs[key] = ing
            end
        end
    end

    -- Scale back if shared ingredients are over-committed
    for key, needed in pairs(totalNeeded) do
        local ing = ingDefs[key]
        local available = countItemIn(chest, ing)
        if needed > available then
            local ratio = available / needed
            print("  -> Scaling back: only " .. available .. " of " .. ing.id .. " available, need " .. needed)
            for _, item in ipairs(items) do
                if itemSets[item.name] then
                    for _, itemIng in ipairs(item.ingredients) do
                        if getIngKey(itemIng) == key then
                            itemSets[item.name] = math.floor(itemSets[item.name] * ratio)
                        end
                    end
                end
            end
            -- Recalculate totalNeeded and ingDefs after scaling
            totalNeeded = {}
            ingDefs = {}
            for _, it in ipairs(items) do
                local s = itemSets[it.name] or 0
                if s > 0 then
                    for _, i in ipairs(it.ingredients) do
                        local k = getIngKey(i)
                        totalNeeded[k] = (totalNeeded[k] or 0) + (s * (i.qty or 1))
                        ingDefs[k] = i
                    end
                end
            end
        end
    end

    -- Subtract what's already in the table
    local totalToPush = {}
    for key, needed in pairs(totalNeeded) do
        local alreadyInTable = inTable[key] or 0
        local toPush = math.max(0, needed - alreadyInTable)
        if toPush > 0 then
            totalToPush[key] = toPush
        end
    end

    -- Check available table slots
    local stacksToPush = 0
    for _ in pairs(totalToPush) do stacksToPush = stacksToPush + 1 end
    local availableSlots = getAvailableTableSlots()

    if stacksToPush > availableSlots then
        print("Not enough table slots: need " .. stacksToPush .. " have " .. availableSlots)
        print("Waiting 2 min for table to clear...")
        sleep(WAIT_TABLE_FULL)
        availableSlots = getAvailableTableSlots()
        if stacksToPush > availableSlots then
            print("Table still full, stopping.")
            return false
        end
    end

    -- Push all ingredients, looping for multiple stacks
    for key, qty in pairs(totalToPush) do
        local ing = ingDefs[key]
        if ing == nil then
            print("Warning: no ingredient definition for key " .. key .. ", skipping")
        elseif qty > 0 then
            local remaining = qty
            while remaining > 0 do
                local slot = findSlot(ing)
                if slot then
                    local toPush = math.min(remaining, STACK)
                    print("Pushing " .. toPush .. "x " .. ing.id .. " (" .. remaining .. " remaining)")
                    chest.pushItems(above_name, slot, toPush)
                    remaining = remaining - toPush
                else
                    print("Could not find " .. ing.id .. " in chest!")
                    break
                end
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
            if detail and (detail.name == CHIPSET or detail.name == GATE) then
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