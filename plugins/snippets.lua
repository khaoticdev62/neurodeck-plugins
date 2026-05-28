-- plugins/snippets.lua
-- Code Snippet Library — store, retrieve, and manage reusable code fragments.
-- JPE: A snippet is any chunk of text you type more than twice. Instead of grep-ing
--      through old files or asking the AI for the nth time, you save it once and
--      pull it back with two words. Think of it as a personal clipboard with names.
--
-- Snippets are stored in a JSON-like plain text format, one per line:
-- <name>|||<content>

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── Storage path ──────────────────────────────────────────────────────────────

local SNIP_FILE
if WIN then
    local appdata = execute("echo %APPDATA%"):gsub("[\r\n]+", "")
    SNIP_FILE = appdata .. "\\neurodeck\\plugin-snippets.txt"
    execute("if not exist \"" .. appdata .. "\\neurodeck\" mkdir \"" .. appdata .. "\\neurodeck\"")
else
    local home = execute("echo $HOME"):gsub("[\r\n]+", "")
    SNIP_FILE  = home .. "/.config/neurodeck/plugin-snippets.txt"
    execute("mkdir -p '" .. home .. "/.config/neurodeck'")
end

-- ── Storage helpers ───────────────────────────────────────────────────────────

local SEP = "|||"   -- field separator that won't appear in normal code

local function load_snippets()
    local raw
    if WIN then
        raw = execute("type \"" .. SNIP_FILE .. "\" 2>nul") or ""
    else
        raw = execute("cat '" .. SNIP_FILE .. "' 2>/dev/null") or ""
    end
    local snips = {}
    for line in raw:gmatch("[^\r\n]+") do
        if line:gsub("%s+", "") ~= "" then
            local name, content = line:match("^([^|]+)" .. SEP .. "(.+)$")
            if name and content then
                snips[name:lower()] = { name = name, content = content }
            end
        end
    end
    return snips
end

local function save_snippets(snips)
    local lines = {}
    for _, s in pairs(snips) do
        table.insert(lines, s.name .. SEP .. s.content)
    end
    table.sort(lines)
    local raw = table.concat(lines, "\n")
    if WIN then
        local escaped = raw:gsub("'", "''")
        execute("powershell -Command \"Set-Content -Path '" .. SNIP_FILE ..
            "' -Value '" .. escaped .. "' -Encoding UTF8\" 2>nul")
    else
        local escaped = raw:gsub("'", "'\\''")
        execute("printf '%s' '" .. escaped .. "' > '" .. SNIP_FILE .. "' 2>/dev/null")
    end
end

local function valid_name(s)
    return s:match("^[a-zA-Z0-9_%-]+$") ~= nil
end

-- ── /addsnip — save a snippet ─────────────────────────────────────────────────
-- Usage: /addsnip <name> <content>
-- Example: /addsnip gitinit git init && git add -A && git commit -m "init"

registerCommand("addsnip", function(args)
    local name, content = args:match("^(%S+)%s+(.+)$")
    if not name or not content then
        return "Usage: /addsnip <name> <content>\nNames: letters, numbers, - and _ only.\nExample: /addsnip curl-json curl -sH 'Content-Type: application/json'"
    end
    name = name:lower()
    if not valid_name(name) then
        return "Invalid name '" .. name .. "'. Use only letters, digits, hyphens, and underscores."
    end
    if #content > 2000 then
        return "Snippet too long (max 2000 chars). For large blocks, save to a file instead."
    end
    local snips = load_snippets()
    local existed = snips[name] ~= nil
    snips[name] = { name = name, content = content }
    save_snippets(snips)
    return string.format(
        existed and "✏ Updated snippet '%s'." or "✅ Saved snippet '%s'.", name)
end)

-- ── /snip — retrieve a snippet ────────────────────────────────────────────────

registerCommand("snip", function(args)
    local name = args:match("^(%S+)") or ""
    if name == "" then
        return "Usage: /snip <name>\nList all with /snips."
    end
    name = name:lower()
    local snips = load_snippets()
    local s = snips[name]
    if not s then
        -- Fuzzy suggest: names that start with the query
        local suggestions = {}
        for k in pairs(snips) do
            if k:find(name, 1, true) then table.insert(suggestions, k) end
        end
        if #suggestions > 0 then
            table.sort(suggestions)
            return string.format("Snippet '%s' not found. Did you mean: %s?",
                name, table.concat(suggestions, ", "))
        end
        return string.format("Snippet '%s' not found. Use /snips to list all.", name)
    end
    return string.format("── %s ──────────────\n%s", s.name, s.content)
end)

-- ── /snips — list all snippets ────────────────────────────────────────────────

registerCommand("snips", function(args)
    local snips = load_snippets()
    local keys  = {}
    for k in pairs(snips) do table.insert(keys, k) end

    if #keys == 0 then
        return "No snippets saved yet. Use /addsnip <name> <content> to create one."
    end

    -- Optional filter
    local filter = args:match("^(%S+)") or ""
    local fl     = filter:lower()
    local lines  = {}
    table.sort(keys)
    for _, k in ipairs(keys) do
        if fl == "" or k:find(fl, 1, true) then
            local preview = snips[k].content:sub(1, 60):gsub("[\r\n]+", " ")
            if #snips[k].content > 60 then preview = preview .. "…" end
            table.insert(lines, string.format("  %-20s  %s", k, preview))
        end
    end

    if #lines == 0 then return "No snippets matching '" .. filter .. "'." end
    table.insert(lines, 1, string.format("Snippets (%d):", #lines))
    return table.concat(lines, "\n")
end)

-- ── /delsnip — delete a snippet ───────────────────────────────────────────────

registerCommand("delsnip", function(args)
    local name = args:match("^(%S+)") or ""
    if name == "" then return "Usage: /delsnip <name>" end
    name = name:lower()
    local snips = load_snippets()
    if not snips[name] then
        return string.format("Snippet '%s' doesn't exist.", name)
    end
    snips[name] = nil
    save_snippets(snips)
    return string.format("🗑 Deleted snippet '%s'.", name)
end)

-- ── /copysnip — copy a snippet to clipboard (Linux/X11 or xclip) ─────────────

registerCommand("copysnip", function(args)
    local name = args:match("^(%S+)") or ""
    if name == "" then return "Usage: /copysnip <name>" end
    name = name:lower()
    local snips = load_snippets()
    local s = snips[name]
    if not s then return string.format("Snippet '%s' not found.", name) end

    local content_escaped = s.content:gsub("'", "'\\''")
    local out
    if WIN then
        out = execute("echo " .. s.content:gsub("[\"^]", "") .. " | clip 2>nul")
        return "Snippet '" .. name .. "' sent to clipboard (Windows clip)."
    else
        out = execute("printf '%s' '" .. content_escaped .. "' | xclip -selection clipboard 2>/dev/null")
        if out and out:find("Error") then
            out = execute("printf '%s' '" .. content_escaped .. "' | xsel --clipboard --input 2>/dev/null")
        end
        return "Snippet '" .. name .. "' copied to clipboard.\n" .. s.content
    end
end)

print("[Plugin] snippets loaded — /snip /addsnip /snips /delsnip /copysnip")
