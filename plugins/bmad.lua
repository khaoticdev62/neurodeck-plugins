-- plugins/bmad.lua
-- Preinstalled BMad framework plugin.
-- Maps shortcuts /john, /sally, etc., to their respective BMad persona prompts.

local bmad_personas = {
    john = { name = "John", role = "Product Manager", greeting = "Hello! I'm John, the Product Manager. I'll help you structure your requirements and draft PRDs. What project are we building?" },
    sally = { name = "Sally", role = "UX Designer", greeting = "Hi there! I'm Sally, your UX Designer. Let's design some beautiful, intuitive, and highly responsive user interfaces!" },
    winston = { name = "Winston", role = "System Architect", greeting = "Greetings. Winston here, System Architect. Let's map out our system modules, pick the stack, and ensure a robust implementation." },
    amelia = { name = "Amelia", role = "Senior Developer", greeting = "Hey! Amelia here. Ready to write some clean, performant, and secure code. Let me know what we are developing." },
    paige = { name = "Paige", role = "Technical Writer", greeting = "Hello! I'm Paige, the Technical Writer. I'll write and structure the markdown docs, wikis, and user guides for the project." },
    mary = { name = "Mary", role = "Business Analyst", greeting = "Hello. I'm Mary, the Business Analyst. I will help structure the user stories, plan the epics, and outline acceptance criteria." }
}

for cmd, persona in pairs(bmad_personas) do
    registerCommand(cmd, function(args)
        local ok = setPersona(persona.name)
        if ok then
            local msg = string.format("System: Active Persona switched to %s (%s).\n\n%s", persona.name, persona.role, persona.greeting)
            if args and args ~= "" then
                print(string.format("[BMad %s] Switch triggered with query: '%s'", persona.name, args))
                msg = msg .. "\n\nQuery context received. Type your prompt below to interact."
            end
            return msg
        else
            return string.format("System: Error switching to persona '%s'. Make sure it exists in S-Term.", persona.name)
        end
    end)
end

print("[Plugin] BMad framework shortcuts loaded (/john, /sally, /winston, /amelia, /paige, /mary).")
