# Modules & Features

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


# Technical Reference

## Overview

`Microsoft.PowerShell_profile.ps1` is a startup profile for PowerShell 5.1+/7+ on Windows. It is automatically loaded in every new session via `$PROFILE` and has the following core objectives:

- Minimize boot time through plugin caching
- Expose a consistent set of utility aliases and functions
- Configure PSReadLine for an improved command-line editing experience
- Ensure robustness through error handling and explicit scoping

The file is structured into 9 numbered sections, clearly delimited by header comments.

---

## Profile Architecture

The profile is now modular, separating responsibilities into individual files that are imported by the main file.

```
config-powershell7/
├── .github/workflows/          # CI/CD Automation (GitHub Actions)
├── Microsoft.PowerShell_profile.ps1    # Main Loader
├── install.ps1                 # Automated installation script
├── tests/                      # Unit testing suite
└── modules/
    ├── cache/
    │   └── cache.ps1                   # Zoxide, Oh-My-Posh, Terminal-Icons
    ├── git/
    │   └── git.ps1                     # Git aliases and functions
    ├── navigation/
    │   └── navigation.ps1              # Navigation aliases (up, mkcd, la)
    ├── system/
    │   ├── psreadline.ps1              # PSReadLine config and keybindings
    │   └── system.ps1                  # Sudo, processes, DNS, IP
    └── text_utils/
        └── text_utils.ps1              # Touch, unzip, sed, grep, clipboard
```

---

## Startup Flow

The execution order when opening a new session:

```
1. PowerShell loads $PROFILE automatically (Microsoft.PowerShell_profile.ps1).
2. The Loader starts the boot stopwatch and defines $script: variables.
3. The Loader loads all submodules using dot-sourcing (. "$moduleDir/..."):
   ├── cache.ps1: Checks/loads Zoxide and Oh-My-Posh cache.
   ├── psreadline.ps1: Configures terminal and history prediction.
   ├── navigation.ps1: Adds directory shortcuts.
   ├── text_utils.ps1: Adds file manipulation functions.
   ├── system.ps1: OS functions and Sudo.
   └── git.ps1: Loads Git functions (only if 'git' is in PATH).
4. The Loader stops the stopwatch and displays the boot summary.
```

> The function and alias definitions (step 3) are nearly instantaneous. The real boot cost is in the cache (`cache.ps1`).

---

## Plugin Caching System

### Purpose

Avoid the startup cost of `zoxide init powershell` and `oh-my-posh init pwsh` on every session. Each adds ~100ms to boot time.

### Implementation

**Fingerprint (Get-PluginFingerprint):**

```powershell
$zcmd = Get-Command zoxide -ErrorAction SilentlyContinue
$ocmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
$parts = @(
    if ($zcmd) { $zcmd.Source } else { $null }
    if ($ocmd) { $ocmd.Source } else { $null }
    $script:ThemePath
    [int](Test-Path $script:ThemePath)
)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($parts -join '|')
$md5   = [System.Security.Cryptography.MD5]::Create()
try    { [System.BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '' }
finally{ $md5.Dispose() }
```

The fingerprint is derived from binary paths and the existence of the theme file. Any change (tool update, theme switch) invalidates the cache.

**Regeneration (Update-PluginCache):**

The cache is a dynamically generated `.ps1` file built via `StringBuilder`. It contains:
- Zoxide initialization code (`zoxide init powershell`)
- Oh My Posh initialization code (with specific theme if it exists, or default)
- `$script:StartupModules.Add(...)` lines for the boot summary

**Loading:**

```powershell
if ($script:CachedFP -ne $script:CurrentFP) { script:Update-PluginCache }
if (Test-Path $script:CachePath)             { . $script:CachePath }
```

### Cache location

```
$HOME\.cache_pwsh_plugins.ps1
```

### Manual invalidation

```powershell
Clear-PluginCache  # alias: Clear-Cache
# Restart the terminal
```

---

## Module Management

### Terminal-Icons

Loaded on demand via `Import-TerminalIcons` function (alias: `icons`). Checks if already loaded before importing to prevent double-loading:

```powershell
if (Get-Module Terminal-Icons) { return }
Import-Module Terminal-Icons -ErrorAction SilentlyContinue
```

### PSReadLine

Checked with `Get-Command Set-PSReadLineOption` before configuring — if unavailable, the block is silently skipped. Features conditional on PS 7+:

```powershell
if ($script:PSMajor -ge 7) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
}
```

### Zoxide and Oh My Posh

Initialized via cache. `Update-PluginCache` checks availability with `Get-Command` before including in the cache.

---

## Aliases — Technical View

| Alias | Target | Rationale |
|---|---|---|
| `Clear-Cache` | `Clear-PluginCache` | PS-idiomatic name (`Verb-Noun`) kept as primary; alias for convenience |
| `icons` | `Import-TerminalIcons` | Shorthand for interactive use |
| `cpy` | `Copy-ToClipboard` | Equivalent to Unix `xclip`/`pbcopy` |
| `k9` | `pkill` | Container/CLI convention (SIGKILL = 9) |
| `gss` | `gst` | Mnemonic alternative for `git status --short` |

**Note on `gcm`:** The alias `gcm` was intentionally avoided as it is a native PowerShell alias for `Get-Command`. The function uses `gcmt` to prevent collision.

**Note on `gs`:** The alias `gs` was avoided as it may collide with `Get-Service` in PS 5.1 environments.

---

## Functions — Technical Detail

### Section 4: Navigation

**`mkcd`**
- `[Parameter(Mandatory)]` — enables tab completion and prevents no-argument calls
- Uses `try/catch` with `Write-Error` instead of unhandled `New-Item`
- `-Force` on `New-Item` creates intermediate directories

**`nf`**
- Accepts `ValueFromPipeline` — allows `"file.txt" | nf`
- Processed in `process {}` block to support multiple pipeline items

### Section 5: Files and Text

**`touch`**
- If file exists: updates `LastWriteTime` via `(Get-Item $File).LastWriteTime = Get-Date`
- If not: creates with `New-Item -ItemType File -Force`
- Accepts `ValueFromPipeline`

**`which`**
- Uses `(Get-Command $Cmd -ErrorAction SilentlyContinue).Source`
- Emits `Write-Warning` if not found (no exception thrown)

**`unzip`**
- Default destination: `.` (current directory)
- Uses `Expand-Archive` with `-Force` (overwrites)
- `try/catch` with `Write-Error` on failure

**`head` / `tail`**
- `head`: `Get-Content -TotalCount $Lines`
- `tail`: `Get-Content -Tail $Lines`
- `-Lines` parameter with default value `10`

**`grep`**
- Implemented as `filter` (not `function`) — optimized for pipeline, processes line by line
- Uses `Select-String -Pattern $Pattern`

**`Copy-ToClipboard` (cpy)**
- Implemented with `begin/process/end` for correct pipeline accumulation
- Uses `StringBuilder` for efficiency
- `$null` explicitly ignored in `process {}`
- `TrimEnd()` on final result removes trailing newlines

**`sed`**
- Reads with `[System.IO.File]::ReadAllText` with UTF8+BOM encoding (compatible with PS 5.1 and 7)
- Writes to a temporary `.tmp` file in the same directory as the target
- `Move-Item` from `.tmp` to target = atomic OS-level rename operation
- Optional `-Backup` creates a `.bak` before replacement
- `.tmp` cleanup in `catch` prevents orphaned files

### Section 6: System

**`pgrep`**
- Uses `Where-Object { $_.ProcessName -like "*$Name*" }` instead of `-Name` directly, because `Get-Process -Name` does not accept mid-string wildcards
- Displays: Id, ProcessName, CPU, Mem(MB) formatted

**`pubip`**
- Cache in `$script:CachedPublicIP` — avoids multiple requests per session
- `-Force` bypasses cache and fetches fresh value
- 3 fallback endpoints: `api.ipify.org`, `icanhazip.com`, `ifconfig.me/ip`
- 3-second timeout per endpoint
- Catches `[System.Net.WebException]` separately for better diagnostics

**`sysinfo`**
- Primary: `Get-CimInstance Win32_OperatingSystem` + `Win32_ComputerSystem`
- Fallback (if CIM fails): reads `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion`
- Returns `PSCustomObject` with fields: Computer, User, OS, PS, Uptime, RAM_GB

**`flushdns`**
- Checks `$script:IsAdmin` before executing `Clear-DnsClientCache`
- Silent failure with `Write-Warning` if not Admin

### Section 7: Git

**`gcom`**
- Checks `$LASTEXITCODE` after `git add .` — if it fails, does not execute the commit

**`lazyg`**
- Detects interactive environment via `[Environment]::UserInteractive` and `$env:CI`, `$IsLinux`, `$IsMacOS`
- In non-interactive environments (CI, Linux, macOS): skips confirmation (or requires `-Force`)
- Uses `[Console]::ReadLine()` instead of `ReadKey()` — compatible with environments without an interactive console
- Checks `$LASTEXITCODE` after `git add` and `git commit` — failure at any step aborts the rest

### Section 8: Sudo

**`sudo`**
- Detects `!!` as a special argument and replaces it with the last history command (`Get-History -Count 1`)
- Selects `pwsh` (PS 7+) or `powershell` (PS 5.1) based on `$script:PSMajor`
- Uses `-EncodedCommand` with Unicode Base64 to preserve quotes and special characters in complex commands
- Without arguments: opens a new empty elevated session

---

## Security and Robustness

### Explicit `$script:` scope

All variables shared between functions use explicit `$script:`, preventing leakage into the user session's global scope and avoiding ambiguity in function contexts.

### `script:`-scoped functions

`Get-PluginFingerprint` and `Update-PluginCache` are declared as `function script:...`, making them invisible to end users and limiting their scope to the profile file.

### Guaranteed Dispose

The MD5 object in `Get-PluginFingerprint` uses `try/finally` to guarantee `Dispose()` even on exception, preventing unmanaged resource leaks.

### Boot summary in scriptblock

Section 9 runs inside `& { ... }` so local variables (`$ms`, `$color`, `$plugins`, `$admin`) do not leak into the user session.

### Error handling

- `try/catch` in functions with side effects (`mkcd`, `unzip`, `sed`, `sysinfo`, `lazyg`)
- `Write-Error` for fatal function errors
- `Write-Warning` for warning conditions (no permission, endpoint unavailable)
- `Write-Verbose` for diagnostic information (no noise in normal output)
- `-ErrorAction SilentlyContinue` on `Get-Command` and other existence checks

### ExecutionPolicy

The profile requires `RemoteSigned` or higher at `CurrentUser` scope. Downloaded files must be unblocked with `Unblock-File` to avoid the digital signature error.

### Sudo and privileges

`flushdns` checks `$script:IsAdmin` before executing. `sudo` uses `Start-Process -Verb RunAs` to request UAC elevation, without storing credentials.

---

## Compatibility

| Scenario | Behavior |
|---|---|
| PS 5.1, without updated PSReadLine | PSReadLine configured without history prediction |
| PS 7+, with PSReadLine | History prediction enabled with ListView |
| No git in PATH | Entire section 7 skipped; `Write-Verbose` logs the reason |
| Without Zoxide | Cache generated without Zoxide initialization |
| Without Oh My Posh | Cache generated without Oh My Posh initialization |
| Without `atomic.omp.json` theme | Oh My Posh uses default theme automatically |
| Linux/macOS (PS Core) | `lazyg` skips interactive confirmation; `df` and `flushdns` may fail |
| CI environment (`$env:CI`) | `lazyg` detects and skips interactive confirmation |

---

## Performance

### Reference measurements

| Scenario | Expected boot time |
|---|---|
| Without Oh My Posh / Zoxide, valid cache | < 100ms |
| With Oh My Posh + Zoxide, valid cache | < 200ms |
| With Oh My Posh + Zoxide, cache miss | < 400ms (single regeneration) |

### Applied techniques

| Technique | Where | Impact |
|---|---|---|
| Plugin initialization cache | Section 2 | ~200ms saved per session |
| Incremental MD5 fingerprint | `Get-PluginFingerprint` | Invalidates cache only when necessary |
| `StringBuilder` for cache generation | `Update-PluginCache` | Avoids string concatenation in loop |
| `StringBuilder` in `Copy-ToClipboard` | Section 5 | Efficiency in long pipelines |
| Single-line cache read | Section 2 (`-TotalCount 1`) | Avoids reading entire file to verify fingerprint |
| Conditional Git loading | Section 7 | Avoids failure if git not installed |
| `filter` for `grep` | Section 5 | Line-by-line processing without buffering |
| `[System.IO.File]` for `sed` | Section 5 | Consistent encoding between PS 5.1 and 7 |

---
---

## Automated Testing and CI

The project includes a unit testing suite to ensure that functions and aliases work as expected across different PowerShell versions.

### Local Testing Suite
Tests are located in `tests/Microsoft.PowerShell_profile.Tests_diff.ps1`. They verify:
- Profile loading without errors.
- Navigation functionality (`up`, `home`, `mkcd`).
- File and text operations (`touch`, `nf`, `head`, `tail`).
- Existence of critical aliases and system functions.

To run tests locally:
```powershell
pwsh -c "./tests/Microsoft.PowerShell_profile.Tests_diff.ps1 -Verbose"
```

### GitHub Actions (CI)
The repository uses **GitHub Actions** to automatically validate every push or pull request.
- **Environment:** Tests run on **Windows Server** instances (`windows-latest`).
- **Validation:** Ensures that code changes do not break initialization or core functions in clean environments.
- **Badge:** The current test status can be viewed at the top of the `README.md`.
