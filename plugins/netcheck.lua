-- plugins/netcheck.lua
-- Network Diagnostics — connectivity tests, DNS lookups, port checks, and IP info.
-- JPE: Network debugging always starts with the same five questions:
--      "Can I reach it?", "Does DNS resolve?", "Is the port open?",
--      "What's my IP?", "What route does traffic take?"
--      This plugin answers all five from inside NEURODECK.

local function clean(s)
    if not s or s == "" then return "" end
    -- Allow hostname chars: letters, digits, dots, hyphens, colons (IPv6)
    return s:gsub("[^%w%.%-%:]", "")
end

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── /ping — ICMP ping ─────────────────────────────────────────────────────────
-- Usage: /ping <host> [count]

registerCommand("ping", function(args)
    local host  = args:match("^(%S+)") or ""
    local count = args:match("%s+(%d+)$") or "4"
    count = tostring(math.min(tonumber(count) or 4, 10))
    host  = clean(host)
    if host == "" then return "Usage: /ping <hostname or IP> [count]\nExample: /ping google.com 4" end

    local cmd
    if WIN then
        cmd = "ping -n " .. count .. " " .. host .. " 2>nul"
    else
        cmd = "ping -c " .. count .. " -W 3 " .. host .. " 2>&1"
    end
    local out = execute(cmd)
    return out ~= "" and out or ("Could not ping " .. host .. ".")
end)

-- ── /myip — public and local IP addresses ────────────────────────────────────

registerCommand("myip", function(_args)
    local lines = {}

    -- Public IP via multiple resilient services
    local public_ip
    local services = {
        "https://api.ipify.org",
        "https://checkip.amazonaws.com",
        "https://icanhazip.com",
    }
    for _, svc in ipairs(services) do
        local out = execute("curl -s --max-time 5 \"" .. svc .. "\" 2>/dev/null"):gsub("%s+", "")
        if out ~= "" and out:match("^%d+%.%d+%.%d+%.%d+$") then
            public_ip = out
            break
        end
    end
    table.insert(lines, "Public  : " .. (public_ip or "unavailable"))

    -- Local IP
    local local_ip
    if WIN then
        local raw = execute("ipconfig 2>nul")
        local_ip = raw:match("IPv4 Address[^:]*:%s*([%d%.]+)")
    else
        local_ip = execute("hostname -I 2>/dev/null | awk '{print $1}'"):gsub("[\r\n]+", "")
        if local_ip == "" then
            local_ip = execute("ip route get 1 2>/dev/null | awk '/src/{print $7}'"):gsub("[\r\n]+", "")
        end
    end
    table.insert(lines, "Local   : " .. (local_ip ~= "" and local_ip or "unknown"))

    -- Hostname
    local host = execute("hostname 2>/dev/null"):gsub("[\r\n]+", "")
    if host ~= "" then table.insert(lines, "Hostname: " .. host) end

    return table.concat(lines, "\n")
end)

-- ── /dns — DNS lookup ─────────────────────────────────────────────────────────
-- Usage: /dns <hostname>       — A records
--        /dns mx <hostname>    — MX records
--        /dns txt <hostname>   — TXT records

registerCommand("dns", function(args)
    local record_type, host

    local first = args:match("^(%S+)")
    local rest  = args:match("^%S+%s+(.+)$")

    -- Detect if first word is a known record type
    local known_types = { a=true, aaaa=true, mx=true, txt=true, cname=true, ns=true, ptr=true }
    if known_types[first and first:lower() or ""] and rest then
        record_type = first:upper()
        host        = clean(rest:match("^(%S+)") or "")
    else
        record_type = "A"
        host        = clean(first or "")
    end

    if host == "" then
        return "Usage: /dns <hostname>\n       /dns <MX|TXT|AAAA|NS|CNAME> <hostname>"
    end

    local out
    if WIN then
        local cmd = string.format("nslookup -type=%s %s 2>nul", record_type, host)
        out = execute(cmd)
    else
        -- prefer dig, fall back to nslookup, then host
        out = execute(string.format("dig +short %s %s 2>/dev/null", record_type, host))
        if out == "" then
            out = execute(string.format("nslookup -type=%s %s 2>/dev/null", record_type, host))
        end
    end

    if out == "" or out:gsub("%s+", "") == "" then
        return string.format("No %s records found for '%s'.", record_type, host)
    end
    return string.format("DNS %s for %s:\n%s", record_type, host, out)
end)

-- ── /curl — HTTP check (headers + status code) ────────────────────────────────
-- Usage: /curl <url>

registerCommand("curl", function(args)
    local url = args:match("^(%S+)") or ""
    if url == "" then return "Usage: /curl <url>\nExample: /curl https://api.github.com" end
    -- Only allow http and https
    if not url:match("^https?://") then
        return "Only http:// and https:// URLs are allowed."
    end
    local out = execute("curl -sI --max-time 10 \"" .. url .. "\" 2>/dev/null"):sub(1, 1500)
    return out ~= "" and out or ("Could not reach " .. url)
end)

-- ── /nc — check if a TCP port is open ─────────────────────────────────────────
-- Usage: /nc <host> <port>

registerCommand("nc", function(args)
    local host, port = args:match("^(%S+)%s+(%d+)")
    if not host or not port then
        return "Usage: /nc <host> <port>\nExample: /nc google.com 443"
    end
    host = clean(host)
    port = tostring(math.min(tonumber(port) or 0, 65535))

    local out
    if WIN then
        out = execute(string.format(
            "powershell -Command \"try { $c=New-Object System.Net.Sockets.TcpClient('%s',%s); $c.Close(); 'open' } catch { 'closed' }\" 2>nul",
            host, port)):gsub("[\r\n]+", "")
        if out == "open" then
            return string.format("✅ %s:%s is OPEN", host, port)
        else
            return string.format("❌ %s:%s is CLOSED or unreachable", host, port)
        end
    else
        out = execute(string.format(
            "nc -z -w 3 %s %s 2>&1 && echo open || echo closed", host, port)):gsub("[\r\n]+", "")
        if out == "open" then
            return string.format("✅ %s:%s is OPEN", host, port)
        else
            return string.format("❌ %s:%s is CLOSED or unreachable", host, port)
        end
    end
end)

-- ── /tracert — traceroute to a host ──────────────────────────────────────────

registerCommand("tracert", function(args)
    local host = clean(args:match("^(%S+)") or "")
    if host == "" then return "Usage: /tracert <hostname or IP>" end
    local cmd
    if WIN then
        cmd = "tracert -h 15 " .. host .. " 2>nul"
    else
        cmd = "traceroute -m 15 " .. host .. " 2>&1 || tracepath " .. host .. " 2>&1"
    end
    local out = execute(cmd)
    return out ~= "" and out:sub(1, 3000) or ("Could not traceroute to " .. host)
end)

-- ── /ipinfo — geolocation for an IP or hostname ───────────────────────────────

registerCommand("ipinfo", function(args)
    local target = clean(args:match("^(%S+)") or "")
    local url    = target ~= "" and ("https://ipinfo.io/" .. target .. "/json") or "https://ipinfo.io/json"
    local out    = execute("curl -s --max-time 8 \"" .. url .. "\" 2>/dev/null")
    if out == "" then return "Could not reach ipinfo.io. Check your internet connection." end
    -- Pretty-print the JSON fields we care about
    local ip      = out:match('"ip"%s*:%s*"([^"]+)"')
    local city    = out:match('"city"%s*:%s*"([^"]+)"')
    local region  = out:match('"region"%s*:%s*"([^"]+)"')
    local country = out:match('"country"%s*:%s*"([^"]+)"')
    local org     = out:match('"org"%s*:%s*"([^"]+)"')
    local tz      = out:match('"timezone"%s*:%s*"([^"]+)"')
    local loc     = out:match('"loc"%s*:%s*"([^"]+)"')
    local lines   = {}
    if ip      then table.insert(lines, "IP       : " .. ip) end
    if city    then table.insert(lines, "City     : " .. city) end
    if region  then table.insert(lines, "Region   : " .. region) end
    if country then table.insert(lines, "Country  : " .. country) end
    if org     then table.insert(lines, "Org/ISP  : " .. org) end
    if tz      then table.insert(lines, "Timezone : " .. tz) end
    if loc     then table.insert(lines, "Coords   : " .. loc) end
    return #lines > 0 and table.concat(lines, "\n") or out
end)

print("[Plugin] netcheck loaded — /ping /myip /dns /curl /nc /tracert /ipinfo")
