-- plugins/docker.lua
-- Docker Toolkit — container management, image inspection, log tailing, and cleanup.
-- JPE: Docker's CLI is powerful but verbose. This plugin wraps the most common
--      day-to-day operations — "what containers are running?", "show me the logs",
--      "clean up everything stopped" — into short, memorable commands.

local function clean(s)
    if not s or s == "" then return "" end
    -- Container names/IDs: alphanumeric, underscores, hyphens, dots
    return s:gsub("[^%w%-%._]", "")
end

local function docker_available()
    local out = execute("docker --version 2>&1"):gsub("[\r\n]+", "")
    return not out:find("not found") and not out:find("not recognized") and out ~= ""
end

-- ── /dps — running containers ─────────────────────────────────────────────────

registerCommand("dps", function(_args)
    if not docker_available() then return "Docker not found. Install Docker or Docker Desktop." end
    local out = execute("docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}' 2>&1")
    return out ~= "" and out or "No running containers."
end)

-- ── /dpsa — all containers (including stopped) ────────────────────────────────

registerCommand("dpsa", function(_args)
    if not docker_available() then return "Docker not found." end
    local out = execute("docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>&1")
    return out ~= "" and out or "No containers."
end)

-- ── /dlogs — container logs ───────────────────────────────────────────────────
-- Usage: /dlogs <container>       — last 50 lines
--        /dlogs <container> <n>   — last n lines

registerCommand("dlogs", function(args)
    local name, n = args:match("^(%S+)%s*(%d*)")
    if not name or name == "" then
        return "Usage: /dlogs <container-name> [lines]\nExample: /dlogs my-api 100"
    end
    name = clean(name)
    n    = tostring(math.min(tonumber(n) or 50, 500))
    if not docker_available() then return "Docker not found." end
    local out = execute(string.format("docker logs --tail %s %s 2>&1", n, name))
    return out ~= "" and out:sub(1, 4000) or ("No logs for container '" .. name .. "'.")
end)

-- ── /dstart — start a stopped container ──────────────────────────────────────

registerCommand("dstart", function(args)
    local name = clean(args:match("^(%S+)") or "")
    if name == "" then return "Usage: /dstart <container-name>" end
    if not docker_available() then return "Docker not found." end
    return execute("docker start " .. name .. " 2>&1")
end)

-- ── /dstop — stop a running container ────────────────────────────────────────

registerCommand("dstop", function(args)
    local name = clean(args:match("^(%S+)") or "")
    if name == "" then return "Usage: /dstop <container-name>" end
    if not docker_available() then return "Docker not found." end
    return execute("docker stop " .. name .. " 2>&1")
end)

-- ── /drestart — restart a container ──────────────────────────────────────────

registerCommand("drestart", function(args)
    local name = clean(args:match("^(%S+)") or "")
    if name == "" then return "Usage: /drestart <container-name>" end
    if not docker_available() then return "Docker not found." end
    return execute("docker restart " .. name .. " 2>&1")
end)

-- ── /dexec — run a command in a running container ─────────────────────────────
-- Usage: /dexec <container> <command>

registerCommand("dexec", function(args)
    local name, cmd = args:match("^(%S+)%s+(.+)$")
    if not name or not cmd then
        return "Usage: /dexec <container> <command>\nExample: /dexec my-app sh -c 'ls /app'"
    end
    name = clean(name)
    cmd  = cmd:gsub("[;|&`$<>%(%){}%[%]\"'\\]", "")
    if not docker_available() then return "Docker not found." end
    return execute(string.format("docker exec %s %s 2>&1", name, cmd)):sub(1, 3000)
end)

-- ── /dimages — list Docker images ────────────────────────────────────────────

registerCommand("dimages", function(_args)
    if not docker_available() then return "Docker not found." end
    local out = execute("docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}' 2>&1")
    return out ~= "" and out or "No images."
end)

-- ── /drm — remove a stopped container ────────────────────────────────────────

registerCommand("drm", function(args)
    local name = clean(args:match("^(%S+)") or "")
    if name == "" then return "Usage: /drm <container-name>" end
    if not docker_available() then return "Docker not found." end
    return execute("docker rm " .. name .. " 2>&1")
end)

-- ── /drmi — remove an image ───────────────────────────────────────────────────

registerCommand("drmi", function(args)
    local name = clean(args:match("^(%S+)") or "")
    if name == "" then return "Usage: /drmi <image:tag>" end
    if not docker_available() then return "Docker not found." end
    return execute("docker rmi " .. name .. " 2>&1")
end)

-- ── /dclean — prune stopped containers, dangling images, unused networks ─────

registerCommand("dclean", function(args)
    if not docker_available() then return "Docker not found." end
    local confirm = args:match("^(%S+)") or ""
    if confirm ~= "yes" then
        return "This will remove all stopped containers, dangling images, and unused networks.\n" ..
               "Type '/dclean yes' to proceed."
    end
    local c_out = execute("docker container prune -f 2>&1")
    local i_out = execute("docker image prune -f 2>&1")
    local n_out = execute("docker network prune -f 2>&1")
    return "Containers:\n" .. c_out .. "\n\nImages:\n" .. i_out .. "\n\nNetworks:\n" .. n_out
end)

-- ── /dstats — live resource usage snapshot ───────────────────────────────────

registerCommand("dstats", function(_args)
    if not docker_available() then return "Docker not found." end
    -- --no-stream gives a one-shot snapshot instead of a live feed
    local out = execute("docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}' 2>&1")
    return out ~= "" and out or "No containers running."
end)

-- ── /dinspect — inspect a container ──────────────────────────────────────────

registerCommand("dinspect", function(args)
    local name = clean(args:match("^(%S+)") or "")
    if name == "" then return "Usage: /dinspect <container-name>" end
    if not docker_available() then return "Docker not found." end
    -- Show a human-readable subset of inspect output
    local out = execute(string.format(
        "docker inspect %s 2>&1 | head -80", name))
    return out ~= "" and out or ("No container '" .. name .. "' found.")
end)

-- ── /dcompose — docker-compose shortcuts ──────────────────────────────────────
-- Usage: /dcompose up|down|ps|logs [service]

registerCommand("dcompose", function(args)
    local sub     = args:match("^(%S+)") or ""
    local service = args:match("^%S+%s+(%S+)") or ""
    service       = clean(service)

    local compose_cmd = execute("docker compose version 2>&1"):find("version") and "docker compose"
        or (execute("docker-compose --version 2>&1"):find("version") and "docker-compose")
        or nil

    if not compose_cmd then
        return "Neither 'docker compose' nor 'docker-compose' found."
    end

    if sub == "up" then
        local out = execute(compose_cmd .. " up -d " .. service .. " 2>&1")
        return out
    elseif sub == "down" then
        return execute(compose_cmd .. " down 2>&1")
    elseif sub == "ps" then
        return execute(compose_cmd .. " ps 2>&1")
    elseif sub == "logs" then
        local tail = 50
        return execute(string.format("%s logs --tail %d %s 2>&1", compose_cmd, tail, service)):sub(1, 3000)
    elseif sub == "restart" then
        return execute(compose_cmd .. " restart " .. service .. " 2>&1")
    else
        return "Usage: /dcompose <up|down|ps|logs|restart> [service]"
    end
end)

print("[Plugin] docker loaded — /dps /dpsa /dlogs /dstart /dstop /drestart /dexec /dimages /drm /drmi /dclean /dstats /dinspect /dcompose")
