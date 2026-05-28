-- plugins/coderunner.lua
-- Code Runner — execute code snippets in popular languages directly from chat.
-- JPE: You paste a snippet, you want to know if it runs. This plugin gives you
--      a fast REPL-style execution path for Python, Node.js, Bash, Lua, and more
--      without leaving NEURODECK. Every execution goes through the security validator
--      in the Rust layer, so the same safety gates that protect the terminal apply here.
--
-- NOTE: Code is passed to the language runtime as a temporary file execution.
--       Execution timeout is controlled by the OS — long-running scripts will block.
--       Do not run infinite loops.

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- Write code to a temp file and execute it, then clean up.
-- Returns the combined stdout+stderr output.
local function run_in_tempfile(code, extension, runner_cmd)
    local tmpfile
    if WIN then
        local tmp = execute("echo %TEMP%"):gsub("[\r\n]+", "")
        tmpfile = tmp .. "\\nd_coderun_" .. os.time() .. extension
        -- Write via PowerShell to handle multiline correctly
        local escaped = code:gsub("'", "''")
        execute("powershell -Command \"Set-Content -Path '" .. tmpfile ..
            "' -Value '" .. escaped .. "' -Encoding UTF8\" 2>nul")
    else
        tmpfile = "/tmp/nd_coderun_" .. os.time() .. extension
        local escaped = code:gsub("'", "'\\''")
        execute("printf '%s' '" .. escaped .. "' > '" .. tmpfile .. "' 2>/dev/null")
    end

    local cmd = runner_cmd:gsub("{file}", WIN and tmpfile:gsub("/", "\\") or tmpfile)
    local out = execute(cmd .. " 2>&1")

    -- Cleanup
    if WIN then
        execute("del \"" .. tmpfile .. "\" 2>nul")
    else
        execute("rm -f '" .. tmpfile .. "' 2>/dev/null")
    end

    return out
end

-- ── /py — run Python code ────────────────────────────────────────────────────
-- Usage: /py <python expression or multi-line code>
-- Example: /py print([x**2 for x in range(10)])

registerCommand("py", function(args)
    if args == "" then
        return "Usage: /py <python code>\nExample: /py import math; print(math.pi)"
    end

    local python_bin = "python3"
    local ver = execute("python3 --version 2>&1"):gsub("[\r\n]+", "")
    if ver == "" or ver:find("not found") or ver:find("not recognized") then
        python_bin = "python"
        ver = execute("python --version 2>&1"):gsub("[\r\n]+", "")
        if ver == "" or ver:find("not found") then
            return "Python not found. Install Python 3 to use /py."
        end
    end

    -- Single-line: run via -c flag for speed
    if not args:find("\n") then
        local safe = args:gsub('"', '\\"')
        local out = execute(python_bin .. ' -c "' .. safe .. '" 2>&1')
        return out ~= "" and out:sub(1, 3000) or "(no output)"
    end

    return run_in_tempfile(args, ".py", python_bin .. " {file}"):sub(1, 3000)
end)

-- ── /node — run JavaScript (Node.js) ─────────────────────────────────────────

registerCommand("js", function(args)
    if args == "" then
        return "Usage: /js <javascript code>\nExample: /js console.log(Array.from({length:5},(_,i)=>i*i))"
    end

    local node = execute("node --version 2>&1"):gsub("[\r\n]+", "")
    if node == "" or node:find("not found") or node:find("not recognized") then
        return "Node.js not found. Install Node.js to use /js."
    end

    if not args:find("\n") then
        local safe = args:gsub('"', '\\"')
        return execute('node -e "' .. safe .. '" 2>&1'):sub(1, 3000)
    end

    return run_in_tempfile(args, ".js", "node {file}"):sub(1, 3000)
end)

-- ── /sh — run a shell script ──────────────────────────────────────────────────

registerCommand("sh", function(args)
    if args == "" then
        return "Usage: /sh <shell command or script>\nFor multi-line scripts, separate lines with \\n."
    end

    if WIN then
        -- On Windows, route to PowerShell
        local safe = args:gsub('"', '\\"')
        return execute('powershell -Command "' .. safe .. '" 2>&1'):sub(1, 3000)
    else
        local safe = args:gsub("'", "'\\''")
        return execute("sh -c '" .. safe .. "' 2>&1"):sub(1, 3000)
    end
end)

-- ── /lua — run a Lua snippet ──────────────────────────────────────────────────
-- This runs inside the NEURODECK Lua engine itself via loadstring.
-- It has access to all the same globals (execute, print, sendPrompt, etc.).

registerCommand("lua", function(args)
    if args == "" then
        return "Usage: /lua <lua code>\nExample: /lua print(math.sqrt(144))\nNote: has access to all NEURODECK Lua globals."
    end
    local fn, err = load(args)
    if not fn then
        return "Lua syntax error: " .. tostring(err)
    end
    local ok, result = pcall(fn)
    if not ok then
        return "Lua runtime error: " .. tostring(result)
    end
    return result and tostring(result) or "(executed, no return value)"
end)

-- ── /cargo — run a Rust snippet via cargo-script or rust-script ───────────────

registerCommand("rs", function(args)
    if args == "" then
        return "Usage: /rs <rust expression>\nRequires cargo-script: cargo install cargo-script\nExample: /rs fn main(){println!(\"{}\", 2_u64.pow(32));}"
    end

    local has_cargo = execute("cargo --version 2>&1"):gsub("[\r\n]+", "")
    if has_cargo:find("not found") then
        return "Cargo not found. Install Rust from https://rustup.rs"
    end

    -- Wrap bare expressions in a main function if needed
    local code = args
    if not code:find("fn main") then
        code = 'fn main() { ' .. code .. ' }'
    end

    local out = run_in_tempfile(code, ".rs", "cargo script {file}"):sub(1, 3000)
    if out:find("cargo script") and out:find("not found") then
        return "cargo-script not installed. Run:\n  cargo install cargo-script\n\nThen retry."
    end
    return out
end)

-- ── /eval — smart multi-language evaluator ────────────────────────────────────
-- Detects language from a leading shebang or hint comment, or defaults to Python.
-- Usage: /eval #python\nprint("hello")
--        /eval #js\nconsole.log("hello")

registerCommand("eval", function(args)
    if args == "" then
        return "Usage: /eval #<lang>\\n<code>\n" ..
               "Langs: py, js, sh, lua\n" ..
               "Example: /eval #py\\nprint(sum(range(101)))"
    end

    local lang, code
    local hint = args:match("^#(%S+)")
    if hint then
        lang = hint:lower()
        code = args:match("^#%S+%s*(.+)$") or ""
    else
        lang = "py"
        code = args
    end

    -- Dispatch to the appropriate runner
    if lang == "py" or lang == "python" then
        local fn = _commands and _commands["py"]
        return fn and fn(code) or "Python runner not available."
    elseif lang == "js" or lang == "node" or lang == "javascript" then
        local fn = _commands and _commands["js"]
        return fn and fn(code) or "Node.js runner not available."
    elseif lang == "sh" or lang == "bash" or lang == "shell" then
        local fn = _commands and _commands["sh"]
        return fn and fn(code) or "Shell runner not available."
    elseif lang == "lua" then
        local fn = _commands and _commands["lua"]
        return fn and fn(code) or "Lua runner not available."
    elseif lang == "rs" or lang == "rust" then
        local fn = _commands and _commands["rs"]
        return fn and fn(code) or "Rust runner not available."
    else
        return string.format(
            "Unknown language '%s'. Supported: py, js, sh, lua, rs", lang)
    end
end)

-- ── /repl-help — quick reference ─────────────────────────────────────────────

registerCommand("repl", function(_args)
    return table.concat({
        "┌─ NEURODECK Code Runner ───────────────────────────────┐",
        "  /py   <code>        Python 3",
        "  /js   <code>        Node.js (JavaScript)",
        "  /sh   <cmd>         Shell (bash on Linux, PS on Windows)",
        "  /lua  <code>        Lua 5.4 (inside NEURODECK runtime)",
        "  /rs   <code>        Rust (requires cargo-script)",
        "  /eval #<lang> <code> Smart multi-language runner",
        "",
        "  All runners output combined stdout+stderr.",
        "  Long-running scripts will block — avoid infinite loops.",
        "└────────────────────────────────────────────────────────┘",
    }, "\n")
end)

print("[Plugin] coderunner loaded — /py /js /sh /lua /rs /eval /repl")
