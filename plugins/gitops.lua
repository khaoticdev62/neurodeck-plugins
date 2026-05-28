-- plugins/gitops.lua
-- Git Operations — fast-access git shortcuts for the solo developer workflow.
-- JPE: Every command here maps to something you'd type in a terminal ten times
--      a day. The goal is one keystroke instead of twenty.

-- Sanitize user input before it touches the shell
local function clean(s)
    if not s or s == "" then return "" end
    return s:gsub('[;|&`$<>%(%){}%[%]"\'\\]', "")
end

-- ── /gs — git status ──────────────────────────────────────────────────────────

registerCommand("gs", function(_args)
    local out = execute("git status 2>&1")
    if not out or out == "" then return "Not in a git repository (or git not installed)." end
    return out
end)

-- ── /gd — git diff (staged and unstaged) ─────────────────────────────────────

registerCommand("gd", function(args)
    local flag = args:find("--staged") and "--staged" or ""
    local out = execute("git diff " .. flag .. " --stat 2>&1")
    if not out or out:find("^%s*$") then return "No changes to diff." end
    -- For readability, show the stat summary plus a short diff preview
    local detail = execute("git diff " .. flag .. " 2>&1"):sub(1, 2000)
    return out .. "\n" .. detail
end)

-- ── /gl — git log (last N commits) ───────────────────────────────────────────

registerCommand("gl", function(args)
    local n = tonumber(clean(args)) or 10
    if n > 50 then n = 50 end
    local out = execute(string.format(
        "git log --oneline --decorate --color=never -n %d 2>&1", n))
    return out ~= "" and out or "No commits found (empty repository?)."
end)

-- ── /gc — git commit ──────────────────────────────────────────────────────────
-- Usage: /gc Your commit message here

registerCommand("gc", function(args)
    local msg = args:gsub("[\"'`\\]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then
        return "Usage: /gc <commit message>\nExample: /gc fix: correct navbar highlight on mobile"
    end
    -- Stage all tracked changes first, then commit
    local stage = execute("git add -u 2>&1")
    local out   = execute('git commit -m "' .. msg .. '" 2>&1')
    local result = {}
    if stage and stage ~= "" then table.insert(result, stage) end
    table.insert(result, out)
    return table.concat(result, "\n")
end)

-- ── /gca — git commit all (including untracked) ───────────────────────────────

registerCommand("gca", function(args)
    local msg = args:gsub("[\"'`\\]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then
        return "Usage: /gca <commit message>\nStages ALL files (including new) before committing."
    end
    local stage = execute("git add -A 2>&1")
    local out   = execute('git commit -m "' .. msg .. '" 2>&1')
    local result = {}
    if stage and stage ~= "" then table.insert(result, stage) end
    table.insert(result, out)
    return table.concat(result, "\n")
end)

-- ── /gp — git push ────────────────────────────────────────────────────────────

registerCommand("gp", function(args)
    local remote = "origin"
    local extra  = ""
    if args ~= "" then
        local parts = {}
        for p in args:gmatch("%S+") do table.insert(parts, clean(p)) end
        if #parts >= 1 then remote = parts[1] end
        if #parts >= 2 then extra = parts[2] end
    end
    local cmd = string.format("git push %s %s 2>&1", remote, extra)
    return execute(cmd)
end)

-- ── /gf — git fetch + pull ────────────────────────────────────────────────────

registerCommand("gf", function(_args)
    local fetch = execute("git fetch --all 2>&1")
    local pull  = execute("git pull 2>&1")
    return (fetch or "") .. "\n" .. (pull or "")
end)

-- ── /gb — git branches ────────────────────────────────────────────────────────

registerCommand("gb", function(args)
    local flag = args:find("-r") and "-r" or (args:find("-a") and "-a" or "")
    local out = execute("git branch " .. flag .. " --sort=-committerdate 2>&1")
    return out ~= "" and out or "No branches found."
end)

-- ── /gco — git checkout ───────────────────────────────────────────────────────
-- Usage: /gco <branch>   or   /gco -b <new-branch>

registerCommand("gco", function(args)
    if args == "" then
        return "Usage: /gco <branch-name>\n       /gco -b <new-branch>"
    end
    local safe = clean(args)
    return execute("git checkout " .. safe .. " 2>&1")
end)

-- ── /gst — git stash operations ───────────────────────────────────────────────
-- Usage: /gst        — stash current changes
--        /gst pop    — restore latest stash
--        /gst list   — list all stashes
--        /gst drop   — drop latest stash

registerCommand("gst", function(args)
    local sub = args:match("^(%S+)") or ""
    if sub == "pop" then
        return execute("git stash pop 2>&1")
    elseif sub == "list" then
        local out = execute("git stash list 2>&1")
        return out ~= "" and out or "Stash is empty."
    elseif sub == "drop" then
        return execute("git stash drop 2>&1")
    else
        return execute("git stash 2>&1")
    end
end)

-- ── /greset — git reset (safe: HEAD only, no hard destroy) ───────────────────

registerCommand("greset", function(args)
    local sub = clean(args:match("^(%S*)") or "")
    if sub == "" or sub == "soft" then
        return execute("git reset --soft HEAD~1 2>&1")
    elseif sub == "mixed" then
        return execute("git reset HEAD~1 2>&1")
    else
        return "Usage: /greset [soft|mixed]\n  soft  — undo last commit, keep changes staged\n  mixed — undo last commit, keep changes unstaged\n\nNOTE: Hard reset is intentionally excluded to prevent data loss."
    end
end)

-- ── /gdiff-files — list changed files only ───────────────────────────────────

registerCommand("gchanged", function(_args)
    local out = execute("git status --short 2>&1")
    return out ~= "" and out or "Working tree clean."
end)

print("[Plugin] gitops loaded — /gs /gd /gl /gc /gca /gp /gf /gb /gco /gst /greset /gchanged")
