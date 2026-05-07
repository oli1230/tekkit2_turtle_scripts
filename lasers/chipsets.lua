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
local PULSAR = "buildcraftsilicon:plug_pulsar"

local items = {
    { name = "Iron Chipset",    type = "chipset", damage = 1, ingredients = {
        { id = "minecraft:redstone",    damage = 0, qty = 1 },
        { id = "minecraft:iron_ingot",  damage = 0, qty = 1 },
    }},
    { name = "Gold Chipset",    type = "chipset", damage = 2, ingredients = {
        { id = "minecraft:redstone",    damage = 0, qty = 1 },
        { id = "minecraft:gold_ingot",  damage = 0, qty = 1 },
    }},
    { name = "Quartz Chipset",  type = "chipset", damage = 3, ingredients = {
        { id = "minecraft:redstone",    damage = 0, qty = 1 },
        { id = "minecraft:quartz",      damage = 0, qty = 1 },
    }},
    { name = "Diamond Chipset", type = "chipset", damage = 4, ingredients = {
        { id = "minecraft:redstone",    damage = 0, qty = 1 },
        { id = "minecraft:diamond",     damage = 0, qty = 1 },
    }},
    { name = "Pipe Pulsar",     type = "pulsar",  damage = 0, ingredients = {
        { id = "buildcraftcore:engine", damage = 0, qty = 1 },
        { id = "minecraft:iron_ingot",  damage = 0, qty = 2 },
    }},
}

local function countItemIn(periph, itemId, itemDamage)
    local total = 0
    for slot, item in pairs(periph.list()) do
        if item.name == itemId then
            local meta = periph.getItemMeta(slot)
            if meta and meta.damage == itemDamage then
                total = total + item.count
            end
        end
    end
    return total
end

local function countChipsets()
    local counts = {}
    for _, item in ipairs(items) do counts[item.name] = 0 end
    for slot, item in pairs(chest.list()) do
        if item.name == CHIPSET then
            local meta = chest.getItemMeta(slot)
            for _, chip in ipairs(items) do
                if chip.type == "chipset" and meta and meta.damage == chip.damage then
                    counts[chip.name] = counts[chip.name] + item.count
                end
            end
        elseif item.name == PULSAR then
            counts["Pipe Pulsar"] = (counts["Pipe Pulsar"] or 0) + item.count
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

local function findSlot(itemId, itemDamage)
    for slot, item in pairs(chest.list()) do
        if item.name == itemId then
            local meta = chest.getItemMeta(slot)
            if meta and meta.damage == itemDamage then
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

local function getTableIngredients()
    local inTable = {}
    for slot, item in pairs(above.list()) do
        local meta = above.getItemMeta(slot)
        local damage = meta and meta.damage or 0
        local key = item.name .. ":" .. damage
        inTable[key] = (inTable[key] or 0) + item.count
    end
    return inTable
end

local function runCycle()
    local counts = countChipsets()
    if isFullyStocked(counts) then
        print("Already fully stocked, nothing to do.")
        return true
    end

    print("--- Checking stock ---")
    local missingRetries = 0
    local inTable = getTableIngredients()
    local ingDefs = {}
    local totalNeeded = {}

    -- First pass: figure out how many sets of each item we can and need to make
    local itemSets = {}
    for _, item in ipairs(items) do
        local have = counts[item.name] or 0
        local need = TARGET - have
        print(item.name .. ": " .. have .. "/" .. TARGET)

        if need > 0 then
            local sets = need  -- how many we need to make
            local canPush = true

            for _, ing in ipairs(item.ingredients) do
                local qty = ing.qty or 1
                local available = countItemIn(chest, ing.id, ing.damage)
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
                -- Limit sets by availability
                local possibleSets = math.floor(available / qty)
                sets = math.min(sets, possibleSets)
            end

            if canPush then
                itemSets[item.name] = sets
            end
        end
    end

    -- Second pass: sum up ALL ingredient requirements across ALL items
    -- This correctly handles shared ingredients like redstone
    for _, item in ipairs(items) do
        local sets = itemSets[item.name] or 0
        if sets > 0 then
            for _, ing in ipairs(item.ingredients) do
                local qty = ing.qty or 1
                local key = ing.id .. ":" .. ing.damage
                totalNeeded[key] = (totalNeeded[key] or 0) + (sets * qty)
                ingDefs[key] = ing
            end
        end
    end

    -- However, first pass availability check didn't account for shared ingredients
    -- being consumed by multiple items. Re-check availability against combined totals
    -- and scale back proportionally if needed
    for key, needed in pairs(totalNeeded) do
        local ing = ingDefs[key]
        local available = countItemIn(chest, ing.id, ing.damage)
        if needed > available then
            -- Scale back all items that use this ingredient proportionally
            local ratio = available / needed
            print("  -> Scaling back: only " .. available .. " of " .. ing.id .. " available, need " .. needed)
            for _, item in ipairs(items) do
                if itemSets[item.name] then
                    for _, itemIng in ipairs(item.ingredients) do
                        if itemIng.id == ing.id and itemIng.damage == ing.damage then
                            itemSets[item.name] = math.floor(itemSets[item.name] * ratio)
                        end
                    end
                end
            end
            -- Recalculate totalNeeded after scaling
            totalNeeded = {}
            for _, it in ipairs(items) do
                local s = itemSets[it.name] or 0
                if s > 0 then
                    for _, i in ipairs(it.ingredients) do
                        local k = i.id .. ":" .. i.damage
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
        -- Recheck after waiting
        availableSlots = getAvailableTableSlots()
        if stacksToPush > availableSlots then
            print("Table still full, stopping.")
            return false
        end
    end

    -- Push all ingredients in one go
    for key, qty in pairs(totalToPush) do
        local ing = ingDefs[key]
        if ing and qty > 0 then
            local slot = findSlot(ing.id, ing.damage)
            if slot then
                print("Pushing " .. qty .. "x " .. ing.id)
                chest.pushItems(above_name, slot, qty)
            else
                print("Could not find " .. ing.id .. " in chest!")
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
            if detail and (detail.name == CHIPSET or detail.name == PULSAR) then
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

    local finalCounts = countChipsets()
    return isFullyStocked(finalCounts)
end

-- Main loop
rednet.open("right")
print("Turtle ID: " .. os.getComputerID())
print("Listening for rednet trigger...")

while true do
    local senderID, message = rednet.receive()
    print("Triggered by ID " .. senderID .. ": " .. tostring(message))

    -- Fix 3: repeat cycle up to MAX_CYCLES times until fully stocked
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