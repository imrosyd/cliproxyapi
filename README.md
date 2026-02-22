# CLIProxyAPI

Multiple AI providers through a single OpenAI-compatible API.

## What is CLIProxyAPI?

A local proxy server that lets you access multiple AI providers (Gemini, Claude, GPT, Qwen, etc.) through **one endpoint** (`localhost:8317`).

**Key Features:**
- One endpoint for all AI models
- No API keys needed (uses OAuth tokens from free tiers)
- Works with any OpenAI-compatible client (Droid, Claude Code, Cursor, etc.)
- Auto quota management

---

## Quick Install

### Windows (PowerShell)

```powershell
# One-line install
irm https://cdn.jsdelivr.net/gh/imrosyd/cliproxyapi@main/scripts/install-cliproxyapi.ps1 | iex

# After install, restart terminal then:
cpa-start -Background    # Start server
cpa-oauth -All           # Login to all providers
cpa-gui                  # Open GUI Control Center
```

### Linux / macOS

```bash
# One-line install
curl -fsSL https://cdn.jsdelivr.net/gh/imrosyd/cliproxyapi@main/unix/install-cliproxyapi.sh | bash

# After install, restart terminal then:
cpa-start -b             # Start server
cpa-oauth --all          # Login to all providers
cpa-gui                  # Open GUI Control Center
```

---

## Available Commands

| Command | Description |
|---------|-------------|
| `cpa-start` | Start/stop/restart server |
| `cpa-oauth` | Login to OAuth providers |
| `cpa-gui` | Open GUI Control Center |
| `cpa-update` | Update to latest version |
| `cpa-uninstall` | Remove everything |
| `cpa-benchmark` | Test provider latency |

---

## Supported Providers

| Provider | Models |
|----------|--------|
| **Gemini CLI** | gemini-2.5-pro, gemini-3-pro-preview |
| **Antigravity** | claude-opus-4.5-thinking, claude-sonnet-4.5, gpt-oss-120b |
| **GitHub Copilot** | claude-opus-4.5, gpt-5-mini, grok-code-fast-1 |
| **Codex** | gpt-5.1-codex-max |
| **Claude** | claude-sonnet-4, claude-opus-4 |
| **Qwen** | qwen3-coder-plus |
| **iFlow** | glm-4.6, minimax-m2 |
| **Kiro (AWS)** | kiro-claude-opus-4.5, kiro-claude-sonnet-4.5 |

---

## Usage with CLI Tools

Set your tool to use:
- **Base URL**: `http://localhost:8317/v1`
- **API Key**: `sk-dummy` (any non-empty string)

### Factory Droid
Auto-configured on install. Just run `droid` after starting the proxy.

### Claude Code
```bash
ANTHROPIC_BASE_URL="http://localhost:8317/v1" ANTHROPIC_API_KEY="sk-dummy" claude
```

### Python
```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:8317/v1", api_key="sk-dummy")
response = client.chat.completions.create(
    model="gemini-2.5-pro",
    messages=[{"role": "user", "content": "Hello!"}]
)
```

### curl
```bash
curl http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-dummy" \
  -d '{"model": "gemini-2.5-pro", "messages": [{"role": "user", "content": "Hello!"}]}'
```

---

## Custom AI Providers

Add your own OpenAI-compatible providers (OpenRouter, Ollama, LMStudio, Groq, DeepSeek, etc.):

```powershell
# Windows
add-provider.ps1 -Template openrouter -ApiKey "sk-or-xxx"

# Linux/macOS
./unix/add-provider.sh --template openrouter --api-key "sk-or-xxx"
```

Providers stored in `~/.cliproxyapi/providers.json`.

---

## File Locations

| File | Location |
|------|----------|
| Binary | `~/bin/cliproxyapi` |
| Config | `~/.cliproxyapi/config.yaml` |
| Auth tokens | `~/.cliproxyapi/*.json` |
| Custom providers | `~/.cliproxyapi/providers.json` |

---

## Systemd Auto-Start (Linux)

```bash
cpa-start --enable      # Enable auto-start on boot
cpa-start --disable     # Disable auto-start
systemctl --user status cliproxyapi  # Check status
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Connection refused | Run `cpa-start` first |
| Unauthorized | Use any non-empty API key (e.g., `sk-dummy`) |
| Model not found | Login to provider: `cpa-oauth --gemini` |
| OAuth login fails | Try incognito mode or check network |

---

## Credits

- [CLIProxyAPIPlus](https://github.com/router-for-me/CLIProxyAPIPlus) - Original proxy server
- [CLIProxyAPIPlus-Easy-Installation](https://github.com/julianromli/CLIProxyAPIPlus-Easy-Installation) - Original installation scripts

---

## License

MIT License - See [LICENSE](LICENSE) file.
