-- plugins/sprint.lua
-- Sprint & Task Tracker — lightweight backlog management built into the terminal.
-- JPE: A sprint tracker doesn't need Jira or Linear. For a solo developer, a numbered
--      list of tasks with statuses (todo → in-progress → done) is 90% of what you need.
--      This plugin gives you that, persisted as plain text, queryable from chat.
--
-- Task format: <id>|<status>|<priority>|<title>
-- Status: todo, doing, done, blocked
-- Priority: p1 (critical), p2 (high), p3 (normal), p4 (low)

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── Storage ───────────────────────────────────────────────────────────────────

local SPRINT_FILE
if WIN then
    local appdata = execute("echo %APPDATA%"):gsub("[\r\n]+", "")
    SPRINT_FILE = appdata .. "\\neurodeck\\plugin-sprint.txt"
    execute("if not exist \"" .. appdata .. "\\neurodeck\" mkdir \"" .. appdata .. "\\neurodeck\"")
else
    local home = execute("echo $HOME"):gsub("[\r\n]+", "")
    SPRINT_FILE = home .. "/.config/neurodeck/plugin-sprint.txt"
    execute("mkdir -p '" .. home .. "/.config/neurodeck'")
end

local STATUS_ICONS = { todo = "○", doing = "◉", done = "✓", blocked = "✗" }
local PRIORITY_LABELS = { p1 = "[P1]", p2 = "[P2]", p3 = "[P3]", p4 = "[P4]" }

local function load_tasks()
    local raw
    if WIN then
        raw = execute("type \"" .. SPRINT_FILE .. "\" 2>nul") or ""
    else
        raw = execute("cat '" .. SPRINT_FILE .. "' 2>/dev/null") or ""
    end
    local tasks = {}
    local max_id = 0
    for line in raw:gmatch("[^\r\n]+") do
        if line:gsub("%s+", "") ~= "" then
            local id, status, priority, title = line:match("^(%d+)|(%S+)|(%S+)|(.+)$")
            if id then
                local task = { id = tonumber(id), status = status, priority = priority, title = title }
                table.insert(tasks, task)
                if tonumber(id) > max_id then max_id = tonumber(id) end
            end
        end
    end
    return tasks, max_id
end

local function save_tasks(tasks)
    local lines = {}
    for _, t in ipairs(tasks) do
        table.insert(lines, string.format("%d|%s|%s|%s", t.id, t.status, t.priority, t.title))
    end
    local raw = table.concat(lines, "\n")
    if WIN then
        local escaped = raw:gsub("'", "''")
        execute("powershell -Command \"Set-Content -Path '" .. SPRINT_FILE ..
            "' -Value '" .. escaped .. "' -Encoding UTF8\" 2>nul")
    else
        local escaped = raw:gsub("'", "'\\''")
        execute("printf '%s' '" .. escaped .. "' > '" .. SPRINT_FILE .. "' 2>/dev/null")
    end
end

local function format_task(t)
    local icon = STATUS_ICONS[t.status] or "?"
    local pri  = PRIORITY_LABELS[t.priority] or ""
    return string.format("  #%-3d %s %s %s", t.id, icon, pri, t.title)
end

-- ── /task — add a task ────────────────────────────────────────────────────────
-- Usage: /task <title>
--        /task p1 <title>    — set priority (p1/p2/p3/p4)

registerCommand("task", function(args)
    local text = args:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return "Usage: /task <title>\n       /task p1 <title>\nPriorities: p1=critical p2=high p3=normal p4=low"
    end

    local priority = "p3"
    local first = text:match("^(%S+)")
    if first and first:match("^p[1-4]$") then
        priority = first
        text = text:match("^%S+%s+(.+)$") or text
    end

    if text == "" or text == first then
        return "Usage: /task p<1-4> <title>\nExample: /task p1 Fix auth token expiry bug"
    end

    local tasks, max_id = load_tasks()
    local new_id = max_id + 1
    table.insert(tasks, { id = new_id, status = "todo", priority = priority, title = text })
    save_tasks(tasks)
    return string.format("✅ Task #%d added: %s %s", new_id, PRIORITY_LABELS[priority], text)
end)

-- ── /tasks — list tasks ────────────────────────────────────────────────────────
-- /tasks           — all active (todo + doing)
-- /tasks all       — everything including done
-- /tasks done      — completed tasks
-- /tasks p1        — filter by priority

registerCommand("tasks", function(args)
    local filter = args:match("^(%S+)") or ""
    local tasks = load_tasks()
    if #tasks == 0 then
        return "No tasks. Use /task <title> to add one."
    end

    local show_all  = filter == "all"
    local show_done = filter == "done"
    local show_pri  = filter:match("^p[1-4]$")
    local show_stat = filter == "todo" or filter == "doing" or filter == "blocked"

    -- Group tasks
    local groups = {
        { label = "● DOING",   tasks = {}, key = "doing" },
        { label = "✗ BLOCKED", tasks = {}, key = "blocked" },
        { label = "○ TO DO",   tasks = {}, key = "todo" },
        { label = "✓ DONE",    tasks = {}, key = "done" },
    }

    local counts = { todo = 0, doing = 0, done = 0, blocked = 0 }

    for _, t in ipairs(tasks) do
        counts[t.status] = (counts[t.status] or 0) + 1

        local include = false
        if show_all then
            include = true
        elseif show_done then
            include = t.status == "done"
        elseif show_stat then
            include = t.status == filter
        elseif show_pri then
            include = t.priority == filter and t.status ~= "done"
        else
            include = t.status ~= "done"
        end

        if include then
            for _, g in ipairs(groups) do
                if g.key == t.status then
                    table.insert(g.tasks, t)
                end
            end
        end
    end

    -- Sort each group by priority (p1 first)
    for _, g in ipairs(groups) do
        table.sort(g.tasks, function(a, b)
            if a.priority ~= b.priority then return a.priority < b.priority end
            return a.id < b.id
        end)
    end

    local lines = {
        string.format("┌─ SPRINT BOARD ─────────────── todo:%d doing:%d blocked:%d done:%d ┐",
            counts.todo, counts.doing, counts.blocked, counts.done)
    }

    local any = false
    for _, g in ipairs(groups) do
        if #g.tasks > 0 then
            table.insert(lines, "  " .. g.label)
            for _, t in ipairs(g.tasks) do
                table.insert(lines, format_task(t))
            end
            any = true
        end
    end

    if not any then
        table.insert(lines, "  (no tasks in this view)")
    end

    table.insert(lines, "└────────────────────────────────────────────────────────┘")
    table.insert(lines, "  /doing <id>  /done <id>  /blocked <id>  /deltask <id>")
    return table.concat(lines, "\n")
end)

-- ── /doing — move a task to in-progress ──────────────────────────────────────

registerCommand("doing", function(args)
    local id = tonumber(args:match("^%s*(%d+)"))
    if not id then return "Usage: /doing <task-id>" end
    local tasks = load_tasks()
    for _, t in ipairs(tasks) do
        if t.id == id then
            t.status = "doing"
            save_tasks(tasks)
            return string.format("◉ Task #%d → in progress: %s", id, t.title)
        end
    end
    return string.format("Task #%d not found.", id)
end)

-- ── /done — mark a task complete ──────────────────────────────────────────────

registerCommand("done", function(args)
    local id = tonumber(args:match("^%s*(%d+)"))
    if not id then return "Usage: /done <task-id>" end
    local tasks = load_tasks()
    for _, t in ipairs(tasks) do
        if t.id == id then
            t.status = "done"
            save_tasks(tasks)
            return string.format("✓ Task #%d done: %s", id, t.title)
        end
    end
    return string.format("Task #%d not found.", id)
end)

-- ── /blocked — mark a task blocked ────────────────────────────────────────────

registerCommand("blocked", function(args)
    local id = tonumber(args:match("^%s*(%d+)"))
    if not id then return "Usage: /blocked <task-id>" end
    local tasks = load_tasks()
    for _, t in ipairs(tasks) do
        if t.id == id then
            t.status = "blocked"
            save_tasks(tasks)
            return string.format("✗ Task #%d marked blocked: %s", id, t.title)
        end
    end
    return string.format("Task #%d not found.", id)
end)

-- ── /deltask — delete a task ──────────────────────────────────────────────────

registerCommand("deltask", function(args)
    local id = tonumber(args:match("^%s*(%d+)"))
    if not id then return "Usage: /deltask <task-id>" end
    local tasks = load_tasks()
    for i, t in ipairs(tasks) do
        if t.id == id then
            local title = t.title
            table.remove(tasks, i)
            save_tasks(tasks)
            return string.format("🗑 Deleted task #%d: %s", id, title)
        end
    end
    return string.format("Task #%d not found.", id)
end)

-- ── /velocity — sprint summary stats ─────────────────────────────────────────

registerCommand("velocity", function(_args)
    local tasks = load_tasks()
    local counts = { todo = 0, doing = 0, done = 0, blocked = 0 }
    local by_priority = { p1 = 0, p2 = 0, p3 = 0, p4 = 0 }
    for _, t in ipairs(tasks) do
        counts[t.status] = (counts[t.status] or 0) + 1
        if t.status ~= "done" then
            by_priority[t.priority] = (by_priority[t.priority] or 0) + 1
        end
    end
    local total     = #tasks
    local active    = total - counts.done
    local pct_done  = total > 0 and math.floor(counts.done / total * 100) or 0
    local bar       = string.rep("█", math.floor(pct_done / 5)) .. string.rep("░", 20 - math.floor(pct_done / 5))
    return string.format(
        "Sprint velocity:\n" ..
        "  Progress : [%s] %d%%\n" ..
        "  Total    : %d tasks\n" ..
        "  Done     : %d  |  Doing: %d  |  Todo: %d  |  Blocked: %d\n" ..
        "  Active   : %d tasks remaining\n" ..
        "  By priority (active only): P1:%d  P2:%d  P3:%d  P4:%d",
        bar, pct_done, total,
        counts.done, counts.doing, counts.todo, counts.blocked,
        active,
        by_priority.p1, by_priority.p2, by_priority.p3, by_priority.p4)
end)

print("[Plugin] sprint loaded — /task /tasks /doing /done /blocked /deltask /velocity")
