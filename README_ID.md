# CLIProxyAPI Easy Installation

> Script instalasi satu-klik untuk [CLIProxyAPI](https://github.com/imrosyd/cliproxyapi) - Akses berbagai provider AI melalui satu endpoint API yang kompatibel dengan OpenAI.

[English](README.md) | Bahasa Indonesia

---

## Apa itu CLIProxyAPI?

**CLIProxyAPI** adalah server proxy lokal yang memungkinkan Anda mengakses berbagai provider AI (Gemini, Claude, GPT, Qwen, dll.) melalui **satu endpoint API yang kompatibel dengan OpenAI**.

Bayangkan seperti "router" untuk model AI - Anda login sekali ke setiap provider via OAuth, dan proxy menangani sisanya. CLI tools Anda (Droid, Claude Code, Cursor, dll.) cukup berkomunikasi dengan `localhost:8317` seperti OpenAI.

### Mengapa Menggunakan Ini?

- **Satu endpoint, banyak model** - Pindah antara Claude, GPT, Gemini tanpa mengubah konfigurasi
- **Tanpa API key** - Menggunakan token OAuth dari tier gratis (Gemini CLI, GitHub Copilot, dll.)
- **Kompatibel dengan klien OpenAI** - Droid, Claude Code, Cursor, Continue, OpenCode, dll.
- **Manajemen kuota otomatis** - Otomatis berpindah provider saat satu mencapai batas rate limit

---

## Provider yang Didukung

| Provider | Perintah Login | Model Tersedia |
|----------|----------------|----------------|
| **Gemini CLI** | `--login` | gemini-2.5-pro, gemini-3-pro-preview |
| **Antigravity** | `--antigravity-login` | claude-opus-4.5-thinking, claude-sonnet-4.5, gpt-oss-120b |
| **GitHub Copilot** | `--github-copilot-login` | claude-opus-4.5, gpt-5-mini, grok-code-fast-1 |
| **Codex** | `--codex-login` | gpt-5.1-codex-max |
| **Claude** | `--claude-login` | claude-sonnet-4, claude-opus-4 |
| **Qwen** | `--qwen-login` | qwen3-coder-plus |
| **iFlow** | `--iflow-login` | glm-4.6, minimax-m2 |
| **Kiro (AWS)** | `--kiro-aws-login` | kiro-claude-opus-4.5, kiro-claude-sonnet-4.5 |

---

## Quick Start

### Windows

#### Prasyarat

- **Git** - [Download](https://git-scm.com/downloads)
- **Go 1.21+** (opsional, untuk build dari source) - [Download](https://go.dev/dl/)

#### Opsi 1: Instalasi Satu Baris (Rekomendasi)

```powershell
# Download dan jalankan installer (via JSDelivr CDN - lebih cepat)
irm https://cdn.jsdelivr.net/gh/imrosyd/cliproxyapi@main/scripts/install-cliproxyapi.ps1 | iex

# Alternatif (via GitHub raw)
irm https://raw.githubusercontent.com/imrosyd/cliproxyapi/main/scripts/install-cliproxyapi.ps1 | iex
```

#### Opsi 2: Instalasi Manual

```powershell
# Clone repo ini
git clone https://github.com/imrosyd/cliproxyapi.git
cd cliproxyapi

# Jalankan installer
.\scripts\install-cliproxyapi.ps1
```

#### Setelah Instalasi

Script terinstal di `~/bin/` dan otomatis ditambahkan ke PATH.

```powershell
# Restart terminal (atau refresh PATH)
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User')

# Jalankan server di background
cpa-start -Background

# Login ke providers
cpa-oauth -All

# Buka GUI Control Center (kontrol penuh via browser)
cpa-gui
```

### Linux / macOS

#### Prasyarat

- **Git** - `sudo apt install git` (Ubuntu/Debian) atau `brew install git` (macOS)
- **Go 1.21+** (opsional, untuk build dari source) - `sudo apt install golang-go` atau `brew install go`
- **curl** - Biasanya sudah terinstal

#### Opsi 1: Instalasi Satu Baris (Rekomendasi)

```bash
# Download dan jalankan installer (via JSDelivr CDN - lebih cepat)
curl -fsSL https://cdn.jsdelivr.net/gh/imrosyd/cliproxyapi@main/unix/install-cliproxyapi.sh | bash

# Alternatif (via GitHub raw)
curl -fsSL https://raw.githubusercontent.com/imrosyd/cliproxyapi/main/unix/install-cliproxyapi.sh | bash
```

#### Opsi 2: Instalasi Manual

```bash
# Clone repo ini
git clone https://github.com/imrosyd/cliproxyapi.git
cd cliproxyapi

# Jalankan installer
./unix/install-cliproxyapi.sh

# Atau dengan pre-built binary (tanpa Go)
./unix/install-cliproxyapi.sh --prebuilt
```

#### Setelah Instalasi

Script terinstal di `~/bin/` dan otomatis ditambahkan ke PATH.

```bash
# Restart terminal atau reload shell config
source ~/.bashrc  # atau ~/.zshrc

# Jalankan server di background
cpa-start -b

# Login ke providers
cpa-oauth --all

# Buka GUI Control Center (kontrol penuh via browser)
cpa-gui
```

**Script yang Tersedia:**
- `cpa-start` - Start/stop/restart server + manajemen systemd
- `cpa-oauth` - Login ke provider OAuth
- `cpa-gui` - Buka GUI Control Center
- `cpa-update` - Update ke versi terbaru
- `cpa-uninstall` - Hapus instalasi
- `cpa-benchmark` - Test latency provider

---

## Custom AI Providers (AI SDK)

CLIProxyAPI mendukung custom AI providers yang kompatibel dengan format **Vercel AI SDK**. Tambahkan provider sendiri seperti OpenRouter, Ollama, LMStudio, Together AI, Groq, atau API yang kompatibel dengan OpenAI.

### Quick Start

#### Windows (PowerShell)

```powershell
# Mode interaktif
add-provider.ps1

# Gunakan template
add-provider.ps1 -Template openrouter -ApiKey "sk-or-xxx"

# List providers
list-providers.ps1

# Test koneksi
test-provider.ps1 openrouter
```

#### Linux / macOS (Bash)

```bash
# Mode interaktif
./unix/add-provider.sh -i

# Gunakan template
./unix/add-provider.sh --template openrouter --api-key "sk-or-xxx"

# List providers
./unix/list-providers.sh

# Test koneksi
./unix/test-provider.sh openrouter
```

### File Konfigurasi Provider

Provider disimpan di `~/.cliproxyapi/providers.json`:

```json
{
  "$schema": "https://cliproxyapi.dev/schema/providers.json",
  "providers": {
    "cliproxy": {
      "npm": "@ai-sdk/anthropic",
      "options": {
        "baseURL": "https://codex.zumy.dev/v1",
        "apiKey": "kodek"
      },
      "models": {
        "gpt-5.3-codex": {
          "name": "GPT 5.3 Codex",
          "reasoning": true,
          "limit": {
            "context": 400000,
            "output": 128000
          },
          "modalities": {
            "input": ["text", "image", "pdf"],
            "output": ["text"]
          },
          "variants": {
            "none": { "reasoningEffort": "none", "textVerbosity": "none" },
            "low": { "reasoningEffort": "low", "textVerbosity": "low" },
            "medium": { "reasoningEffort": "medium", "textVerbosity": "medium" },
            "high": { "reasoningEffort": "high", "textVerbosity": "high" },
            "max": { "reasoningEffort": "xhigh", "textVerbosity": "xhigh" }
          }
        }
      }
    }
  }
}
```

### Template yang Tersedia

| Template | Base URL | Deskripsi |
|----------|----------|-----------|
| `openrouter` | `https://openrouter.ai/api/v1` | 100+ model dari berbagai provider |
| `ollama` | `http://localhost:11434/v1` | LLM lokal (tanpa API key) |
| `lmstudio` | `http://localhost:1234/v1` | LLM lokal (tanpa API key) |
| `together` | `https://api.together.xyz/v1` | Together AI cloud API |
| `groq` | `https://api.groq.com/openai/v1` | Groq fast inference |
| `codex` | `https://codex.zumy.dev/v1` | Codex by Zumy |

### Field Konfigurasi Model

| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `name` | string | Nama tampilan model |
| `reasoning` | boolean | Apakah model mendukung thinking/reasoning |
| `limit.context` | number | Ukuran context window dalam tokens |
| `limit.output` | number | Maksimum output tokens |
| `modalities.input` | array | Tipe input: `text`, `image`, `pdf`, `audio`, `video` |
| `modalities.output` | array | Tipe output: `text`, `image`, `audio` |
| `variants` | object | Variasi model dengan pengaturan reasoning/verbosity |

### Menggunakan dengan CLIProxyAPI

Setelah menambahkan custom providers, mereka otomatis bekerja dengan CLIProxyAPI:

```bash
# Jalankan server
cpa-start -b

# Gunakan custom model
curl http://localhost:8317/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-dummy" \
  -d '{"model": "gpt-5.3-codex", "messages": [{"role": "user", "content": "Halo!"}]}'
```

### Manajemen via GUI

Buka Control Center untuk mengelola provider secara visual:

```bash
cpa-gui
```

Navigasi ke tab **Custom** untuk:
- Tambah/edit/hapus provider
- Test koneksi
- Import/export konfigurasi
- Gunakan template yang tersedia

---

## Systemd Service (Auto-Start saat Boot)

Pada sistem Linux dengan systemd, installer otomatis menyiapkan user service.

```bash
# Aktifkan auto-start saat boot
cpa-start --enable

# Nonaktifkan auto-start
cpa-start --disable

# Cek status service
systemctl --user status cliproxyapi

# Lihat log service
journalctl --user -u cliproxyapi -f
```

Service menggunakan `loginctl enable-linger` sehingga berjalan saat boot, bukan hanya saat login.

---

## Latency Benchmark

Test response latency untuk semua model yang tersedia dan temukan provider ter tercepat.

```bash
# Jalankan benchmark (server harus berjalan)
cpa-benchmark

# Tampilkan 5 tercepat
cpa-benchmark --top 5

# Output sebagai JSON
cpa-benchmark --json

# Gunakan port custom
cpa-benchmark --port 9000
```

Hasil disimpan ke `~/.cliproxyapi/benchmark.json` untuk referensi.

---

## Auto-Update

Installer menyiapkan **timer auto-update mingguan** via systemd yang otomatis mendownload binary CLIProxyAPI terbaru dari GitHub. Jika server sedang berjalan, akan direstart dengan binary baru.

```bash
# Cek update terjadwal berikutnya
systemctl --user list-timers cliproxyapi-update

# Lihat log update
cat ~/.cliproxyapi/logs/update.log

# Jalankan update manual
cpa-update --prebuilt

# Nonaktifkan auto-update
systemctl --user disable --now cliproxyapi-update.timer

# Aktifkan kembali auto-update
systemctl --user enable --now cliproxyapi-update.timer
```

---

## Penggunaan dengan Berbagai CLI Tools

### Factory Droid

Installer **otomatis mengkonfigurasi** Droid dengan memperbarui `~/.factory/config.json`.

Cukup jalankan proxy dan pilih model di Droid:

```powershell
# Jalankan proxy di background
cpa-start -Background

# Gunakan Droid normal - custom model akan muncul di model selector
droid
```

Atau gunakan GUI:

```powershell
# Buka Control Center, klik "Start", lalu gunakan Droid
cpa-gui
```

### Claude Code

Set environment variables sebelum menjalankan:

```powershell
# PowerShell
$env:ANTHROPIC_BASE_URL = "http://localhost:8317/v1"
$env:ANTHROPIC_API_KEY = "sk-dummy"
claude

# Atau dalam satu baris
$env:ANTHROPIC_BASE_URL="http://localhost:8317/v1"; $env:ANTHROPIC_API_KEY="sk-dummy"; claude
```

Untuk konfigurasi permanen, tambahkan ke PowerShell profile (`$PROFILE`):

```powershell
$env:ANTHROPIC_BASE_URL = "http://localhost:8317/v1"
$env:ANTHROPIC_API_KEY = "sk-dummy"
```

### OpenCode

Buat atau edit `~/.opencode/config.json`:

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

Buka **Settings → Models → OpenAI API**:

- **API Key**: `sk-dummy`
- **Base URL**: `http://localhost:8317/v1`
- **Model**: Pilih dari model yang tersedia (misal., `gemini-2.5-pro`)

### Generic OpenAI Client (Python)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8317/v1",
    api_key="sk-dummy"  # String apapun bisa
)

response = client.chat.completions.create(
    model="gemini-2.5-pro",  # Atau model lain yang didukung
    messages=[{"role": "user", "content": "Halo!"}]
)
print(response.choices[0].message.content)
```

---

## Model yang Tersedia

### Antigravity Provider
| Model ID | Deskripsi |
|----------|-----------|
| `gemini-claude-opus-4-5-thinking` | Claude Opus 4.5 dengan extended thinking |
| `gemini-claude-sonnet-4-5-thinking` | Claude Sonnet 4.5 dengan extended thinking |
| `gemini-claude-sonnet-4-5` | Claude Sonnet 4.5 |
| `gemini-3-pro-preview` | Gemini 3 Pro Preview |
| `gpt-oss-120b-medium` | GPT OSS 120B |

### GitHub Copilot Provider
| Model ID | Deskripsi |
|----------|-----------|
| `claude-opus-4.5` | Claude Opus 4.5 |
| `gpt-5-mini` | GPT-5 Mini |
| `grok-code-fast-1` | Grok Code Fast |

### Gemini CLI Provider
| Model ID | Deskripsi |
|----------|-----------|
| `gemini-2.5-pro` | Gemini 2.5 Pro |
| `gemini-3-pro-preview` | Gemini 3 Pro Preview |

### Codex Provider
| Model ID | Deskripsi |
|----------|-----------|
| `gpt-5.1-codex-max` | GPT-5.1 Codex Max |

### Qwen Provider
| Model ID | Deskripsi |
|----------|-----------|
| `qwen3-coder-plus` | Qwen3 Coder Plus |

### iFlow Provider
| Model ID | Deskripsi |
|----------|-----------|
| `glm-4.6` | GLM 4.6 |
| `minimax-m2` | Minimax M2 |

### Kiro (AWS) Provider
| Model ID | Deskripsi |
|----------|-----------|
| `kiro-claude-opus-4.5` | Claude Opus 4.5 via Kiro |
| `kiro-claude-sonnet-4.5` | Claude Sonnet 4.5 via Kiro |
| `kiro-claude-sonnet-4` | Claude Sonnet 4 via Kiro |
| `kiro-claude-haiku-4.5` | Claude Haiku 4.5 via Kiro |

---

## Lokasi File

### Windows

| File | Lokasi | Deskripsi |
|------|--------|-----------|
| Binary | `~/bin/cliproxyapi.exe` | Executable proxy server |
| Config | `~/.cliproxyapi/config.yaml` | Konfigurasi proxy |
| Auth tokens | `~/.cliproxyapi/*.json` | Token OAuth untuk setiap provider |
| Providers | `~/.cliproxyapi/providers.json` | Custom AI providers |
| Droid config | `~/.factory/config.json` | Custom models untuk Factory Droid |
| Source | `~/CLIProxyAPI-source/` | Source yang di-clone (jika build dari source) |

### Linux / macOS

| File | Lokasi | Deskripsi |
|------|--------|-----------|
| Binary | `~/bin/cliproxyapi` | Executable proxy server |
| Config | `~/.cliproxyapi/config.yaml` | Konfigurasi proxy |
| Auth tokens | `~/.cliproxyapi/*.json` | Token OAuth untuk setiap provider |
| Providers | `~/.cliproxyapi/providers.json` | Custom AI providers |
| Systemd | `~/.config/systemd/user/cliproxyapi.service` | Auto-start service |
| Benchmark | `~/.cliproxyapi/benchmark.json` | Hasil benchmark terbaru |
| Source | `~/CLIProxyAPI-source/` | Source yang di-clone (jika build dari source) |

---

## Troubleshooting

### "Connection refused" saat menggunakan CLI

Pastikan proxy server berjalan:

```powershell
# Windows
cliproxyapi --config ~/.cliproxyapi/config.yaml
```

```bash
# Linux/macOS
cliproxyapi --config ~/.cliproxyapi/config.yaml
```

### "Unauthorized" atau "Invalid API key"

Proxy menerima API key apapun. Pastikan Anda menggunakan `sk-dummy` atau string non-kosong lainnya.

### OAuth login gagal

1. Pastikan Anda memiliki browser terinstal
2. Coba dengan flag `--incognito` untuk sesi baru
3. Periksa apakah website provider dapat diakses

### Model tidak ditemukan

1. Pastikan Anda sudah login ke provider yang menyediakan model tersebut
2. Periksa ejaan model name (case-sensitive)
3. Jalankan `cpa-oauth` untuk melihat provider mana yang sudah Anda login

### Kuota exceeded

Proxy otomatis berpindah ke provider/model lain saat kuota tercapai. Jika semua provider sudah exhausted, tunggu reset kuota (biasanya 1-24 jam tergantung provider).

---

## Credits

- [CLIProxyAPIPlus](https://github.com/router-for-me/CLIProxyAPIPlus) - Proxy server asli
- [CLIProxyAPIPlus-Easy-Installation](https://github.com/julianromli/CLIProxyAPIPlus-Easy-Installation) - Script instalasi mudah asli
- Kontributor komunitas untuk implementasi GitHub Copilot dan Kiro OAuth

---

## License

MIT License - Lihat file [LICENSE](LICENSE).

---

## Contributing

PR sangat diterima! Silakan:
- Tambah dukungan untuk lebih banyak CLI tools
- Perbaiki dokumentasi
- Laporkan bug
- Sarankan fitur baru

---

**Selamat coding!** 🚀
