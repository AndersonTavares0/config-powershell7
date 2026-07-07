# Installation & Compatibility

## How Modularization Works

The profile uses a modular architecture for maintainability and organization.
The main file `Microsoft.PowerShell_profile.ps1` acts as a **Loader**:

1.  It identifies the repository root via `$env:__PROFILE_REPO_ROOT` (set by
    the installer) or `$PSScriptRoot` as fallback.
2.  Automatically loads scripts from `modules/` via *dot-sourcing* in strict
    order: **config -> cache -> navigation -> git -> system -> psreadline ->
    text_utils**.
3.  Each module is wrapped in `try/catch` so a failure in one non-critical
    module does not block the rest.

> [!IMPORTANT]
> You must keep the `modules/`, `lib/`, and
> `Microsoft.PowerShell_profile.ps1` files together in the cloned repository
> for loading to work correctly.

---

## Compatibility

| Component | Minimum Version |
|---|---|
| Windows | 10 or higher |
| Linux | Fedora (any modern distro with PS 7+) |
| macOS | Any version with PS 7+ |
| PowerShell | 5.1+ (full features on PS 7+) |
| Oh My Posh | Any current version (optional) |
| Zoxide | Any current version (optional) |

> The profile automatically detects the platform and PowerShell version,
> enabling advanced PSReadLine features only on PS 7+.

---

## Installation

### One-Line Remote Install (recommended)

```powershell
irm https://github.com/AndersonTavares0/config-powershell7/raw/main/setup.ps1 | iex
```

The script detects whether you are in an interactive terminal and launches
either the WPF GUI (Windows) or the CLI menu. It performs the following:

1.  **Elevates to Administrator** automatically (UAC on Windows)
2.  **Installs dependencies via WinGet** — PowerShell 7, Git, Oh My Posh,
    Zoxide
3.  **Downloads the repository** to
    `[Environment]::GetFolderPath('MyDocuments')\config-powershell7`
4.  **Installs FiraCode Nerd Font** via Shell API
5.  **Configures Windows Terminal** with FiraCode as default font
6.  **Prompts for OMP theme selection** — live list fetched from GitHub API
    with search and preview
7.  **Prompts for terminal color theme** — choose from Catppuccin Mocha/Latte,
    Dracula, Nord, Tokyo Night, One Half Dark for Windows Terminal and/or
    Alacritty
8.  **Downloads the selected OMP theme** with validation
9.  **Optionally installs Alacritty**, Topgrade (universal package updater),
    and Scoop
10. **Links the profile** via dot-source, configuring `$env:POSH_THEME`

> Dynamic paths via `[Environment]::GetFolderPath` — works with OneDrive.
> Idempotent — safe to run multiple times.
> Blocks wrapped in Try-Catch with clear messages.

### Prerequisites (manual installation)

| Component | Installation | Required |
|---|---|---|
| **PowerShell 7+** | `winget install Microsoft.PowerShell` (Win)<br>`sudo dnf install powershell` (Fedora) | Yes |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com)<br>Recommended: FiraCode Nerd Font | Yes |
| **Git** | `winget install Git.Git` | Yes |
| **Oh My Posh** | `winget install JanDeDobbeleer.OhMyPosh` | Optional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Optional |
| **PSReadLine** | Included in PS 7<br>Update: `Install-Module PSReadLine -Force` | Yes |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Optional |

---

### Step 1: Configure Execution Policy

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 2: Clone the repository

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
```

### Step 3: Automated Installation

> **Remote (recommended):** `irm https://.../setup.ps1 | iex`
>
> **Windows GUI:** Double-click `install.cmd` or run `.\setup.ps1`
>
> **CLI menu:** `.\setup.ps1 -CLI`
>
> **Legacy headless:** `.\install.ps1 -NonInteractive`

The installer writes a lightweight `$PROFILE` file that dot-sources the
repository profile via `$env:__PROFILE_REPO_ROOT`. No symlinks.

The installer performs these steps:
1.  **ExecutionPolicy** — sets `RemoteSigned` at `CurrentUser` scope
2.  **Dependency installation** — winget packages (PS7, Git, Oh My Posh,
    Zoxide), Nerd Font, PS modules (Terminal-Icons, PSReadLine), and optional
    Alacritty, Topgrade, Scoop
3.  **Theme selection** — OMP theme fetched from GitHub API, terminal color
    theme chosen from curated list
4.  **Backup** — if an existing non-ours profile exists, backs it up with a
    unique timestamp
5.  **Profile link** — writes the dot-source profile file to `$PROFILE`
6.  **Cache setup** — generates TTL cache on first load

> **Chocolatey** is no longer in the GUI flow but remains available via the
> legacy `install.ps1 -NonInteractive`.

### install.cmd (batch/PowerShell hybrid)

`install.cmd` works in two ways:
- **Double-click** — runs as batch, calls PowerShell to download and execute
  `setup.ps1` from the web
- **`irm install.cmd | iex`** — content is interpreted as PowerShell, running
  the setup script

---

### Manual Installation (Alternative)

If you prefer not to use the script:

1.  **Unblock downloaded files:**
    ```powershell
    Get-ChildItem -Recurse *.ps1 | Unblock-File
    ```

2.  **Link via Dot-Source:**
    Add these lines to your `$PROFILE`:
    ```powershell
    $env:__PROFILE_REPO_ROOT = "C:\Path\To\Your\config-powershell7"
    . "C:\Path\To\Your\config-powershell7\Microsoft.PowerShell_profile.ps1"
    ```

3.  **Set an OMP theme (optional):**
    ```powershell
    $env:POSH_THEME = 'jandedobbeleer'
    ```

---

## Uninstallation

1.  Navigate to the repository folder.
2.  Run the uninstall script:
    ```powershell
    .\uninstall.ps1
    ```

> **Windows:** Double-click `uninstall.cmd`.

The uninstaller:
- Detects whether `$PROFILE` was created by this project (only removes ours)
- Offers interactive backup restoration (newest first); use `-NonInteractive`
  to skip prompts
- Cleans up the plugin cache file (`~\.cache_pwsh_plugins.ps1` or XDG
  equivalent)
- Provides manual cleanup guidance for optional tools

---

## Additional Configuration

### Oh My Posh Theme

During installation, you can select from the full list of OMP themes fetched
live from the GitHub API. The installer downloads the selected theme, validates
it, and sets `$env:POSH_THEME` in your profile stub.

To change themes after installation:

```powershell
$env:POSH_THEME = 'montys'
```

The profile reads this variable at boot. Empty or unset falls back to
`atomic` (included with the repo). Themes are stored in
`$HOME\.poshthemes\{name}.omp.json` (Windows) or
`$XDG_DATA_HOME/poshthemes/{name}.omp.json` (Linux/macOS).

### Terminal Color Theme

During installation you can apply a terminal color scheme to Windows Terminal,
Alacritty, or both. Available themes:
- Catppuccin Mocha (dark)
- Catppuccin Latte (light)
- Dracula (dark)
- Nord (dark)
- Tokyo Night (dark)
- One Half Dark (dark)
