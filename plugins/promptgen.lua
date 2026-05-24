-- plugins/promptgen.lua
-- Prompt Lab plugin — exposes /promptlab, /promptgen <task>, and /formula commands.
-- Also defines global prompt assembly functions for the S-Term Elite Prompt Lab UI.

-- ─────────────────────────────────────────────────────────────────────────────
-- Framework-specific formatting functions
-- ─────────────────────────────────────────────────────────────────────────────

local function format_default(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    if task and task ~= "" then
        table.insert(parts, "**Task/Objective:**\n" .. task)
    end
    if context and context ~= "" then
        table.insert(parts, "**Context/Background:**\n" .. context)
    end
    if tone and tone ~= "" then
        table.insert(parts, "**Tone/Style:**\n" .. tone)
    end
    if constraints and constraints ~= "" then
        table.insert(parts, "**Constraints:**\n" .. constraints)
    end
    if format and format ~= "" then
        table.insert(parts, "**Output Format:**\n" .. format)
    end
    if examples and examples ~= "" then
        table.insert(parts, "**Examples:**\n" .. examples)
    end
    return table.concat(parts, "\n\n")
end

local function format_aida(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    
    local body = "Write a persuasive response for the following task using the AIDA framework:\n\n"
    if task and task ~= "" then
        body = body .. "**Task:** " .. task .. "\n"
    end
    if context and context ~= "" then
        body = body .. "**Context:** " .. context .. "\n"
    end
    body = body .. "\n" ..
        "ATTENTION: Hook the reader immediately.\n" ..
        "INTEREST: Build relevance and context.\n" ..
        "DESIRE: Show value and benefit.\n" ..
        "ACTION: State a clear next step."
    table.insert(parts, body)

    if tone and tone ~= "" then
        table.insert(parts, "**Tone/Style:**\n" .. tone)
    end
    if constraints and constraints ~= "" then
        table.insert(parts, "**Constraints:**\n" .. constraints)
    end
    if format and format ~= "" then
        table.insert(parts, "**Output Format:**\n" .. format)
    end
    if examples and examples ~= "" then
        table.insert(parts, "**Examples:**\n" .. examples)
    end
    return table.concat(parts, "\n\n")
end

local function format_scqa(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    
    local body = "Respond to the following task using the SCQA consulting narrative framework:\n\n"
    if task and task ~= "" then
        body = body .. "**Task:** " .. task .. "\n"
    end
    if context and context ~= "" then
        body = body .. "**Context:** " .. context .. "\n"
    end
    body = body .. "\n" ..
        "SITUATION: Establish the current context.\n" ..
        "COMPLICATION: Identify the core tension or problem.\n" ..
        "QUESTION: State what needs to be resolved.\n" ..
        "ANSWER: Provide your recommendation."
    table.insert(parts, body)

    if tone and tone ~= "" then
        table.insert(parts, "**Tone/Style:**\n" .. tone)
    end
    if constraints and constraints ~= "" then
        table.insert(parts, "**Constraints:**\n" .. constraints)
    end
    if format and format ~= "" then
        table.insert(parts, "**Output Format:**\n" .. format)
    end
    if examples and examples ~= "" then
        table.insert(parts, "**Examples:**\n" .. examples)
    end
    return table.concat(parts, "\n\n")
end

local function format_pastor(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    
    local body = "Apply the PASTOR copywriting framework to this task:\n\n"
    if task and task ~= "" then
        body = body .. "**Task:** " .. task .. "\n"
    end
    if context and context ~= "" then
        body = body .. "**Context:** " .. context .. "\n"
    end
    body = body .. "\n" ..
        "PROBLEM: Define the pain point clearly.\n" ..
        "AMPLIFY: Show the cost of inaction.\n" ..
        "STORY: Share a relatable scenario.\n" ..
        "TRANSFORMATION: Demonstrate the outcome.\n" ..
        "OFFER: Present the solution.\n" ..
        "RESPONSE: Call to action."
    table.insert(parts, body)

    if tone and tone ~= "" then
        table.insert(parts, "**Tone/Style:**\n" .. tone)
    end
    if constraints and constraints ~= "" then
        table.insert(parts, "**Constraints:**\n" .. constraints)
    end
    if format and format ~= "" then
        table.insert(parts, "**Output Format:**\n" .. format)
    end
    if examples and examples ~= "" then
        table.insert(parts, "**Examples:**\n" .. examples)
    end
    return table.concat(parts, "\n\n")
end

local function format_pas(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    
    local body = "Use the PAS framework to address this task:\n\n"
    if task and task ~= "" then
        body = body .. "**Task:** " .. task .. "\n"
    end
    if context and context ~= "" then
        body = body .. "**Context:** " .. context .. "\n"
    end
    body = body .. "\n" ..
        "PROBLEM: Describe the problem concisely.\n" ..
        "AGITATE: Intensify the urgency — what happens if this isn't solved?\n" ..
        "SOLUTION: Present the clear, actionable solution."
    table.insert(parts, body)

    if tone and tone ~= "" then
        table.insert(parts, "**Tone/Style:**\n" .. tone)
    end
    if constraints and constraints ~= "" then
        table.insert(parts, "**Constraints:**\n" .. constraints)
    end
    if format and format ~= "" then
        table.insert(parts, "**Output Format:**\n" .. format)
    end
    if examples and examples ~= "" then
        table.insert(parts, "**Examples:**\n" .. examples)
    end
    return table.concat(parts, "\n\n")
end

local function format_cot(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    if task and task ~= "" then
        table.insert(parts, "**Task/Objective:**\n" .. task)
    end
    if context and context ~= "" then
        table.insert(parts, "**Context/Background:**\n" .. context)
    end
    
    local cot_instruction = "Think through this step by step before giving your final answer. Show your reasoning explicitly at each stage. Label each step (Step 1, Step 2, etc.) and end with a clear final answer."
    table.insert(parts, "**Reasoning Process:**\n" .. cot_instruction)

    if tone and tone ~= "" then
        table.insert(parts, "**Tone/Style:**\n" .. tone)
    end
    if constraints and constraints ~= "" then
        table.insert(parts, "**Constraints:**\n" .. constraints)
    end
    if format and format ~= "" then
        table.insert(parts, "**Output Format:**\n" .. format)
    end
    if examples and examples ~= "" then
        table.insert(parts, "**Examples:**\n" .. examples)
    end
    return table.concat(parts, "\n\n")
end

local function format_tot(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    if task and task ~= "" then
        table.insert(parts, "**Task/Objective:**\n" .. task)
    end
    if context and context ~= "" then
        table.insert(parts, "**Context/Background:**\n" .. context)
    end
    
    local tot_instruction = "Use a Tree of Thought approach. Generate three distinct reasoning branches for this task, evaluate each one, then select and complete the most promising path.\n\n" ..
        "Branch A: [first approach]\n" ..
        "Branch B: [second approach]\n" ..
        "Branch C: [third approach]\n\n" ..
        "Evaluation: Identify which branch is strongest and why.\n\n" ..
        "Final answer: Complete the winning branch in full."
    table.insert(parts, "**Reasoning Process (Tree of Thought):**\n" .. tot_instruction)

    if tone and tone ~= "" then
        table.insert(parts, "**Tone/Style:**\n" .. tone)
    end
    if constraints and constraints ~= "" then
        table.insert(parts, "**Constraints:**\n" .. constraints)
    end
    if format and format ~= "" then
        table.insert(parts, "**Output Format:**\n" .. format)
    end
    if examples and examples ~= "" then
        table.insert(parts, "**Examples:**\n" .. examples)
    end
    return table.concat(parts, "\n\n")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- 8 new formula formatters
-- ─────────────────────────────────────────────────────────────────────────────

local function format_star(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    local body = "Structure your response using the STAR framework:\n\n"
    if task and task ~= "" then body = body .. "**Task:** " .. task .. "\n" end
    if context and context ~= "" then body = body .. "**Context:** " .. context .. "\n" end
    body = body .. "\n" ..
        "SITUATION: Describe the relevant background.\n" ..
        "TASK: Clarify the specific responsibility or challenge.\n" ..
        "ACTION: Detail the exact steps taken or recommended.\n" ..
        "RESULT: Quantify the outcome or expected impact."
    table.insert(parts, body)
    if tone and tone ~= "" then table.insert(parts, "**Tone/Style:**\n" .. tone) end
    if constraints and constraints ~= "" then table.insert(parts, "**Constraints:**\n" .. constraints) end
    if format and format ~= "" then table.insert(parts, "**Output Format:**\n" .. format) end
    if examples and examples ~= "" then table.insert(parts, "**Examples:**\n" .. examples) end
    return table.concat(parts, "\n\n")
end

local function format_rice(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    local body = "Evaluate and prioritize using the RICE scoring framework:\n\n"
    if task and task ~= "" then body = body .. "**Task:** " .. task .. "\n" end
    if context and context ~= "" then body = body .. "**Context:** " .. context .. "\n" end
    body = body .. "\n" ..
        "REACH: How many users/customers will this affect per period?\n" ..
        "IMPACT: What is the magnitude of the effect (1=minimal, 3=massive)?\n" ..
        "CONFIDENCE: How certain are we in these estimates (0–100%)?\n" ..
        "EFFORT: How many person-months is this? (Lower = better)\n\n" ..
        "RICE Score = (Reach × Impact × Confidence) / Effort\n\n" ..
        "Provide your prioritized ranking with scores and rationale."
    table.insert(parts, body)
    if tone and tone ~= "" then table.insert(parts, "**Tone/Style:**\n" .. tone) end
    if constraints and constraints ~= "" then table.insert(parts, "**Constraints:**\n" .. constraints) end
    if format and format ~= "" then table.insert(parts, "**Output Format:**\n" .. format) end
    if examples and examples ~= "" then table.insert(parts, "**Examples:**\n" .. examples) end
    return table.concat(parts, "\n\n")
end

local function format_icio(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    local body = "Precision task specification using the ICIO framework:\n\n"
    if task and task ~= "" then body = body .. "**INPUT:** " .. task .. "\n" end
    if context and context ~= "" then body = body .. "**CONTEXT:** " .. context .. "\n" end
    if constraints and constraints ~= "" then
        body = body .. "**CONSTRAINTS:** " .. constraints .. "\n"
    end
    body = body .. "**INSTRUCTIONS:** Complete the task precisely as specified. Follow all constraints exactly.\n"
    if format and format ~= "" then
        body = body .. "**OUTPUT:** " .. format
    else
        body = body .. "**OUTPUT:** Provide the most accurate, complete result possible."
    end
    table.insert(parts, body)
    if tone and tone ~= "" then table.insert(parts, "**Tone/Style:**\n" .. tone) end
    if examples and examples ~= "" then table.insert(parts, "**Examples:**\n" .. examples) end
    return table.concat(parts, "\n\n")
end

local function format_react(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    local body = "Use the ReAct (Reason + Act) framework. For each step, explicitly state your Thought before your Action.\n\n"
    if task and task ~= "" then body = body .. "**Task:** " .. task .. "\n" end
    if context and context ~= "" then body = body .. "**Context:** " .. context .. "\n" end
    body = body .. "\n" ..
        "Follow this loop until the task is complete:\n\n" ..
        "Thought: [Reason about what to do next]\n" ..
        "Action: [The specific action to take]\n" ..
        "Observation: [Result of the action]\n" ..
        "... (repeat as needed)\n\n" ..
        "Final Answer: [Conclusive result]"
    table.insert(parts, body)
    if tone and tone ~= "" then table.insert(parts, "**Tone/Style:**\n" .. tone) end
    if constraints and constraints ~= "" then table.insert(parts, "**Constraints:**\n" .. constraints) end
    if format and format ~= "" then table.insert(parts, "**Output Format:**\n" .. format) end
    if examples and examples ~= "" then table.insert(parts, "**Examples:**\n" .. examples) end
    return table.concat(parts, "\n\n")
end

local function format_spin(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    if persona and persona ~= "" then
        table.insert(parts, "**Role/Persona:**\n" .. persona)
    end
    local body = "Apply the SPIN questioning framework to this task:\n\n"
    if task and task ~= "" then body = body .. "**Task:** " .. task .. "\n" end
    if context and context ~= "" then body = body .. "**Context:** " .. context .. "\n" end
    body = body .. "\n" ..
        "SITUATION questions: Understand the current state.\n" ..
        "PROBLEM questions: Uncover the pain points and difficulties.\n" ..
        "IMPLICATION questions: Explore the consequences of inaction.\n" ..
        "NEED-PAYOFF questions: Highlight the value of solving the problem.\n\n" ..
        "After working through SPIN, synthesize your findings into a compelling recommendation."
    table.insert(parts, body)
    if tone and tone ~= "" then table.insert(parts, "**Tone/Style:**\n" .. tone) end
    if constraints and constraints ~= "" then table.insert(parts, "**Constraints:**\n" .. constraints) end
    if format and format ~= "" then table.insert(parts, "**Output Format:**\n" .. format) end
    if examples and examples ~= "" then table.insert(parts, "**Examples:**\n" .. examples) end
    return table.concat(parts, "\n\n")
end

local function format_rtf(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    local role = (persona and persona ~= "") and persona or "a knowledgeable expert"
    local task_str = (task and task ~= "") and task or "complete the described objective"
    local fmt_str = (format and format ~= "") and format or "a clear, structured response"
    local body = string.format(
        "ROLE: %s\n\nTASK: %s\n\nFORMAT: %s",
        role, task_str, fmt_str)
    if context and context ~= "" then
        body = body .. "\n\nCONTEXT: " .. context
    end
    table.insert(parts, body)
    if tone and tone ~= "" then table.insert(parts, "**Tone/Style:**\n" .. tone) end
    if constraints and constraints ~= "" then table.insert(parts, "**Constraints:**\n" .. constraints) end
    if examples and examples ~= "" then table.insert(parts, "**Examples:**\n" .. examples) end
    return table.concat(parts, "\n\n")
end

local function format_expert(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    local domain = (persona and persona ~= "") and persona or "a world-class domain expert"
    local body = string.format(
        "You are %s. Approach this task with your deepest domain expertise, precision, and professional rigor.\n\n",
        domain)
    if task and task ~= "" then body = body .. "**Task:** " .. task .. "\n" end
    if context and context ~= "" then body = body .. "**Context:** " .. context .. "\n" end
    body = body .. "\nCalibrate your response as if presenting to a senior expert peer audience. " ..
        "Reference relevant frameworks, cite best practices, acknowledge trade-offs, " ..
        "and flag edge cases that a non-expert would miss."
    table.insert(parts, body)
    if tone and tone ~= "" then table.insert(parts, "**Tone/Style:**\n" .. tone) end
    if constraints and constraints ~= "" then table.insert(parts, "**Constraints:**\n" .. constraints) end
    if format and format ~= "" then table.insert(parts, "**Output Format:**\n" .. format) end
    if examples and examples ~= "" then table.insert(parts, "**Examples:**\n" .. examples) end
    return table.concat(parts, "\n\n")
end

local function format_socratic(persona, task, context, tone, constraints, format, examples)
    local parts = {}
    local guide = (persona and persona ~= "") and persona or "a Socratic tutor"
    local body = string.format(
        "You are %s. Your method is to guide understanding exclusively through questions — " ..
        "never state answers directly. Ask one question at a time, listen for the response, " ..
        "and build the next question on what the learner reveals.\n\n", guide)
    if task and task ~= "" then body = body .. "**Topic/Goal:** " .. task .. "\n" end
    if context and context ~= "" then body = body .. "**Learner Context:** " .. context .. "\n" end
    body = body .. "\nBegin by establishing what the learner already knows. " ..
        "Probe assumptions. Reveal contradictions gently. " ..
        "Guide toward the insight without giving it away."
    table.insert(parts, body)
    if tone and tone ~= "" then table.insert(parts, "**Tone/Style:**\n" .. tone) end
    if constraints and constraints ~= "" then table.insert(parts, "**Constraints:**\n" .. constraints) end
    if format and format ~= "" then table.insert(parts, "**Output Format:**\n" .. format) end
    if examples and examples ~= "" then table.insert(parts, "**Examples:**\n" .. examples) end
    return table.concat(parts, "\n\n")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Global prompt assembly hook for Rust/Tauri frontend
-- ─────────────────────────────────────────────────────────────────────────────

function assemble_prompt_via_lua(persona, task, context, tone, constraints, format, examples, formula_name)
    formula_name = formula_name or "default"
    formula_name = formula_name:lower()

    if formula_name == "aida" then
        return format_aida(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "scqa" then
        return format_scqa(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "pastor" then
        return format_pastor(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "pas" then
        return format_pas(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "cot" then
        return format_cot(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "tot" then
        return format_tot(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "star" then
        return format_star(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "rice" then
        return format_rice(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "icio" then
        return format_icio(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "react" then
        return format_react(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "spin" then
        return format_spin(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "rtf" then
        return format_rtf(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "expert" then
        return format_expert(persona, task, context, tone, constraints, format, examples)
    elseif formula_name == "socratic" then
        return format_socratic(persona, task, context, tone, constraints, format, examples)
    else
        return format_default(persona, task, context, tone, constraints, format, examples)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CLI / Command Line compatibility hooks
-- ─────────────────────────────────────────────────────────────────────────────

local FORMULA_KEYS = {
    "AIDA", "SCQA", "PASTOR", "PAS", "CoT", "ToT",
    "STAR", "RICE", "ICIO", "ReAct", "SPIN", "RTF", "Expert", "Socratic"
}

registerCommand("promptgen", function(args)
    if not args or args == "" then
        return "Usage: /promptgen <task description>\n\nExample: /promptgen Explain quantum entanglement to a 10-year-old"
    end
    local prompt = format_cot("", args, "", "", "", "", "")
    return string.format(
        "[Prompt Lab — CoT Formula]\n\n%s\n\n" ..
        "─────────────────────────────────────\n" ..
        "Tip: Open the Prompt Lab tab (📝) to access all 15 formulas, templates, and JPE explanation.", prompt)
end)

registerCommand("promptlab", function(_args)
    local lines = {"[Prompt Lab — Formula Registry]\n"}
    local registry = {
        {"AIDA",     "Attention › Interest › Desire › Action"},
        {"SCQA",     "Situation › Complication › Question › Answer"},
        {"PASTOR",   "Problem › Amplify › Story › Transformation › Offer › Response"},
        {"PAS",      "Problem › Agitate › Solution"},
        {"CoT",      "Chain of Thought (step-by-step reasoning)"},
        {"ToT",      "Tree of Thought (multi-branch exploration)"},
        {"STAR",     "Situation › Task › Action › Result"},
        {"RICE",     "Reach › Impact › Confidence › Effort (prioritization)"},
        {"ICIO",     "Input › Constraints › Instructions › Output"},
        {"ReAct",    "Reason + Act loop (agent tasks)"},
        {"SPIN",     "Situation › Problem › Implication › Need-Payoff"},
        {"RTF",      "Role › Task › Format (minimal 3-part)"},
        {"Expert",   "Expert persona activation with domain calibration"},
        {"Socratic", "Guided discovery through Socratic questioning"},
    }
    for i, entry in ipairs(registry) do
        table.insert(lines, string.format("  %2d. %-12s %s", i, entry[1], entry[2]))
    end
    table.insert(lines, "\nOpen the Prompt Lab tab (📝 icon in the nav bar) for the full interactive UI.")
    table.insert(lines, "Or use: /formula <name> <task>  to generate any formula immediately.")
    return table.concat(lines, "\n")
end)

registerCommand("formula", function(args)
    if not args or args == "" then
        local keys = table.concat(FORMULA_KEYS, " | ")
        return "Usage: /formula <name> <task>\n\nAvailable: " .. keys
    end

    local name, rest = args:match("^(%S+)%s*(.*)")
    if not name then
        return "Usage: /formula <name> <task>"
    end

    local name_lower = name:lower()
    if not rest or rest == "" then
        return string.format("Usage: /formula %s <task description>", name)
    end

    local prompt
    if name_lower == "aida" then
        prompt = format_aida("", rest, "", "", "", "", "")
    elseif name_lower == "scqa" then
        prompt = format_scqa("", rest, "", "", "", "", "")
    elseif name_lower == "pastor" then
        prompt = format_pastor("", rest, "", "", "", "", "")
    elseif name_lower == "pas" then
        prompt = format_pas("", rest, "", "", "", "", "")
    elseif name_lower == "cot" then
        prompt = format_cot("", rest, "", "", "", "", "")
    elseif name_lower == "tot" then
        prompt = format_tot("", rest, "", "", "", "", "")
    elseif name_lower == "star" then
        prompt = format_star("", rest, "", "", "", "", "")
    elseif name_lower == "rice" then
        prompt = format_rice("", rest, "", "", "", "", "")
    elseif name_lower == "icio" then
        prompt = format_icio("", rest, "", "", "", "", "")
    elseif name_lower == "react" then
        prompt = format_react("", rest, "", "", "", "", "")
    elseif name_lower == "spin" then
        prompt = format_spin("", rest, "", "", "", "", "")
    elseif name_lower == "rtf" then
        prompt = format_rtf("", rest, "", "", "", "", "")
    elseif name_lower == "expert" then
        prompt = format_expert("", rest, "", "", "", "", "")
    elseif name_lower == "socratic" then
        prompt = format_socratic("", rest, "", "", "", "", "")
    else
        local keys = table.concat(FORMULA_KEYS, ", ")
        return string.format("Unknown formula '%s'. Available: %s", name, keys)
    end

    return string.format("[Prompt Lab — %s]\n\n%s", name:upper(), prompt)
end)

print("[Plugin] Prompt Lab loaded — 15 formulas (/promptlab, /promptgen, /formula).")
