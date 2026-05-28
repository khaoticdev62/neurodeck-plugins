-- plugins/aitools.lua
-- AI Workflow Accelerators — opinionated LLM shortcuts for the solo developer.
-- JPE: Each command here is a pre-wired prompt template with your input dropped in.
--      You type what you want done; it formats the best possible prompt and fires
--      it at the active LLM. No prompt engineering required.

-- ── /summarize — distill any text into key points ────────────────────────────

registerCommand("summarize", function(args)
    if args == "" then
        return "Usage: /summarize <text>\nPaste the content you want condensed into bullet points."
    end
    local prompt = string.format(
        "Summarize the following text into 3–5 concise bullet points. " ..
        "Each bullet should capture one essential idea. " ..
        "Be precise — omit filler, keep substance.\n\n---\n%s\n---",
        args)
    print("[aitools] Summarizing…")
    return sendPrompt(prompt)
end)

-- ── /explain — explain a concept in plain English ────────────────────────────

registerCommand("explain", function(args)
    if args == "" then
        return "Usage: /explain <concept or code snippet>\nExample: /explain Rust lifetimes"
    end
    local prompt = string.format(
        "Explain the following concept or code clearly and concisely. " ..
        "Use plain English first, then technical detail. " ..
        "Include a simple analogy if it helps. End with one practical takeaway.\n\n%s",
        args)
    print("[aitools] Explaining…")
    return sendPrompt(prompt)
end)

-- ── /eli5 — explain like I'm five ────────────────────────────────────────────

registerCommand("eli5", function(args)
    if args == "" then
        return "Usage: /eli5 <topic>\nExample: /eli5 asymmetric encryption"
    end
    local prompt = string.format(
        "Explain '%s' like I'm five years old. " ..
        "Use simple words, a relatable everyday analogy, " ..
        "and no jargon. Keep it under 100 words.",
        args)
    print("[aitools] Simplifying…")
    return sendPrompt(prompt)
end)

-- ── /improve — rewrite text to be cleaner and more effective ─────────────────

registerCommand("improve", function(args)
    if args == "" then
        return "Usage: /improve <text to rewrite>\nWorks on emails, commit messages, docs, error messages, UI copy."
    end
    local prompt = string.format(
        "Rewrite the following text to be clearer, more concise, and more professional. " ..
        "Fix grammar and awkward phrasing. " ..
        "Preserve the original intent and tone. " ..
        "Output only the improved version — no explanation.\n\n%s",
        args)
    print("[aitools] Improving…")
    return sendPrompt(prompt)
end)

-- ── /review — code review ─────────────────────────────────────────────────────

registerCommand("review", function(args)
    if args == "" then
        return "Usage: /review <code snippet>\nPaste the code you want reviewed for bugs, security, and style."
    end
    local prompt = string.format(
        "Act as a senior software engineer doing a code review. " ..
        "Review the following code for:\n" ..
        "1. Bugs and logic errors\n" ..
        "2. Security vulnerabilities (injection, memory safety, auth)\n" ..
        "3. Performance issues\n" ..
        "4. Code clarity and naming\n" ..
        "5. Missing edge case handling\n\n" ..
        "For each issue found: name it, explain why it's a problem, and give the fix.\n" ..
        "If the code looks solid, say so explicitly.\n\n" ..
        "```\n%s\n```",
        args)
    print("[aitools] Reviewing code…")
    return sendPrompt(prompt)
end)

-- ── /translate — translate text to another language ───────────────────────────
-- Usage: /translate <lang> <text>
-- Example: /translate Spanish Hello, how are you today?

registerCommand("translate", function(args)
    local lang, text = args:match("^(%S+)%s+(.+)$")
    if not lang or not text then
        return "Usage: /translate <language> <text>\nExample: /translate Japanese What time is the meeting?"
    end
    local prompt = string.format(
        "Translate the following text into %s. " ..
        "Output only the translation — no explanation, no original text.\n\n%s",
        lang, text)
    print("[aitools] Translating to " .. lang .. "…")
    return sendPrompt(prompt)
end)

-- ── /bullet — convert prose into bullet points ────────────────────────────────

registerCommand("bullet", function(args)
    if args == "" then
        return "Usage: /bullet <prose text>\nConverts paragraphs into structured bullet points."
    end
    local prompt = string.format(
        "Convert the following prose into a clear, structured bullet-point list. " ..
        "Group related points under sub-bullets if needed. " ..
        "Be concise — each bullet should be one complete idea.\n\n%s",
        args)
    print("[aitools] Bulleting…")
    return sendPrompt(prompt)
end)

-- ── /debug — explain an error message ────────────────────────────────────────

registerCommand("debug", function(args)
    if args == "" then
        return "Usage: /debug <error message or stack trace>\nPaste the error and get a diagnosis."
    end
    local prompt = string.format(
        "I encountered this error. Diagnose it:\n\n" ..
        "1. What caused it (root cause in plain English)\n" ..
        "2. How to fix it (concrete steps)\n" ..
        "3. How to prevent it in future code\n\n" ..
        "Error:\n```\n%s\n```",
        args)
    print("[aitools] Diagnosing…")
    return sendPrompt(prompt)
end)

-- ── /docstring — generate a docstring for a function ──────────────────────────

registerCommand("docstring", function(args)
    if args == "" then
        return "Usage: /docstring <function code>\nGenerates a documentation comment for the function."
    end
    local prompt = string.format(
        "Write a clear, concise docstring for the following function. " ..
        "Include: what it does, each parameter (name, type, purpose), " ..
        "the return value, and any important side effects or exceptions. " ..
        "Match the documentation style for the language detected.\n\n" ..
        "Output only the docstring comment — no surrounding code.\n\n" ..
        "```\n%s\n```",
        args)
    print("[aitools] Generating docstring…")
    return sendPrompt(prompt)
end)

-- ── /regex — generate a regular expression ────────────────────────────────────

registerCommand("regex", function(args)
    if args == "" then
        return "Usage: /regex <describe what to match>\nExample: /regex match a US phone number with optional country code"
    end
    local prompt = string.format(
        "Write a regular expression that matches the following requirement:\n\n%s\n\n" ..
        "Provide:\n" ..
        "1. The regex pattern\n" ..
        "2. Flags to use (if any)\n" ..
        "3. Three example strings that MATCH\n" ..
        "4. Two example strings that DON'T match\n" ..
        "5. A brief explanation of each capture group or major part",
        args)
    print("[aitools] Building regex…")
    return sendPrompt(prompt)
end)

-- ── /naming — generate good names for a thing ────────────────────────────────

registerCommand("naming", function(args)
    if args == "" then
        return "Usage: /naming <describe the thing to name>\nExample: /naming a function that validates JWT tokens and returns the decoded payload"
    end
    local prompt = string.format(
        "Suggest 5 excellent names for: %s\n\n" ..
        "For each name provide:\n" ..
        "- The name itself (function/variable style and PascalCase if a class)\n" ..
        "- One sentence explaining why it's good\n\n" ..
        "Prioritize clarity over cleverness. Names should be instantly understandable to a new developer.",
        args)
    print("[aitools] Generating names…")
    return sendPrompt(prompt)
end)

print("[Plugin] aitools loaded — /summarize /explain /eli5 /improve /review /translate /bullet /debug /docstring /regex /naming")
