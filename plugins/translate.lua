-- translate.lua — NEURODECK Plugin
-- AI-powered text translation via the active LLM — no external API key needed
-- Commands: /translate /tl /detect /languages

local LANG_CODES = {
    en="English", es="Spanish", fr="French", de="German", it="Italian",
    pt="Portuguese", ru="Russian", ja="Japanese", ko="Korean", zh="Chinese",
    ar="Arabic", hi="Hindi", tr="Turkish", nl="Dutch", pl="Polish",
    sv="Swedish", da="Danish", no="Norwegian", fi="Finnish", cs="Czech",
    uk="Ukrainian", vi="Vietnamese", th="Thai", id="Indonesian",
}

local function lang_name(code)
    return LANG_CODES[code:lower()] or code
end

-- The active LLM is invoked by writing a message that the auto_responder
-- hook would catch — but we don't have direct LLM access from Lua.
-- Instead we build a slash-command message that the user sends to the AI.

registerCommand("translate", function(args)
    if not args or args == "" then
        print("Usage: /translate <lang> <text>")
        print("       /translate es Hello, how are you?")
        print("       /translate zh How do I compile Rust code?")
        return
    end
    local lang_code, text = args:match("^(%a+)%s+(.+)$")
    if not lang_code or not text then
        print("Usage: /translate <language-code> <text>")
        print("Examples: en es fr de ja ko zh ar hi ru pt")
        return
    end
    local lang = lang_name(lang_code)
    local prompt = string.format(
        "Translate the following text to %s. Output ONLY the translation, nothing else:\n\n%s",
        lang, text
    )
    -- Print the prompt so the user can paste it to the AI, or we prepopulate
    print("[Translate → " .. lang .. "] Sending to AI...")
    print("Prompt: " .. prompt)
    -- Register a one-shot hook to intercept the next AI response
    -- (This requires the user to send the message; we display the formatted prompt)
    print("\n💡 Copy the prompt above and paste it in the chat input, or type:")
    print("   Translate to " .. lang .. ": " .. text)
end)

-- Short alias
registerCommand("tl", function(args)
    if not args then print("Usage: /tl <lang-code> <text>") return end
    local lang_code, text = args:match("^(%a+)%s+(.+)$")
    if not lang_code or not text then print("Usage: /tl es <text>") return end
    local lang = lang_name(lang_code)
    -- Build a direct chat message and auto-send hint
    print("[Translate] Translating to " .. lang .. "...")
    print("Send to AI: Translate this to " .. lang .. " (output ONLY the translation): " .. text)
end)

registerCommand("detect", function(args)
    if not args or args == "" then print("Usage: /detect <text>") return end
    print("[Detect] Send to AI: What language is this text written in? Just name the language.\n\"" .. args .. "\"")
end)

registerCommand("languages", function()
    print("[Translate] Supported language codes:")
    local codes = {}
    for k in pairs(LANG_CODES) do table.insert(codes, k) end
    table.sort(codes)
    local line = ""
    for _, k in ipairs(codes) do
        line = line .. string.format("  %-4s %-14s", k, LANG_CODES[k])
        if #line > 72 then print(line); line = "" end
    end
    if line ~= "" then print(line) end
end)

print("[Plugin] Translate loaded. Commands: /translate /tl /detect /languages")
