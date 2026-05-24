# NEURODECK Plugin Registry

Community plugin repository for [NEURODECK](https://github.com/khaoticdev62/NEURODECK) — the AI-powered terminal OS for Steam Deck.

## Installing Plugins

Open NEURODECK → Settings → Plugin Manager → Marketplace tab → click **Install** on any plugin.

## Publishing a Plugin

1. Fork this repo
2. Add your `.lua` file to `plugins/`
3. Add an entry to `registry.json`
4. Open a Pull Request

### registry.json entry format

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "author": "your-github-username",
  "version": "1.0.0",
  "description": "What it does.",
  "tags": ["utility"],
  "download_url": "https://raw.githubusercontent.com/your-org/neurodeck-plugins/main/plugins/my_plugin.lua",
  "lua_file": "my_plugin.lua",
  "installed": false,
  "enabled": false
}
```

### Lua Plugin API

Globals available inside all NEURODECK plugins:

| Global | Signature | Description |
|---|---|---|
| `print` | `print(...)` | Stream text to the frontend terminal |
| `execute` | `execute(cmd) -> string` | Run a shell command; returns stdout+stderr |
| `registerCommand` | `registerCommand(name, fn)` | Register `/name` slash command |
| `registerHook` | `registerHook(event, fn)` | Hook `onMessage` or `onAIResponse` events |
| `setPersona` | `setPersona(name)` | Switch the active LLM persona |

## License

MIT
