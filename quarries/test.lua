local p = peripheral.wrap("left")
local f = fs.open("commandHelp_output.txt", "w")

local help = p.commandHelp()
if type(help) == "table" then
    for k, v in pairs(help) do
        f.writeLine(tostring(k) .. " = " .. tostring(v))
    end
else
    f.writeLine(tostring(help))
end

f.close()
print("Done, saved to commandHelp_output.txt")