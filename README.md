# CLIProxyAPI Easy Installation

> One-click setup scripts for [CLIProxyAPI](https://github.com/imrosyd/cliproxyapi) - Use multiple AI providers through a single OpenAI-compatible API.

[English](README.md) | [Bahasa Indonesia](README_ID.md)

---

## What is CLIProxyAPI?

**CLIProxyAPI** is a local proxy server that lets you access multiple AI providers (Gemini, Claude, GPT, Qwen, etc.) through a **single OpenAI-compatible API endpoint**.

Think of it as a "router" for AI models - you login once to each provider via OAuth, and the proxy handles everything else. Your CLI tools (Droid, Claude Code, Cursor, etc.) just talk to `localhost:8317` like it's OpenAI.

### Why Use This?

- **One endpoint, many models** - Switch between Claude, GPT, Gemini without changing configs
- **No API keys needed** - Uses OAuth tokens from free tiers (Gemini CLI, GitHub Copilot, etc.)
- **Works with any OpenAI-compatible client** - Droid, Claude Code, Cursor, Continue, OpenCode, etc.
- **Auto quota management** - Automatically switches providers when one hits rate limits

---

## Supported Providers

| Provider | Login Command | Models Available |
|----------|---------------|------------------|
| **Gemini CLI** | `--login` | gemini-2.5-pro, gemini-3-pro-preview |
| **Antigravity** | `--antigravity-login` | claude-opus-4.5-thinking, claude-sonnet-4.5, gpt-oss-120b |
| **GitHub Copilot** | `--github-copilot-login` | claude-opus-4.5, gpt-5-mini, grok-code-fast-1 |
| **Codex** | `--codex-login` | gpt-5.1-codex-max |
| **Claude** | `--claude-login` | claude-sonnet-4, claude-opus-4 |
| **Qwen** | `--qwen-login` | qwen3-coder-plus |
| **iFlow** | `--iflow-login` | glm-4.6, minimax-m2 |
| **Kiro (AWS)** | `--kiro-aws-login` | kiro-claude-opus-4.5, kiro-claude-sonnet-4.5 |

---

## How It Works

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   Your CLI      │     │   CLIProxyAPI    │     │   AI Providers  │
│  (Droid, etc.)  │────▶│   localhost:8317     │────▶│  Gemini, Claude │
│                 │     │                      │     │  GPT, Qwen, etc │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
        │                        │
        │  OpenAI API format     │  OAuth tokens
        │  POST /v1/chat/...     │  (stored locally)
        ▼                        ▼
   model: "gemini-2.5-pro"  ──▶  Routes to Gemini
   model: "claude-opus-4.5" ──▶  Routes to Copilot
   model: "gpt-5.1-codex"   ──▶  Routes to Codex
```

1. **You login** to each provider once (OAuth flow opens in browser)
2. **Tokens are stored** locally in `~/.cliproxyapi/*.json`
3. **Proxy server runs** on `localhost:8317`
4. **Your CLI sends requests** to the proxy using OpenAI API format
5. **Proxy routes** requests to the correct provider based on model name

---

## Quick Start

### Windows

#### Prerequisites

- **Git** - [Download](https://git-scm.com/downloads)
- **Go 1.21+** (optional, for building from source) - [Download](https://go.dev/dl/)

#### Option 1: One-Line Install (Recommended)

```powershell
# Download and run the installer (via JSDelivr CDN - faster)
irm https://cdn.jsdelivr.net/gh/imrosyd/cliproxyapi@main/scripts/install-cliproxyapi.ps1 | iex

# Alternative (via GitHub raw)
irm https://raw.githubusercontent.com/imrosyd/cliproxyapi/main/scripts/install-cliproxyapi.ps1 | iex
```

#### Option 2: Manual Install

```powershell
# Clone this repo
git clone https://github.com/imrosyd/cliproxyapi.git
cd cliproxyapi

# Run the installer
.\scripts\install-cliproxyapi.ps1
```

#### After Installation

Scripts are installed to `~/bin/` and added to PATH automatically.

```powershell
# Restart terminal (or refresh PATH)
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User')

# Start server in background
cpa-start -Background

# Login to providers
cpa-oauth -All

# Open GUI Control Center (full control via browser)
cpa-gui
```

### Linux / macOS

#### Prerequisites

- **Git** - `sudo apt install git` (Ubuntu/Debian) or `brew install git` (macOS)
- **Go 1.21+** (optional, for building from source) - `sudo apt install golang-go` or `brew install go`
- **curl** - Usually pre-installed

#### Option 1: One-Line Install (Recommended)

```bash
# Download and run the installer (via JSDelivr CDN - faster)
curl -fsSL https://cdn.jsdelivr.net/gh/imrosyd/cliproxyapi@main/unix/install-cliproxyapi.sh | bash

# Alternative (via GitHub raw)
curl -fsSL https://raw.githubusercontent.com/imrosyd/cliproxyapi/main/unix/install-cliproxyapi.sh | bash
```

#### Option 2: Manual Install

```bash
# Clone this repo
git clone https://github.com/imrosyd/cliproxyapi.git
cd cliproxyapi

# Run the installer
./unix/install-cliproxyapi.sh

# Or with pre-built binary (no Go required)
./unix/install-cliproxyapi.sh --prebuilt
```

#### After Installation

Scripts are installed to `~/bin/` and added to PATH automatically.

```bash
# Restart terminal or reload shell config
source ~/.bashrc  # or ~/.zshrc

# Start server in background
cpa-start -b

# Login to providers
cpa-oauth --all

# Open GUI Control Center (full control via browser)
cpa-gui
```

**Available Scripts:**
- `cpa-start` - Start/stop/restart server + systemd management
- `cpa-oauth` - Login to OAuth providers
- `cpa-gui` - Open GUI Control Center
- `cpa-update` - Update to latest version
- `cpa-uninstall` - Remove everything
- `cpa-benchmark` - Test provider latency

---

## Systemd Service (Auto-Start on Boot)

On Linux systems with systemd, the installer automatically sets up a user service.

```bash
# Enable auto-start on boot
cpa-start --enable

# Disable auto-start
cpa-start --disable

# Check service status
systemctl --user status cliproxyapi

# View service logs
journalctl --user -u cliproxyapi -f
```

The service uses `loginctl enable-linger` so it starts on boot, not just on login.

---

## Latency Benchmark

Test response latency for all available models and find the fastest provider.

```bash
# Run benchmark (server must be running)
cpa-benchmark

# Show only top 5 fastest
cpa-benchmark --top 5

# Output as JSON
cpa-benchmark --json

# Use custom port
cpa-benchmark --port 9000
```

Results are saved to `~/.cliproxyapi/benchmark.json` for reference.

---

## Auto-Update

The installer sets up a **weekly auto-update timer** via systemd that automatically downloads the latest CLIProxyAPI binary from GitHub. If the server is running, it will be restarted with the new binary.

```bash
# Check next scheduled update
systemctl --user list-timers cliproxyapi-update

# View update logs
cat ~/.cliproxyapi/logs/update.log

# Run update manually
cpa-update --prebuilt

# Disable auto-update
systemctl --user disable --now cliproxyapi-update.timer

# Re-enable auto-update
systemctl --user enable --now cliproxyapi-update.timer
```

---

## Usage with Different CLI Tools

### Factory Droid

The install script **automatically configures** Droid by updating `~/.factory/config.json`.

Just start the proxy and select a model in Droid:

```powershell
# Start proxy in background
cpa-start -Background

# Use Droid normally - custom models will appear in model selector
droid
```

Or use the GUI:

```powershell
# Open Control Center, click "Start", then use Droid
cpa-gui
```

### Claude Code

Set environment variables before running:

```powershell
# PowerShell
$env:ANTHROPIC_BASE_URL = "http://localhost:8317/v1"
$env:ANTHROPIC_API_KEY = "sk-dummy"
claude

# Or in one line
$env:ANTHROPIC_BASE_URL="http://localhost:8317/v1"; $env:ANTHROPIC_API_KEY="sk-dummy"; claude
```

For persistent config, add to your PowerShell profile (`$PROFILE`):

```powershell
$env:ANTHROPIC_BASE_URL = "http://localhost:8317/v1"
$env:ANTHROPIC_API_KEY = "sk-dummy"
```

### OpenCode

Create or edit `~/.opencode/config.json`:

```json
{
  "provider": "openai",
  "model": "gemini-2.5-pro",
  "providers": {
    "openai": {
      "apiKey": "sk-dummy",
      "baseUrl": "http://localhost:8317/v1"
    }
  }
}
```

### Cursor

Go to **Settings → Models → OpenAI API**:

- **API Key**: `sk-dummy`
- **Base URL**: `http://localhost:8317/v1`
- **Model**: Choose from available models (e.g., `gemini-2.5-pro`)

### Continue (VS Code Extension)

Edit `~/.continue/config.json`:

```json
{
  "models": [
    {
      "title": "CLIProxy - Gemini",
      "provider": "openai",
      "model": "gemini-2.5-pro",
      "apiKey": "sk-dummy",
      "apiBase": "http://localhost:8317/v1"
    },
    {
      "title": "CLIProxy - Claude",
      "provider": "openai", 
      "model": "claude-opus-4.5",
      "apiKey": "sk-dummy",
      "apiBase": "http://localhost:8317/v1"
    }
  ]
}
```

### Generic OpenAI Client (Python)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8317/v1",
    api_key="sk-dummy"  # Any string works
)

response = client.chat.completions.create(
    model="gemini-2.5-pro",  # Or any supported model
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
```

### Generic OpenAI Client (curl)

```bash
curl http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-dummy" \
  -d '{
    "model": "gemini-2.5-pro",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## Available Models

### Antigravity Provider
| Model ID | Description |
|----------|-------------|
| `gemini-claude-opus-4-5-thinking` | Claude Opus 4.5 with extended thinking |
| `gemini-claude-sonnet-4-5-thinking` | Claude Sonnet 4.5 with extended thinking |
| `gemini-claude-sonnet-4-5` | Claude Sonnet 4.5 |
| `gemini-3-pro-preview` | Gemini 3 Pro Preview |
| `gpt-oss-120b-medium` | GPT OSS 120B |

### GitHub Copilot Provider
| Model ID | Description |
|----------|-------------|
| `claude-opus-4.5` | Claude Opus 4.5 |
| `gpt-5-mini` | GPT-5 Mini |
| `grok-code-fast-1` | Grok Code Fast |

### Gemini CLI Provider
| Model ID | Description |
|----------|-------------|
| `gemini-2.5-pro` | Gemini 2.5 Pro |
| `gemini-3-pro-preview` | Gemini 3 Pro Preview |

### Codex Provider
| Model ID | Description |
|----------|-------------|
| `gpt-5.1-codex-max` | GPT-5.1 Codex Max |

### Qwen Provider
| Model ID | Description |
|----------|-------------|
| `qwen3-coder-plus` | Qwen3 Coder Plus |

### iFlow Provider
| Model ID | Description |
|----------|-------------|
| `glm-4.6` | GLM 4.6 |
| `minimax-m2` | Minimax M2 |

### Kiro (AWS) Provider
| Model ID | Description |
|----------|-------------|
| `kiro-claude-opus-4.5` | Claude Opus 4.5 via Kiro |
| `kiro-claude-sonnet-4.5` | Claude Sonnet 4.5 via Kiro |
| `kiro-claude-sonnet-4` | Claude Sonnet 4 via Kiro |
| `kiro-claude-haiku-4.5` | Claude Haiku 4.5 via Kiro |

---

## Scripts Reference

### Windows Scripts (`scripts/*.ps1`)

### `cpa-start` (Windows)

Server manager - start, stop, and monitor.

```powershell
# Start server (foreground)
cpa-start

# Start in background
cpa-start -Background

# Check status
cpa-start -Status

# Stop server
cpa-start -Stop

# Restart
cpa-start -Restart

# View logs
cpa-start -Logs
```

### `install-cliproxyapi.ps1`

Full installation script.

```powershell
# Default: Build from source
.\install-cliproxyapi.ps1

# Use pre-built binary (no Go required)
.\install-cliproxyapi.ps1 -UsePrebuilt

# Force reinstall (overwrites existing)
.\install-cliproxyapi.ps1 -Force

# Skip OAuth instructions
.\install-cliproxyapi.ps1 -SkipOAuth
```

### `cpa-update` (Windows)

Update to latest version.

```powershell
# Update from source (if cloned)
cpa-update

# Update using pre-built binary
cpa-update -UsePrebuilt

# Force update even if up-to-date
cpa-update -Force
```

### `cpa-oauth` (Windows)

Interactive OAuth login helper.

```powershell
# Interactive menu
cpa-oauth

# Login to all providers
cpa-oauth -All

# Login to specific providers
cpa-oauth -Gemini -Copilot -Kiro
```

### `cpa-uninstall` (Windows)

Clean uninstallation.

```powershell
# Uninstall (keeps auth files)
cpa-uninstall

# Remove everything including auth
cpa-uninstall -All

# Force without confirmation
cpa-uninstall -All -Force
```

### `cpa-gui` (Windows)

GUI Control Center with full server management.

```powershell
# Open GUI (starts management server on port 8318)
cpa-gui

# Use custom port
cpa-gui -Port 9000

# Don't auto-open browser
cpa-gui -NoBrowser
```

**Features:**
- Real-time server status monitoring
- Start/Stop/Restart buttons (actually work!)
- OAuth login buttons for all providers
- **Request Statistics** - Total requests, success rate, avg latency, errors
- **Auto-Updater** - Click version badge to check for updates
- Provider auth status indicators (green = connected)
- Available models list (when server is running)
- Configuration editor (edit config.yaml directly)
- Copy endpoint button for quick setup
- Auto-start option (remembers your preference)
- Activity log viewer
- Keyboard shortcuts: `R` to refresh, `Esc` to close modals

The GUI runs a local management server on `localhost:8318` that handles all control commands.

### Linux / macOS Scripts (`unix/*.sh`)

### `cpa-start`

Server manager - start, stop, and monitor.

```bash
# Start server (foreground)
cpa-start

# Start in background
cpa-start -b

# Check status
cpa-start --status

# Stop server
cpa-start --stop

# Restart
cpa-start --restart

# View logs
cpa-start --logs

# Enable systemd auto-start
cpa-start --enable

# Disable systemd auto-start
cpa-start --disable
```

### `install-cliproxyapi.sh`

Full installation script.

```bash
# Default: Build from source
./install-cliproxyapi.sh

# Use pre-built binary (no Go required)
./install-cliproxyapi.sh --prebuilt

# Force reinstall (overwrites existing)
./install-cliproxyapi.sh --force

# Skip OAuth instructions
./install-cliproxyapi.sh --skip-oauth
```

### `cpa-update`

Update to latest version.

```bash
# Update from source (if cloned)
cpa-update

# Update using pre-built binary
cpa-update --prebuilt

# Force update even if up-to-date
cpa-update --force
```

### `cpa-oauth`

Interactive OAuth login helper.

```bash
# Interactive menu
cpa-oauth

# Login to all providers
cpa-oauth --all

# Login to specific providers
cpa-oauth --gemini --copilot --kiro
```

### `cpa-uninstall`

Clean uninstallation.

```bash
# Uninstall (keeps auth files)
cpa-uninstall

# Remove everything including auth
cpa-uninstall --all

# Force without confirmation
cpa-uninstall --all --force
```

### `cpa-gui`

GUI Control Center with full server management.

```bash
# Open GUI (starts management server on port 8318)
cpa-gui

# Use custom port
cpa-gui --port 9000

# Don't auto-open browser
cpa-gui --no-browser
```

### `cpa-benchmark`

Latency benchmark for all available models.

```bash
# Benchmark all models
cpa-benchmark

# Show top 5 fastest
cpa-benchmark --top 5

# JSON output
cpa-benchmark --json
```

---

## File Locations

### Windows

| File | Location | Description |
|------|----------|-------------|
| Binary | `~/bin/cliproxyapi.exe` | The proxy server executable |
| Config | `~/.cliproxyapi/config.yaml` | Proxy configuration |
| Auth tokens | `~/.cliproxyapi/*.json` | OAuth tokens for each provider |
| Droid config | `~/.factory/config.json` | Custom models for Factory Droid |
| Source | `~/CLIProxyAPI-source/` | Cloned source (if built from source) |

### Linux / macOS

| File | Location | Description |
|------|----------|-------------|
| Binary | `~/bin/cliproxyapi` | The proxy server executable |
| Config | `~/.cliproxyapi/config.yaml` | Proxy configuration |
| Auth tokens | `~/.cliproxyapi/*.json` | OAuth tokens for each provider |
| Systemd | `~/.config/systemd/user/cliproxyapi.service` | Auto-start service |
| Benchmark | `~/.cliproxyapi/benchmark.json` | Latest benchmark results |
| Source | `~/CLIProxyAPI-source/` | Cloned source (if built from source) |

---

## Custom AI Providers (AI SDK)

CLIProxyAPI supports custom AI providers compatible with **Vercel AI SDK** format. Add your own providers like OpenRouter, Ollama, LMStudio, Together AI, Groq, or any OpenAI-compatible API.

### Quick Start

#### Windows (PowerShell)

```powershell
# Interactive mode
add-provider.ps1

# Use template
add-provider.ps1 -Template openrouter -ApiKey "sk-or-xxx"

# List providers
list-providers.ps1

# Test connection
test-provider.ps1 openrouter
```

#### Linux / macOS (Bash)

```bash
# Interactive mode
./unix/add-provider.sh -i

# Use template
./unix/add-provider.sh --template openrouter --api-key "sk-or-xxx"

# List providers
./unix/list-providers.sh

# Test connection
./unix/test-provider.sh openrouter
```

### Provider Configuration File

Providers are stored in `~/.cliproxyapi/providers.json`:

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
          "limit": {
            "context": 64000,
            "output": 4096
          },
          "modalities": {
            "input": ["text"],
            "output": ["text"]
          }
        },
        "deepseek-reasoner": {
          "name": "DeepSeek Reasoner",
          "reasoning": true,
          "limit": {
            "context": 64000,
            "output": 8192
          },
          "modalities": {
            "input": ["text"],
            "output": ["text"]
          }
        }
      }
    }
  }
}
```

### Pre-defined Templates

| Template | Base URL | Description |
|----------|----------|-------------|
| `openrouter` | `https://openrouter.ai/api/v1` | 100+ models from various providers |
| `ollama` | `http://localhost:11434/v1` | Local LLM (no API key needed) |
| `lmstudio` | `http://localhost:1234/v1` | Local LLM (no API key needed) |
| `together` | `https://api.together.xyz/v1` | Together AI cloud API |
| `groq` | `https://api.groq.com/openai/v1` | Groq fast inference |
| `deepseek` | `https://api.deepseek.com/v1` | DeepSeek API |

### Model Configuration Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name for the model |
| `reasoning` | boolean | Whether model supports thinking/reasoning |
| `limit.context` | number | Context window size in tokens |
| `limit.output` | number | Maximum output tokens |
| `modalities.input` | array | Input types: `text`, `image`, `pdf`, `audio`, `video` |
| `modalities.output` | array | Output types: `text`, `image`, `audio` |
| `variants` | object | Model variants with reasoning/verbosity settings |

### Using with CLIProxyAPI

After adding custom providers, they work automatically with CLIProxyAPI:

```bash
# Start the server
cpa-start -b

# Use custom model
curl http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-dummy" \
  -d '{"model": "deepseek-chat", "messages": [{"role": "user", "content": "Hello!"}]}'
```

### GUI Management

Open the Control Center to manage providers visually:

```bash
cpa-gui
```

Navigate to the **Custom** tab to:
- Add/edit/delete providers
- Test connections
- Import/export configurations
- Use pre-defined templates

### Export / Import

```powershell
# Windows
export-providers.ps1 -o providers.json
export-providers.ps1 --format yaml -o providers.yaml
```

```bash
# Linux/macOS
./unix/export-providers.sh -o providers.json
./unix/export-providers.sh --format yaml -o providers.yaml
```

---

## Troubleshooting

### "Connection refused" when using CLI

Make sure the proxy server is running:

```powershell
# Windows
cliproxyapi --config ~/.cliproxyapi/config.yaml
```

```bash
# Linux/macOS
cliproxyapi --config ~/.cliproxyapi/config.yaml
```

### "Unauthorized" or "Invalid API key"

The proxy accepts any API key. Make sure you're using `sk-dummy` or any non-empty string.

### OAuth login fails

1. Make sure you have a browser installed
2. Try with `--incognito` flag for fresh session
3. Check if the provider's website is accessible

### Model not found

1. Make sure you've logged into the provider that offers that model
2. Check the model name spelling (case-sensitive)
3. Run `cpa-oauth` to see which providers you're logged into

### Quota exceeded

The proxy auto-switches to another provider/model when quota is hit. If all providers are exhausted, wait for quota reset (usually 1-24 hours depending on provider).

---

## Credits

- [CLIProxyAPIPlus](https://github.com/router-for-me/CLIProxyAPIPlus) - The original proxy server
- [CLIProxyAPIPlus-Easy-Installation](https://github.com/julianromli/CLIProxyAPIPlus-Easy-Installation) - Original easy installation scripts
- Community contributors for GitHub Copilot and Kiro OAuth implementations

---

## License

MIT License - See [LICENSE](LICENSE) file.

---

## Contributing

PRs welcome! Feel free to:
- Add support for more CLI tools
- Improve documentation
- Report bugs
- Suggest new features

---

**Happy coding!** 🚀
