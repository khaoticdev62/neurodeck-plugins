-- plugins/timetools.lua
-- Time Tools — timestamps, date math, countdowns, timezone info, and a Pomodoro timer.
-- JPE: Every developer needs to answer the same time questions constantly —
--      "what's the Unix timestamp?", "how long since this date?", "what time is it in UTC?"
--      This plugin answers all of them without leaving the terminal.

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── /now — current local time and UTC ────────────────────────────────────────

registerCommand("now", function(_args)
    local local_time, utc_time, ts
    if WIN then
        local_time = execute("powershell -Command \"Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'\" 2>nul"):gsub("[\r\n]+", "")
        utc_time   = execute("powershell -Command \"(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'\" 2>nul"):gsub("[\r\n]+", "")
        ts         = execute("powershell -Command \"[int][double]::Parse((Get-Date -UFormat %s))\" 2>nul"):gsub("[\r\n]+", "")
    else
        local_time = execute("date '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null"):gsub("[\r\n]+", "")
        utc_time   = execute("date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null"):gsub("[\r\n]+", "")
        ts         = execute("date +%s 2>/dev/null"):gsub("[\r\n]+", "")
    end
    local lines = {}
    if local_time ~= "" then table.insert(lines, "Local : " .. local_time) end
    if utc_time   ~= "" then table.insert(lines, "UTC   : " .. utc_time) end
    if ts         ~= "" then table.insert(lines, "Unix  : " .. ts) end
    return #lines > 0 and table.concat(lines, "\n") or "Could not determine current time."
end)

-- ── /ts — current Unix timestamp ─────────────────────────────────────────────

registerCommand("ts", function(_args)
    local out
    if WIN then
        out = execute("powershell -Command \"[int][double]::Parse((Get-Date -UFormat %s))\" 2>nul"):gsub("[\r\n]+", "")
    else
        out = execute("date +%s 2>/dev/null"):gsub("[\r\n]+", "")
    end
    return out ~= "" and ("Unix timestamp: " .. out) or "Could not get timestamp."
end)

-- ── /utc — current UTC time ───────────────────────────────────────────────────

registerCommand("utc", function(_args)
    local out
    if WIN then
        out = execute("powershell -Command \"(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'\" 2>nul"):gsub("[\r\n]+", "")
    else
        out = execute("date -u '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null"):gsub("[\r\n]+", "")
    end
    return out ~= "" and out or "Could not get UTC time."
end)

-- ── /date — formatted date ────────────────────────────────────────────────────
-- /date           — today's date
-- /date <format>  — custom format (strftime on Linux, powershell on Windows)

registerCommand("date", function(args)
    local fmt = args:gsub("[;|&`$<>%(%){}%[%]\"'\\]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if WIN then
        local psfmt = (fmt ~= "") and fmt or "yyyy-MM-dd"
        return execute("powershell -Command \"Get-Date -Format '" .. psfmt .. "'\" 2>nul"):gsub("[\r\n]+", "")
    else
        local strfmt = (fmt ~= "") and fmt or "%Y-%m-%d"
        return execute("date '+'" .. strfmt .. "' 2>/dev/null"):gsub("[\r\n]+", "")
    end
end)

-- ── /tzlist — list common timezones with current time ─────────────────────────

registerCommand("tzlist", function(_args)
    local zones = {
        { "UTC",             "UTC" },
        { "New York",        "America/New_York" },
        { "Los Angeles",     "America/Los_Angeles" },
        { "Chicago",         "America/Chicago" },
        { "London",          "Europe/London" },
        { "Paris",           "Europe/Paris" },
        { "Berlin",          "Europe/Berlin" },
        { "Dubai",           "Asia/Dubai" },
        { "Kolkata",         "Asia/Kolkata" },
        { "Tokyo",           "Asia/Tokyo" },
        { "Sydney",          "Australia/Sydney" },
    }
    if WIN then
        return "Timezone list requires Linux/SteamOS. Run /utc for UTC reference."
    end
    local lines = { "Current time in major zones:" }
    for _, z in ipairs(zones) do
        local t = execute("TZ='" .. z[2] .. "' date '+%H:%M %Z' 2>/dev/null"):gsub("[\r\n]+", "")
        if t ~= "" then
            table.insert(lines, string.format("  %-14s %s", z[1], t))
        end
    end
    return table.concat(lines, "\n")
end)

-- ── /age — days since a date ──────────────────────────────────────────────────
-- Usage: /age 2024-01-15

registerCommand("age", function(args)
    local datestr = args:match("(%d%d%d%d%-%d%d%-%d%d)")
    if not datestr then
        return "Usage: /age YYYY-MM-DD\nExample: /age 2024-01-15"
    end
    local out
    if WIN then
        out = execute("powershell -Command \"$d=[datetime]'" .. datestr ..
            "'; $now=Get-Date; [int]($now - $d).TotalDays\" 2>nul"):gsub("[\r\n]+", "")
        if out ~= "" then
            return string.format("%s was %s days ago.", datestr, out)
        end
    else
        local epoch_then = execute("date -d '" .. datestr .. "' +%s 2>/dev/null"):gsub("[\r\n]+", "")
        local epoch_now  = execute("date +%s 2>/dev/null"):gsub("[\r\n]+", "")
        if epoch_then ~= "" and epoch_now ~= "" then
            local diff = math.floor((tonumber(epoch_now) - tonumber(epoch_then)) / 86400)
            if diff >= 0 then
                return string.format("%s was %d days ago.", datestr, diff)
            else
                return string.format("%s is %d days from now.", datestr, math.abs(diff))
            end
        end
    end
    return "Could not parse date '" .. datestr .. "'. Use YYYY-MM-DD format."
end)

-- ── /pomodoro — Pomodoro session marker ───────────────────────────────────────
-- JPE: Tracks the start time of a Pomodoro session in-memory.
--      "/pomodoro start" stamps now, "/pomodoro check" shows elapsed.
--      Use it with a real timer app — this is your session anchor.

local pom_start = nil
local pom_label = ""

registerCommand("pomodoro", function(args)
    local sub = args:match("^(%S+)") or "start"
    sub = sub:lower()

    if sub == "start" then
        local label = args:match("^%S+%s+(.+)$") or "Focus session"
        if WIN then
            pom_start = execute("powershell -Command \"[int][double]::Parse((Get-Date -UFormat %s))\" 2>nul"):gsub("[\r\n]+", "")
        else
            pom_start = execute("date +%s 2>/dev/null"):gsub("[\r\n]+", "")
        end
        pom_label = label
        return string.format("🍅 Pomodoro started: '%s'\n25-minute session in progress. Use /pomodoro check to see elapsed time.", label)

    elseif sub == "check" then
        if not pom_start or pom_start == "" then
            return "No Pomodoro running. Use /pomodoro start [label] to begin."
        end
        local now_ts
        if WIN then
            now_ts = execute("powershell -Command \"[int][double]::Parse((Get-Date -UFormat %s))\" 2>nul"):gsub("[\r\n]+", "")
        else
            now_ts = execute("date +%s 2>/dev/null"):gsub("[\r\n]+", "")
        end
        local elapsed = tonumber(now_ts) - tonumber(pom_start)
        local mins    = math.floor(elapsed / 60)
        local secs    = elapsed % 60
        local remain  = 25 * 60 - elapsed
        if remain < 0 then
            return string.format("🍅 '%s' — DONE! Ran for %dm %ds (over by %dm %ds). Take a break!",
                pom_label, mins, secs, math.floor(-remain/60), (-remain)%60)
        end
        return string.format("🍅 '%s' — %dm %ds elapsed | %dm %ds remaining",
            pom_label, mins, secs, math.floor(remain/60), remain%60)

    elseif sub == "stop" then
        pom_start = nil
        pom_label = ""
        return "🍅 Pomodoro cancelled."

    else
        return "Usage:\n  /pomodoro start [label]  — begin a 25-min session\n  /pomodoro check          — see elapsed/remaining time\n  /pomodoro stop           — cancel"
    end
end)

-- ── /week — day of week and week number ───────────────────────────────────────

registerCommand("week", function(_args)
    local out
    if WIN then
        out = execute("powershell -Command \"$d=Get-Date; 'Week ' + (Get-Date -UFormat %V) + ' | ' + $d.DayOfWeek + ' ' + $d.ToString('yyyy-MM-dd')\" 2>nul"):gsub("[\r\n]+", "")
    else
        out = execute("date '+Week %V | %A %Y-%m-%d' 2>/dev/null"):gsub("[\r\n]+", "")
    end
    return out ~= "" and out or "Could not determine week info."
end)

print("[Plugin] timetools loaded — /now /ts /utc /date /tzlist /age /pomodoro /week")
