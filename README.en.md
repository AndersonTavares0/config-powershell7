# PowerShell Profile

A PowerShell initialization profile focused on minimal boot latency, development ergonomics, and portability. Designed to be quickly restored in case of system formatting or migration.

> **Target boot time:** < 200ms on a clean session; < 400ms with OMP + Zoxide active.

---

## Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Command Reference](#command-reference)
   - [Navigation](#navigation)
   - [Files and Text](#files-and-text)
   - [Git](#git)
   - [System](#system)
   - [Admin](#admin)
4. [Technical Decisions](#technical-decisions)
5. [Study Notes](#study-notes)

---

## Requirements

| Component | Installation | Required |
|---|---|---|
| PowerShell 5.1+ | Included in Windows 10+; PS 7: `winget install Microsoft.PowerShell` | ✅ |
| Nerd Font | [nerdfonts.com](https://www.nerdfonts.com) — Recommended: `FiraCode Nerd Font` | ✅ (for icons) |
| Git | `winget install Git.Git` | ✅ |
| Oh My Posh | `winget install JanDeLaaj.oh-my-posh` | Optional |
| Zoxide | `winget install ajeetdsouza.zoxide` | Optional |
| PSReadLine | Included in PS 7; update via `Install-Module PSReadLine -Force` | ✅ |
| Terminal-Icons | `Install-Module Terminal-Icons -Repository PSGallery` | Optional (lazy load) |

> **Compatibility:** PS 5.1 (Windows PowerShell) and PS Core 7+. Features exclusive to PS 7 (e.g., `PredictionViewStyle`) are activated conditionally via `$PSMajor`.

---

## Installation

### 1. Clone the repository

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
```

### 2. Locate your profile path

```powershell
$PROFILE
# PS 7  → C:\Users\<username>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
# PS 5.1 → C:\Users\<username>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

### 3. Apply the profile

**Option A — Direct copy (simple):**

```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Option B — Symbolic link (keeps the repo synced with `git pull`):**

```powershell
# Requires terminal with Administrator privileges
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

### 4. Install required modules

```powershell
Install-Module PSReadLine     -AllowPrerelease -Force -Scope CurrentUser
Install-Module Terminal-Icons -Repository PSGallery  -Scope CurrentUser
```

### 5. Install the Oh My Posh theme

The profile looks for the `atomic` theme at `~\.poshthemes\atomic.omp.json`.
If the file doesn't exist, OMP will start with the default theme automatically.

```powershell
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh config export --output "$HOME\.poshthemes\atomic.omp.json"
# Or download directly: https://ohmyposh.dev/docs/themes
```

### 6. Clear the plugin cache (when needed)

The profile generates a cache at `~\.cache_pwsh_plugins.ps1` on first run to avoid reinitializing OMP and Zoxide on every boot. If you install, remove, or update these components, clear the cache:

```powershell
Clear-Cache
# Restart the terminal afterwards
```

### 7. Check boot time

When you open the terminal, the loading time is displayed automatically:

```
PS 7.6.1 · OMP:atomic, Zoxide  [143ms]   ← within target (green)
PS 7.6.1 · OMP:atomic, Zoxide  [287ms]   ← acceptable (yellow)
PS 7.6.1 · OMP:atomic, Zoxide  [543ms]   ← investigate (red)
```

---

## Command Reference

### Navigation

| Command | Action |
|---|---|
| `docs` | Go to `~/Documents` |
| `dtop` | Go to `~/Desktop` |
| `home` | Go to `$HOME` |
| `up` | Go up one level (`cd ..`) |
| `up2` | Go up two levels (`cd ../..`) |
| `la` | List files in table format |
| `ll` | List all files including hidden |
| `mkcd <path>` | Create directory and enter it |
| `nf <name>` | Create empty file(s) |

> **Note:** `home` and `up` replace the shortcuts `~` and `..` which in some contexts conflict with native PowerShell operators.

> **Zoxide (`z`):** after a few visits, `z proj` automatically navigates to `~/Dev/projects/my-project` based on usage frequency.

---

### Files and Text

| Command | Action |
|---|---|
| `touch <file>` | Create file or update timestamp |
| `which <cmd>` | Show the path of an executable |
| `unzip <file> [dest]` | Extract `.zip` (default: current folder) |
| `head <file> [n]` | First N lines (default: 10) |
| `tail <file> [n]` | Last N lines (default: 10) |
| `grep <pattern>` | Filter input via pipeline |
| `clip` | Copy entire pipeline to clipboard |
| `cpy` | Alias for `clip` |
| `pst` | Paste from clipboard |
| `sed <file> <find> <replace> [-Backup]` | Atomic file substitution (UTF-8 safe) |
| `icons` | Load Terminal-Icons (lazy load) |
| `Clear-Cache` | Remove plugin cache and request restart |

**Examples:**

```powershell
# Filter lines containing "error" from a log
Get-Content app.log | grep "error"

# Copy command output to clipboard
git log --oneline -20 | clip

# Safe substitution in UTF-8 file (with automatic backup)
sed .\config.json "localhost" "192.168.1.10" -Backup

# Create multiple files via pipeline
"index.html","style.css","app.js" | nf

# Update timestamp of multiple files via pipeline
"index.html","style.css","app.js" | touch
```

---

### Git

| Command | Git Equivalent |
|---|---|
| `gst` / `gs` | `git status -sb` |
| `ga` | `git add .` |
| `gco <msg>` | `git commit -m "<msg>"` |
| `gpush` | `git push` |
| `gpull` | `git pull` |
| `glog` | `git log --oneline --graph -15` |
| `gundo` | `git reset --soft HEAD~1` (undo last commit, keep changes) |
| `gdiff` | `git diff` |
| `gcl <url>` | `git clone <url>` |
| `gcom <msg>` | `git add .`; `git commit -m "<msg>"` |
| `lazyg <msg>` | `git add .`; `git commit -m "<msg>"`; `git push` (asks for confirmation) |

**Quick workflow example:**

```powershell
# View status, then stage + commit + push with interactive confirmation
lazyg "fix: correct form validation"

# Bypass confirmation (useful in scripts or CI)
lazyg "chore: bump version" -Force
```

> ⚠️ **`lazyg` is destructive** — stages *everything*, commits and pushes in sequence. Always review the displayed `git status` before confirming with `y`.

> **Note:** Commands are chained with `;` (semicolon), not `&&`. The `&&` operator only exists in PowerShell 7+. Since this profile supports PS 5.1, `;` ensures universal compatibility.

---

### System

| Command | Action |
|---|---|
| `df` | Disk usage per volume (size, free, % free) |
| `pgrep <name>` | Search processes by name (displays ID, CPU and RAM in MB) |
| `pkill <name>` / `k9 <name>` | Kill process by name (`Stop-Process -Force`) |
| `flushdns` | Flush DNS cache (requires Administrator privilege) |
| `pubip [-Force]` | Display public IP (uses session cache; `-Force` ignores cache) |
| `sysinfo` | System summary: host, user, OS, PS version, uptime, RAM |

---

### Admin

```powershell
# Open new elevated PowerShell window
sudo

# Execute specific command as Administrator
sudo netsh interface reset
```

> The `sudo` command automatically detects whether you're using PS 5.1 or PS 7 and opens the correct version with `-Verb RunAs`.

---

## Technical Decisions

### Plugin cache system

On first run, the profile initializes Zoxide and Oh My Posh, captures their initialization output in a `StringBuilder`, and saves the result to `~\.cache_pwsh_plugins.ps1`. On subsequent runs, it just reads the cache:

```
First boot  → generates cache  → ~200–400ms
Later boots → reads cache      → minimal cost
```

When you install, remove, or update OMP or Zoxide, run `Clear-Cache` to regenerate.

---

### Why `filter` instead of `function` for `grep`?

`function` accumulates all pipeline objects in `$input` before processing. `filter` processes each object immediately as it arrives — essential for pipelines with large files or streams:

```powershell
# filter: processes line by line (true streaming, no collection allocation)
filter grep([string]$Pattern) { $_ | Select-String -Pattern $Pattern }
```

---

### Why `begin/process/end` in `clip`?

A `filter` would call `Set-Clipboard` for each pipeline item — each call would overwrite the previous one. With 10 lines in the pipe, only the last would be copied. The `begin/process/end` block accumulates everything first:

```powershell
function clip {
    begin   { $buf = [System.Text.StringBuilder]::new() }
    process { [void]$buf.AppendLine($_) }
    end     { $buf.ToString().TrimEnd() | Set-Clipboard }
}
```

---

### Atomic writes in `sed`

The `sed` command never overwrites the original file directly. The flow is:

```
Read original → process → write to .tmp → Move-Item replaces atomically
```

If any step fails, the `.tmp` is removed and the original remains intact. The `-Backup` parameter creates a `.bak` copy before replacement.

---

### Why `Get-Command` instead of `Get-Module -ListAvailable`?

`Get-Module -ListAvailable` scans all directories in `$env:PSModulePath` on disk. `Get-Command` only queries what's already resolved in PATH — approximately **100ms faster**.

---

### Why Terminal-Icons is lazy loaded?

The module costs between 80ms and 150ms to import. Since icons only matter in interactive file exploration sessions, it's loaded on demand:

```powershell
# Load icons only when needed
icons
```

---

### Explicit UTF-8 encoding in `sed`

PS 5.1 uses `Default` encoding (ANSI/Windows-1252) and PS 7 uses UTF-8 without BOM by default in some operations. Without explicit `-Encoding UTF8`, files with special characters can be corrupted:

---

### Session cache in `pubip`

The first call to `pubip` queries `https://api.ipify.org` and stores the result in `$script:CachedPublicIP`. Subsequent calls return the in-memory value without a new network request.

---

### `$script:` scope on global variables

Variables like `$script:BootTimer`, `$script:StartupModules`, and `$script:CachedPublicIP` use the `$script:` scope explicitly to avoid collision with variables the user might define in their session.

---

### Why `;` and not `&&` for command chaining?

The `&&` operator (pipeline chain operator) was introduced in PowerShell 7.0. Since this profile declares compatibility with PS 5.1 (`#Requires -Version 5.1`), all chains use `;` (semicolon), which has worked since PS 1.0.

---

## Study Notes

### The profile is a script executed every startup

Everything in `Microsoft.PowerShell_profile.ps1` runs every time the terminal starts. If boot is slow, the culprit is almost always a heavy module being imported in a blocking way. Use the timer displayed at startup to identify the problem:

```
PS 7.6.1 · OMP:atomic, Zoxide  [143ms]   ← within target  ✅
PS 7.6.1 · OMP:atomic, Zoxide  [387ms]   ← acceptable     🟡
PS 7.6.1 · OMP:atomic, Zoxide  [543ms]   ← investigate    🔴
```

---

### Concepts covered in this profile

| Concept | Where it appears in the profile |
|---|---|
| Aliases | `gs`, `k9`, `cpy` — shortcuts for functions and cmdlets |
| Custom functions | `lazyg`, `sysinfo`, `mkcd` — reusable code blocks |
| Filter vs Function | `grep` uses `filter` for true streaming in the pipeline |
| `begin/process/end` | `clip` — fine-grained control of pipeline lifecycle |
| Lazy Loading | `icons` — on-demand import |
| Session cache | `pubip`, `$script:CachedPublicIP` — avoids repeated requests |
| Disk cache | `~\.cache_pwsh_plugins.ps1` — avoids reinitializing OMP/Zoxide |
| State caching | `$PSMajor`, `$IsAdmin` — avoids recalculation on each use |
| Explicit scope | `$script:` — isolates profile variables from user session |
| Atomic writes | `sed` — protects original against partial failures |
| External modules | PSReadLine, Terminal-Icons, Oh My Posh, Zoxide |
| Conditional execution | PS 7 features activated via `if ($PSMajor -ge 7)` |
| Chaining with `;` | `gcom`, `lazyg` — compatible with PS 5.1 and 7+ |

---

### Execution Policy on Windows

Unlike Linux, Windows blocks unsigned scripts by default. To enable profile execution:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Repository Structure

```
config-powershell7/
├── Microsoft.PowerShell_profile.ps1   # Main profile
├── README.md                          # Portuguese documentation
└── README.en.md                       # English documentation
```

---

*Revision: 2026-04 — PS 5.1+ / PS Core 7+ / Windows 10+*

+++ README.en.md (修改后)
# 🚀 PowerShell Profile

A PowerShell initialization profile focused on minimal boot latency, development ergonomics, and portability. Designed to be quickly restored in case of system formatting or migration.

> **🎯 Target boot time:** < 200ms on a clean session; < 400ms with OMP + Zoxide active.

---

## 📑 Table of Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Command Reference](#command-reference)
4. [Unit Tests](#unit-tests)
5. [Technical Decisions](#technical-decisions)
6. [Study Notes](#study-notes)
7. [Repository Structure](#repository-structure)

---

## ⚙️ Requirements

| Component | Installation | Required |
|-----------|--------------|----------|
| **PowerShell 5.1+** | Included in Windows 10+; PS 7: `winget install Microsoft.PowerShell` | ✅ |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com) — Recommended: `FiraCode Nerd Font` | ✅ (for icons) |
| **Git** | `winget install Git.Git` | ✅ |
| **Oh My Posh** | `winget install JanDeLaaj.oh-my-posh` | Optional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Optional |
| **PSReadLine** | Included in PS 7; update via `Install-Module PSReadLine -Force` | ✅ |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Optional (lazy load) |

> **💡 Compatibility:** Works on PS 5.1 (Windows PowerShell) and PS Core 7+. PS 7 exclusive features are activated conditionally.

---

## 📥 Installation

### 1. Clone the repository

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
```

### 2. Locate your profile path

```powershell
$PROFILE
```

Expected output:
- **PS 7:** `C:\Users\<username>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- **PS 5.1:** `C:\Users\<username>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

### 3. Apply the profile

**Option A — Direct copy (simple):**

```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Option B — Symbolic link (keeps synced with `git pull`):**

```powershell
# Requires terminal as Administrator
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

### 4. Install required modules

```powershell
Install-Module PSReadLine     -AllowPrerelease -Force -Scope CurrentUser
Install-Module Terminal-Icons -Repository PSGallery  -Scope CurrentUser
```

### 5. Install the Oh My Posh theme

The profile looks for the `atomic` theme at `~\.poshthemes\atomic.omp.json`. If it doesn't exist, OMP starts with the default theme automatically.

```powershell
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh config export --output "$HOME\.poshthemes\atomic.omp.json"
# Or download directly: https://ohmyposh.dev/docs/themes
```

### 6. Clear the plugin cache (when needed)

The profile generates a cache at `~\.cache_pwsh_plugins.ps1` on first run to avoid reinitializing OMP and Zoxide on every boot. If you install, remove, or update these components, clear the cache:

```powershell
Clear-Cache
# Restart the terminal afterwards
```

### 7. Check boot time

When you open the terminal, the loading time is displayed automatically:

```
PS 7.6.1 · OMP:atomic, Zoxide  [143ms]   ← within target ✅
PS 7.6.1 · OMP:atomic, Zoxide  [287ms]   ← acceptable 🟡
PS 7.6.1 · OMP:atomic, Zoxide  [543ms]   ← investigate 🔴
```

---

## 📚 Command Reference

### Navigation

| Command | Action |
|---------|--------|
| `docs` | Go to `~/Documents` |
| `dtop` | Go to `~/Desktop` |
| `home` | Go to `$HOME` |
| `up` | Go up one level (`cd ..`) |
| `up2` | Go up two levels (`cd ../..`) |
| `la` | List files in table format |
| `ll` | List all files including hidden |
| `mkcd <path>` | Create directory and enter it |
| `nf <name>` | Create empty file(s) |
| `z <path>` | Smart navigation by frequency (Zoxide) |

> **📝 Note:** `home` and `up` replace shortcuts `~` and `..` to avoid conflicts with native PowerShell operators.

> **💡 Zoxide:** After a few visits, `z proj` automatically navigates to `~/Dev/projects/my-project` based on usage frequency.

---

### Files and Text

| Command | Action |
|---------|--------|
| `touch <file>` | Create file or update timestamp |
| `which <cmd>` | Show the path of an executable |
| `unzip <file> [dest]` | Extract `.zip` (default: current folder) |
| `head <file> [n]` | First N lines (default: 10) |
| `tail <file> [n]` | Last N lines (default: 10) |
| `grep <pattern>` | Filter input via pipeline |
| `clip` / `cpy` | Copy entire pipeline to clipboard |
| `pst` | Paste from clipboard |
| `sed <file> <find> <replace> [-Backup]` | Atomic file substitution (UTF-8 safe) |
| `icons` | Load Terminal-Icons (lazy load) |
| `Clear-Cache` | Remove plugin cache |

**Examples:**

```powershell
# Filter lines containing "error" from a log
Get-Content app.log | grep "error"

# Copy command output to clipboard
git log --oneline -20 | clip

# Safe substitution in UTF-8 file (with backup)
sed .\config.json "localhost" "192.168.1.10" -Backup

# Create multiple files via pipeline
"index.html","style.css","app.js" | nf

# Update timestamp of multiple files via pipeline
"index.html","style.css","app.js" | touch
```

---

### Git

| Command | Git Equivalent |
|---------|----------------|
| `gst` / `gs` | `git status -sb` |
| `ga` | `git add .` |
| `gco <msg>` | `git commit -m "<msg>"` |
| `gpush` | `git push` |
| `gpull` | `git pull` |
| `glog` | `git log --oneline --graph -15` |
| `gundo` | `git reset --soft HEAD~1` |
| `gdiff` | `git diff` |
| `gcl <url>` | `git clone <url>` |
| `gcom <msg>` | `git add .` + `git commit -m "<msg>"` |
| `lazyg <msg>` | `git add .` + `commit` + `push` (asks for confirmation) |

**Quick workflow example:**

```powershell
# View status, then stage + commit + push with interactive confirmation
lazyg "fix: correct form validation"

# Bypass confirmation (useful in scripts or CI)
lazyg "chore: bump version" -Force
```

> ⚠️ **`lazyg` is destructive** — stages *everything*. Always review `git status` before confirming.

> **📝 Note:** Commands use `;` (semicolon) for compatibility with PS 5.1 and 7+.

---

### System

| Command | Action |
|---------|--------|
| `df` | Disk usage per volume (size, free, % free) |
| `pgrep <name>` | Search processes by name (ID, CPU, RAM in MB) |
| `pkill <name>` / `k9 <name>` | Kill process by name |
| `flushdns` | Flush DNS cache (requires Administrator) |
| `pubip [-Force]` | Display public IP (uses session cache) |
| `sysinfo` | System summary: host, user, OS, uptime, RAM |

---

### Admin

```powershell
# Open new elevated PowerShell window
sudo

# Execute specific command as Administrator
sudo netsh interface reset
```

> The `sudo` command automatically detects whether you're using PS 5.1 or PS 7 and opens the correct version.

---

## 🧪 Unit Tests

To ensure all functions and aliases are working correctly and that no changes have broken the system, the project includes an automated test suite.

### How to run tests

1. **Allow script execution** (required only once):
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **Load the current profile** (ensures functions are in memory):
   ```powershell
   . $PROFILE
   ```

3. **Run the test script**:
   ```powershell
   .\Microsoft.PowerShell_profile.Tests.ps1
   ```

### What is validated?

The script runs **36 unit tests**, verifying:
* **Navigation Integrity:** Whether `home`, `docs`, and `up` access the correct directories.
* **File Operations:** Validation of directory creation with `mkcd` and file manipulation with `nf` and `touch`.
* **Text Processing:** Verification of `head` and `tail` logic.
* **Cache System:** Checking if plugin cache cleanup functions are registered.
* **Command Availability:** Ensures all Git, System, and Administration (Sudo) aliases were loaded successfully.

---

## 🔧 Technical Decisions

### Plugin cache system

On first run, the profile initializes Zoxide and Oh My Posh, captures their initialization output in a `StringBuilder`, and saves the result to `~\.cache_pwsh_plugins.ps1`. On subsequent runs, it just reads the cache:

```
First boot  → generates cache  → ~200–400ms
Later boots → reads cache      → minimal cost
```

When you install, remove, or update OMP or Zoxide, run `Clear-Cache` to regenerate.

---

### Why `filter` instead of `function` for `grep`?

`function` accumulates all pipeline objects in `$input` before processing. `filter` processes each object immediately as it arrives — essential for pipelines with large files or streams:

```powershell
# filter: processes line by line (true streaming, no collection allocation)
filter grep([string]$Pattern) { $_ | Select-String -Pattern $Pattern }
```

---

### Why `begin/process/end` in `clip`?

A `filter` would call `Set-Clipboard` for each pipeline item — each call would overwrite the previous one. With 10 lines in the pipe, only the last would be copied. The `begin/process/end` block accumulates everything first:

```powershell
function clip {
    begin   { $buf = [System.Text.StringBuilder]::new() }
    process { [void]$buf.AppendLine($_) }
    end     { $buf.ToString().TrimEnd() | Set-Clipboard }
}
```

---

### Atomic writes in `sed`

The `sed` command never overwrites the original file directly. The flow is:

```
Read original → process → write to .tmp → Move-Item replaces atomically
```

If any step fails, the `.tmp` is removed and the original remains intact. The `-Backup` parameter creates a `.bak` copy before replacement.

---

### Why `Get-Command` instead of `Get-Module -ListAvailable`?

`Get-Module -ListAvailable` scans all directories in `$env:PSModulePath` on disk. `Get-Command` only queries what's already resolved in PATH — approximately **100ms faster**.

---

### Why Terminal-Icons is lazy loaded?

The module costs between 80ms and 150ms to import. Since icons only matter in interactive file exploration sessions, it's loaded on demand:

```powershell
# Load icons only when needed
icons
```

---

### Explicit UTF-8 encoding in `sed`

PS 5.1 uses `Default` encoding (ANSI/Windows-1252) and PS 7 uses UTF-8 without BOM by default in some operations. Without explicit `-Encoding UTF8`, files with special characters can be corrupted.

---

### Session cache in `pubip`

The first call to `pubip` queries `https://api.ipify.org` and stores the result in `$script:CachedPublicIP`. Subsequent calls return the in-memory value without a new network request.

---

### `$script:` scope on global variables

Variables like `$script:BootTimer`, `$script:StartupModules`, and `$script:CachedPublicIP` use the `$script:` scope explicitly to avoid collision with variables the user might define in their session.

---

### Why `;` and not `&&` for command chaining?

The `&&` operator (pipeline chain operator) was introduced in PowerShell 7.0. Since this profile declares compatibility with PS 5.1 (`#Requires -Version 5.1`), all chains use `;` (semicolon), which has worked since PS 1.0.

---

## 📖 Study Notes

### The profile is a script executed every startup

Everything in `Microsoft.PowerShell_profile.ps1` runs every time the terminal starts. If boot is slow, the culprit is almost always a heavy module being imported in a blocking way. Use the timer displayed at startup to identify the problem:

```
PS 7.6.1 · OMP:atomic, Zoxide  [143ms]   ← within target  ✅
PS 7.6.1 · OMP:atomic, Zoxide  [387ms]   ← acceptable     🟡
PS 7.6.1 · OMP:atomic, Zoxide  [543ms]   ← investigate    🔴
```

---

### Concepts covered in this profile

| Concept | Where it appears in the profile |
|---------|---------------------------------|
| Aliases | `gs`, `k9`, `cpy` — shortcuts for functions and cmdlets |
| Custom functions | `lazyg`, `sysinfo`, `mkcd` — reusable code blocks |
| Filter vs Function | `grep` uses `filter` for true streaming in the pipeline |
| `begin/process/end` | `clip` — fine-grained control of pipeline lifecycle |
| Lazy Loading | `icons` — on-demand import |
| Session cache | `pubip`, `$script:CachedPublicIP` — avoids repeated requests |
| Disk cache | `~\.cache_pwsh_plugins.ps1` — avoids reinitializing OMP/Zoxide |
| State caching | `$PSMajor`, `$IsAdmin` — avoids recalculation on each use |
| Explicit scope | `$script:` — isolates profile variables from user session |
| Atomic writes | `sed` — protects original against partial failures |
| External modules | PSReadLine, Terminal-Icons, Oh My Posh, Zoxide |
| Conditional execution | PS 7 features activated via `if ($PSMajor -ge 7)` |
| Chaining with `;` | `gcom`, `lazyg` — compatible with PS 5.1 and 7+ |

---

### Execution Policy on Windows

Unlike Linux, Windows blocks unsigned scripts by default. To enable profile execution and run unit tests:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 📁 Repository Structure

```
config-powershell7/
├── Microsoft.PowerShell_profile.ps1        # Main profile
├── Microsoft.PowerShell_profile.Tests.ps1  # Unit test suite
├── README.md                               # Portuguese documentation
├── README.en.md                            # English documentation
├── .gitignore                              # Git ignore rules
├── LICENSE                                 # MIT License (EN)
└── LICENÇA.pt-BR                           # MIT License (PT-BR)
```

---

*Revision: 2026-04 — PS 5.1+ / PS Core 7+ / Windows 10+*
