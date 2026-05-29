-- clipboard.lua — NEURODECK Plugin
-- Persistent clipboard history — save, list, copy, and search entries
-- Commands: /clip /clips /copyclip /delclip /clearclips /searchclips

local state_file = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
state_file = state_file .. "/.config/neurodeck/data/clipboard.json"

local function load_clips()
    local f = io.open(state_file, "r")
    if not f then return {} end
    local raw = f:read("*a"); f:close()
    local ok, t = pcall(function()
        -- simple JSON array parse for strings
        local clips = {}
        for item in raw:gmatch('"(.-[^\\])"') do
            table.insert(clips, item:gsub('\\"', '"'))
        end
        return clips
    end)
    return ok and t or {}
end

local function save_clips(clips)
    local f = io.open(state_file, "w")
    if not f then return end
    f:write('["' .. table.concat(clips, '","'):gsub('"', '\\"') .. '"]')
    f:close()
end

registerCommand("clip", function(args)
    if not args or args == "" then
        print("Usage: /clip <text to save>")
        return
    end
    local clips = load_clips()
    -- Deduplicate
    for i, c in ipairs(clips) do
        if c == args then table.remove(clips, i) break end
    end
    table.insert(clips, 1, args)
    if #clips > 50 then table.remove(clips) end
    save_clips(clips)
    print("[Clip] Saved: " .. args:sub(1, 60) .. (#args > 60 and "…" or ""))
end)

registerCommand("clips", function()
    local clips = load_clips()
    if #clips == 0 then print("[Clips] Empty.") return end
    for i, c in ipairs(clips) do
        print(string.format("[%02d] %s", i, c:sub(1, 80) .. (#c > 80 and "…" or "")))
    end
end)

registerCommand("copyclip", function(args)
    local n = tonumber(args)
    if not n then print("Usage: /copyclip <number>") return end
    local clips = load_clips()
    if not clips[n] then print("[Clip] No entry #" .. n) return end
    local text = clips[n]
    -- Write to system clipboard
    local os_name = os.getenv("OS") or ""
    if os_name:find("Windows") then
        execute("echo " .. text:gsub('"', '\\"') .. " | clip")
    else
        execute("echo '" .. text:gsub("'", "'\\''") .. "' | xclip -selection clipboard 2>/dev/null || echo '" .. text:gsub("'", "'\\''") .. "' | xsel --clipboard --input 2>/dev/null")
    end
    print("[Clip] Copied to clipboard: " .. text:sub(1, 60))
end)

registerCommand("delclip", function(args)
    local n = tonumber(args)
    if not n then print("Usage: /delclip <number>") return end
    local clips = load_clips()
    if not clips[n] then print("[Clip] No entry #" .. n) return end
    table.remove(clips, n)
    save_clips(clips)
    print("[Clip] Deleted entry #" .. n)
end)

registerCommand("clearclips", function()
    save_clips({})
    print("[Clips] Cleared.")
end)

registerCommand("searchclips", function(args)
    if not args or args == "" then print("Usage: /searchclips <query>") return end
    local clips = load_clips()
    local found = 0
    for i, c in ipairs(clips) do
        if c:lower():find(args:lower(), 1, true) then
            print(string.format("[%02d] %s", i, c:sub(1, 80)))
            found = found + 1
        end
    end
    if found == 0 then print("[Clips] No matches for: " .. args) end
end)

print("[Plugin] Clipboard Manager loaded. Commands: /clip /clips /copyclip /delclip /clearclips /searchclips")
