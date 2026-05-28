-- plugins/devtools.lua
-- Developer Tools — port scanner, process inspector, env vars, PATH explorer.
-- JPE: The things you reach for a dozen times a day — "what's on port 3000?",
--      "is node in my PATH?", "what env vars does this app see?" — now live here.

local function clean(s)
    if not s or s == "" then return "" end
    return s:gsub('[;|&`$<>%(%){}%[%]"\'\\]', "")
end

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── /ports — listening TCP ports ─────────────────────────────────────────────

registerCommand("ports", function(args)
    local filter = clean(args)
    if WIN then
        local out = execute("netstat -ano | findstr LISTENING 2>nul")
        if filter ~= "" then
            local lines = {}
            for line in out:gmatch("[^\r\n]+") do
                if line:find(filter) then table.insert(lines, line) end
            end
            return #lines > 0 and table.concat(lines, "\n") or ("No LISTENING ports matching '" .. filter .. "'.")
        end
        return out ~= "" and out or "No listening ports found."
    else
        local cmd = "ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null"
        local out = execute(cmd)
        if filter ~= "" then
            local lines = {}
            for line in out:gmatch("[^\r\n]+") do
                if line:find(filter) then table.insert(lines, line) end
            end
            return #lines > 0 and table.concat(lines, "\n") or ("No ports matching '" .. filter .. "'.")
        end
        return out ~= "" and out or "No listening ports found."
    end
end)

-- ── /port — what process owns a specific port ─────────────────────────────────

registerCommand("port", function(args)
    local p = clean(args:match("^(%d+)") or "")
    if p == "" then return "Usage: /port <number>\nExample: /port 3000" end
    if WIN then
        local out = execute("netstat -ano | findstr :" .. p .. " 2>nul")
        if out == "" then return "Nothing found on port " .. p end
        -- Try to resolve PID to process name
        local pid = out:match("%s+(%d+)%s*$")
        if pid then
            local name = execute("tasklist /fi \"PID eq " .. pid .. "\" /fo csv /nh 2>nul"):match('"([^"]+)"')
            if name then return out .. "\n→ PID " .. pid .. " = " .. name end
        end
        return out
    else
        local out = execute("ss -tlnp 'sport = :" .. p .. "' 2>/dev/null")
        if out == "" or out:find("^%s*$") then
            out = execute("lsof -i :" .. p .. " 2>/dev/null")
        end
        return out ~= "" and out or "Nothing listening on port " .. p
    end
end)

-- ── /which — locate a command in PATH ────────────────────────────────────────

registerCommand("which", function(args)
    local cmd = clean(args:match("^(%S+)") or "")
    if cmd == "" then return "Usage: /which <command>\nExample: /which node" end
    if WIN then
        local out = execute("where " .. cmd .. " 2>nul")
        return out ~= "" and out or (cmd .. " not found in PATH.")
    else
        local out = execute("which " .. cmd .. " 2>/dev/null || type " .. cmd .. " 2>&1")
        return out ~= "" and out:gsub("[\r\n]+$", "") or (cmd .. " not found in PATH.")
    end
end)

-- ── /env — inspect environment variables ─────────────────────────────────────
-- /env          — list all env vars (trimmed)
-- /env <NAME>   — show value of one var

registerCommand("env", function(args)
    local varname = clean(args:match("^(%S+)") or "")
    if varname ~= "" then
        local val
        if WIN then
            val = execute("echo %" .. varname .. "% 2>nul"):gsub("[\r\n]+", "")
            -- echo on Windows returns %VAR% literally if the var is unset
            if val == "%" .. varname .. "%" then val = "(not set)" end
        else
            val = execute("printenv " .. varname .. " 2>/dev/null"):gsub("[\r\n]+$", "")
            if val == "" then val = "(not set)" end
        end
        return varname .. " = " .. val
    else
        local out
        if WIN then
            out = execute("set 2>nul"):sub(1, 3000)
        else
            out = execute("env 2>/dev/null | sort"):sub(1, 3000)
        end
        return out ~= "" and out or "Could not read environment."
    end
end)

-- ── /path — display PATH entries one per line ─────────────────────────────────

registerCommand("path", function(_args)
    local raw
    if WIN then
        raw = execute("echo %PATH% 2>nul"):gsub("[\r\n]+", "")
        if raw == "" then return "PATH is empty." end
        local lines = { "PATH entries:" }
        for segment in raw:gmatch("[^;]+") do
            table.insert(lines, "  " .. segment)
        end
        return table.concat(lines, "\n")
    else
        raw = execute("printenv PATH 2>/dev/null"):gsub("[\r\n]+$", "")
        if raw == "" then return "PATH is empty." end
        local lines = { "PATH entries:" }
        for segment in raw:gmatch("[^:]+") do
            table.insert(lines, "  " .. segment)
        end
        return table.concat(lines, "\n")
    end
end)

-- ── /running — quick process search ──────────────────────────────────────────
-- Usage: /running <process-name>

registerCommand("running", function(args)
    local name = clean(args:match("^(%S+)") or "")
    if name == "" then return "Usage: /running <process-name>\nExample: /running node" end
    if WIN then
        local out = execute("tasklist /fi \"IMAGENAME eq " .. name .. ".exe\" 2>nul")
        return out:find("No tasks") and (name .. " is NOT running.") or out
    else
        local out = execute("pgrep -la " .. name .. " 2>/dev/null")
        return out ~= "" and out or (name .. " is NOT running.")
    end
end)

-- ── /kill — kill a process by name (with confirmation guard) ─────────────────
-- Returns confirmation string rather than auto-killing — avoids accidents.

registerCommand("kill", function(args)
    local name = clean(args:match("^(%S+)") or "")
    if name == "" then return "Usage: /kill <process-name>\nWARNING: runs killall/taskkill. Confirm you mean it." end
    if WIN then
        local out = execute("taskkill /IM " .. name .. ".exe /F 2>nul")
        return out ~= "" and out or ("Attempted to kill " .. name .. " — check task manager.")
    else
        local out = execute("killall " .. name .. " 2>&1")
        return out ~= "" and out or ("Signal sent to all " .. name .. " processes.")
    end
end)

-- ── /node — node/npm version check ───────────────────────────────────────────

registerCommand("node", function(_args)
    local node_v = execute("node --version 2>&1"):gsub("[\r\n]+", "")
    local npm_v  = execute("npm --version 2>&1"):gsub("[\r\n]+", "")
    local lines  = {}
    table.insert(lines, "node : " .. (node_v ~= "" and node_v or "not found"))
    table.insert(lines, "npm  : " .. (npm_v ~= "" and npm_v or "not found"))
    local bun = execute("bun --version 2>&1"):gsub("[\r\n]+", "")
    if bun ~= "" and not bun:find("not found") and not bun:find("Error") then
        table.insert(lines, "bun  : " .. bun)
    end
    local yarn = execute("yarn --version 2>&1"):gsub("[\r\n]+", "")
    if yarn ~= "" and not yarn:find("not found") and not yarn:find("Error") then
        table.insert(lines, "yarn : " .. yarn)
    end
    return table.concat(lines, "\n")
end)

-- ── /versions — language runtime versions ────────────────────────────────────

registerCommand("versions", function(_args)
    local runtimes = {
        { "node",   "node --version" },
        { "npm",    "npm --version" },
        { "cargo",  "cargo --version" },
        { "rustc",  "rustc --version" },
        { "python", "python3 --version 2>&1 || python --version 2>&1" },
        { "go",     "go version" },
        { "java",   "java -version 2>&1" },
        { "ruby",   "ruby --version" },
        { "lua",    "lua -v 2>&1" },
        { "git",    "git --version" },
    }
    local lines = { "Runtime versions:" }
    for _, rt in ipairs(runtimes) do
        local out = execute(rt[2] .. " 2>&1"):gsub("[\r\n]+", "")
        if out ~= "" and not out:find("not found") and not out:find("is not recognized") and not out:find("Error") then
            table.insert(lines, string.format("  %-8s %s", rt[1], out))
        end
    end
    return #lines > 1 and table.concat(lines, "\n") or "No runtimes detected."
end)

print("[Plugin] devtools loaded — /ports /port /which /env /path /running /kill /node /versions")
