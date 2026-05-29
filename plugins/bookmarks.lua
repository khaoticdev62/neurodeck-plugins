-- bookmarks.lua — NEURODECK Plugin
-- URL bookmark manager — save, tag, search, and open URLs from the terminal
-- Commands: /bm /bms /delbm /searchbm /openbm /tagbm

local state_file = (os.getenv("HOME") or os.getenv("USERPROFILE") or ".") .. "/.config/neurodeck/data/bookmarks.json"

local function load_bms()
    local f = io.open(state_file, "r")
    if not f then return {} end
    local raw = f:read("*a"); f:close()
    local bms = {}
    for entry in raw:gmatch("{(.-)}") do
        local url   = entry:match('"url":"(.-)"')
        local title = entry:match('"title":"(.-)"')
        local tag   = entry:match('"tag":"(.-)"') or ""
        if url then table.insert(bms, { url = url, title = title or url, tag = tag }) end
    end
    return bms
end

local function save_bms(bms)
    local f = io.open(state_file, "w")
    if not f then return end
    local parts = {}
    for _, b in ipairs(bms) do
        local entry = string.format('{"url":"%s","title":"%s","tag":"%s"}',
            b.url:gsub('"', '\\"'), (b.title or b.url):gsub('"', '\\"'), (b.tag or ""):gsub('"', '\\"'))
        table.insert(parts, entry)
    end
    f:write("[" .. table.concat(parts, ",") .. "]")
    f:close()
end

local function open_url(url)
    local os_name = os.getenv("OS") or ""
    if os_name:find("Windows") then
        execute("start " .. url)
    else
        execute("xdg-open '" .. url:gsub("'", "") .. "' 2>/dev/null || open '" .. url:gsub("'", "") .. "' 2>/dev/null")
    end
end

registerCommand("bm", function(args)
    if not args or args == "" then print("Usage: /bm <url> [title]") return end
    local url, title = args:match("^(https?://%S+)%s*(.*)$")
    if not url then print("[BM] Invalid URL. Must start with http:// or https://") return end
    local bms = load_bms()
    for _, b in ipairs(bms) do
        if b.url == url then print("[BM] Already saved: " .. url) return end
    end
    table.insert(bms, { url = url, title = (title ~= "" and title or url), tag = "" })
    save_bms(bms)
    print("[BM] Saved: " .. url)
end)

registerCommand("bms", function()
    local bms = load_bms()
    if #bms == 0 then print("[BM] No bookmarks yet. Use /bm <url> to add.") return end
    for i, b in ipairs(bms) do
        local tag = b.tag ~= "" and " [" .. b.tag .. "]" or ""
        print(string.format("[%02d]%s %s\n     %s", i, tag, b.title:sub(1,60), b.url))
    end
end)

registerCommand("delbm", function(args)
    local n = tonumber(args)
    if not n then print("Usage: /delbm <number>") return end
    local bms = load_bms()
    if not bms[n] then print("[BM] No bookmark #" .. n) return end
    print("[BM] Deleted: " .. bms[n].url)
    table.remove(bms, n)
    save_bms(bms)
end)

registerCommand("searchbm", function(args)
    if not args or args == "" then print("Usage: /searchbm <query>") return end
    local bms = load_bms()
    local found = 0
    for i, b in ipairs(bms) do
        local hay = (b.url .. " " .. b.title .. " " .. b.tag):lower()
        if hay:find(args:lower(), 1, true) then
            print(string.format("[%02d] %s\n     %s", i, b.title:sub(1,60), b.url))
            found = found + 1
        end
    end
    if found == 0 then print("[BM] No matches for: " .. args) end
end)

registerCommand("openbm", function(args)
    local n = tonumber(args)
    if not n then print("Usage: /openbm <number>") return end
    local bms = load_bms()
    if not bms[n] then print("[BM] No bookmark #" .. n) return end
    open_url(bms[n].url)
    print("[BM] Opening: " .. bms[n].url)
end)

registerCommand("tagbm", function(args)
    if not args then print("Usage: /tagbm <number> <tag>") return end
    local n, tag = args:match("^(%d+)%s+(.+)$")
    if not n then print("Usage: /tagbm <number> <tag>") return end
    local bms = load_bms()
    if not bms[tonumber(n)] then print("[BM] No bookmark #" .. n) return end
    bms[tonumber(n)].tag = tag
    save_bms(bms)
    print("[BM] Tagged #" .. n .. " as: " .. tag)
end)

print("[Plugin] Bookmarks loaded. Commands: /bm /bms /delbm /searchbm /openbm /tagbm")
