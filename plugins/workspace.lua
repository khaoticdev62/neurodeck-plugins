-- plugins/workspace.lua
-- Workspace Manager — switch project contexts, set working directories, run project commands.
-- JPE: A "workspace" is a named project with a root path and optional quick-run commands.
--      Switching workspace sets the context for subsequent /run calls so you don't have
--      to type the full path every time. Think of it like "cd" with memory.
--
-- Workspaces persist across sessions. Each workspace stores:
--   name, path, and up to 3 named quick-run scripts (e.g. "dev", "test", "build").

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── Storage ───────────────────────────────────────────────────────────────────

local PROJ_FILE
if WIN then
    local appdata = execute("echo %APPDATA%"):gsub("[\r\n]+", "")
    PROJ_FILE = appdata .. "\\neurodeck\\plugin-workspaces.txt"
    execute("if not exist \"" .. appdata .. "\\neurodeck\" mkdir \"" .. appdata .. "\\neurodeck\"")
else
    local home = execute("echo $HOME"):gsub("[\r\n]+", "")
    PROJ_FILE  = home .. "/.config/neurodeck/plugin-workspaces.txt"
    execute("mkdir -p '" .. home .. "/.config/neurodeck'")
end

-- Format: name|path|dev_cmd|test_cmd|build_cmd
local SEP = "|"

local function load_workspaces()
    local raw
    if WIN then
        raw = execute("type \"" .. PROJ_FILE .. "\" 2>nul") or ""
    else
        raw = execute("cat '" .. PROJ_FILE .. "' 2>/dev/null") or ""
    end
    local ws = {}
    for line in raw:gmatch("[^\r\n]+") do
        if line:gsub("%s+", "") ~= "" then
            local parts = {}
            for part in (line .. SEP .. SEP .. SEP .. SEP):gmatch("([^|]*)|") do
                table.insert(parts, part)
            end
            if parts[1] and parts[1] ~= "" then
                ws[parts[1]:lower()] = {
                    name  = parts[1],
                    path  = parts[2] or "",
                    dev   = parts[3] or "",
                    test  = parts[4] or "",
                    build = parts[5] or "",
                }
            end
        end
    end
    return ws
end

local function save_workspaces(ws)
    local lines = {}
    for _, w in pairs(ws) do
        table.insert(lines, table.concat({
            w.name, w.path, w.dev, w.test, w.build
        }, SEP))
    end
    table.sort(lines)
    local raw = table.concat(lines, "\n")
    if WIN then
        local escaped = raw:gsub("'", "''")
        execute("powershell -Command \"Set-Content -Path '" .. PROJ_FILE ..
            "' -Value '" .. escaped .. "' -Encoding UTF8\" 2>nul")
    else
        local escaped = raw:gsub("'", "'\\''")
        execute("printf '%s' '" .. escaped .. "' > '" .. PROJ_FILE .. "' 2>/dev/null")
    end
end

-- Active workspace (in-memory, resets on restart)
local _active = nil   -- workspace table

-- ── /addproj — register a workspace ──────────────────────────────────────────
-- Usage: /addproj <name> <path>
-- Example: /addproj neurodeck ~/Desktop/S-Term

registerCommand("addproj", function(args)
    local name, path = args:match("^(%S+)%s+(.+)$")
    if not name or not path then
        return "Usage: /addproj <name> <path>\n" ..
               "Example: /addproj myapp ~/projects/myapp\n\n" ..
               "After adding, set scripts with:\n" ..
               "  /projset <name> dev <command>\n" ..
               "  /projset <name> test <command>\n" ..
               "  /projset <name> build <command>"
    end

    name = name:lower():gsub("[^a-z0-9_%-]", "")
    path = path:gsub("^%s+", ""):gsub("%s+$", "")

    -- Expand ~ on Linux
    if not WIN then
        if path:sub(1,1) == "~" then
            local home = execute("echo $HOME"):gsub("[\r\n]+", "")
            path = home .. path:sub(2)
        end
    end

    -- Verify path exists
    local exists
    if WIN then
        exists = execute("if exist \"" .. path:gsub("/","\\") .. "\" echo yes 2>nul"):find("yes")
    else
        exists = execute("test -d '" .. path:gsub("'","'\\''") .. "' && echo yes 2>/dev/null"):find("yes")
    end

    local ws = load_workspaces()
    local existed = ws[name] ~= nil
    ws[name] = {
        name  = name,
        path  = path,
        dev   = ws[name] and ws[name].dev   or "",
        test  = ws[name] and ws[name].test  or "",
        build = ws[name] and ws[name].build or "",
    }
    save_workspaces(ws)

    local warn = (not exists) and "\n⚠ Warning: path does not exist (yet)." or ""
    return string.format(
        existed and "✏ Updated workspace '%s' → %s%s" or "✅ Added workspace '%s' → %s%s",
        name, path, warn)
end)

-- ── /projset — set a workspace script ────────────────────────────────────────
-- Usage: /projset <name> <dev|test|build> <command>

registerCommand("projset", function(args)
    local name, script_type, cmd = args:match("^(%S+)%s+(%S+)%s+(.+)$")
    if not name then
        return "Usage: /projset <workspace> <dev|test|build> <command>\n" ..
               "Example: /projset neurodeck dev npm run tauri dev"
    end
    name        = name:lower()
    script_type = script_type:lower()

    local valid_types = { dev = true, test = true, build = true }
    if not valid_types[script_type] then
        return "Script type must be: dev, test, or build."
    end

    local ws = load_workspaces()
    if not ws[name] then
        return string.format("Workspace '%s' not found. Use /addproj to create it first.", name)
    end
    ws[name][script_type] = cmd
    save_workspaces(ws)
    return string.format("✅ Set %s.%s = %s", name, script_type, cmd)
end)

-- ── /proj — switch to a workspace ────────────────────────────────────────────
-- Usage: /proj <name>

registerCommand("proj", function(args)
    local name = args:match("^(%S+)") or ""
    if name == "" then
        -- No arg — show current workspace
        if _active then
            return string.format(
                "Active workspace: %s\nPath: %s\n" ..
                "Scripts — dev: %s | test: %s | build: %s\n\n" ..
                "Use /run dev|test|build to execute. Use /proj <name> to switch.",
                _active.name, _active.path,
                _active.dev  ~= "" and _active.dev  or "(none)",
                _active.test ~= "" and _active.test ~= "" and _active.test or "(none)",
                _active.build ~= "" and _active.build or "(none)")
        end
        return "No workspace active. Use /proj <name> to switch.\nList available with /projs."
    end

    name = name:lower()
    local ws = load_workspaces()
    local w  = ws[name]
    if not w then
        return string.format("Workspace '%s' not found. Use /addproj <name> <path> to create it.", name)
    end
    _active = w
    return string.format(
        "✅ Switched to workspace '%s'\nPath  : %s\nDev   : %s\nTest  : %s\nBuild : %s\n\nRun scripts with /run dev|test|build",
        w.name, w.path,
        w.dev   ~= "" and w.dev   or "(not set)",
        w.test  ~= "" and w.test  or "(not set)",
        w.build ~= "" and w.build or "(not set)")
end)

-- ── /projs — list all workspaces ─────────────────────────────────────────────

registerCommand("projs", function(_args)
    local ws = load_workspaces()
    local names = {}
    for k in pairs(ws) do table.insert(names, k) end
    if #names == 0 then
        return "No workspaces defined yet. Use /addproj <name> <path> to add one."
    end
    table.sort(names)
    local lines = { string.format("Workspaces (%d):", #names) }
    for _, k in ipairs(names) do
        local w      = ws[k]
        local active = (_active and _active.name == k) and " ◀ active" or ""
        table.insert(lines, string.format("  %-16s %s%s", k, w.path, active))
        if w.dev   ~= "" then table.insert(lines, string.format("    dev   : %s", w.dev)) end
        if w.test  ~= "" then table.insert(lines, string.format("    test  : %s", w.test)) end
        if w.build ~= "" then table.insert(lines, string.format("    build : %s", w.build)) end
    end
    return table.concat(lines, "\n")
end)

-- ── /run — execute a workspace script ────────────────────────────────────────
-- Usage: /run dev|test|build   (requires active workspace)
--        /run <shell-command>  (runs in active workspace path)

registerCommand("run", function(args)
    if not _active then
        return "No active workspace. Use /proj <name> first.\nList workspaces with /projs."
    end

    local sub = args:match("^(%S+)") or ""
    local cmd

    if sub == "dev" then
        cmd = _active.dev
        if cmd == "" then return string.format("No dev script set for '%s'. Use /projset %s dev <command>.", _active.name, _active.name) end
    elseif sub == "test" then
        cmd = _active.test
        if cmd == "" then return string.format("No test script set for '%s'. Use /projset %s test <command>.", _active.name, _active.name) end
    elseif sub == "build" then
        cmd = _active.build
        if cmd == "" then return string.format("No build script set for '%s'. Use /projset %s build <command>.", _active.name, _active.name) end
    else
        -- Arbitrary command in the workspace path
        cmd = args:gsub("[;|&`$<>%(%){}%[%]\"'\\]", "")
        if cmd == "" then return "Usage: /run <dev|test|build> or /run <command>" end
    end

    local full_cmd
    if WIN then
        local win_path = _active.path:gsub("/", "\\")
        full_cmd = string.format("cd /d \"%s\" && %s 2>&1", win_path, cmd)
    else
        local safe_path = _active.path:gsub("'", "\\'")
        full_cmd = string.format("cd '%s' && %s 2>&1", safe_path, cmd)
    end

    print(string.format("[workspace] Running in %s: %s", _active.path, cmd))
    local out = execute(full_cmd)
    return out ~= "" and out:sub(1, 4000) or ("Command completed (no output).")
end)

-- ── /cwd — current working directory ─────────────────────────────────────────

registerCommand("cwd", function(_args)
    local cwd
    if WIN then
        cwd = execute("cd 2>nul"):gsub("[\r\n]+", "")
    else
        cwd = execute("pwd 2>/dev/null"):gsub("[\r\n]+", "")
    end
    local active_info = _active and (" (workspace: " .. _active.name .. ")") or ""
    return cwd .. active_info
end)

-- ── /delproj — remove a workspace ────────────────────────────────────────────

registerCommand("delproj", function(args)
    local name = args:match("^(%S+)") or ""
    if name == "" then return "Usage: /delproj <workspace-name>" end
    name = name:lower()
    local ws = load_workspaces()
    if not ws[name] then
        return string.format("Workspace '%s' not found.", name)
    end
    ws[name] = nil
    save_workspaces(ws)
    if _active and _active.name == name then _active = nil end
    return string.format("🗑 Removed workspace '%s'.", name)
end)

print("[Plugin] workspace loaded — /proj /projs /addproj /projset /delproj /run /cwd")
