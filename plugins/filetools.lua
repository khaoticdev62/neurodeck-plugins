-- plugins/filetools.lua
-- File System Tools — find, inspect, hash files, and explore directory trees.
-- JPE: The questions you constantly ask the file system — "where is that file?",
--      "what's the biggest thing in this folder?", "is this the same file as that?" —
--      all live here as one-word commands.

local function clean_path(s)
    if not s or s == "" then return "." end
    -- Strip dangerous shell chars but allow path chars: letters, digits, /\.-_~ and spaces
    return s:gsub("[;|&`$<>%(%){}%[%]\"'\\]", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function clean_pattern(s)
    if not s or s == "" then return "*" end
    return s:gsub("[;|&`$<>%(%){}%[%]\"'\\]", "")
end

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── /find — locate files matching a name pattern ─────────────────────────────
-- Usage: /find <pattern>          — search from current directory
--        /find <pattern> <path>   — search from specified path

registerCommand("find", function(args)
    local pattern, search_path
    local parts = {}
    for p in args:gmatch("%S+") do table.insert(parts, p) end

    if #parts == 0 then
        return "Usage: /find <filename-pattern> [path]\nExample: /find *.rs src/"
    elseif #parts == 1 then
        pattern     = clean_pattern(parts[1])
        search_path = "."
    else
        pattern     = clean_pattern(parts[1])
        search_path = clean_path(table.concat(parts, " ", 2))
    end

    local out
    if WIN then
        out = execute(string.format("dir /s /b \"%s\\%s\" 2>nul", search_path:gsub("/", "\\"), pattern))
    else
        out = execute(string.format("find %s -name '%s' 2>/dev/null | head -50", search_path, pattern))
    end

    if not out or out:gsub("%s+", "") == "" then
        return string.format("No files matching '%s' found in '%s'.", pattern, search_path)
    end
    local lines = {}
    local count = 0
    for line in out:gmatch("[^\r\n]+") do
        if line:gsub("%s+", "") ~= "" then
            table.insert(lines, "  " .. line)
            count = count + 1
        end
    end
    if count == 0 then return string.format("No files matching '%s'.", pattern) end
    table.insert(lines, 1, string.format("Found %d file(s) matching '%s':", count, pattern))
    if count >= 50 then table.insert(lines, "(results capped at 50 — narrow your pattern)") end
    return table.concat(lines, "\n")
end)

-- ── /tree — directory tree view ───────────────────────────────────────────────
-- Usage: /tree [path] [depth]

registerCommand("tree", function(args)
    local parts = {}
    for p in args:gmatch("%S+") do table.insert(parts, p) end
    local depth = 3
    local path  = "."

    if #parts >= 1 then
        local last = parts[#parts]
        if last:match("^%d+$") then
            depth = math.min(tonumber(last), 6)
            if #parts >= 2 then
                path = clean_path(table.concat(parts, " ", 1, #parts - 1))
            end
        else
            path = clean_path(args)
        end
    end

    local out
    if WIN then
        out = execute(string.format("tree /f \"%s\" 2>nul", path:gsub("/", "\\")))
        return out ~= "" and out:sub(1, 3000) or ("Could not tree '" .. path .. "'.")
    else
        out = execute(string.format("tree -L %d '%s' 2>/dev/null", depth, path:gsub("'", "'\\''")))
        if out == "" or out:find("not found") then
            -- Fallback to find-based tree
            out = execute(string.format(
                "find '%s' -maxdepth %d 2>/dev/null | sort | awk -F/ '{" ..
                "indent=\"\"; for(i=NF;i>1;i--) indent=indent\"  \"; print indent $NF}'",
                path:gsub("'", "\\'"), depth))
        end
        return out ~= "" and out:sub(1, 3000) or ("Could not tree '" .. path .. "'.")
    end
end)

-- ── /ls — directory listing with sizes ───────────────────────────────────────

registerCommand("ls", function(args)
    local path = clean_path(args)
    local out
    if WIN then
        out = execute(string.format("dir \"%s\" 2>nul", path:gsub("/", "\\")))
    else
        out = execute(string.format("ls -lah --color=never '%s' 2>/dev/null", path:gsub("'", "'\\''")))
    end
    return out ~= "" and out:sub(1, 3000) or ("Could not list '" .. path .. "'.")
end)

-- ── /size — disk usage of a directory or file ────────────────────────────────

registerCommand("size", function(args)
    local path = clean_path(args ~= "" and args or ".")
    local out
    if WIN then
        -- PowerShell: sum file sizes recursively
        out = execute(string.format(
            "powershell -Command \"$s=(Get-ChildItem '%s' -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum; " ..
            "if($s -gt 1GB){'%.2f GB' -f ($s/1GB)} elseif($s -gt 1MB){'%.2f MB' -f ($s/1MB)} else{'%.0f KB' -f ($s/1KB)}\" 2>nul",
            path))
        return out ~= "" and (path .. " : " .. out:gsub("[\r\n]+", "")) or "Could not measure size."
    else
        out = execute(string.format("du -sh '%s' 2>/dev/null | awk '{print $1}'", path:gsub("'", "'\\''"))):gsub("[\r\n]+", "")
        return out ~= "" and (path .. " : " .. out) or "Could not measure size."
    end
end)

-- ── /recent — recently modified files ────────────────────────────────────────
-- Usage: /recent [n] [path]      — last n modified files (default 10)

registerCommand("recent", function(args)
    local parts = {}
    for p in args:gmatch("%S+") do table.insert(parts, p) end
    local n     = 10
    local path  = "."

    if #parts >= 1 and parts[1]:match("^%d+$") then
        n = math.min(tonumber(parts[1]), 50)
        if #parts >= 2 then path = clean_path(table.concat(parts, " ", 2)) end
    elseif #parts >= 1 then
        path = clean_path(args)
    end

    local out
    if WIN then
        out = execute(string.format(
            "powershell -Command \"Get-ChildItem '%s' -Recurse -File -ErrorAction SilentlyContinue " ..
            "| Sort-Object LastWriteTime -Descending | Select-Object -First %d " ..
            "| Format-Table LastWriteTime,Length,Name -AutoSize\" 2>nul", path, n))
    else
        out = execute(string.format(
            "find '%s' -type f -printf '%%TY-%%Tm-%%Td %%TH:%%TM  %%P\\n' 2>/dev/null " ..
            "| sort -r | head -n %d", path:gsub("'", "\\'"), n))
    end

    return out ~= "" and out:sub(1, 3000) or ("No files found in '" .. path .. "'.")
end)

-- ── /hashfile — SHA-256 checksum of a file ────────────────────────────────────

registerCommand("hashfile", function(args)
    local path = clean_path(args)
    if path == "." or path == "" then
        return "Usage: /hashfile <filepath>\nExample: /hashfile ~/Downloads/neurodeck.AppImage"
    end
    local out
    if WIN then
        out = execute(string.format("certutil -hashfile \"%s\" SHA256 2>nul", path:gsub("/", "\\")))
        -- certutil output: first line = label, second = hash, third = confirmation
        local hash = ""
        local i = 0
        for line in out:gmatch("[^\r\n]+") do
            i = i + 1
            if i == 2 then hash = line:gsub("%s+", "") end
        end
        return hash ~= "" and ("SHA-256: " .. hash .. "\nFile: " .. path) or ("Could not hash '" .. path .. "'.")
    else
        out = execute(string.format("sha256sum '%s' 2>/dev/null || shasum -a 256 '%s' 2>/dev/null",
            path:gsub("'", "\\'"), path:gsub("'", "\\'")))
        local hash = out:match("^(%x+)")
        return hash and ("SHA-256: " .. hash .. "\nFile: " .. path) or ("Could not hash '" .. path .. "'.")
    end
end)

-- ── /diff — diff two files ────────────────────────────────────────────────────

registerCommand("diff", function(args)
    local file1, file2 = args:match("^(%S+)%s+(%S+)")
    if not file1 or not file2 then
        return "Usage: /diff <file1> <file2>"
    end
    file1 = clean_path(file1)
    file2 = clean_path(file2)
    local out
    if WIN then
        out = execute(string.format("fc \"%s\" \"%s\" 2>nul", file1:gsub("/","\\"), file2:gsub("/","\\")))
    else
        out = execute(string.format("diff --color=never '%s' '%s' 2>&1",
            file1:gsub("'","'\\''"), file2:gsub("'","'\\''"))):sub(1, 3000)
    end
    return out ~= "" and out or "Files are identical."
end)

print("[Plugin] filetools loaded — /find /tree /ls /size /recent /hashfile /diff")
