-- plugins/journal.lua
-- Developer Journal — timestamped log of decisions, findings, and progress notes.
-- JPE: A dev journal is not a diary. It's an audit trail. You write "tried X, failed
--      because Y, pivoted to Z" so that future-you doesn't repeat the same mistakes.
--      Each entry is one line with a timestamp. The whole thing is searchable plain text.
--
-- Journal differs from Notes in purpose: notes are tasks/reminders, journal entries
-- are narrative records of work — decisions made, bugs found, approaches tried.

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── Storage path ──────────────────────────────────────────────────────────────

local JOURNAL_FILE
if WIN then
    local appdata = execute("echo %APPDATA%"):gsub("[\r\n]+", "")
    JOURNAL_FILE = appdata .. "\\neurodeck\\plugin-journal.txt"
    execute("if not exist \"" .. appdata .. "\\neurodeck\" mkdir \"" .. appdata .. "\\neurodeck\"")
else
    local home = execute("echo $HOME"):gsub("[\r\n]+", "")
    JOURNAL_FILE = home .. "/.config/neurodeck/plugin-journal.txt"
    execute("mkdir -p '" .. home .. "/.config/neurodeck'")
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function ts()
    if WIN then
        return execute("powershell -Command \"Get-Date -Format 'yyyy-MM-dd HH:mm'\" 2>nul"):gsub("[\r\n]+", "")
    else
        return execute("date '+%Y-%m-%d %H:%M' 2>/dev/null"):gsub("[\r\n]+", "")
    end
end

local function load_entries()
    local raw
    if WIN then
        raw = execute("type \"" .. JOURNAL_FILE .. "\" 2>nul") or ""
    else
        raw = execute("cat '" .. JOURNAL_FILE .. "' 2>/dev/null") or ""
    end
    local entries = {}
    for line in raw:gmatch("[^\r\n]+") do
        if line:gsub("%s+", "") ~= "" then
            table.insert(entries, line)
        end
    end
    return entries
end

local function append_entry(line)
    if WIN then
        local escaped = line:gsub("[\"^&<>|]", "")
        execute("echo " .. escaped .. " >> \"" .. JOURNAL_FILE .. "\" 2>nul")
    else
        local escaped = line:gsub("'", "'\\''")
        execute("printf '%s\\n' '" .. escaped .. "' >> '" .. JOURNAL_FILE .. "' 2>/dev/null")
    end
end

local function overwrite_entries(entries)
    local raw = table.concat(entries, "\n")
    if WIN then
        local escaped = raw:gsub("'", "''")
        execute("powershell -Command \"Set-Content -Path '" .. JOURNAL_FILE ..
            "' -Value '" .. escaped .. "' -Encoding UTF8\" 2>nul")
    else
        local escaped = raw:gsub("'", "'\\''")
        execute("printf '%s' '" .. escaped .. "' > '" .. JOURNAL_FILE .. "' 2>/dev/null")
    end
end

-- ── /log — append a journal entry ────────────────────────────────────────────
-- Usage: /log <entry text>
-- Example: /log Discovered the memory leak was caused by the event listener not being removed on unmount.

registerCommand("log", function(args)
    local text = args:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return "Usage: /log <entry>\nExample: /log Fixed the auth race condition by adding a mutex around session state."
    end
    local entry = "[" .. ts() .. "] " .. text
    append_entry(entry)
    return "📓 Logged."
end)

-- ── /journal — display recent entries ────────────────────────────────────────
-- Usage: /journal [n]    — last n entries (default 20)

registerCommand("journal", function(args)
    local n = math.min(tonumber(args:match("^%s*(%d+)")) or 20, 200)
    local entries = load_entries()

    if #entries == 0 then
        return "Journal is empty. Use /log <entry> to add your first entry."
    end

    -- Show the last n entries, newest first for easy reading
    local start = math.max(1, #entries - n + 1)
    local lines = { string.format("── JOURNAL (last %d of %d entries) ──────", math.min(n, #entries), #entries) }
    for i = #entries, start, -1 do
        table.insert(lines, entries[i])
    end
    return table.concat(lines, "\n")
end)

-- ── /jtoday — today's entries only ───────────────────────────────────────────

registerCommand("jtoday", function(_args)
    local today
    if WIN then
        today = execute("powershell -Command \"Get-Date -Format 'yyyy-MM-dd'\" 2>nul"):gsub("[\r\n]+", "")
    else
        today = execute("date '+%Y-%m-%d' 2>/dev/null"):gsub("[\r\n]+", "")
    end

    local entries = load_entries()
    local hits    = {}
    for _, entry in ipairs(entries) do
        if entry:find(today, 1, true) then
            table.insert(hits, entry)
        end
    end

    if #hits == 0 then
        return "No journal entries for today (" .. today .. ") yet. Use /log to add one."
    end
    local lines = { string.format("── TODAY (%s) — %d entries ──", today, #hits) }
    for i = #hits, 1, -1 do table.insert(lines, hits[i]) end
    return table.concat(lines, "\n")
end)

-- ── /searchlog — full-text journal search ────────────────────────────────────

registerCommand("searchlog", function(args)
    local query = args:gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return "Usage: /searchlog <keyword>" end

    local entries = load_entries()
    local ql      = query:lower()
    local hits    = {}
    for _, entry in ipairs(entries) do
        if entry:lower():find(ql, 1, true) then
            table.insert(hits, entry)
        end
    end

    if #hits == 0 then return string.format("No entries matching '%s'.", query) end
    local lines = { string.format("Search '%s' — %d match(es):", query, #hits) }
    for i = #hits, 1, -1 do table.insert(lines, hits[i]) end
    return table.concat(lines, "\n")
end)

-- ── /jstats — journal statistics ─────────────────────────────────────────────

registerCommand("jstats", function(_args)
    local entries = load_entries()
    if #entries == 0 then return "No journal entries yet." end

    -- Count entries per day
    local by_day = {}
    for _, e in ipairs(entries) do
        local day = e:match("%[(%d%d%d%d%-%d%d%-%d%d)")
        if day then
            by_day[day] = (by_day[day] or 0) + 1
        end
    end

    local days_sorted = {}
    for d in pairs(by_day) do table.insert(days_sorted, d) end
    table.sort(days_sorted)

    local first_date = days_sorted[1] or "unknown"
    local last_date  = days_sorted[#days_sorted] or "unknown"
    local total_words = 0
    for _, e in ipairs(entries) do
        for _ in e:gmatch("%S+") do total_words = total_words + 1 end
    end

    local lines = {
        string.format("Journal stats:"),
        string.format("  Total entries : %d", #entries),
        string.format("  Active days   : %d", #days_sorted),
        string.format("  Total words   : ~%d", total_words),
        string.format("  First entry   : %s", first_date),
        string.format("  Latest entry  : %s", last_date),
        "",
        "Entries per day (last 7 active):",
    }
    local start_i = math.max(1, #days_sorted - 6)
    for i = start_i, #days_sorted do
        local d = days_sorted[i]
        local bars = string.rep("▪", math.min(by_day[d], 20))
        table.insert(lines, string.format("  %s  %s (%d)", d, bars, by_day[d]))
    end
    return table.concat(lines, "\n")
end)

-- ── /clearlog — wipe the journal ─────────────────────────────────────────────

registerCommand("clearlog", function(args)
    local confirm = args:match("^(%S+)") or ""
    if confirm ~= "yes" then
        local n = #load_entries()
        return string.format(
            "This will permanently delete all %d journal entries.\n" ..
            "Type '/clearlog yes' to confirm.", n)
    end
    overwrite_entries({})
    return "Journal cleared."
end)

-- ── onMessage hook: /log shorthand detection ─────────────────────────────────
-- When a user message starts with "LOG:" (all caps), auto-log it to the journal.
-- This is opt-in magic: typing "LOG: found the bug" auto-journals without /log.

registerHook("onMessage", function(message)
    local text = message:gsub("^%s+", "")
    if text:match("^LOG:%s+") then
        local entry_text = text:match("^LOG:%s+(.+)$")
        if entry_text and entry_text ~= "" then
            append_entry("[" .. ts() .. "] [auto] " .. entry_text)
            print("[journal] Auto-logged: " .. entry_text:sub(1, 60))
        end
    end
    return message
end)

print("[Plugin] journal loaded — /log /journal /jtoday /searchlog /jstats /clearlog")
