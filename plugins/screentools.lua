-- screentools.lua — NEURODECK Plugin
-- Screenshot, screen recording, and display tools for Steam Deck / Linux / Windows
-- Commands: /screenshot /record /stoprecord /displays /brightness /scale

local function is_windows()
    return (os.getenv("OS") or ""):find("Windows") ~= nil
end

local function is_steamdeck()
    local f = io.open("/sys/devices/virtual/dmi/id/product_name", "r")
    if not f then return false end
    local name = f:read("*l"); f:close()
    return name and name:find("Jupiter") ~= nil
end

local function screenshot_dir()
    if is_windows() then
        return (os.getenv("USERPROFILE") or ".") .. "\\Pictures\\Screenshots"
    end
    return (os.getenv("HOME") or ".") .. "/Pictures/Screenshots"
end

registerCommand("screenshot", function(args)
    local dir = screenshot_dir()
    local ts = os.date("%Y%m%d-%H%M%S")
    local path

    if is_windows() then
        path = dir .. "\\neurodeck-" .. ts .. ".png"
        execute("mkdir \"" .. dir .. "\" 2>nul & powershell -Command \"Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::PrimaryScreen | ForEach-Object { $bmp = New-Object System.Drawing.Bitmap($_.Bounds.Width, $_.Bounds.Height); $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($_.Bounds.Location, [System.Drawing.Point]::Empty, $_.Bounds.Size); $bmp.Save('" .. path .. "') }\"")
    elseif is_steamdeck() then
        path = dir .. "/neurodeck-" .. ts .. ".png"
        execute("mkdir -p '" .. dir .. "' && grim '" .. path .. "' 2>/dev/null || scrot '" .. path .. "' 2>/dev/null || import -window root '" .. path .. "' 2>/dev/null")
    else
        path = dir .. "/neurodeck-" .. ts .. ".png"
        execute("mkdir -p '" .. dir .. "' && grim '" .. path .. "' 2>/dev/null || scrot '" .. path .. "' 2>/dev/null || gnome-screenshot -f '" .. path .. "' 2>/dev/null")
    end
    print("[Screenshot] Saved: " .. path)
end)

registerCommand("record", function(args)
    if is_windows() then
        print("[Record] Use Xbox Game Bar (Win+G) or OBS on Windows.")
        return
    end
    local dir = screenshot_dir()
    local ts = os.date("%Y%m%d-%H%M%S")
    local path = dir .. "/neurodeck-rec-" .. ts .. ".mp4"
    execute("mkdir -p '" .. dir .. "'")
    if is_steamdeck() then
        -- Steam Deck uses pipewire/wlroots
        execute("nohup wf-recorder -f '" .. path .. "' &")
        print("[Record] Recording started → " .. path .. "  (use /stoprecord to stop)")
    else
        execute("nohup ffmpeg -f x11grab -r 30 -s 1920x1080 -i :0.0 -codec:v libx264 -preset ultrafast '" .. path .. "' &")
        print("[Record] Recording started → " .. path)
    end
end)

registerCommand("stoprecord", function()
    if is_windows() then return end
    execute("pkill -SIGINT wf-recorder 2>/dev/null; pkill -SIGINT ffmpeg 2>/dev/null")
    print("[Record] Stopped. Check ~/Pictures/Screenshots/ for the file.")
end)

registerCommand("displays", function()
    if is_windows() then
        execute("powershell -Command \"Get-WmiObject -Class Win32_VideoController | Select-Object Name, CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate | Format-Table -AutoSize\"")
    else
        execute("xrandr --query 2>/dev/null || wlr-randr 2>/dev/null || echo 'xrandr/wlr-randr not found'")
    end
end)

registerCommand("brightness", function(args)
    if is_windows() then
        print("[Brightness] Use the Windows Display Settings to adjust brightness.")
        return
    end
    if not args then
        execute("cat /sys/class/backlight/*/brightness 2>/dev/null | head -1 || xrandr --verbose | grep -i brightness | head -3")
        return
    end
    local pct = tonumber(args)
    if not pct or pct < 0 or pct > 100 then print("Usage: /brightness <0-100>") return end
    if is_steamdeck() then
        execute("echo " .. math.floor(pct * 2.55) .. " | sudo tee /sys/class/backlight/amdgpu_bl0/brightness 2>/dev/null")
    else
        execute("xrandr --output $(xrandr | grep ' connected' | head -1 | cut -d' ' -f1) --brightness " .. pct/100)
    end
    print("[Brightness] Set to " .. pct .. "%")
end)

print("[Plugin] Screen Tools loaded. Commands: /screenshot /record /stoprecord /displays /brightness")
