-- auto_responder.lua
-- Plugin: hooks into the onMessage event to log trigger words
-- Place this file in the plugins/ directory to auto-load on startup

local trigger_words = {"help", "error", "bug", "crash", "fail"}

registerHook("onMessage", function(message)
    local msg_lower = message:lower()
    for _, word in ipairs(trigger_words) do
        if msg_lower:find(word) then
            print("[AutoResponder] Trigger detected: '" .. word .. "' in message.")
            print("[AutoResponder] Routing to support context...")
            break
        end
    end
    -- Return the message unchanged (pass-through)
    return message
end)

registerHook("onAIResponse", function(response)
    -- Log response length as a debug metric
    local word_count = 0
    for _ in response:gmatch("%S+") do
        word_count = word_count + 1
    end
    print(string.format("[AutoResponder] AI response received: %d words.", word_count))
    return response
end)

print("[Plugin] auto_responder hooks registered (onMessage, onAIResponse).")
