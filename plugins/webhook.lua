-- webhook.lua — NEURODECK Plugin
-- Quick local HTTP webhook receiver for testing integrations
-- Commands: /webhook /webhookstop /webhooklogs /webhookurl

local active_port = nil
local log_file = (os.getenv("HOME") or os.getenv("USERPROFILE") or ".") .. "/.config/neurodeck/data/webhook_log.txt"

local function is_windows()
    return (os.getenv("OS") or ""):find("Windows") ~= nil
end

registerCommand("webhook", function(args)
    local port = tonumber(args) or 9000
    if port < 1024 or port > 65535 then
        print("[Webhook] Port must be between 1024–65535. Default is 9000.")
        return
    end
    active_port = port

    print("[Webhook] Starting listener on http://localhost:" .. port)
    print("[Webhook] Use /webhooklogs to see incoming requests.")
    print("[Webhook] Use /webhookstop to stop.")

    if is_windows() then
        -- Use netsh + a PowerShell loop on Windows
        local cmd = string.format(
            "powershell -NoProfile -Command \"$l = [System.Net.HttpListener]::new(); $l.Prefixes.Add('http://localhost:%d/'); $l.Start(); Write-Host '[Webhook] Listening on :%d'; for ($i=0;$i -lt 50;$i++) { $ctx = $l.GetContext(); $req = $ctx.Request; $body = (New-Object System.IO.StreamReader $req.InputStream).ReadToEnd(); $ts = Get-Date -Format 'HH:mm:ss'; $line = \\\"%s $ts [$($req.HttpMethod)] $($req.Url.PathAndQuery) body=$body\\\"; Add-Content '%s' $line; Write-Host $line; $ctx.Response.StatusCode=200; $ctx.Response.OutputStream.Close() }; $l.Stop()\"",
            port, port, "WEBHOOK", log_file
        )
        execute("start /b cmd /c " .. cmd)
    else
        -- Use netcat on Linux/Steam Deck
        local nc_cmd = string.format(
            "nohup bash -c 'while true; do nc -l %d -q 1 | tee -a %s | head -20; done' &",
            port, log_file
        )
        execute(nc_cmd)
        print("[Webhook] Using netcat (nc). Each request logged to: " .. log_file)
    end
end)

registerCommand("webhookstop", function()
    if is_windows() then
        execute("powershell -Command \"Stop-Process -Name powershell -ErrorAction SilentlyContinue\"")
    else
        execute("pkill -f 'nc -l " .. (active_port or 9000) .. "' 2>/dev/null")
    end
    active_port = nil
    print("[Webhook] Stopped.")
end)

registerCommand("webhooklogs", function(args)
    local n = tonumber(args) or 20
    local f = io.open(log_file, "r")
    if not f then print("[Webhook] No logs yet.") return end
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    if #lines == 0 then print("[Webhook] Log is empty.") return end
    local start = math.max(1, #lines - n + 1)
    print("[Webhook] Last " .. n .. " entries:")
    for i = start, #lines do print(lines[i]) end
end)

registerCommand("webhookurl", function()
    local port = active_port or 9000
    print("[Webhook] Local URL: http://localhost:" .. port)
    print("[Webhook] LAN URL:   http://<your-ip>:" .. port)
    -- Try to get local IP
    local r
    if is_windows() then
        r = io.popen("powershell -Command \"(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' } | Select-Object -First 1).IPAddress\" 2>$null")
    else
        r = io.popen("hostname -I 2>/dev/null | awk '{print $1}'")
    end
    if r then
        local ip = r:read("*l"); r:close()
        if ip and ip ~= "" then
            print("[Webhook] LAN URL:   http://" .. ip:gsub("%s+","") .. ":" .. port)
        end
    end
end)

print("[Plugin] Webhook Receiver loaded. Commands: /webhook <port> /webhookstop /webhooklogs /webhookurl")
