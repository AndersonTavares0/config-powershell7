# VM Validation Checklist (Windows 11 x64)

Manual complement to `.github/workflows/validate.yml`. Runners cannot cover
clicked-through GUI, real OneDrive redirection, or legacy user state — this
checklist does. Run against a disposable VM with a snapshot taken **before**
step 1. Roll back to the snapshot between sections.

Conventions: `[PASS]` means the exact expected result was observed. Any
deviation stops the section and blocks release.

## 0. Baseline

1. Snapshot the clean VM (Windows 11 x64, network on).
2. Record before state:
   ```powershell
   $PSVersionTable.PSVersion
   $PROFILE.CurrentUserAllHosts
   Get-ExecutionPolicy -List
   winget --version
   ```

## 1. Double-click install (PS 5.1 entry)

1. Double-click `install.cmd`.
2. [PASS] Full install completes; PowerShell 7 profile loads in a new `pwsh`
   (`Get-Command docs` resolves).
3. [PASS] `Documents\WindowsPowerShell` was **not** configured; the managed
   block lives in `Documents\PowerShell\profile.ps1`.

## 2. Idempotency and convergence (issue #50)

1. Hash managed files (profile, `%APPDATA%\alacritty` tree).
2. Re-run the installer with identical selections.
3. [PASS] Hashes unchanged, no new `.bak*` files.
4. Change only the OMP/Alacritty theme, re-run.
5. [PASS] Only theme fragments and the managed profile block changed.

## 3. Existing user content

1. Roll back to snapshot. Seed `$PROFILE.CurrentUserAllHosts` with a custom
   function plus a path containing `'`, `$`, and Unicode.
2. Install, then uninstall via `uninstall.ps1 -NonInteractive`.
3. [PASS] Custom content present after install; managed block gone and custom
   content intact after uninstall.

## 4. OneDrive redirection

1. Roll back to snapshot. Redirect Documents to a OneDrive-style path (or an
   uninitialized/empty Known-Folder value).
2. Install.
3. [PASS] Managed repository lands under `LocalApplicationData`, never inside
   the redirected Documents; profile loads on a fresh logon.

## 5. Alacritty lifecycle

1. Case A — clean machine: [PASS] exe `>= 0.14`, absolute `pwsh.exe` in
   `base.toml`, Nerd Font configured, imports order base → theme → user.
2. Case B — pre-existing `alacritty.toml`: [PASS] preserved as
   `alacritty.user.toml`, exactly one backup, user settings win.
3. Case C — legacy `alacritty.yml` only: [PASS] migrated, original YAML
   untouched.
4. Uninstall: [PASS] wrapper restored/removed, owned `config-powershell7`
   directory gone.

## 6. Failure visibility

1. Run the installer with an unreachable repository path.
2. [PASS] Non-zero exit, no partial managed state left active.

## Sign-off

All boxes `[PASS]` on a clean snapshot per section: ______________ (date).
