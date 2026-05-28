-- plugins/weather.lua
-- Weather — current conditions and forecast via wttr.in (no API key required).
-- JPE: wttr.in is a free, no-registration weather service that speaks plain text.
--      Curl it, display it. That's the whole trick — no OAuth, no rate limits.

local function clean(s)
    if not s or s == "" then return "" end
    -- Allow letters, digits, spaces, dashes, commas — block shell metacharacters
    return s:gsub("[;|&`$<>%(%){}%[%]\"'\\]", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- URL-encode spaces as + (good enough for city names)
local function urlencode_simple(s)
    return s:gsub("%s+", "+")
end

-- ── /weather — current conditions ────────────────────────────────────────────
-- Usage: /weather [city]    — defaults to auto-detected location

registerCommand("weather", function(args)
    local city    = clean(args)
    local target  = city ~= "" and urlencode_simple(city) or ""
    local url     = "wttr.in/" .. target .. "?format=3"
    local cmd     = "curl -s --max-time 8 \"https://" .. url .. "\" 2>/dev/null"
    local fallback_cmd = "curl -s --max-time 8 \"http://" .. url .. "\" 2>/dev/null"

    local out = execute(cmd):gsub("[\r\n]+$", "")
    if out == "" or out:find("^curl") then
        out = execute(fallback_cmd):gsub("[\r\n]+$", "")
    end

    if out == "" then
        return "Could not reach wttr.in. Check your internet connection."
    end
    if out:find("Unknown location") or out:find("Sorry") then
        return "Location not found: '" .. city .. "'. Try a major city name."
    end

    return out
end)

-- ── /forecast — 3-day forecast ────────────────────────────────────────────────

registerCommand("forecast", function(args)
    local city   = clean(args)
    local target = city ~= "" and urlencode_simple(city) or ""
    -- format=v2 gives a compact 3-day table
    local url    = "wttr.in/" .. target .. "?format=v2&no-color"
    local cmd    = "curl -s --max-time 10 \"https://" .. url .. "\" 2>/dev/null"

    local out = execute(cmd)
    if out == "" or out:find("^curl") then
        return "Could not reach wttr.in. Check your internet connection."
    end
    if out:find("Unknown location") or out:find("Sorry") then
        return "Location not found: '" .. city .. "'. Try a major city name."
    end

    -- Trim to reasonable length
    return out:sub(1, 2000)
end)

-- ── /moon — current moon phase ────────────────────────────────────────────────

registerCommand("moon", function(_args)
    local out = execute("curl -s --max-time 8 \"https://wttr.in/Moon?format=%25m\" 2>/dev/null"):gsub("[\r\n]+", "")
    if out == "" then
        return "Could not fetch moon phase from wttr.in."
    end
    return "Moon phase: " .. out
end)

-- ── /temp — quick temperature check ──────────────────────────────────────────
-- Returns just the temperature in °C and °F for the given city

registerCommand("temp", function(args)
    local city   = clean(args)
    local target = city ~= "" and urlencode_simple(city) or ""
    -- %t = temperature, %C = condition description
    local url    = "wttr.in/" .. target .. "?format=%25l:+%25t+(%25C)"
    local cmd    = "curl -s --max-time 8 \"https://" .. url .. "\" 2>/dev/null"
    local out    = execute(cmd):gsub("[\r\n]+$", "")
    if out == "" then return "Could not fetch temperature." end
    return out
end)

print("[Plugin] weather loaded — /weather /forecast /moon /temp")
