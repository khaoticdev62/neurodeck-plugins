-- plugins/steamdeck.lua
-- Steam Deck Hardware Control — TDP, performance modes, battery, display, and system info.
-- JPE: The Steam Deck is a PC that pretends to be a console. Under the hood you have
--      full AMD APU control. This plugin exposes the levers that matter: power envelope,
--      GPU clock, refresh rate, and battery state — all from the NEURODECK terminal.
--
-- Most ryzenadj commands require root (sudo). Use gamescope + devmode on SteamOS.
-- On Windows, these commands print instructions instead of running hardware calls.

local function is_steamdeck()
    -- Check for SteamOS or the Steam Deck specific DMI info
    local os_id = execute("cat /etc/os-release 2>/dev/null | grep '^ID='"):gsub("[\r\n]+", "")
    local dmi   = execute("cat /sys/class/dmi/id/product_name 2>/dev/null"):gsub("[\r\n]+", "")
    return os_id:find("steamos") or dmi:find("Jupiter") or dmi:find("Galileo")
end

local function is_linux()
    local r = execute("uname -s 2>/dev/null"):gsub("[\r\n]+", "")
    return r == "Linux"
end

local LINUX = is_linux()
local DECK  = is_steamdeck()

-- ── /deck — system overview ────────────────────────────────────────────────────

registerCommand("deck", function(_args)
    if not LINUX then
        return "Steam Deck commands require SteamOS/Linux. Windows dev note: these will work on-device."
    end

    local lines = { "┌─ STEAM DECK / SYSTEM INFO ─────────────────────────────┐" }

    -- CPU / APU
    local cpu = execute("grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2"):gsub("^%s+", ""):gsub("[\r\n]+", "")
    if cpu ~= "" then table.insert(lines, "  APU      : " .. cpu) end

    -- RAM
    local mem = execute("free -m 2>/dev/null | awk '/Mem:/{print $2\" MB total | \"$3\" MB used\"}'"):gsub("[\r\n]+", "")
    if mem ~= "" then table.insert(lines, "  RAM      : " .. mem) end

    -- GPU info via glxinfo or /sys
    local gpu = execute("glxinfo 2>/dev/null | grep 'OpenGL renderer' | cut -d: -f2"):gsub("^%s+", ""):gsub("[\r\n]+", "")
    if gpu == "" then
        gpu = execute("cat /sys/class/drm/card*/device/product_name 2>/dev/null | head -1"):gsub("[\r\n]+", "")
    end
    if gpu ~= "" then table.insert(lines, "  GPU      : " .. gpu) end

    -- Battery
    local bat_cap = execute("cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1"):gsub("[\r\n]+", "")
    local bat_sta = execute("cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1"):gsub("[\r\n]+", "")
    if bat_cap ~= "" then
        table.insert(lines, "  Battery  : " .. bat_cap .. "%" .. (bat_sta ~= "" and " (" .. bat_sta .. ")" or ""))
    end

    -- CPU temperature
    local temp = execute("cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1"):gsub("[\r\n]+", "")
    if temp ~= "" then
        local temp_c = math.floor(tonumber(temp) / 1000)
        table.insert(lines, string.format("  CPU Temp : %d°C", temp_c))
    end

    -- SteamOS version
    if DECK then
        local ver = execute("cat /etc/os-release 2>/dev/null | grep VERSION_ID | cut -d= -f2"):gsub("[\"'\r\n]+", "")
        if ver ~= "" then table.insert(lines, "  SteamOS  : " .. ver) end
    end

    -- Kernel
    local kernel = execute("uname -r 2>/dev/null"):gsub("[\r\n]+", "")
    if kernel ~= "" then table.insert(lines, "  Kernel   : " .. kernel) end

    -- Uptime
    local uptime = execute("uptime -p 2>/dev/null || uptime"):gsub("[\r\n]+", ""):gsub("^%s+", "")
    table.insert(lines, "  Uptime   : " .. uptime)

    table.insert(lines, "└────────────────────────────────────────────────────────┘")
    return table.concat(lines, "\n")
end)

-- ── /battery — battery status detail ─────────────────────────────────────────

registerCommand("battery", function(_args)
    if not LINUX then
        return "Battery info requires Linux/SteamOS."
    end

    local capacity = execute("cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1"):gsub("[\r\n]+", "")
    local status   = execute("cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1"):gsub("[\r\n]+", "")
    local energy   = execute("cat /sys/class/power_supply/BAT*/energy_now 2>/dev/null | head -1"):gsub("[\r\n]+", "")
    local full     = execute("cat /sys/class/power_supply/BAT*/energy_full 2>/dev/null | head -1"):gsub("[\r\n]+", "")
    local voltage  = execute("cat /sys/class/power_supply/BAT*/voltage_now 2>/dev/null | head -1"):gsub("[\r\n]+", "")
    local power    = execute("cat /sys/class/power_supply/BAT*/power_now 2>/dev/null | head -1"):gsub("[\r\n]+", "")

    local lines = {}
    if capacity ~= "" then
        local bar_filled = math.floor(tonumber(capacity) / 5)
        local bar = string.rep("█", bar_filled) .. string.rep("░", 20 - bar_filled)
        table.insert(lines, string.format("Battery : %s%% [%s]", capacity, bar))
    end
    if status   ~= "" then table.insert(lines, "Status  : " .. status) end
    if energy   ~= "" and full ~= "" then
        local e_wh = tonumber(energy) / 1000000
        local f_wh = tonumber(full) / 1000000
        table.insert(lines, string.format("Energy  : %.1f Wh / %.1f Wh", e_wh, f_wh))
    end
    if voltage  ~= "" then
        table.insert(lines, string.format("Voltage : %.2f V", tonumber(voltage) / 1000000))
    end
    if power    ~= "" and power ~= "0" then
        local p_w = tonumber(power) / 1000000
        table.insert(lines, string.format("Draw    : %.1f W", p_w))
    end

    return #lines > 0 and table.concat(lines, "\n") or "Battery information unavailable."
end)

-- ── /tdp — set or read TDP (Thermal Design Power) ────────────────────────────
-- Usage: /tdp         — read current TDP (from ryzenadj or /sys)
--        /tdp <watts> — set TDP (requires ryzenadj and sudo/root)

registerCommand("tdp", function(args)
    if not LINUX then
        return "TDP control requires Linux/SteamOS.\nOn Steam Deck: run ryzenadj via developer mode or PowerTools."
    end

    local watts = tonumber(args:match("^%s*(%d+)"))

    if not watts then
        -- Read current TDP from ryzenadj (informational)
        local ra = execute("ryzenadj 2>&1 | head -20")
        if ra ~= "" and not ra:find("not found") then
            return "ryzenadj TDP info:\n" .. ra
        end
        -- Fallback: hwmon power limit
        local limit = execute("cat /sys/class/powercap/intel-rapl*/constraint_0_power_limit_uw 2>/dev/null | head -1"):gsub("[\r\n]+", "")
        if limit ~= "" then
            return string.format("Power limit: %.1f W", tonumber(limit) / 1000000)
        end
        return "Usage: /tdp <watts>  (e.g. /tdp 15)\nInstall ryzenadj for full TDP control."
    end

    if watts < 3 or watts > 35 then
        return "TDP out of safe range (3–35W). Steam Deck default is 15W."
    end

    local mw = watts * 1000  -- milliwatts for ryzenadj
    local cmd = string.format(
        "sudo ryzenadj --stapm-limit=%d --fast-limit=%d --slow-limit=%d 2>&1",
        mw, mw, mw)
    local out = execute(cmd)
    if out:find("not found") then
        return string.format(
            "ryzenadj not found. Install it:\n" ..
            "  flatpak install --user com.github.AdnanHodzic.auto-cpufreq\n" ..
            "Or via PowerTools in Gaming Mode.\n\n" ..
            "Requested TDP: %dW", watts)
    end
    return string.format("TDP set to %dW:\n%s", watts, out)
end)

-- ── /perf — switch CPU governor / performance mode ───────────────────────────
-- Usage: /perf [performance|powersave|balanced|schedutil]

registerCommand("perf", function(args)
    if not LINUX then
        return "CPU governor control requires Linux/SteamOS."
    end

    local mode = args:match("^(%S+)") or ""
    local valid_modes = { performance=true, powersave=true, schedutil=true, balanced=true }

    -- Read current
    local current = execute("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null"):gsub("[\r\n]+", "")

    if mode == "" or not valid_modes[mode] then
        return string.format(
            "Current governor: %s\n\n" ..
            "Usage: /perf <mode>\n" ..
            "Modes:\n" ..
            "  performance — max clocks, max power\n" ..
            "  schedutil   — responsive to load (recommended for gaming)\n" ..
            "  balanced    — auto scaling\n" ..
            "  powersave   — minimum clocks, best battery",
            current ~= "" and current or "unknown")
    end

    local out = execute(string.format(
        "echo '%s' | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>&1",
        mode))
    if out:find("Permission denied") then
        return "Permission denied. Run NEURODECK with sudo or use PowerTools in Gaming Mode."
    end
    return string.format("CPU governor set to '%s'. Previous: %s", mode, current)
end)

-- ── /fps — set refresh rate / FPS cap ────────────────────────────────────────
-- On SteamOS Game Mode, the FPS cap and refresh rate are set via gamescope.

registerCommand("fps", function(args)
    local target = tonumber(args:match("^%s*(%d+)"))
    if not target then
        local current = execute("cat /sys/class/drm/card*/modes 2>/dev/null | head -5"):gsub("[\r\n]+", " ")
        return "Usage: /fps <limit>\n" ..
               "Common targets: 30, 40, 45, 60 (native), 90\n\n" ..
               "Note: In Game Mode, set FPS via the Quick Access Menu (⋯ button).\n" ..
               "In Desktop Mode, fps caps apply via gamescope -r <rate>.\n\n" ..
               "Available modes: " .. current
    end

    -- In Desktop Mode, try xrandr for refresh rate
    if target >= 30 and target <= 90 then
        local xrandr = execute(string.format("xrandr --output eDP-1 -r %d 2>&1", target))
        if xrandr:find("not found") then
            return string.format(
                "FPS cap %dfps requested.\n" ..
                "In Game Mode: use Quick Access Menu → Performance → Frame Rate Limit.\n" ..
                "In Desktop Mode: ensure gamescope is launched with '-r %d'.",
                target, target)
        end
        return string.format("Refresh rate set to %dHz via xrandr:\n%s", target, xrandr)
    end
    return "FPS target must be between 30 and 90 for Steam Deck."
end)

-- ── /vram — VRAM usage (shared UMA) ──────────────────────────────────────────

registerCommand("vram", function(_args)
    if not LINUX then return "VRAM info requires Linux/SteamOS." end
    local out = execute("radeontop -d - -l 1 2>/dev/null | head -5")
    if out == "" or out:find("not found") then
        -- Fallback via sysfs
        local vram = execute("cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -1"):gsub("[\r\n]+", "")
        local vtot = execute("cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | head -1"):gsub("[\r\n]+", "")
        if vram ~= "" and vtot ~= "" then
            local used_mb  = math.floor(tonumber(vram) / 1048576)
            local total_mb = math.floor(tonumber(vtot) / 1048576)
            return string.format("VRAM: %d MB used / %d MB total (shared UMA)", used_mb, total_mb)
        end
        return "VRAM info unavailable. Install radeontop for live stats."
    end
    return out
end)

-- ── /gamemode — toggle Game Mode / Desktop Mode hint ─────────────────────────

registerCommand("gamemode", function(args)
    if not LINUX then
        return "Game Mode control requires SteamOS."
    end
    local sub = args:match("^(%S+)") or ""
    if sub == "on" or sub == "start" then
        return "To enter Game Mode:\n" ..
               "  1. Return to Steam (click Steam logo or run 'steam')\n" ..
               "  2. The display will switch to gamescope at 1280×800\n" ..
               "  Or run: steam -gamepadui"
    elseif sub == "off" or sub == "desktop" then
        return "You're already in Desktop Mode.\n" ..
               "To return to Game Mode: click 'Return to Gaming Mode' on the desktop."
    else
        local in_gamescope = execute("pgrep gamescope 2>/dev/null"):gsub("[\r\n]+", "")
        if in_gamescope ~= "" then
            return "Currently running inside Gamescope (Game Mode).\n" ..
                   "PID: " .. in_gamescope
        else
            return "Currently in Desktop Mode.\n" ..
                   "Use /gamemode on to get instructions for switching to Game Mode."
        end
    end
end)

print("[Plugin] steamdeck loaded — /deck /battery /tdp /perf /fps /vram /gamemode")
