# Installation & Compatibility

## How Modularization Works

The profile uses a modular architecture for maintainability and organization. The main file `Microsoft.PowerShell_profile.ps1` acts as a **Loader**:

1.  It identifies the repository root via `$env:__PROFILE_REPO_ROOT` (set by the installer) or `$PSScriptRoot` as fallback.
2.  Automatically loads scripts from `modules/` via *dot-sourcing* in strict order: **config → cache → navigation → git → system → psreadline → text_utils**.
3.  Each module is wrapped in `try/catch` so a failure in one non-critical module does not block the rest of the profile.

> [!IMPORTANT]
> You must keep the `modules/`, `lib/`, and `Microsoft.PowerShell_profile.ps1` files together in the cloned repository for loading to work correctly.

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

> The profile automatically detects the platform and PowerShell version, enabling advanced PSReadLine features only on PS 7+.

---

## Installation

### One-Line Remote Install (recomendado)

```powershell
irm https://raw.githubusercontent.com/AndersonTavares0/config-powershell7/main/install.ps1 | iex
```

O script baixa e executa o instalador universal que:

1. **Eleva para Administrador** automaticamente (UAC)
2. **Instala dependências via WinGet** — PowerShell 7, Git, Oh My Posh, Zoxide, Alacritty
3. **Baixa o repositório** para `[Environment]::GetFolderPath('MyDocuments')\config-powershell7`
4. **Instala a FiraCode Nerd Font** via Shell API do Windows
5. **Configura o Alacritty** com tema Tokyo Night + FiraCode
6. **Configura o Windows Terminal** com FiraCode como fonte padrão
7. **Solicita seleção de tema** Oh My Posh (GUI dropdown ou CLI interativo)
8. **Baixa o tema OMP selecionado** (padrão: `jandedobbeleer`) com validação de download
9. **Linka o profile** via dot-source, configurando `$env:POSH_THEME`

> Caminhos dinâmicos com `[Environment]::GetFolderPath` — funciona com OneDrive ativado.
> Idempotente — pode rodar várias vezes sem quebrar.
> Tudo em blocos Try-Catch com mensagens em português.

### Prerequisites (instalação manual)

| Component | Installation | Required |
|---|---|---|
| **PowerShell 7+** | `winget install Microsoft.PowerShell` (Win)<br>`sudo dnf install powershell` (Fedora) | ✅ |
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

### Step 3: Automated Installation

> **Remote (recomendado):** `irm https://.../install.ps1 | iex`  
> **Windows:** Double-click `install.cmd` to launch the WPF GUI installer.  
> **CI/headless:** Use `.\install.ps1` or `.\setup.ps1`.

The installer writes a lightweight `$PROFILE` file that dot-sources the repository profile via `$env:__PROFILE_REPO_ROOT`. No symlinks.

**Remote install (qualquer máquina):**
```powershell
irm https://raw.githubusercontent.com/AndersonTavares0/config-powershell7/main/install.ps1 | iex
```

**WPF GUI (Windows):**
```powershell
.\setup.ps1
# or double-click install.cmd
```

**CLI terminal menu (fallback for non-interactive / CI):**
```powershell
.\setup.ps1 -CLI
```

**Legacy headless (CI):**
```powershell
.\install.ps1 -NonInteractive
```

The installer performs these steps:
1. **ExecutionPolicy** — sets `RemoteSigned` at `CurrentUser` scope (Windows only)
2. **Dependency installation** — WinGet packages (PS7, Git, Oh My Posh, Zoxide), Nerd Font, PS modules (Terminal-Icons, PSReadLine), and optional tools (Alacritty with Catppuccin Mocha, Chocolatey with custom sources, Scoop with custom buckets)
3. **Backup** — if an existing non-ours profile exists, backs it up with a unique timestamp
4. **Profile link** — writes the dot-source profile file to `$PROFILE`
5. **Cache setup** — generates TTL cache on first load

### install.cmd (batch/PowerShell híbrido)

O `install.cmd` funciona de duas formas:
- **Duplo clique** — executa como batch, chama PowerShell e baixa o `install.ps1` da internet
- **`irm install.cmd | iex`** — o conteúdo é interpretado como PowerShell, baixando e executando o `install.ps1`

---

### Manual Installation (Alternative)

If you prefer not to use the script:

1. **Unblock downloaded files:**
   ```powershell
   Get-ChildItem -Recurse *.ps1 | Unblock-File
   ```
2. **Link via Dot-Source:**
   Add the following lines to your `$PROFILE`:
   ```powershell
   $env:__PROFILE_REPO_ROOT = "C:\Path\To\Your\config-powershell7"
   . "C:\Path\To\Your\config-powershell7\Microsoft.PowerShell_profile.ps1"
   ```

---

## Uninstallation

To remove the profile and restore your previous environment:

1.  Navigate to the repository folder.
2.  Run the uninstall script:
    ```powershell
    .\uninstall.ps1
    ```

> **Windows:** You can also double-click `uninstall.cmd`.

The uninstaller:
- Detects whether `$PROFILE` was created by this project (only removes ours)
- Offers interactive backup restoration (newest first); use `-NonInteractive` to skip prompts
- Cleans up the plugin cache file (`~\.cache_pwsh_plugins.ps1` or XDG equivalent)
- Provides manual cleanup guidance for optional modules and tools

---

## Additional Configuration

### Oh My Posh Theme

During installation, you can select from curated themes via GUI dropdown or CLI prompt. The installer downloads the selected theme, validates it, and sets `$env:POSH_THEME` in your profile stub.

**Default theme:** `jandedobbeleer` (recommended)

**Available themes:** `jandedobbeleer`, `powerlevel10k_lean`, `powerlevel10k_modern`, `powerlevel10k_rainbow`, `atomic`

To change themes after installation, set `$env:POSH_THEME`:
```powershell
$env:POSH_THEME = 'powerlevel10k_lean'
```
The profile reads this variable at boot. Empty or unset = `atomic`.

Themes are stored at `$HOME\.poshthemes\{name}.omp.json` (Windows) or `$XDG_DATA_HOME/poshthemes/{name}.omp.json` (Linux).
