-- plugins/aliases.lua
-- Dynamic Command Aliases — create shorthand commands that expand to longer ones.
-- JPE: An alias is a nickname for a command you type constantly. "/gs" is shorter
--      than "git status". But sometimes you want shortcuts for YOUR specific workflow —
--      "/deploy", "/test", "/reset" mapped to whatever that means on your project.
--      This plugin lets you define those shortcuts at runtime and persist them.
--
-- Aliases are stored in a flat file and re-registered each time the app starts.
-- Aliases can target ANY NEURODECK command (including other Lua plugin commands).
-- They cannot target shell commands directly — use /run for that.

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── Storage path ──────────────────────────────────────────────────────────────

local ALIAS_FILE
if WIN then
    local appdata = execute("echo %APPDATA%"):gsub("[\r\n]+", "")
    ALIAS_FILE = appdata .. "\\neurodeck\\plugin-aliases.txt"
    execute("if not exist \"" .. appdata .. "\\neurodeck\" mkdir \"" .. appdata .. "\\neurodeck\"")
else
    local home = execute("echo $HOME"):gsub("[\r\n]+", "")
    ALIAS_FILE = home .. "/.config/neurodeck/plugin-aliases.txt"
    execute("mkdir -p '" .. home .. "/.config/neurodeck'")
end

-- ── In-memory alias table ─────────────────────────────────────────────────────

local _aliases = {}   -- { [alias_name] = target_command_string }

-- ── Storage helpers ───────────────────────────────────────────────────────────

local function load_aliases_from_disk()
    local raw
    if WIN then
        raw = execute("type \"" .. ALIAS_FILE .. "\" 2>nul") or ""
    else
        raw = execute("cat '" .. ALIAS_FILE .. "' 2>/dev/null") or ""
    end
    local loaded = {}
    for line in raw:gmatch("[^\r\n]+") do
        local name, target = line:match("^([a-z0-9_%-]+)=(.+)$")
        if name and target then
            loaded[name] = target
        end
    end
    return loaded
end

local function save_aliases_to_disk(aliases)
    local lines = {}
    for k, v in pairs(aliases) do
        table.insert(lines, k .. "=" .. v)
    end
    table.sort(lines)
    local raw = table.concat(lines, "\n")
    if WIN then
        local escaped = raw:gsub("'", "''")
        execute("powershell -Command \"Set-Content -Path '" .. ALIAS_FILE ..
            "' -Value '" .. escaped .. "' -Encoding UTF8\" 2>nul")
    else
        local escaped = raw:gsub("'", "'\\''")
        execute("printf '%s' '" .. escaped .. "' > '" .. ALIAS_FILE .. "' 2>/dev/null")
    end
end

-- Register one alias as a live command in the Lua runtime
-- The registered function calls the target command's handler via _commands table.
-- Since we can't call registerCommand from inside a registerCommand callback
-- (the _commands table is accessed at call time), we use a closure over the
-- alias target string.
local function register_alias(name, target)
    _aliases[name] = target
    registerCommand(name, function(extra_args)
        -- Find the target command and its handler
        local target_name = target:match("^(%S+)")
        local target_args = target:match("^%S+%s*(.*)") or ""
        -- Append any args the user passed to the alias itself
        if extra_args and extra_args ~= "" then
            target_args = target_args ~= "" and (target_args .. " " .. extra_args) or extra_args
        end
        -- Route to the target command's handler via _commands table
        local fn = _commands and _commands[target_name]
        if fn then
            return fn(target_args)
        end
        return string.format(
            "Alias '%s' → '%s' (args: '%s')\n" ..
            "Target command '%s' is not loaded. Check that its plugin is enabled.",
            name, target, target_args, target_name)
    end)
end

-- ── Boot: restore persisted aliases ───────────────────────────────────────────

local persisted = load_aliases_from_disk()
local restored = 0
for name, target in pairs(persisted) do
    local ok, err = pcall(register_alias, name, target)
    if ok then
        restored = restored + 1
    else
        print("[aliases] Failed to restore alias '" .. name .. "': " .. tostring(err))
    end
end
if restored > 0 then
    print(string.format("[aliases] Restored %d alias(es) from disk.", restored))
end

-- ── /alias — create an alias ──────────────────────────────────────────────────
-- Usage: /alias <alias-name> <target-command> [args]
-- Example: /alias gs gitops-gs
-- Example: /alias myip netcheck-myip

registerCommand("alias", function(args)
    local name, target = args:match("^([a-z0-9_%-]+)%s+(.+)$")
    if not name or not target then
        return "Usage: /alias <name> <target-command> [default-args]\n" ..
               "  name   : letters, digits, hyphens, underscores only\n" ..
               "  target : a NEURODECK command name and optional default args\n\n" ..
               "Example: /alias gstatus gs\n" ..
               "         /alias summarize-en aitools-summarize in English:"
    end
    name   = name:lower()
    target = target:gsub("^%s+", ""):gsub("%s+$", "")

    -- Guard: don't let aliases shadow built-in commands we know about
    local protected = { alias=true, aliases=true, unalias=true, help=true }
    if protected[name] then
        return string.format("'%s' is a protected command name.", name)
    end

    register_alias(name, target)
    save_aliases_to_disk(_aliases)

    local existed = persisted[name] ~= nil
    persisted[name] = target
    return string.format(
        existed and "✏ Updated alias: /%s → %s" or "✅ Created alias: /%s → %s",
        name, target)
end)

-- ── /aliases — list all active aliases ────────────────────────────────────────

registerCommand("aliases", function(_args)
    if next(_aliases) == nil then
        return "No aliases defined. Use /alias <name> <target> to create one."
    end
    local names = {}
    for k in pairs(_aliases) do table.insert(names, k) end
    table.sort(names)
    local lines = { string.format("Active aliases (%d):", #names) }
    for _, k in ipairs(names) do
        table.insert(lines, string.format("  /%-16s → %s", k, _aliases[k]))
    end
    return table.concat(lines, "\n")
end)

-- ── /unalias — remove an alias ────────────────────────────────────────────────

registerCommand("unalias", function(args)
    local name = args:match("^([a-z0-9_%-]+)"):lower()
    if not name or name == "" then return "Usage: /unalias <alias-name>" end
    if not _aliases[name] then
        return string.format("Alias '%s' doesn't exist.", name)
    end
    local target = _aliases[name]
    _aliases[name] = nil
    persisted[name] = nil
    save_aliases_to_disk(_aliases)
    -- We can't un-register a command from the Lua runtime, but setting it to
    -- return an error message is the next best thing.
    registerCommand(name, function(_)
        return string.format("Alias '%s' has been deleted. Re-create it with /alias.", name)
    end)
    return string.format("🗑 Removed alias '/%s' (was → %s).", name, target)
end)

print("[Plugin] aliases loaded — /alias /aliases /unalias")
