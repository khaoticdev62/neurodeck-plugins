-- plugins/crypto.lua
-- Cryptography & Encoding Tools — hashing, base64, UUIDs, and password generation.
-- JPE: The three things developers constantly need from a crypto toolkit are:
--      "make me a hash of this", "encode/decode this base64", and "give me a strong
--      random token". This plugin delivers all three without opening a browser.

local function clean(s)
    if not s or s == "" then return "" end
    return s:gsub("[\"'\\`]", "")
end

local function is_windows()
    local r = execute("uname -s 2>/dev/null")
    return r == nil or r == "" or r:find("Error") ~= nil
end

local WIN = is_windows()

-- ── /hash — compute a hash ────────────────────────────────────────────────────
-- Usage: /hash <text>           — SHA-256 by default
--        /hash md5 <text>       — MD5
--        /hash sha1 <text>      — SHA-1
--        /hash sha512 <text>    — SHA-512

registerCommand("hash", function(args)
    if args == "" then
        return "Usage: /hash <text>\n       /hash <algo> <text>\nAlgorithms: md5, sha1, sha256 (default), sha512"
    end

    local first_word = args:match("^(%S+)")
    local algo, text

    if first_word == "md5" or first_word == "sha1" or first_word == "sha256" or first_word == "sha512" then
        algo = first_word
        text = args:match("^%S+%s+(.+)$") or ""
    else
        algo = "sha256"
        text = args
    end

    if text == "" then
        return string.format("Usage: /hash %s <text>", algo)
    end

    local safe_text = clean(text)

    if WIN then
        -- PowerShell has Get-FileHash for strings via a temp approach
        local ps_algo = ({
            md5    = "MD5",
            sha1   = "SHA1",
            sha256 = "SHA256",
            sha512 = "SHA512"
        })[algo] or "SHA256"
        local cmd = string.format(
            "powershell -Command \"$t = [System.Text.Encoding]::UTF8.GetBytes('%s'); " ..
            "$h = [System.Security.Cryptography.%sManaged]::new(); " ..
            "$b = $h.ComputeHash($t); " ..
            "($b | ForEach-Object { $_.ToString('x2') }) -join ''\" 2>nul",
            safe_text:gsub("'", "''"), ps_algo)
        local out = execute(cmd):gsub("[\r\n]+", "")
        return out ~= "" and string.format("%s(%s) = %s", algo, text, out)
            or ("Could not compute " .. algo .. " hash on Windows.")
    else
        local cmd
        if algo == "md5" then
            cmd = string.format("printf '%%s' '%s' | md5sum 2>/dev/null || printf '%%s' '%s' | md5 2>/dev/null",
                safe_text:gsub("'", "'\\''"), safe_text:gsub("'", "'\\''"))
        elseif algo == "sha1" then
            cmd = string.format("printf '%%s' '%s' | sha1sum 2>/dev/null", safe_text:gsub("'", "'\\''"))
        elseif algo == "sha512" then
            cmd = string.format("printf '%%s' '%s' | sha512sum 2>/dev/null", safe_text:gsub("'", "'\\''"))
        else
            cmd = string.format("printf '%%s' '%s' | sha256sum 2>/dev/null", safe_text:gsub("'", "'\\''"))
        end
        local out = execute(cmd):match("^(%x+)") or ""
        return out ~= "" and string.format("%s(%s) = %s", algo, text, out)
            or ("Could not compute " .. algo .. ". Install coreutils (sha256sum, md5sum).")
    end
end)

-- ── /b64enc — base64 encode ───────────────────────────────────────────────────

registerCommand("b64enc", function(args)
    if args == "" then return "Usage: /b64enc <text to encode>" end
    local safe = clean(args):gsub("'", "'\\''")
    local out
    if WIN then
        out = execute("powershell -Command \"[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('" ..
            clean(args):gsub("'", "''") .. "'))\" 2>nul"):gsub("[\r\n]+", "")
    else
        out = execute("printf '%s' '" .. safe .. "' | base64 2>/dev/null"):gsub("[\r\n%s]+", "")
    end
    return out ~= "" and ("Base64: " .. out) or "Encoding failed."
end)

-- ── /b64dec — base64 decode ───────────────────────────────────────────────────

registerCommand("b64dec", function(args)
    if args == "" then return "Usage: /b64dec <base64 string>" end
    local safe = args:match("^([A-Za-z0-9+/=]+)") or ""
    if safe == "" then return "Invalid base64 input — only A-Z a-z 0-9 + / = are allowed." end
    local out
    if WIN then
        out = execute("powershell -Command \"[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('" ..
            safe .. "'))\" 2>nul"):gsub("[\r\n]+$", "")
    else
        out = execute("printf '%s' '" .. safe .. "' | base64 -d 2>/dev/null"):gsub("[\r\n]+$", "")
    end
    return out ~= "" and ("Decoded: " .. out) or "Decoding failed — is the input valid base64?"
end)

-- ── /uuid — generate a UUID v4 ────────────────────────────────────────────────

registerCommand("uuid", function(args)
    local count = math.min(tonumber(args:match("^%s*(%d+)")) or 1, 10)
    local uuids = {}
    for _ = 1, count do
        local out
        if WIN then
            out = execute("powershell -Command \"[System.Guid]::NewGuid().ToString()\" 2>nul"):gsub("[\r\n]+", "")
        else
            -- Try /proc/sys/kernel/random/uuid first, then uuidgen, then python
            out = execute("cat /proc/sys/kernel/random/uuid 2>/dev/null"):gsub("[\r\n]+", "")
            if out == "" then
                out = execute("uuidgen 2>/dev/null"):gsub("[\r\n]+", "")
            end
            if out == "" then
                out = execute("python3 -c \"import uuid; print(uuid.uuid4())\" 2>/dev/null"):gsub("[\r\n]+", "")
            end
        end
        if out ~= "" then table.insert(uuids, out) end
    end
    return #uuids > 0 and table.concat(uuids, "\n") or "Could not generate UUID on this system."
end)

-- ── /pwgen — generate a cryptographically random password ────────────────────
-- Usage: /pwgen [length] [charset]
-- Charsets: alpha, num, alnum, special (default)

registerCommand("pwgen", function(args)
    local length  = tonumber(args:match("(%d+)")) or 24
    if length > 128 then length = 128 end
    local charset = args:find("alpha") and "alpha"
        or args:find("num") and "num"
        or args:find("alnum") and "alnum"
        or "special"

    local out
    if WIN then
        local ps_chars
        if charset == "alpha" then
            ps_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        elseif charset == "num" then
            ps_chars = "0123456789"
        elseif charset == "alnum" then
            ps_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        else
            ps_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
        end
        out = execute(string.format(
            "powershell -Command \"$c='%s'; (1..%d | ForEach-Object { $c[(Get-Random -Max %d)] }) -join ''\" 2>nul",
            ps_chars, length, #ps_chars)):gsub("[\r\n]+", "")
    else
        local char_class
        if charset == "alpha" then
            char_class = "[:alpha:]"
        elseif charset == "num" then
            char_class = "[:digit:]"
        elseif charset == "alnum" then
            char_class = "[:alnum:]"
        else
            char_class = "[:graph:]"
        end
        out = execute(string.format(
            "LC_ALL=C tr -dc '%s' < /dev/urandom 2>/dev/null | head -c %d",
            char_class, length)):gsub("[\r\n]+", "")
        if out == "" then
            -- Python fallback
            out = execute(string.format(
                "python3 -c \"import secrets, string; " ..
                "c=string.%s; print(''.join(secrets.choice(c) for _ in range(%d)))\" 2>/dev/null",
                charset == "special" and "printable" or
                charset == "alnum"   and "ascii_letters+string.digits" or
                charset == "num"     and "digits" or "ascii_letters",
                length)):gsub("[\r\n]+", "")
        end
    end

    if out ~= "" then
        return string.format(
            "Password (%d chars, %s):\n%s\n\nStrength: %d bits of entropy",
            length, charset, out,
            math.floor(length * (
                charset == "num" and 3.32 or
                charset == "alpha" and 4.7 or
                charset == "alnum" and 5.95 or 6.55)))
    end
    return "Could not generate password. Install python3 or coreutils."
end)

-- ── /token — generate a hex session token ────────────────────────────────────
-- Fast random token for API keys, session IDs, webhook secrets, etc.

registerCommand("token", function(args)
    local bytes = math.min(tonumber(args:match("^%s*(%d+)")) or 32, 64)
    local out
    if WIN then
        out = execute(string.format(
            "powershell -Command \"-join ((1..%d) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })\" 2>nul",
            bytes)):gsub("[\r\n]+", "")
    else
        out = execute(string.format(
            "LC_ALL=C od -vAn -N%d -tx1 < /dev/urandom 2>/dev/null | tr -d ' \\n'", bytes)):gsub("[\r\n]+", "")
        if out == "" then
            out = execute(string.format(
                "python3 -c \"import secrets; print(secrets.token_hex(%d))\" 2>/dev/null", bytes)):gsub("[\r\n]+", "")
        end
    end
    return out ~= "" and ("Token: " .. out) or "Could not generate token."
end)

print("[Plugin] crypto loaded — /hash /b64enc /b64dec /uuid /pwgen /token")
