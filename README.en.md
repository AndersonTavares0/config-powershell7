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
| `home` | Go to `$HOME` |
| `up` | Go up one level (`cd ..`) |
| `la` | List files in table format |
| `mkcd <path>` | Create directory and enter it |

### Files and Text

| Command | Action |
|---------|------|
| `touch <file>` | Create file or update timestamp |
| `grep <pat>` | Filter input via pipeline |
| `clip` | Copy pipeline output to clipboard |
| `sed` | Atomic replacement in files |

### Git

| Command | Git Equivalent |
|---------|-----------------|
| `gst` | `git status -sb` |
| `gcom <m>` | `git add .` + `commit` |
| `lazyg <m>` | `add` + `commit` + `push` |

### System

| Command | Action |
|---------|------|
| `df` | Disk usage |
| `pubip` | Display public IP (cached) |
| `sysinfo` | Hardware summary and uptime |

### Administration

```powershell
# Open new elevated PowerShell window
sudo
```

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
| **Navigation** | `docs`, `home`, `up`, `dtop`, `up2` |
| **Files** | `mkcd`, `nf`, `touch`, `unzip` |
| **Text** | `head`, `tail`, `bat`, `cat` |
| **System** | `pkill`, `k9`, `pgrep`, `which` |
| **Git** | `gst`, `ga`, `gcmt`, `gco`, `gpush`, `gpull`, `glog`, `gundo`, `gdiff`, `gcl`, `gcom`, `lazyg`, `gss` |
| **Clipboard** | `cpy`, `pst`, `Copy-ToClipboard` |
| **Plugin Cache** | `Clear-PluginCache`, `Clear-Cache`, `Import-TerminalIcons`, `icons` |
| **Display** | `la`, `ll` |
| **Administration** | `flushdns` |

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

*Revision: 2026-04 — Compatible with PS 5.1+ / PS Core 7+ / Windows 10+*
