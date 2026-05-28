-- plugins/sysmon.lua
-- System Monitor — live CPU, RAM, disk, uptime, and process stats.
-- JPE: Think of this as the dashboard you'd see in a spaceship cockpit.
--      Every command gives you a snapshot of the machine's health right now.

local function is_windows()
    local result = execute("uname -s 2>/dev/null")
    return result == nil or result == "" or result:find("Windows") ~= nil or result:find("Error") ~= nil
end

local WIN = is_windows()

-- ── /sysmon — full system overview ───────────────────────────────────────────

registerCommand("sysmon", function(_args)
    local lines = { "┌─ SYSTEM MONITOR ──────────────────────────────────────┐" }

    if WIN then
        -- CPU name
        local cpu = execute("wmic cpu get Name /value 2>nul"):match("Name=(.-)[\r\n]")
        table.insert(lines, "  CPU     : " .. (cpu and cpu:gsub("^%s+", "") or "unknown"))

        -- RAM total and available
        local ram_total = execute("wmic computersystem get TotalPhysicalMemory /value 2>nul"):match("TotalPhysicalMemory=(%d+)")
        local ram_free  = execute("wmic OS get FreePhysicalMemory /value 2>nul"):match("FreePhysicalMemory=(%d+)")
        if ram_total and ram_free then
            local total_gb = math.floor(tonumber(ram_total) / 1073741824 * 10 + 0.5) / 10
            local free_mb  = math.floor(tonumber(ram_free)  / 1024)
            local used_mb  = math.floor(tonumber(ram_total) / 1048576) - free_mb
            table.insert(lines, string.format("  RAM     : %.1f GB total | %d MB used | %d MB free", total_gb, used_mb, free_mb))
        end

        -- Uptime
        local uptime = execute("net stats workstation 2>nul"):match("Statistics since (.-)[\r\n]")
        if uptime then
            table.insert(lines, "  Online  : since " .. uptime:gsub("^%s+", ""))
        end

        -- Disk C:
        local disk = execute("wmic logicaldisk where DeviceID='C:' get FreeSpace,Size /value 2>nul")
        local free_bytes = disk:match("FreeSpace=(%d+)")
        local size_bytes = disk:match("Size=(%d+)")
        if free_bytes and size_bytes then
            local free_gb = math.floor(tonumber(free_bytes) / 1073741824)
            local size_gb = math.floor(tonumber(size_bytes) / 1073741824)
            table.insert(lines, string.format("  Disk C: : %d GB free / %d GB total", free_gb, size_gb))
        end
    else
        -- Uptime
        local uptime = execute("uptime -p 2>/dev/null || uptime"):gsub("[\r\n]+", ""):gsub("^%s+", "")
        table.insert(lines, "  Uptime  : " .. uptime)

        -- CPU model
        local cpu = execute("grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2"):gsub("^%s+", ""):gsub("[\r\n]+", "")
        if cpu == "" then cpu = execute("sysctl -n machdep.cpu.brand_string 2>/dev/null"):gsub("[\r\n]+", "") end
        table.insert(lines, "  CPU     : " .. (cpu ~= "" and cpu or "unknown"))

        -- CPU load
        local load = execute("cat /proc/loadavg 2>/dev/null"):match("^([%d%.]+%s+[%d%.]+%s+[%d%.]+)")
        if load then table.insert(lines, "  Load    : " .. load .. " (1m 5m 15m)") end

        -- RAM
        local meminfo = execute("free -m 2>/dev/null | awk '/Mem:/{print $2, $3, $4}'"):gsub("[\r\n]+", "")
        if meminfo ~= "" then
            local total, used, free = meminfo:match("(%d+)%s+(%d+)%s+(%d+)")
            if total then
                table.insert(lines, string.format("  RAM     : %s MB total | %s MB used | %s MB free", total, used, free))
            end
        end

        -- Disk
        local disk = execute("df -h / 2>/dev/null | awk 'NR==2{print $2, $3, $4, $5}'"):gsub("[\r\n]+", "")
        if disk ~= "" then
            local size, used, avail, pct = disk:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
            if size then
                table.insert(lines, string.format("  Disk /  : %s total | %s used (%s) | %s free", size, used, pct, avail))
            end
        end
    end

    table.insert(lines, "└────────────────────────────────────────────────────────┘")
    return table.concat(lines, "\n")
end)

-- ── /cpu — CPU usage snapshot ─────────────────────────────────────────────────

registerCommand("cpu", function(_args)
    if WIN then
        local pct = execute("wmic cpu get LoadPercentage /value 2>nul"):match("LoadPercentage=(%d+)")
        return pct and ("CPU load: " .. pct .. "%") or "Could not read CPU load on this system."
    else
        local load = execute("cat /proc/loadavg 2>/dev/null"):match("^([%d%.]+)")
        local cores = execute("nproc 2>/dev/null"):gsub("[\r\n]+", "")
        local top = execute("top -bn1 2>/dev/null | grep 'Cpu(s)' | awk '{print $2+$4}'"):gsub("[\r\n]+", "")
        local lines = {}
        if top ~= "" then table.insert(lines, "CPU usage : " .. top .. "%") end
        if load then table.insert(lines, "Load avg  : " .. load .. " (1m)") end
        if cores ~= "" then table.insert(lines, "Cores     : " .. cores) end
        return #lines > 0 and table.concat(lines, "\n") or "CPU data unavailable."
    end
end)

-- ── /ram — memory breakdown ───────────────────────────────────────────────────

registerCommand("ram", function(_args)
    if WIN then
        local total = execute("wmic computersystem get TotalPhysicalMemory /value 2>nul"):match("TotalPhysicalMemory=(%d+)")
        local free  = execute("wmic OS get FreePhysicalMemory /value 2>nul"):match("FreePhysicalMemory=(%d+)")
        if total and free then
            local total_mb = math.floor(tonumber(total) / 1048576)
            local free_mb  = math.floor(tonumber(free) / 1024)
            local used_mb  = total_mb - free_mb
            local pct = math.floor(used_mb / total_mb * 100)
            return string.format("RAM: %d MB used / %d MB total (%d%% in use)\nFree: %d MB", used_mb, total_mb, pct, free_mb)
        end
        return "Could not read memory stats."
    else
        local out = execute("free -m 2>/dev/null | awk '/Mem:/{printf \"total=%s used=%s free=%s shared=%s buff=%s avail=%s\", $2,$3,$4,$5,$6,$7}'")
        if out and out ~= "" then
            local t,u,f,s,b,a = out:match("total=(%d+) used=(%d+) free=(%d+) shared=(%d+) buff=(%d+) avail=(%d+)")
            if t then
                local pct = math.floor(tonumber(u) / tonumber(t) * 100)
                return string.format(
                    "RAM Total : %s MB\n" ..
                    "Used      : %s MB (%d%%)\n" ..
                    "Free      : %s MB\n" ..
                    "Available : %s MB\n" ..
                    "Buffers   : %s MB | Shared: %s MB",
                    t, u, pct, f, a, b, s)
            end
        end
        return "Memory data unavailable."
    end
end)

-- ── /disk — disk usage overview ───────────────────────────────────────────────

registerCommand("disk", function(args)
    local path = args ~= "" and args:gsub("[;|&`<>]", "") or ""
    if WIN then
        local drive = path ~= "" and path:sub(1,2) or "C:"
        local disk = execute("wmic logicaldisk where DeviceID='" .. drive .. "' get FreeSpace,Size /value 2>nul")
        local free_bytes = disk:match("FreeSpace=(%d+)")
        local size_bytes = disk:match("Size=(%d+)")
        if free_bytes and size_bytes then
            local free_gb  = math.floor(tonumber(free_bytes) / 1073741824 * 10) / 10
            local size_gb  = math.floor(tonumber(size_bytes) / 1073741824 * 10) / 10
            local used_gb  = math.floor((tonumber(size_bytes) - tonumber(free_bytes)) / 1073741824 * 10) / 10
            local pct = math.floor((1 - tonumber(free_bytes) / tonumber(size_bytes)) * 100)
            return string.format("Drive %s: %.1f GB used / %.1f GB total (%d%% full) | %.1f GB free",
                drive, used_gb, size_gb, pct, free_gb)
        end
        return "Could not read disk stats for " .. drive
    else
        local target = path ~= "" and path or "/"
        local out = execute("df -h " .. target .. " 2>/dev/null | tail -1"):gsub("[\r\n]+", "")
        if out ~= "" then
            return "Disk " .. target .. ":\n" .. out
        end
        return "Could not read disk stats."
    end
end)

-- ── /uptime — system uptime ───────────────────────────────────────────────────

registerCommand("uptime", function(_args)
    if WIN then
        local since = execute("net stats workstation 2>nul"):match("Statistics since (.-)[\r\n]")
        return since and ("Online since: " .. since:gsub("^%s+", "")) or "Uptime unavailable on this system."
    else
        local out = execute("uptime 2>/dev/null"):gsub("[\r\n]+", ""):gsub("^%s+", "")
        return out ~= "" and out or "uptime unavailable."
    end
end)

-- ── /procs — top 10 processes by CPU ─────────────────────────────────────────

registerCommand("procs", function(_args)
    if WIN then
        local out = execute("tasklist /fo csv /nh 2>nul | sort"):sub(1, 1500)
        return "Running processes (first entries):\n" .. out
    else
        local out = execute("ps aux --sort=-%cpu 2>/dev/null | head -12 | awk '{printf \"%-20s %5s%% %5s MB  %s\\n\", $1, $3, int($6/1024), $11}' 2>/dev/null")
        if out and out ~= "" then
            return "Top processes by CPU:\n" .. out
        end
        return execute("ps aux 2>/dev/null | head -12") or "Process list unavailable."
    end
end)

print("[Plugin] sysmon loaded — /sysmon /cpu /ram /disk /uptime /procs")
