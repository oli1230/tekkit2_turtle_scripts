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
local WIRE = "buildcrafttransport:wire"

local GATE_HASHES = {
    GOLD_OR_BASE    = "2d44d06334bc4aa8f54f2237c2a19876",
    GOLD_OR_LAPIS   = "46399caa2859d1be1f4013ec9af5fa6e",
    -- GOLD_OR_QUARTZ = "unknown", -- commented out until recipe is fixed
    GOLD_OR_DIAMOND = "7e240c9fb089d936a94cf3dafcd94df3",
}

local items = {
    { name = "Brown Wire",      type = "wire", damage = 12, output = 8, ingredients = {
        { id = "minecraft:redstone", damage = 0,  qty = 1 },
        { id = "minecraft:dye",      damage = 3,  qty = 1 },
    }},
    { name = "Black Wire",      type = "wire", damage = 15, output = 8, ingredients = {
        { id = "minecraft:redstone", damage = 0,  qty = 1 },
        { id = "minecraft:dye",      damage = 0,  qty = 1 },
    }},
    { name = "Light Gray Wire", type = "wire", damage = 8,  output = 8, ingredients = {
        { id = "minecraft:redstone", damage = 0,  qty = 1 },
        { id = "minecraft:dye",      damage = 7,  qty = 1 },
    }},
    { name = "Pink Wire",       type = "wire", damage = 6,  output = 8, ingredients = {
        { id = "minecraft:redstone", damage = 0,  qty = 1 },
        { id = "minecraft:dye",      damage = 9,  qty = 1 },
    }},
    { name = "Light Blue Wire", type = "wire", damage = 3,  output = 8, ingredients = {
        { id = "minecraft:redstone", damage = 0,  qty = 1 },
        { id = "minecraft:dye",      damage = 12, qty = 1 },
    }},
    { name = "Orange Wire",     type = "wire", damage = 1,  output = 8, ingredients = {
        { id = "minecraft:redstone", damage = 0,  qty = 1 },
        { id = "minecraft:dye",      damage = 14, qty = 1 },
    }},
    { name = "Lime Wire",       type = "wire", damage = 5,  output = 8, ingredients = {
        { id = "minecraft:redstone", damage = 0,  qty = 1 },
        { id = "minecraft:dye",      damage = 10, qty = 1 },
    }},
    { name = "Yellow Wire",     type = "wire", damage = 4,  output = 8, ingredients = {
        { id = "minecraft:redstone", damage = 0,  qty = 1 },
        { id = "minecraft:dye",      damage = 11, qty = 1 },
    }},
    -- Gold OR gates
    { name = "Gold OR Gate Base",    type = "gate", nbt = GATE_HASHES.GOLD_OR_BASE,    ingredients = {
        { id = CHIPSET, damage = 2, qty = 1 },
    }},
    { name = "Gold OR Lapis Gate",   type = "gate", nbt = GATE_HASHES.GOLD_OR_LAPIS,   ingredients = {
        { id = GATE,    nbt = GATE_HASHES.GOLD_OR_BASE, qty = 1 },
        { id = "minecraft:dye", damage = 4, qty = 1 },
    }},
    --[[ Gold OR Quartz Gate commented out until recipe is fixed
    { name = "Gold OR Quartz Gate",  type = "gate", nbt = GATE_HASHES.GOLD_OR_QUARTZ,  ingredients = {
        { id = GATE,    nbt = GATE_HASHES.GOLD_OR_BASE, qty = 1 },
        { id = CHIPSET, damage = 3, qty = 1 },
    }},
    ]]
    { name = "Gold OR Diamond Gate", type = "gate", nbt = GATE_HASHES.GOLD_OR_DIAMOND, ingredients = {
        { id = GATE,    nbt = GATE_HASHES.GOLD_OR_BASE, qty = 1 },
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
        if item.name == WIRE then
            local meta = chest.getItemMeta(slot)
            for _, it in ipairs(items) do
                if it.type == "wire" and meta and meta.damage == it.damage then
                    counts[it.name] = counts[it.name] + item.count
                end
            end
        elseif item.name == CHIPSET then
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
            local output = item.output or 1
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
                local setsNeeded = math.ceil((TARGET - have) / output)
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
            if detail and (detail.name == WIRE or detail.name == GATE or detail.name == CHIPSET) then
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