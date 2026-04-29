# PowerShell Profile

> PowerShell startup profile optimized for **minimal boot latency**, **development ergonomics**, and **portability**.  
> Designed for quick restoration after system formatting or machine migration.

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

> **Target boot time:** < 200ms in clean sessions | < 400ms with active Oh My Posh + Zoxide

[See technical documentation → docs.en.md](docs.en.md)

---

## Table of Contents

1. [Description](#description)
2. [Features](#features)
3. [Compatibility](#compatibility)
4. [Installation](#installation)
5. [Usage](#usage)
6. [Aliases](#aliases)
7. [Functions](#functions)
8. [Performance](#performance)
9. [Troubleshooting](#troubleshooting)
10. [Tests](#tests)
11. [Repository Structure](#repository-structure)
12. [AI-Assisted Development](#ai-assisted-development)

---

## Description

This repository contains a custom PowerShell profile (`Microsoft.PowerShell_profile.ps1`) that is automatically loaded in every terminal session. The profile defines functions, aliases, and settings that increase productivity, standardize the environment, and reduce startup time through a plugin caching system.

---

## Features

- **Plugin caching system** — avoids reloading Zoxide and Oh My Posh on every session
- **Quick navigation** — aliases for directories and filesystem movement
- **Utility functions** — Unix-like equivalents (`touch`, `which`, `grep`, `head`, `tail`, `sed`)
- **Git shortcuts** — full Git workflow with functions and aliases
- **System functions** — information, processes, disk, DNS, and public IP
- **Clipboard** — copy and paste via pipeline
- **Privilege elevation** — `sudo` opens an elevated session or runs a command as Admin
- **Configured PSReadLine** — smart history, key navigation, autocomplete
- **Boot summary** — displays startup time and loaded modules on each session

---

## Compatibility

| Component | Minimum Version |
|---|---|
| Windows | 10 or higher |
| PowerShell | 5.1+ (full features on PS 7+) |
| Oh My Posh | Any current version (optional) |
| Zoxide | Any current version (optional) |

> The profile automatically detects the PowerShell version and enables advanced PSReadLine features only on PS 7+.

---

## Installation

### Prerequisites

| Component | Installation | Required |
|---|---|---|
| **PowerShell 5.1+** | Included in Windows 10+<br>PS 7: `winget install Microsoft.PowerShell` | ✅ |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com)<br>Recommended: `FiraCode Nerd Font` | ✅ |
| **Git** | `winget install Git.Git` | ✅ |
| **Oh My Posh** | `winget install JanDeDobbeleer.OhMyPosh` | Optional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Optional |
| **PSReadLine** | Included in PS 7<br>Update: `Install-Module PSReadLine -Force` | ✅ |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Optional |

### 1. Configure Execution Policy

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. Clone the repository

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
```

### 3. Unblock the files

Files downloaded from GitHub may be blocked by Windows. Run this before applying the profile:

```powershell
Get-ChildItem *.ps1 | Unblock-File
```

> ⚠️ **Common error:** If you receive *"The file is not digitally signed"*, run `Unblock-File` first.

### 4. Locate the profile path

```powershell
$PROFILE
```

### 5. Apply the profile

**Option A — Direct Copy:**

```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Option B — Symbolic Link (Recommended — requires Admin):**

```powershell
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

### 6. Install Oh My Posh theme (optional)

The profile expects the theme at `$HOME\.poshthemes\atomic.omp.json`. If the file does not exist, the default Oh My Posh theme is used automatically.

```powershell
# Create directory and download theme
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh font install
```

---

## Usage

When opening a new PowerShell session, the profile loads automatically and displays a boot summary:

```
PS 7.4.2 · OMP:atomic · Zoxide [85ms]
```

The line shows: PS version, loaded modules, startup time (green < 200ms, yellow < 400ms, red > 400ms).

---

## Aliases

All aliases available in the profile:

| Alias | Function/Command | Description |
|---|---|---|
| `Clear-Cache` | `Clear-PluginCache` | Removes the plugin cache |
| `icons` | `Import-TerminalIcons` | Loads the Terminal-Icons module |
| `cpy` | `Copy-ToClipboard` | Copies pipeline output to clipboard |
| `k9` | `pkill` | Kills a process by name |
| `gss` | `gst` | `git status -sb` |

---

## Functions

### Navigation

| Function | Description | Example |
|---|---|---|
| `docs` | Navigate to `~/Documents` | `docs` |
| `dtop` | Navigate to `~/Desktop` | `dtop` |
| `home` | Navigate to `$HOME` | `home` |
| `up` | Go up one level (`cd ..`) | `up` |
| `up2` | Go up two levels (`cd ..\..`) | `up2` |
| `la` | List files (excluding hidden) in table | `la` |
| `ll` | List files (including hidden) in table | `ll` |
| `mkcd <path>` | Create directory and enter it | `mkcd projects\new` |
| `nf <file>` | Create empty file | `nf config.json` |

### Files and Text

| Function | Description | Example |
|---|---|---|
| `touch <file>` | Create file or update timestamp | `touch notes.txt` |
| `which <cmd>` | Show command path | `which git` |
| `unzip <file> [dest]` | Extract ZIP (default dest: `.`) | `unzip archive.zip .\output` |
| `head <file> [n]` | Show first n lines (default: 10) | `head log.txt -Lines 5` |
| `tail <file> [n]` | Show last n lines (default: 10) | `tail log.txt -Lines 20` |
| `grep <pattern>` | Filter input via pipeline | `Get-Content log.txt \| grep "error"` |
| `Copy-ToClipboard` / `cpy` | Copy pipeline to clipboard | `cat file.txt \| cpy` |
| `pst` | Paste clipboard content | `pst` |
| `sed <file> <find> <replace> [-Backup]` | Atomic text replacement in file | `sed config.txt "old" "new" -Backup` |

### System

| Function | Description | Example |
|---|---|---|
| `pkill <name>` / `k9` | Kill process by name | `pkill notepad` |
| `pgrep <name>` | List processes by name with details | `pgrep chrome` |
| `flushdns` | Clear DNS cache (requires Admin) | `flushdns` |
| `df` | Show disk usage by volume | `df` |
| `pubip [-Force]` | Display public IP (cached per session) | `pubip` / `pubip -Force` |
| `sysinfo` | Hardware, OS, and uptime summary | `sysinfo` |

### Git

> Git functions are only created if the `git` command is available in the PATH.

| Function | Git Equivalent | Example |
|---|---|---|
| `gst` / `gss` | `git status -sb` | `gst` |
| `ga` | `git add .` | `ga` |
| `gcmt <msg>` | `git commit -m <msg>` | `gcmt "fix: typo"` |
| `gco <branch>` | `git checkout <branch>` | `gco main` |
| `gpush` | `git push` | `gpush` |
| `gpull` | `git pull` | `gpull` |
| `glog` | `git log --oneline --graph -15` | `glog` |
| `gundo` | `git reset --soft HEAD~1` | `gundo` |
| `gdiff` | `git diff` | `gdiff` |
| `gcl <url>` | `git clone <url>` | `gcl https://github.com/user/repo` |
| `gcom <msg>` | `git add .` + `git commit -m` (with error checking) | `gcom "feat: add filter"` |
| `lazyg <msg> [-Force]` | `add` + `commit` + `push` (with interactive confirmation) | `lazyg "chore: update deps"` |

### Administration

```powershell
# Open a new elevated PowerShell window
sudo

# Run a specific command as Administrator
sudo Get-Service

# Re-run the last command from history as Admin
sudo !!
```

### Cache and Plugins

| Function | Alias | Description |
|---|---|---|
| `Clear-PluginCache` | `Clear-Cache` | Removes `~\.cache_pwsh_plugins.ps1` and prompts terminal restart |
| `Import-TerminalIcons` | `icons` | Loads Terminal-Icons module (with double-load check) |

---

## Performance

### Plugin Caching System

The profile avoids reloading Zoxide and Oh My Posh from scratch every session by using a cache file at `~\.cache_pwsh_plugins.ps1`.

**How it works:**

1. On startup, the profile calculates an MD5 fingerprint based on the paths of `zoxide`, `oh-my-posh`, and the current theme.
2. Compares the fingerprint with the one recorded in the cache.
3. If they match, the cache is loaded directly (fast path).
4. If they differ (tools updated, theme changed), the cache is regenerated.

**Estimated savings:** ~200ms per session when the cache is valid.

### PSReadLine

Configured with smart history (no duplicates, up to 5,000 entries), arrow key navigation, and menu autocomplete (Tab). On PS 7+, also enables history prediction with ListView.

### Boot Summary

At the end of loading, the profile displays the total boot time and loaded modules, color-coded:

- 🟢 Green: < 200ms
- 🟡 Yellow: 200–400ms
- 🔴 Red: > 400ms

---

## Troubleshooting

### Profile does not load

**Symptom:** no aliases or functions available after opening the terminal.

**Solution:**

```powershell
# Check if the profile exists
Test-Path $PROFILE

# Check which file is being loaded
$PROFILE

# Manually reload
. $PROFILE
```

### Execution Policy error

**Symptom:** `"File cannot be loaded because running scripts is disabled on this system."`

**Solution:**

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### File blocked by Windows

**Symptom:** `"The file is not digitally signed."`

**Solution:**

```powershell
Get-ChildItem *.ps1 | Unblock-File
```

### Command not recognized after installation

**Symptom:** `"The term 'gst' is not recognized..."`

**Cause:** Git is not in PATH, or the profile was not reloaded.

**Solution:**

```powershell
# Check if git is available
Get-Command git -ErrorAction SilentlyContinue

# Reload the profile
. $PROFILE
```

### Modules not found

**Symptom:** Terminal-Icons or PSReadLine do not load.

**Solution:**

```powershell
Install-Module -Name Terminal-Icons -Scope CurrentUser
Install-Module -Name PSReadLine -Scope CurrentUser -Force
```

### Corrupted or outdated cache

**Symptom:** Oh My Posh or Zoxide do not initialize correctly.

**Solution:**

```powershell
Clear-Cache
# Restart the terminal after running
```

### flushdns does not work

**Symptom:** `"flushdns requer privilégios de Administrador."`

**Solution:** Run the terminal as Administrator or use `sudo flushdns`.

---

## Tests

The project includes unit tests in `Microsoft.PowerShell_profile.Tests_diff.ps1`, implemented with a custom framework (no external dependencies).

### Run

```powershell
cd config-powershell7
.\Microsoft.PowerShell_profile.Tests_diff.ps1

# With verbose output
.\Microsoft.PowerShell_profile.Tests_diff.ps1 -Verbose
```

### Coverage

| Category | Tested Items |
|---|---|
| **Navigation** | `docs`, `dtop`, `home`, `up`, `up2`, `la`, `ll`, `mkcd`, `nf` |
| **Files and Text** | `touch`, `which`, `unzip`, `head`, `tail`, `grep`, `cpy`, `pst`, `Copy-ToClipboard`, `sed` |
| **System** | `pkill`, `k9`, `pgrep`, `flushdns`, `df`, `pubip`, `sysinfo` |
| **Git** | `gst`, `gss`, `ga`, `gcmt`, `gco`, `gpush`, `gpull`, `glog`, `gundo`, `gdiff`, `gcl`, `gcom`, `lazyg` |
| **Administration** | `sudo` |
| **Plugin Cache** | `Clear-PluginCache`, `Clear-Cache`, `Import-TerminalIcons`, `icons` |

### Expected output

```
========================================
TEST SUMMARY
========================================
Total Tests: XX
Passed:      XX
Failed:      0
========================================
```

- ✅ All passed: profile is working correctly.
- ❌ Some failed: check dependencies and Execution Policy.

---

## Repository Structure

```
config-powershell7/
├── Microsoft.PowerShell_profile.ps1           # Main profile code
├── Microsoft.PowerShell_profile.Tests_diff.ps1 # Unit tests
├── readme.md                                   # Documentation (PT-BR)
├── readme.en.md                                # Documentation (EN)
├── docs.md                                     # Technical documentation (PT-BR)
├── docs.en.md                                  # Technical documentation (EN)
├── LICENSE                                     # MIT License (EN)
├── LICENÇA.pt-BR                               # MIT License (PT-BR)
└── .gitignore                                  # Git filters
```

---

## AI-Assisted Development

This project used **Artificial Intelligence** tools to assist with documentation, code review, and refactoring, ensuring software engineering best practices, consistency, and performance.

---

*Revision: 04/29/2026 — Compatible with PS 5.1+ / PS Core 7+ / Windows 10+*
