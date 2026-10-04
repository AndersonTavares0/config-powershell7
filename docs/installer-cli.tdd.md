# Installer and CLI TDD Evidence

## User journeys

- Run setup in a terminal without opening WPF by default.
- Choose Fastfetch and Topgrade independently.
- Select optional coding-agent CLIs and install only selected tools.
- Select bundled `atomic` or a custom Oh My Posh theme without overwriting user files.
- Install PowerShell 7 and dependencies in user scope; approve elevation only after user-scope failure.
- Continue setup when WinGet is missing by choosing per-user Scoop.

## RED and GREEN evidence

| Behavior | RED evidence | GREEN evidence |
|---|---|---|
| Agent CLI metadata | `Setup.Tests.ps1` reported `Get-AgentCliInstallSpec is missing`. | Catalog and official-source assertions pass. |
| Agent CLI installer dispatch | `Install-AgentCli` was not recognized by the setup test. | Mocked installer receives selected tool; all four sources and commands match documented vendor instructions. |
| OMP theme validation | `Setup.Tests.ps1` reported `Test-OmpThemeFile is missing`. | Bundled theme validates; invalid JSON structure is rejected. `oh-my-posh init pwsh --config .\themes\atomic.omp.json` generated a shell-init script successfully. |
| OMP custom-file preservation | Test exposed that an invalid existing custom file was removed after a failed download. | Installer now refuses to replace invalid existing files; regression checks confirm file content remains unchanged. |
| CLI menu index parsing | `Setup.Tests.ps1` reported `ConvertFrom-MenuIndex is missing`. | Valid, non-numeric, and out-of-range choices pass focused checks. |
| WinGet user scope | `Setup.Tests.ps1` reported `Get-WingetPackageArguments is missing`. | Argument tests confirm user scope and agreement flags; no machine scope is requested by default. |
| Scoop fallback mapping | `Setup.Tests.ps1` reported `Get-ScoopPackageName is missing`. | PowerShell and Fastfetch package mappings pass; unknown IDs return no mapping. |
| Local OMP catalog | `Setup.Tests.ps1` reported `Get-LocalOmpThemeList is missing`. | Bundled `atomic` and valid user themes appear offline; invalid theme files stay hidden. |
| Online theme failures | Offline `Invoke-RestMethod` mock forces catalog failure. | CLI keeps local themes; GUI displays local themes before an 8-second online timeout. |
| Environment diagnostics | `Setup.Tests.ps1` reported `Get-InstallerEnvironment is missing`; first implementation exposed unset admin state under strict mode. | Report now includes OS, architecture, PowerShell, elevation, WinGet, Scoop, Node.js, and npm. |
| Isolated provider fallback | Missing WinGet is forced with a mock; no host package manager is used. | Installer forwards package ID to Scoop fallback. |
| PowerShell executable discovery | Candidate paths include a missing file and a temporary fake executable. | Resolver skips missing paths, returns the first existing path, and handles no match. |
| Strict-mode OMP startup | Current Oh My Posh init failed when `_ompInitialized` was unset. | Cache initializes OMP guard only when needed; profile integration passes. |

## Verification

- `pwsh -NoProfile -File .\tests\Unit.Tests.ps1`: 126 passed.
- `pwsh -NoProfile -File .\tests\ThemeOverride.Tests.ps1`: 6 passed.
- `pwsh -NoProfile -File .\tests\Setup.Tests.ps1`: 202 passed.
- `Microsoft.PowerShell_profile.Tests.ps1`: 81 passed when `$PROFILE` points to this repository's profile.
- `Test-ProfileInstallation.ps1 -Detailed`: 68 passed, 0 failed, 1 performance warning (535 ms vs 200 ms target).
- WPF XAML loaded; optional installer controls resolve. GUI shows local themes before online lookup; online list and preview use 8-second timeouts.
- PowerShell parser checked 28 `.ps1` files with no syntax errors.
- `git diff --check`: passed.
- Security audit: passed; no critical code findings.

## Known verification gaps

- Repository has no `package.json` or coverage instrumentation. Coverage percentage is unavailable; the custom PowerShell suites report assertions only.
- PSScriptAnalyzer is not installed in this environment. CI installs and runs it.
- Package-manager fallback and official agent installers were not executed against a clean disposable Windows VM. Unit tests mock installer dispatch; VM validation remains required before release.
- CodeScene MCP is unavailable, so no structural Code Health score was produced.
- Issues remain open until changes are reviewed and merged. No PR was opened.
