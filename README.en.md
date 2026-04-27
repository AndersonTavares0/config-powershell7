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
4. [Technical Decisions](#technical-decisions)
5. [Study Notes](#study-notes)
6. [Repository Structure](#repository-structure)
7. [AI-Assisted Development](#ai-assisted-development)

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
├── Microsoft.PowerShell_profile.Tests.ps1 # Unit tests
├── README.md                            # Documentation (PT-BR)
├── README.en.md                         # Documentation (EN)
└── .gitignore                           # Git filters
```

---

## AI-Assisted Development

This project utilizes **Artificial Intelligence** tools for code optimization and documentation, ensuring the application of software engineering best practices and high performance.

---

*Revision: 2026-04 — Compatible with PS 5.1+ / PS Core 7+ / Windows 10+*
