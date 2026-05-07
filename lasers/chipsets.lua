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
    local tableRetries = 0

    -- Fix 1: accumulate ALL ingredient needs across ALL items first
    -- before calculating how much to push, so shared ingredients
    -- like redstone are summed correctly across multiple chipsets
    local inTable = getTableIngredients()
    local totalNeeded = {}  -- total qty needed per ingredient key across all items
    local ingDefs = {}      -- ingredient definitions keyed for push step

    for _, item in ipairs(items) do
        local have = counts[item.name] or 0
        local need = TARGET - have
        print(item.name .. ": " .. have .. "/" .. TARGET)

        if need > 0 then
            -- Fix 2: calculate sets based on actual deficit, not just one stack
            local setsNeeded = math.ceil(need / 1)  -- 1 output per set
            local sets = setsNeeded
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
                -- Limit sets by what's available
                local possibleSets = math.floor(available / qty)
                sets = math.min(sets, possibleSets)
            end

            if canPush and sets > 0 then
                for _, ing in ipairs(item.ingredients) do
                    local qty = ing.qty or 1
                    local key = ing.id .. ":" .. ing.damage
                    -- Accumulate total needed across all items
                    totalNeeded[key] = (totalNeeded[key] or 0) + (sets * qty)
                    ingDefs[key] = ing
                end
                missingRetries = 0
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
        tableRetries = tableRetries + 1
        print("Not enough table slots: need " .. stacksToPush .. " have " .. availableSlots .. " (" .. tableRetries .. "/" .. MAX_RETRIES .. ")")
        if tableRetries >= MAX_RETRIES then
            print("Table still full after " .. MAX_RETRIES .. " attempts, stopping.")
            return false
        end
        sleep(WAIT_TABLE_FULL)
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

    -- Return whether fully stocked after this cycle
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