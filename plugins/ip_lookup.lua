-- ip_lookup.lua
-- Plugin: registers a /ip_lookup command to fetch the public IP address
-- Place this file in the plugins/ directory to auto-load on startup

registerCommand("ip_lookup", function(args)
    print("[ip_lookup] Fetching public IP address...")
    
    -- Try multiple services for resilience
    local ip = execute("curl -s --max-time 5 https://api.ipify.org 2>/dev/null")
    if not ip or ip == "" then
        ip = execute("curl -s --max-time 5 https://ifconfig.me 2>/dev/null")
    end
    if not ip or ip == "" then
        -- Windows fallback using PowerShell
        ip = execute("powershell -Command \"(Invoke-WebRequest -Uri https://api.ipify.org -UseBasicParsing).Content\" 2>nul")
    end
    
    if ip and ip ~= "" then
        local trimmed_ip = ip:gsub("%s+", "")
        print("Your public IP address is: " .. trimmed_ip)
        return "Public IP: " .. trimmed_ip
    else
        print("Error: Could not determine public IP address.")
        return "Error: Could not reach IP lookup service."
    end
end)

print("[Plugin] ip_lookup command registered. Use /ip_lookup in chat.")
