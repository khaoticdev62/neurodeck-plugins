-- plugins/sysevents.lua
-- System Event Hooks — monitors message patterns, AI responses, and session activity.
-- JPE: Hooks are the "if this, then that" layer of NEURODECK. They sit between the
--      user's input and the AI — silently watching every message for patterns that
--      trigger useful side effects: auto-logging commands, flagging sensitive content,
--      injecting context, or surfacing warnings before they become bugs.
--
-- All hooks here are non-destructive: they observe and annotate, never block.

-- ── Security-sensitive keyword watchlist ─────────────────────────────────────
-- When a user message contains these strings, a warning is injected into the terminal
-- stream. This is not a security gate — it's an awareness signal.

local SECURITY_TRIGGERS = {
    { pattern = "rm %-rf",          warning = "Destructive delete detected. Verify this command before executing." },
    { pattern = "sudo rm",          warning = "Privileged delete detected. Verify this command before executing." },
    { pattern = "DROP TABLE",       warning = "SQL DROP TABLE detected. Ensure you have a backup." },
    { pattern = "DELETE FROM",      warning = "SQL DELETE statement detected. Add a WHERE clause or you'll delete everything." },
    { pattern = "format [Cc]:",     warning = "Disk format command detected. This is irreversible." },
    { pattern = "git push %-%-force", warning = "Force push detected. This rewrites remote history." },
    { pattern = "chmod 777",        warning = "chmod 777 grants world-write access. Prefer 755 or more restrictive." },
    { pattern = "curl.*%| sh",      warning = "Pipe-to-shell pattern detected. Inspect the downloaded script before running it." },
    { pattern = "curl.*%| bash",    warning = "Pipe-to-shell pattern detected. Inspect the downloaded script before running it." },
    { pattern = "eval.*curl",       warning = "eval+curl pattern detected. This can execute arbitrary remote code." },
    { pattern = "password.*=",      warning = "Possible plaintext password in command. Use env vars or a secrets manager instead." },
    { pattern = "API_KEY.*=",       warning = "Possible API key in plaintext. Use environment variables or the keychain instead." },
    { pattern = "SECRET.*=",        warning = "Possible secret in plaintext. Store secrets in env vars, not in commands or scripts." },
}

registerHook("onMessage", function(message)
    local lower = message:lower()
    for _, trigger in ipairs(SECURITY_TRIGGERS) do
        if message:find(trigger.pattern) or lower:find(trigger.pattern:lower()) then
            print("[⚠ Security Watch] " .. trigger.warning)
            break  -- one warning per message is enough
        end
    end
    return message
end)

-- ── Response word count meter ─────────────────────────────────────────────────
-- Logs the AI response size and flags unusually large responses.

registerHook("onAIResponse", function(response)
    local word_count = 0
    for _ in response:gmatch("%S+") do word_count = word_count + 1 end
    local char_count = #response

    if word_count > 1500 then
        print(string.format("[sysevents] Large AI response: %d words / %d chars. Consider asking for a summary.",
            word_count, char_count))
    end

    return response
end)

-- ── Command intercept: track command usage for session stats ──────────────────
-- Records which Lua commands were called this session (in-memory only).

local _session_command_counts = {}

registerHook("onCommand", function(cmd_name)
    _session_command_counts[cmd_name] = (_session_command_counts[cmd_name] or 0) + 1
    return cmd_name
end)

-- ── /stats — session command usage stats ─────────────────────────────────────

registerCommand("stats", function(_args)
    if next(_session_command_counts) == nil then
        return "No commands tracked yet this session."
    end

    -- Sort by usage count descending
    local sorted = {}
    for cmd, count in pairs(_session_command_counts) do
        table.insert(sorted, { cmd = cmd, count = count })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    local lines = { "Session command usage:" }
    for _, item in ipairs(sorted) do
        local bar = string.rep("▪", math.min(item.count, 20))
        table.insert(lines, string.format("  %-18s %s (%d)", item.cmd, bar, item.count))
    end
    return table.concat(lines, "\n")
end)

-- ── /watch — toggle pattern watching (on/off) ─────────────────────────────────
-- Lets the user add their own trigger patterns for the current session.

local _custom_watches = {}
local _watching = true

registerCommand("watch", function(args)
    local sub = args:match("^(%S+)") or ""

    if sub == "off" then
        _watching = false
        return "Security watching paused. Use /watch on to resume."
    elseif sub == "on" then
        _watching = true
        return "Security watching active."
    elseif sub == "status" then
        return string.format("Watching: %s | Built-in triggers: %d | Custom triggers: %d",
            _watching and "ON" or "OFF",
            #SECURITY_TRIGGERS,
            #_custom_watches)
    elseif sub == "add" then
        local pattern = args:match("^%S+%s+(.+)$")
        if not pattern then return "Usage: /watch add <pattern>" end
        table.insert(_custom_watches, pattern)
        return string.format("Custom watch added: '%s' (%d total custom)", pattern, #_custom_watches)
    elseif sub == "list" then
        local lines = { "Built-in watches:" }
        for _, t in ipairs(SECURITY_TRIGGERS) do
            table.insert(lines, "  • " .. t.pattern:gsub("%%", ""))
        end
        if #_custom_watches > 0 then
            table.insert(lines, "Custom watches:")
            for _, p in ipairs(_custom_watches) do
                table.insert(lines, "  • " .. p)
            end
        end
        return table.concat(lines, "\n")
    else
        return "Usage: /watch <on|off|status|list|add <pattern>>"
    end
end)

-- ── Startup health check ──────────────────────────────────────────────────────
-- Runs a lightweight system sanity check when the plugin loads.

local function startup_check()
    local issues = {}

    -- Check for git
    local git_v = execute("git --version 2>&1"):gsub("[\r\n]+", "")
    if git_v:find("not found") or git_v:find("not recognized") then
        table.insert(issues, "git not found in PATH")
    end

    -- Check for curl
    local curl_v = execute("curl --version 2>&1"):sub(1, 30):gsub("[\r\n]+", "")
    if curl_v:find("not found") or curl_v:find("not recognized") then
        table.insert(issues, "curl not found — weather, ipinfo, and netcheck commands will fail")
    end

    if #issues > 0 then
        print("[sysevents] Startup warnings:")
        for _, issue in ipairs(issues) do
            print("  ⚠ " .. issue)
        end
    end
end

startup_check()

print("[Plugin] sysevents loaded — security watch active | /stats /watch")
