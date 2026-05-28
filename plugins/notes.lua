-- plugins/notes.lua
-- Quick Notes — a lightweight in-session scratchpad that also persists to disk.
-- JPE: Picture a sticky-note wall that lives inside the terminal. You pin a thought
--      mid-sprint, pull it back later, and nothing leaves your workflow.
--
-- Notes survive across sessions via a plain text file in the neurodeck data dir.
-- Each line in the file is one note, prefixed with a timestamp.

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- Resolve the notes file path once at plugin load time
local NOTES_FILE
if WIN then
    local appdata = execute("echo %APPDATA%"):gsub("[\r\n]+", "")
    NOTES_FILE = appdata .. "\\neurodeck\\plugin-notes.txt"
    execute("if not exist \"" .. appdata .. "\\neurodeck\" mkdir \"" .. appdata .. "\\neurodeck\"")
else
    local home = execute("echo $HOME"):gsub("[\r\n]+", "")
    NOTES_FILE = home .. "/.config/neurodeck/plugin-notes.txt"
    execute("mkdir -p \"" .. home .. "/.config/neurodeck\"")
end

-- Load all notes from disk into a table
local function load_notes()
    local notes = {}
    local cmd
    if WIN then
        cmd = "type \"" .. NOTES_FILE .. "\" 2>nul"
    else
        cmd = "cat \"" .. NOTES_FILE .. "\" 2>/dev/null"
    end
    local raw = execute(cmd) or ""
    for line in raw:gmatch("[^\r\n]+") do
        if line:gsub("%s+", "") ~= "" then
            table.insert(notes, line)
        end
    end
    return notes
end

-- Persist a table of notes back to disk
local function save_notes(notes)
    local content = table.concat(notes, "\n")
    if WIN then
        -- Write via PowerShell to handle special chars correctly
        local escaped = content:gsub("'", "''")
        execute("powershell -Command \"Set-Content -Path '" .. NOTES_FILE .. "' -Value '" .. escaped .. "' -Encoding UTF8\" 2>nul")
    else
        -- Use printf to avoid echo interpretation issues
        local escaped = content:gsub("'", "'\\''")
        execute("printf '%s' '" .. escaped .. "' > \"" .. NOTES_FILE .. "\" 2>/dev/null")
    end
end

-- Get current timestamp string
local function ts()
    if WIN then
        return execute("powershell -Command \"Get-Date -Format 'yyyy-MM-dd HH:mm'\" 2>nul"):gsub("[\r\n]+", "")
    else
        return execute("date '+%Y-%m-%d %H:%M' 2>/dev/null"):gsub("[\r\n]+", "")
    end
end

-- ── /note — add a note ───────────────────────────────────────────────────────

registerCommand("note", function(args)
    local text = args:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return "Usage: /note <your thought here>\nTip: use /notes to list, /delnote <n> to remove."
    end
    local notes = load_notes()
    local entry = "[" .. ts() .. "] " .. text
    table.insert(notes, entry)
    save_notes(notes)
    return string.format("📌 Note #%d saved: %s", #notes, text)
end)

-- ── /notes — list all notes ───────────────────────────────────────────────────

registerCommand("notes", function(args)
    local notes = load_notes()
    if #notes == 0 then
        return "No notes yet. Use /note <text> to add one."
    end

    -- Optional: filter by keyword
    local filter = args:match("^(%S+)") or ""
    local lines  = {}
    local count  = 0
    for i, note in ipairs(notes) do
        if filter == "" or note:lower():find(filter:lower(), 1, true) then
            table.insert(lines, string.format("  [%2d] %s", i, note))
            count = count + 1
        end
    end

    if count == 0 then
        return "No notes matching '" .. filter .. "'."
    end

    local header = filter == ""
        and string.format("┌─ NOTES (%d) ─────────────────────────────────────┐", count)
        or  string.format("┌─ NOTES matching '%s' (%d) ─┐", filter, count)
    table.insert(lines, 1, header)
    return table.concat(lines, "\n")
end)

-- ── /delnote — delete a note by index ────────────────────────────────────────

registerCommand("delnote", function(args)
    local idx = tonumber(args:match("^%s*(%d+)"))
    if not idx then
        return "Usage: /delnote <number>\nFind the number with /notes."
    end
    local notes = load_notes()
    if idx < 1 or idx > #notes then
        return string.format("No note #%d. You have %d note(s). Use /notes to list them.", idx, #notes)
    end
    local removed = notes[idx]
    table.remove(notes, idx)
    save_notes(notes)
    return string.format("🗑 Deleted note #%d: %s\n%d note(s) remaining.", idx, removed, #notes)
end)

-- ── /clearnotes — wipe all notes ─────────────────────────────────────────────

registerCommand("clearnotes", function(args)
    local confirm = args:match("^(%S+)") or ""
    if confirm ~= "yes" then
        local n = #load_notes()
        return string.format(
            "This will delete all %d note(s). Type '/clearnotes yes' to confirm.", n)
    end
    save_notes({})
    return "All notes cleared."
end)

-- ── /searchnotes — full-text search across notes ─────────────────────────────

registerCommand("searchnotes", function(args)
    local query = args:gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return "Usage: /searchnotes <keyword>" end
    local notes  = load_notes()
    local hits   = {}
    local ql     = query:lower()
    for i, note in ipairs(notes) do
        if note:lower():find(ql, 1, true) then
            table.insert(hits, string.format("  [%2d] %s", i, note))
        end
    end
    if #hits == 0 then return "No notes matching '" .. query .. "'." end
    table.insert(hits, 1, string.format("Search results for '%s' (%d):", query, #hits))
    return table.concat(hits, "\n")
end)

print("[Plugin] notes loaded — /note /notes /delnote /clearnotes /searchnotes")
