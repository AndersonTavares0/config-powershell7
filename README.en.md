# PowerShell Profile

PowerShell startup profile optimized for **minimal boot latency**, **development ergonomics**, and **portability**. Designed for quick restoration after system formatting or machine migration.

> **Target boot time:** < 200ms in clean sessions | < 400ms with active Oh My Posh + Zoxide

---

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Available Commands](#available-commands)
    - [Navigation](#navigation)
    - [Files and Text](#files-and-text)
    - [Git](#git)
    - [System](#system)
    - [Administration](#administration)
4. [Unit Tests](#unit-tests)
5. [Technical Decisions](#technical-decisions)
6. [Study Notes](#study-notes)
7. [Repository Structure](#repository-structure)
8. [AI-Assisted Development](#ai-assisted-development)

---

## Requirements

| Component | Installation | Required |
|------------|------------|-------------|
| **PowerShell 5.1+** | Included in Windows 10+<br>PS 7: `winget install Microsoft.PowerShell` | ✅ |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com)<br>Recommended: `FiraCode Nerd Font` | ✅ |
| **Git** | `winget install Git.Git` | ✅ |
| **Oh My Posh** | `winget install JanDeLaaj.oh-my-posh` | Optional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Optional |
| **PSReadLine** | Included in PS 7<br>Update: `Install-Module PSReadLine -Force` | ✅ |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Optional |

---

## Installation

### 1. Clone the repository

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
```

### 2. Locate the profile path

```powershell
$PROFILE
```

### 3. Apply the profile

**Option A — Direct Copy:**
```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Option B — Symbolic Link (Recommended):**
```powershell
# Requires Admin privileges
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

---

## Available Commands

### Navigation

| Command | Action |
|---------|------|
| `docs` | Go to `~/Documents` |
| `dtop` | Go to `$HOME/Desktop` |
| `home` | Go to `$HOME` |
| `up` | Go up one level (`cd ..`) |
| `up2` | Go up two levels (`cd ..\..`) |
| `la` | List files in table format (excluding hidden) |
| `ll` | List files in table format (including hidden) |
| `mkcd <path>` | Create directory and enter it |
| `nf <file>` | Create empty file |

### Files and Text

| Command | Action |
|---------|------|
| `touch <file>` | Create file or update timestamp |
| `which <cmd>` | Show command path |
| `unzip <file> [dest]` | Extract ZIP archive |
| `head <file> [n]` | Show first n lines (default: 10) |
| `tail <file> [n]` | Show last n lines (default: 10) |
| `grep <pattern>` | Filter input via pipeline |
| `cpy` / `Copy-ToClipboard` | Copy pipeline output to clipboard |
| `pst` | Paste from clipboard |
| `sed <file> <find> <replace> [-Backup]` | Atomic replacement in files |

### System

| Command | Action |
|---------|------|
| `pkill <name>` / `k9` | Kill process by name |
| `pgrep <name>` | List processes by name with details |
| `flushdns` | Clear DNS cache (requires Admin) |
| `df` | Disk usage by volume |
| `pubip [-Force]` | Display public IP (cached) |
| `sysinfo` | Hardware summary and uptime |

### Git

| Command | Git Equivalent |
|---------|-----------------|
| `gst` / `gss` | `git status -sb` |
| `ga` | `git add .` |
| `gcmt <msg>` | `git commit -m <msg>` |
| `gco <branch>` | `git checkout <branch>` |
| `gpush` | `git push` |
| `gpull` | `git pull` |
| `glog` | `git log --oneline --graph -15` |
| `gundo` | `git reset --soft HEAD~1` |
| `gdiff` | `git diff` |
| `gcl <url>` | `git clone <url>` |
| `gcom <msg>` | `git add .` + `git commit -m <msg>` (with error checking) |
| `lazyg <msg> [-Force]` | `add` + `commit` + `push` (with interactive confirmation) |

### Administration

```powershell
# Open new elevated PowerShell window
sudo

# Run specific command as Administrator
sudo <command>

# Re-run last command as Admin
sudo !!
```

### Cache and Plugin Utilities

| Command | Action |
|---------|------|
| `Clear-PluginCache` / `Clear-Cache` | Remove plugin cache and restart terminal |
| `Import-TerminalIcons` / `icons` | Load Terminal-Icons module |

---

## Technical Decisions

### Plugin Caching System
The profile generates a cache at `~\.cache_pwsh_plugins.ps1` to avoid loading Zoxide and Oh My Posh from scratch in every new tab, saving approximately 200ms of boot time.

### Atomic Write in sed
We use a temporary file to ensure that if the process is interrupted, the original file is not corrupted.

---

## Unit Tests

The project includes a unit test file (`Microsoft.PowerShell_profile.Tests_diff.ps1`) that validates all functions, aliases, and behaviors of the profile.

### Running the tests

```powershell
# Navigate to the project directory
cd config-powershell7

# Run the tests
.\Microsoft.PowerShell_profile.Tests_diff.ps1
```

### Execution options

```powershell
# Run with verbose output
.\Microsoft.PowerShell_profile.Tests_diff.ps1 -Verbose

# Run after reloading the profile
$env:PROFILE_CURRENT = $PROFILE
.\Microsoft.PowerShell_profile.Tests_diff.ps1
```

### What is tested

Tests cover:

| Category | Tested Items |
|----------|--------------|
| **Navigation** | `docs`, `dtop`, `home`, `up`, `up2`, `la`, `ll`, `mkcd`, `nf` |
| **Files and Text** | `touch`, `which`, `unzip`, `head`, `tail`, `grep`, `cpy`, `pst`, `Copy-ToClipboard`, `sed` |
| **System** | `pkill`, `k9`, `pgrep`, `flushdns`, `df`, `pubip`, `sysinfo` |
| **Git** | `gst`, `gss`, `ga`, `gcmt`, `gco`, `gpush`, `gpull`, `glog`, `gundo`, `gdiff`, `gcl`, `gcom`, `lazyg` |
| **Administration** | `sudo` |
| **Plugin Cache** | `Clear-PluginCache`, `Clear-Cache`, `Import-TerminalIcons`, `icons` |

### Interpreting results

At the end of execution, you will see a summary:

```
========================================
TEST SUMMARY
========================================
Total Tests: XX
Passed:      XX
Failed:      0
========================================
```

- ✅ **All tests passed:** Your profile is working correctly.
- ❌ **Some tests failed:** Check if all dependencies are installed and if the Execution Policy is configured correctly.

---

## Study Notes

### Execution Policy on Windows
To run this profile, you must allow the execution of local scripts:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Repository Structure

```
config-powershell7/
├── Microsoft.PowerShell_profile.ps1     # Main profile code
├── Microsoft.PowerShell_profile.Tests_diff.ps1 # Unit tests
├── README.md                            # Documentation (PT-BR)
├── README.en.md                         # Documentation (EN)
└── .gitignore                           # Git filters
```

---

## AI-Assisted Development

This project utilizes **Artificial Intelligence** tools for code optimization and documentation, ensuring the application of software engineering best practices and high performance.

---

*Revision: 04/27/2026 — Compatible with PS 5.1+ / PS Core 7+ / Windows 10+*
