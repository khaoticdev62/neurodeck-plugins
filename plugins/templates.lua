-- templates.lua — NEURODECK Plugin
-- Document templates for common developer workflows
-- Commands: /template /tpl /addtpl /deltpl /tpls

local state_file = (os.getenv("HOME") or os.getenv("USERPROFILE") or ".") .. "/.config/neurodeck/data/templates.json"

local BUILTIN = {
    ["pr"] = [[## Summary
- What this PR does (1-3 bullets)

## Changes
-

## Test Plan
- [ ] Manual test
- [ ] Existing tests pass

## Screenshots (if UI change)
]],
    ["standup"] = [[**Yesterday:**
**Today:**
**Blockers:** None
]],
    ["bug"] = [[**Bug Report**

**Description:**

**Steps to reproduce:**
1.
2.

**Expected:**
**Actual:**
**Environment:**
**Severity:**
]],
    ["commit"] = [[feat|fix|chore|docs|refactor(scope): short summary

- What changed
- Why it changed

Closes #
]],
    ["readme"] = [[# Project Name

> One-line description.

## Install

```bash
```

## Usage

```bash
```

## License
MIT
]],
    ["api"] = [[## Endpoint:

**Method:** GET | POST | PUT | DELETE
**Path:** `/api/v1/`

**Auth:** Bearer token

**Request Body:**
```json
{}
```

**Response:**
```json
{}
```
]],
}

local function load_tpls()
    local f = io.open(state_file, "r")
    local custom = {}
    if f then
        local raw = f:read("*a"); f:close()
        for key, val in raw:gmatch('"([^"]+)":"(.-[^\\])"') do
            custom[key] = val:gsub("\\n", "\n"):gsub('\\"', '"')
        end
    end
    local merged = {}
    for k, v in pairs(BUILTIN) do merged[k] = v end
    for k, v in pairs(custom) do merged[k] = v end
    return merged
end

local function save_custom(name, body)
    local f = io.open(state_file, "r")
    local raw = f and f:read("*a") or "{}"
    if f then f:close() end
    raw = raw:gsub("}", string.format('"%s":"%s"}', name, body:gsub('"','\\"'):gsub("\n","\\n")), 1)
    if not raw:find(name, 1, true) then
        raw = "{" .. string.format('"%s":"%s"', name, body:gsub('"','\\"'):gsub("\n","\\n")) .. "}"
    end
    local fw = io.open(state_file, "w")
    if fw then fw:write(raw); fw:close() end
end

registerCommand("tpls", function()
    local tpls = load_tpls()
    local keys = {}
    for k in pairs(tpls) do table.insert(keys, k) end
    table.sort(keys)
    print("[Templates] Available (" .. #keys .. "):")
    for _, k in ipairs(keys) do
        print("  /tpl " .. k)
    end
end)

registerCommand("tpl", function(args)
    if not args or args == "" then print("Usage: /tpl <name>  (see /tpls for list)") return end
    local tpls = load_tpls()
    local body = tpls[args:lower()]
    if not body then print("[Template] Not found: " .. args .. "  (use /tpls to list)") return end
    print("[Template: " .. args .. "]\n" .. body)
end)

registerCommand("template", function(args)
    if not args or args == "" then print("Usage: /template <name>  (see /tpls for list)") return end
    local tpls = load_tpls()
    local body = tpls[args:lower()]
    if not body then print("[Template] Not found: " .. args) return end
    print("[Template: " .. args .. "]\n" .. body)
end)

registerCommand("addtpl", function(args)
    if not args then print("Usage: /addtpl <name> <body...>") return end
    local name, body = args:match("^(%S+)%s+(.+)$")
    if not name then print("Usage: /addtpl <name> <content>") return end
    save_custom(name:lower(), body)
    print("[Template] Saved: " .. name)
end)

registerCommand("deltpl", function(args)
    if not args then print("Usage: /deltpl <name>") return end
    local f = io.open(state_file, "r")
    if not f then print("[Template] No custom templates.") return end
    local raw = f:read("*a"); f:close()
    local new = raw:gsub('"' .. args:lower() .. '":".-[^\\]"[,]?', "")
    local fw = io.open(state_file, "w")
    if fw then fw:write(new); fw:close() end
    print("[Template] Removed: " .. args)
end)

print("[Plugin] Templates loaded. Commands: /tpl /tpls /addtpl /deltpl")
