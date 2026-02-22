# CLIProxyAPI

Multiple AI providers through a single OpenAI-compatible API endpoint.

## What is CLIProxyAPI?

A local proxy server that provides access to multiple AI providers (Gemini, Claude, GPT, Qwen, etc.) through **one endpoint** (`localhost:8317`).

**Key Features:**
- One endpoint for all AI models
- No API keys needed (uses OAuth tokens from free tiers)
- Compatible with any OpenAI client (Droid, Claude Code, Cursor, etc.)
- Auto switch provider when quota exceeded
- GUI Control Center for easy management

---

## Quick Install

### Windows (PowerShell)

```powershell
irm https://cdn.jsdelivr.net/gh/imrosyd/cliproxyapi@main/scripts/install-cliproxyapi.ps1 | iex
```

### Linux / macOS

```bash
curl -fsSL https://cdn.jsdelivr.net/gh/imrosyd/cliproxyapi@main/unix/install-cliproxyapi.sh | bash
```

---

## After Install

Restart terminal, then:

```bash
# 1. Start server
cpa-start -b              # Windows: -Background, Linux: -b

# 2. Login to provider (at least 1)
cpa-oauth --gemini        # Login to Gemini CLI
cpa-oauth --all           # Login to all providers

# 3. Open GUI (optional)
cpa-gui
```

---

## Available Commands

| Command | Description |
|---------|-------------|
| `cpa-start` | Start/stop/restart server |
| `cpa-oauth` | Login to OAuth providers |
| `cpa-gui` | Open GUI Control Center |
| `cpa-update` | Update to latest version |
| `cpa-uninstall` | Remove installation |
| `cpa-benchmark` | Test provider latency |

---

## Supported Providers

| Provider | Login Command | Models |
|----------|---------------|--------|
| **Gemini CLI** | `cpa-oauth --gemini` | gemini-2.5-pro, gemini-3-pro-preview |
| **Antigravity** | `cpa-oauth --antigravity` | claude-opus-4.5-thinking, claude-sonnet-4.5, gpt-oss-120b |
| **GitHub Copilot** | `cpa-oauth --github` | claude-opus-4.5, gpt-5-mini, grok-code-fast-1 |
| **Codex** | `cpa-oauth --codex` | gpt-5.1-codex-max |
| **Claude** | `cpa-oauth --claude` | claude-sonnet-4, claude-opus-4 |
| **Qwen** | `cpa-oauth --qwen` | qwen3-coder-plus |
| **iFlow** | `cpa-oauth --iflow` | glm-4.6, minimax-m2 |
| **Kiro (AWS)** | `cpa-oauth --kiro` | kiro-claude-opus-4.5, kiro-claude-sonnet-4.5 |

---

## CLI Tools Configuration

All CLI tools use the same settings:
- **Base URL**: `http://localhost:8317/v1`
- **API Key**: `sk-dummy` (or any non-empty string)

### Factory Droid

Create or edit `~/.factory/config.json`:

```json
{
  "custom_models": [
    {
      "model": "gemini-2.5-pro",
      "model_display_name": "Gemini 2.5 Pro",
      "base_url": "http://localhost:8317",
      "api_key": "sk-dummy",
      "provider": "anthropic"
    },
    {
      "model": "claude-opus-4.5",
      "model_display_name": "Claude Opus 4.5",
      "base_url": "http://localhost:8317",
      "api_key": "sk-dummy",
      "provider": "anthropic"
    }
  ]
}
```

**Field Explanation:**

| Field | Value | Description |
|-------|-------|-------------|
| `model` | `"gemini-2.5-pro"` | Model ID from Supported Providers table |
| `model_display_name` | `"Gemini 2.5 Pro"` | Display name shown in Droid model selector |
| `base_url` | `"http://localhost:8317"` | CLIProxyAPI endpoint (without `/v1`) |
| `api_key` | `"sk-dummy"` | Any non-empty string (ignored by proxy) |
| `provider` | `"anthropic"` | Use `anthropic` for all models |

Then run:
```bash
cpa-start -b && droid
```

**Source:** [Factory BYOK Documentation](https://docs.factory.ai/cli/byok/overview)

### OpenCode

Create or edit `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "cliproxy": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "CLIProxyAPI",
      "options": {
        "baseURL": "http://localhost:8317/v1",
        "apiKey": "sk-dummy"
      }
    }
  }
}
```

**Field Explanation:**

| Field | Value | Description |
|-------|-------|-------------|
| `npm` | `"@ai-sdk/openai-compatible"` | Required for OpenAI-compatible APIs |
| `name` | `"CLIProxyAPI"` | Display name in OpenCode |
| `options.baseURL` | `"http://localhost:8317/v1"` | CLIProxyAPI endpoint (with `/v1`) |
| `options.apiKey` | `"sk-dummy"` | Any non-empty string |

Then run:
```bash
cpa-start -b && opencode
```

**Set default model:**
```bash
opencode config set model cliproxy/gemini-2.5-pro
```

**Source:** [OpenCode Providers Documentation](https://opencode.ai/docs/providers/)

### Claude Code

```bash
ANTHROPIC_BASE_URL="http://localhost:8317/v1" ANTHROPIC_API_KEY="sk-dummy" claude
```

For permanent config, add to `~/.bashrc` or `~/.zshrc`:
```bash
export ANTHROPIC_BASE_URL="http://localhost:8317/v1"
export ANTHROPIC_API_KEY="sk-dummy"
```

Or create `~/.claude/settings.json`:
```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:8317/v1",
    "ANTHROPIC_API_KEY": "sk-dummy"
  }
}
```

### Kilo CLI

Create or edit `~/.config/kilo/opencode.json`:

```json
{
  "$schema": "https://app.kilo.ai/config.json",
  "provider": {
    "cliproxy": {
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "http://localhost:8317/v1",
        "apiKey": "sk-dummy"
      }
    }
  }
}
```

**Field Explanation:**

| Field | Value | Description |
|-------|-------|-------------|
| `npm` | `"@ai-sdk/openai-compatible"` | Required for OpenAI-compatible APIs |
| `options.baseURL` | `"http://localhost:8317/v1"` | CLIProxyAPI endpoint (with `/v1`) |
| `options.apiKey` | `"sk-dummy"` | Any non-empty string |

Then run:
```bash
cpa-start -b && kilo
```

**Set default model:**
```bash
kilo
# Then use: /models
# Select cliproxy provider and model
```

**Source:** [Kilo CLI Documentation](https://kilo.ai/docs/code-with-ai/platforms/cli)

### Cursor

Go to **Settings → Models → OpenAI API**:
- **API Key**: `sk-dummy`
- **Base URL**: `http://localhost:8317/v1`

### Python

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8317/v1",
    api_key="sk-dummy"
)

response = client.chat.completions.create(
    model="gemini-2.5-pro",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
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

### Via Script

```bash
# Windows
add-provider.ps1 -Template openrouter -ApiKey "sk-or-xxx"

# Linux/macOS
./unix/add-provider.sh --template openrouter --api-key "sk-or-xxx"
```

### Via Config File

Create `~/.cliproxyapi/providers.json`:

```json
{
  "$schema": "https://cliproxyapi.dev/schema/providers.json",
  "providers": {
    "deepseek": {
      "npm": null,
      "options": {
        "baseURL": "https://api.deepseek.com/v1",
        "apiKey": "sk-xxx"
      },
      "models": {
        "deepseek-chat": {
          "name": "DeepSeek Chat",
          "reasoning": false,
          "limit": { "context": 64000, "output": 4096 },
          "modalities": { "input": ["text"], "output": ["text"] }
        }
      }
    }
  }
}
```

### Available Templates

| Template | Base URL |
|----------|----------|
| `openrouter` | `https://openrouter.ai/api/v1` |
| `ollama` | `http://localhost:11434/v1` |
| `lmstudio` | `http://localhost:1234/v1` |
| `groq` | `https://api.groq.com/openai/v1` |
| `deepseek` | `https://api.deepseek.com/v1` |
| `together` | `https://api.together.xyz/v1` |

---

## File Locations

| File | Location |
|------|----------|
| Binary | `~/bin/cliproxyapi` |
| Config | `~/.cliproxyapi/config.yaml` |
| Auth tokens | `~/.cliproxyapi/*.json` |
| Custom providers | `~/.cliproxyapi/providers.json` |
| Logs | `~/.cliproxyapi/logs/` |

---

## Systemd Auto-Start (Linux)

```bash
cpa-start --enable              # Enable auto-start on boot
cpa-start --disable             # Disable auto-start
systemctl --user status cliproxyapi   # Check status
journalctl --user -u cliproxyapi -f    # View logs
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Connection refused | Run `cpa-start` first |
| Unauthorized / Invalid API key | Use any non-empty API key, e.g., `sk-dummy` |
| Model not found | Login to provider: `cpa-oauth --gemini` |
| OAuth login fails | Try incognito mode or check internet connection |
| Quota exceeded | Proxy auto-switches to another provider |

---

## Credits

- [CLIProxyAPIPlus](https://github.com/router-for-me/CLIProxyAPIPlus) - Original proxy server
- [CLIProxyAPIPlus-Easy-Installation](https://github.com/julianromli/CLIProxyAPIPlus-Easy-Installation) - Original installation scripts

---

## License

MIT License - See [LICENSE](LICENSE) file.
