-- calculator.lua — NEURODECK Plugin
-- Safe math evaluator + unit and base conversions
-- Commands: /calc /convert /hex /bin /oct

local function safe_eval(expr)
    -- Allow only safe math tokens
    if expr:match("[^%d%s%.%+%-%*/%%%(%)%^,]") then
        return nil, "unsafe expression"
    end
    local fn, err = load("return " .. expr)
    if not fn then return nil, err end
    local ok, result = pcall(fn)
    if not ok then return nil, tostring(result) end
    return tostring(result), nil
end

registerCommand("calc", function(args)
    if not args or args == "" then
        print("Usage: /calc <expression>  e.g. /calc (5 + 3) * 2 / 4")
        return
    end
    local result, err = safe_eval(args)
    if err then
        print("[Calc] Error: " .. err)
    else
        print("[Calc] " .. args .. " = " .. result)
    end
end)

registerCommand("convert", function(args)
    if not args or args == "" then
        print("Usage: /convert <value> <from> <to>")
        print("Units: km/mi  kg/lb  c/f  m/ft  l/gal  cm/in")
        return
    end
    local val, from, to = args:match("^(%-?%d+%.?%d*)%s+(%a+)%s+(%a+)$")
    if not val then print("[Convert] Usage: /convert 100 km mi") return end
    val = tonumber(val)
    local conversions = {
        ["km->mi"] = function(v) return v * 0.621371 end,
        ["mi->km"] = function(v) return v * 1.60934 end,
        ["kg->lb"] = function(v) return v * 2.20462 end,
        ["lb->kg"] = function(v) return v * 0.453592 end,
        ["c->f"]   = function(v) return v * 9/5 + 32 end,
        ["f->c"]   = function(v) return (v - 32) * 5/9 end,
        ["m->ft"]  = function(v) return v * 3.28084 end,
        ["ft->m"]  = function(v) return v * 0.3048 end,
        ["l->gal"] = function(v) return v * 0.264172 end,
        ["gal->l"] = function(v) return v * 3.78541 end,
        ["cm->in"] = function(v) return v * 0.393701 end,
        ["in->cm"] = function(v) return v * 2.54 end,
    }
    local key = from:lower() .. "->" .. to:lower()
    local fn = conversions[key]
    if not fn then
        print("[Convert] Unknown conversion: " .. from .. " → " .. to)
    else
        print(string.format("[Convert] %s %s = %.4f %s", val, from, fn(val), to))
    end
end)

registerCommand("hex", function(args)
    local n = tonumber(args)
    if n then
        print(string.format("[Hex] %d = 0x%X", n, n))
    else
        local v = tonumber(args, 16)
        if v then print(string.format("[Hex] 0x%s = %d", args:upper(), v))
        else print("[Hex] Usage: /hex <decimal> or /hex <0xHEX>") end
    end
end)

registerCommand("bin", function(args)
    local n = tonumber(args)
    if not n then print("[Bin] Usage: /bin <decimal>") return end
    local bits = ""
    local x = math.floor(n)
    if x == 0 then bits = "0" end
    while x > 0 do
        bits = (x % 2 == 1 and "1" or "0") .. bits
        x = math.floor(x / 2)
    end
    print(string.format("[Bin] %d = 0b%s", n, bits))
end)

print("[Plugin] Calculator loaded. Commands: /calc /convert /hex /bin")
