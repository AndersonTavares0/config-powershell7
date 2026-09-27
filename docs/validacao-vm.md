# Clean VM Validation Matrix (Windows 10/11 x64)

Manual complement to `.github/workflows/validate.yml`. Use disposable Windows
10 and Windows 11 x64 VMs. Snapshot each VM before testing. Restore snapshot
between scenarios. Do not mark expected results as passing until observed.

CI cannot cover OneDrive redirection, user-owned profiles, UAC decisions, or a
machine without WinGet. This matrix covers those states.

## 0. Baseline

1. Snapshot the clean VM with network on.
2. Record before state:
   ```powershell
   [Environment]::OSVersion.Version
   $env:PROCESSOR_ARCHITECTURE
   $PSVersionTable.PSVersion
   $PROFILE.CurrentUserAllHosts
   Get-ExecutionPolicy -List
   Get-Command winget, scoop, pwsh, oh-my-posh -ErrorAction SilentlyContinue
   ```

## 1. Double-click install (PS 5.1 entry)

1. Double-click `install.cmd`.
2. Expected: install completes; PowerShell 7 profile loads in a new `pwsh`
   (`Get-Command docs` resolves).
3. Expected: `Documents\WindowsPowerShell` was **not** configured; the managed
   block lives in `Documents\PowerShell\profile.ps1`.

## 2. WinGet and Scoop states

1. Test WinGet present. Run setup as standard user.
2. Expected: WinGet uses user scope first. Declining UAC leaves package
   uninstalled and does not stop other selected components.
3. Restore snapshot. Make WinGet unavailable, leave Scoop installed, and run setup.
4. Expected: mapped packages install through Scoop; Fastfetch and Topgrade use
   `extras` bucket.
5. Restore snapshot. Make both package managers unavailable.
6. Expected: CLI offers Scoop setup; declining it reports blocked dependencies
   and preserves profile and user settings.

## 3. Idempotency and convergence (issue #50)

1. Hash managed profile and config files.
2. Re-run the installer with identical selections.
3. Expected: hashes unchanged; no new `.bak*` files.
4. Change only the OMP or Windows Terminal theme, re-run.
5. Expected: only selected theme and managed profile block change.

## 4. Themes with no network

1. Install Oh My Posh, clone the repository, then disconnect the VM network.
2. Run `setup.ps1 -Gui`; observe theme list before online request can finish.
3. Expected: `atomic` and valid user themes appear immediately. GUI stays usable.
4. Restore network access, then select upstream theme. Block GitHub access and
   repeat.
5. Expected: upstream lookup ends within eight seconds; local themes remain in
   list. Theme preview also times out without freezing GUI indefinitely.

## 5. Existing user content

1. Roll back to snapshot. Seed `$PROFILE.CurrentUserAllHosts` with a custom
   function plus a path containing `'`, `$`, and Unicode.
2. Install, then uninstall via `uninstall.ps1 -NonInteractive`.
3. Expected: custom content present after install; managed block gone and custom
   content intact after uninstall.

## 6. OneDrive redirection

1. Roll back to snapshot. Redirect Documents to a OneDrive-style path (or an
   uninitialized/empty Known-Folder value).
2. Install.
3. Expected: managed repository lands under `LocalApplicationData`, never inside
   the redirected Documents; profile loads on a fresh logon.

## 7. Optional components

1. Install Fastfetch without Topgrade, then Topgrade without Fastfetch.
2. Expected: each selection installs only selected component and can be repeated.
3. Select each AI CLI separately; then select all.
4. Expected: existing commands are detected; one failed installer does not cancel
   other selected tools.
5. Expected: Oh My Posh uses bundled `atomic` without network and keeps custom
   themes in the user theme directory.

## 8. Failure visibility

1. Run the installer with an unreachable repository path.
2. Expected: non-zero exit; no partial managed state left active.
3. In the GUI, point the repository path at an unreadable location and install.
4. Expected: window reports failure and re-enables its controls; it never
   stays stuck on `Installing...`.

## 9. Restricted host

1. Roll back to snapshot. Run as a standard user, no administrator rights, with
   `Set-ExecutionPolicy AllSigned -Scope CurrentUser`.
2. Install.
3. Expected: FiraCode Nerd Font installs per user (present in
   `%LOCALAPPDATA%\Microsoft\Windows\Fonts` and under
   `HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts`), with no UAC prompt
   for the font step.
4. Expected: execution policy is reported as skipped and left
   unchanged; the install still reports overall success.
5. Expected: on a machine without Windows Terminal, color and font steps
   are skipped rather than failed.

## Sign-off

Record observed results per scenario before release: ______________ (date).
