# Installation & Compatibility

## How Modularization Works

The profile now uses a modular architecture to facilitate maintenance and organization. The main file `Microsoft.PowerShell_profile.ps1` acts as a **Loader**:

1.  It identifies the directory where the repository was cloned (`$PSScriptRoot`).
2.  Automatically loads scripts located in `modules/` via *dot-sourcing*.
3.  This ensures that each functionality (Git, System, Navigation) is in its own file, keeping the main profile clean and fast.

> [!IMPORTANT]
> Due to this structure, **you must keep the `modules/` folder in the same location as the profile file** for loading to work correctly.

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

---

### Step 1: Configure Execution Policy
Open PowerShell and run:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 2: Clone the repository
```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
```

### Step 3: Automated Installation (Zero-UAC)
The repository includes an intelligent script that automates the link creation without requiring Administrator privileges.

**Run in normal terminal:**
```powershell
.\install.ps1
```
*This script will safely dot-source your new profile in `$PROFILE` by explicitly injecting the repository path, backing up any old profile if it exists. It runs entirely in user-space without UAC prompts.*

---

### Manual Installation (Alternative)

If you prefer not to use the script, follow these steps:

1. **Unblock files:**
   ```powershell
   Get-ChildItem -Recurse *.ps1 | Unblock-File
   ```
2. **Link via Dot-Source:**
   Add the following line to your `$PROFILE`:
   ```powershell
   $global:__ProfileRepoRoot = "C:\Path\To\Your\config-powershell7"
   . "C:\Path\To\Your\config-powershell7\Microsoft.PowerShell_profile.ps1"
   ```

---

## Uninstallation

To remove the profile and restore your previous environment:

1.  Navigate to the repository folder.
2.  Run the uninstallation script:
    ```powershell
    .\uninstall.ps1
    ```
*The script will remove the symbolic link and offer the option to restore the backup (`.bak`) and clear the plugin cache.*

---

## Additional Configuration

### Oh My Posh Theme
The profile expects the theme at `$HOME\.poshthemes\atomic.omp.json`. 
```powershell
# Create directory and download theme
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh font install
```
