local p = peripheral.wrap("left")
local f = fs.open("commandHelp_output.txt", "w")

-- Try passing each known method name to commandHelp
local methods = {"listParts", "getLogisticsModule", "getModuleInSlot", "getType", "hasLogisticsModule", "canAccess", "getRouterId", "getPipeForUUID", "getRouterUUID"}

for _, method in ipairs(methods) do
    local ok, result = pcall(function() return p.commandHelp(method) end)
    if ok then
        f.writeLine("=== " .. method .. " ===")
        if type(result) == "table" then
            for k, v in pairs(result) do
                f.writeLine(tostring(k) .. " = " .. tostring(v))
            end
        else
            f.writeLine(tostring(result))
        end
    else
        f.writeLine("=== " .. method .. " === ERROR: " .. tostring(result))
    end
end

f.close()
print("Done, saved to commandHelp_output.txt")