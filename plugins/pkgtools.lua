-- pkgtools.lua — NEURODECK Plugin
-- Package manager shortcuts for npm, pip, cargo, pacman, and apt
-- Commands: /npm /pip /cargo /pac /apt

local function run(cmd)
    execute(cmd)
end

registerCommand("npm", function(args)
    if not args or args == "" then
        print("Usage: /npm <subcommand>  e.g. /npm install express  /npm run build  /npm ls")
        return
    end
    run("npm " .. args)
end)

registerCommand("pip", function(args)
    if not args or args == "" then
        print("Usage: /pip <subcommand>  e.g. /pip install requests  /pip list  /pip freeze")
        return
    end
    local py = "python3"
    if os.getenv("OS") and os.getenv("OS"):find("Windows") then py = "python" end
    run(py .. " -m pip " .. args)
end)

registerCommand("cargo", function(args)
    if not args or args == "" then
        print("Usage: /cargo <subcommand>  e.g. /cargo build  /cargo test  /cargo add serde")
        return
    end
    run("cargo " .. args)
end)

registerCommand("pac", function(args)
    if not args or args == "" then
        print("Usage: /pac <subcommand>  e.g. /pac -Syu  /pac -S neovim  /pac -Qs lua")
        return
    end
    run("sudo pacman " .. args)
end)

registerCommand("apt", function(args)
    if not args or args == "" then
        print("Usage: /apt <subcommand>  e.g. /apt install curl  /apt update  /apt list --installed")
        return
    end
    run("sudo apt " .. args)
end)

registerCommand("pkginfo", function(args)
    if not args or args == "" then
        print("Detected package managers on this system:")
        for _, pm in ipairs({"npm", "pip3", "cargo", "pacman", "apt", "brew", "dnf", "yum"}) do
            local r = io.popen("which " .. pm .. " 2>/dev/null")
            if r then
                local path = r:read("*l"); r:close()
                if path and path ~= "" then
                    print("  ✓ " .. pm .. " → " .. path)
                end
            end
        end
    end
end)

print("[Plugin] Package Tools loaded. Commands: /npm /pip /cargo /pac /apt /pkginfo")
