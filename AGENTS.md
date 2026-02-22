# AGENTS.md - CLIProxyAPI Easy Installation

> Guidance for AI coding agents working on this repository.

## Project Snapshot

- **Type**: Utility scripts collection (PowerShell + Bash)
- **Purpose**: One-click installation scripts for CLIProxyAPI proxy server
- **Platform**: Windows (PowerShell 5.1+), Linux/macOS (Bash 4+)
- **Sub-docs**: See [scripts/AGENTS.md](scripts/AGENTS.md) for PowerShell script-specific patterns

## Quick Commands

### Windows (PowerShell)

```powershell
# Test install script (dry run not available - test on VM/sandbox)
.\scripts\install-cliproxyapi.ps1 -UsePrebuilt

# Test OAuth script (interactive)
.\scripts\cliproxyapi-oauth.ps1

# Test update script
.\scripts\update-cliproxyapi.ps1 -UsePrebuilt

# Test uninstall (use -Force to skip confirmation)
.\scripts\uninstall-cliproxyapi.ps1 -Force
```

### Linux / macOS (Bash)

```bash
# Test install script (dry run not available - test on VM/sandbox)
./unix/install-cliproxyapi.sh --prebuilt

# Test OAuth script (interactive)
./unix/cliproxyapi-oauth.sh

# Test update script
./unix/update-cliproxyapi.sh --prebuilt

# Test uninstall (use --force to skip confirmation)
./unix/uninstall-cliproxyapi.sh --force
```

## Repository Structure

```
├── scripts/           → PowerShell scripts (Windows) [see scripts/AGENTS.md]
├── unix/              → Bash scripts (Linux/macOS)
├── configs/           → Example config files (YAML, JSON)
├── gui/               → HTML GUI for Control Center
├── README.md          → Documentation
└── LICENSE            → MIT
```

## Universal Conventions

### Code Style
- **PowerShell**: Use approved verbs (`Get-`, `Set-`, `New-`, `Remove-`)
- **Bash**: Use snake_case for functions, lowercase for variables
- **Indentation**: 4 spaces (no tabs)
- **Comments**: Use `#` for inline, `<# #>` for block/help (PowerShell)
- **Encoding**: UTF-8 with BOM for PowerShell, UTF-8 for Bash

### Commit Format
```
type: short description

- detail 1
- detail 2
```
Types: `feat`, `fix`, `docs`, `refactor`, `chore`

### Branch Strategy
- `main` - stable releases only
- `dev` - development branch
- Feature branches: `feat/description`

## Security & Secrets

- **NEVER** commit real API keys or OAuth tokens
- Use `sk-dummy` as placeholder in examples
- Config paths use `~` or `$env:USERPROFILE` / `$HOME` (resolved at runtime)
- No hardcoded usernames or paths

## JIT Index

### Find Script Functions (PowerShell)
```powershell
# Find all functions in scripts
Select-String -Path "scripts\*.ps1" -Pattern "^function\s+\w+"

# Find param blocks
Select-String -Path "scripts\*.ps1" -Pattern "param\s*\("
```

### Find Script Functions (Bash)
```bash
# Find all functions in unix scripts
grep -n "^function\s\|^[a-z_]*() {" unix/*.sh

# Find parameter handling
grep -n "case.*in\|for arg in" unix/*.sh
```

### Find Config Patterns
```powershell
# Find model definitions
Select-String -Path "configs\*.json" -Pattern "model_display_name"

# Find YAML keys
Select-String -Path "configs\*.yaml" -Pattern "^\w+:"
```

## Definition of Done

Before PR:
- [ ] Script runs without errors on clean Windows install
- [ ] Script runs without errors on clean Linux/macOS install
- [ ] Help text updated (`Get-Help .\script.ps1` or `./script.sh --help`)
- [ ] README updated if new features added
