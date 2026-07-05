# Unit Tests for Module-Internal Logic

## Problem Statement

The project has three test layers (integration, setup TDD, post-install health check) but all load the full profile and test end-to-end. Functions with rich internal logic — cache rebuild decisions, fingerprint computation, sudo sanitization, sed validation, pubip cache fallback, git LASTEXITCODE branching — have zero isolated coverage. Bugs in these paths are only caught at integration time, making diagnosis harder.

## Goals

- [ ] Add isolated unit tests for each module's internal logic without loading the full PowerShell profile
- [ ] Each sub-suite runs in <100ms with zero external dependencies (no git, oh-my-posh, network)
- [ ] Tests assert behavior, not implementation; edge cases > happy path

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Integration/E2E tests | Already covered by `Microsoft.PowerShell_profile.Tests.ps1` |
| Setup module tests | Already covered by `Setup.Tests.ps1` |
| Post-install health checks | Already covered by `Test-ProfileInstallation.ps1` |
| Performance benchmarks | Already covered by `benchmark.ps1` |
| Module refactoring | Tests only; no source module changes |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Mock strategy | Function-scope overrides + temp files | Modules are dot-sourced; no DI container. Override `Get-Command`, `Get-Item`, `Invoke-RestMethod`, `git` at script scope before dot-source. Temp files for file ops. | y |
| Test location | `tests/Unit.Tests.ps1` (single monolithic file) | Consistent with existing pattern (`Microsoft.PowerShell_profile.Tests.ps1`, `Setup.Tests.ps1`) | y |
| `script:Initialize-PluginCache` auto-run at end of cache.ps1 | Set up mocks so it runs silently | Avoids modifying source files. Mocks return $null for zoxide/omp, temp cache dir | y |
| Framework | Inline `Test-Result`, `Assert-*` functions | Same pattern as existing test files — no Pester dependency | y |

---

## User Stories

### P1: Cache Module Tests ⭐ MVP

**Why P1**: Cache module boots on every profile load; fingerprint/decision-tree bugs cause silent failures.

**Acceptance Criteria**:

1. WHEN `Get-PluginFingerprint` is called with both cmd objects THEN SHALL return delimited string containing paths and versions
2. WHEN `Get-PluginFingerprint` is called with $null cmd objects THEN SHALL omit those sections
3. WHEN `Get-PluginFingerprint` encounters Get-Item failure THEN SHALL return 'unknown'/'0' for version
4. WHEN `Get-ThemeFingerprint` is called and theme file exists THEN SHALL include Length:LastWriteTimeTicks
5. WHEN `Get-ThemeFingerprint` is called and theme file doesn't exist THEN SHALL omit file details
6. WHEN `Get-ThemeFingerprint` encounters Get-Item error THEN SHALL return 'nofile'
7. WHEN `Update-PluginCache` is called with no binaries THEN SHALL write header-only cache
8. WHEN `Update-PluginCache` fails to write cache THEN SHALL warn (no throw)
9. WHEN `Initialize-PluginCache` finds valid cache within TTL THEN SHALL dot-source cache (hot path)
10. WHEN `Initialize-PluginCache` finds expired cache with matching fingerprint THEN SHALL update timestamp, skip rebuild
11. WHEN `Initialize-PluginCache` finds expired cache with different fingerprint THEN SHALL rebuild
12. WHEN `Initialize-PluginCache` finds no cache THEN SHALL create it
13. WHEN `Clear-PluginCache` is called THEN SHALL remove cache file
14. WHEN `Import-TerminalIcons` is called THEN SHALL run without error

### P2: System Module Tests

**Why P2**: sudo sanitization is a security boundary; pubip fallback logic affects UX.

**Acceptance Criteria**:

1. WHEN `pubip` is called with valid cache (<5 min) THEN SHALL return cached IP without network
2. WHEN `pubip` is called with expired cache THEN SHALL query endpoints
3. WHEN `pubip` endpoint1 fails THEN SHALL fallback to endpoint2, then endpoint3
4. WHEN `pubip` all endpoints fail THEN SHALL write ErrorRecord
5. WHEN `pubip -Force` is called THEN SHALL bypass cache
6. WHEN `sudo` is called with !! and history exists THEN SHALL use last command
7. WHEN `sudo` is called with !! and no history THEN SHALL return silently
8. WHEN `sudo` sanitization removes null bytes/control chars THEN SHALL clean command
9. WHEN `sudo` sanitization results in empty command THEN SHALL write ErrorRecord
10. WHEN `sudo` is called with normal command THEN SHALL encode and launch process

### P2: Text Utils Tests

**Why P2**: sed is used for file modification with backup/rollback; file validation protects against data loss.

**Acceptance Criteria**:

1. WHEN `sed` is called with non-existent file THEN SHALL write ErrorRecord
2. WHEN `sed` is called with file >50MB THEN SHALL write ErrorRecord
3. WHEN `sed` is called with valid inputs THEN SHALL replace content atomically
4. WHEN `sed` is called with -Backup THEN SHALL create .bak copy
5. WHEN `sed` encounters write error THEN SHALL clean up tmp file
6. WHEN `Copy-ToClipboard` receives pipeline input THEN SHALL concatenate with newlines
7. WHEN `Copy-ToClipboard` receives $null in pipeline THEN SHALL skip it
8. WHEN `touch` is called on existing file THEN SHALL update timestamp
9. WHEN `touch` is called on non-existent file THEN SHALL create it

### P3: Git Module Tests

**Why P3**: Git LASTEXITCODE branching is used in gcom and lazyg; undetected failures propagate silently.

**Acceptance Criteria**:

1. WHEN `gcom` is called and git add fails THEN SHALL warn and return
2. WHEN `gcom` is called and git commit fails THEN SHALL warn
3. WHEN `gcom` is called and both succeed THEN SHALL complete silently
4. WHEN `lazyg` is called with -Force THEN SHALL skip interactive confirmation
5. WHEN `lazyg` git add fails THEN SHALL warn and return before commit
6. WHEN `lazyg` git commit fails THEN SHALL warn and return before push
7. WHEN `lazyg` git push fails THEN SHALL warn
8. WHEN `Test-InteractiveSession` detects CI=true THEN SHALL return $false
9. WHEN `Test-InteractiveSession` is called in interactive Windows console (no CI) THEN SHALL return $true

---

## Requirements

| ID | Description | Priority | Status |
| -- | ----------- | -------- | ------ |
| CACHE-01 | Get-PluginFingerprint with cmd objects | P1 | Pending |
| CACHE-02 | Get-PluginFingerprint with null cmds | P1 | Pending |
| CACHE-03 | Get-PluginFingerprint on Get-Item failure | P1 | Pending |
| CACHE-04 | Get-ThemeFingerprint with file | P1 | Pending |
| CACHE-05 | Get-ThemeFingerprint without file | P1 | Pending |
| CACHE-06 | Get-ThemeFingerprint on error | P1 | Pending |
| CACHE-07 | Update-PluginCache no binaries | P1 | Pending |
| CACHE-08 | Update-PluginCache write failure | P1 | Pending |
| CACHE-09 | Initialize-PluginCache hot path | P1 | Pending |
| CACHE-10 | Initialize-PluginCache expired + matching fp | P1 | Pending |
| CACHE-11 | Initialize-PluginCache expired + different fp | P1 | Pending |
| CACHE-12 | Initialize-PluginCache no cache | P1 | Pending |
| CACHE-13 | Clear-PluginCache | P1 | Pending |
| CACHE-14 | Import-TerminalIcons early return | P1 | Pending |
| SYS-01 | pubip valid cache return | P2 | Pending |
| SYS-02 | pubip expired cache query | P2 | Pending |
| SYS-03 | pubip endpoint fallback chain | P2 | Pending |
| SYS-04 | pubip all endpoints fail | P2 | Pending |
| SYS-05 | pubip -Force bypass cache | P2 | Pending |
| SYS-06 | sudo !! with history | P2 | Pending |
| SYS-07 | sudo !! without history | P2 | Pending |
| SYS-08 | sudo sanitization | P2 | Pending |
| SYS-09 | sudo empty after sanitization | P2 | Pending |
| SYS-10 | sudo normal command | P2 | Pending |
| TEXT-01 | sed file not found | P2 | Pending |
| TEXT-02 | sed file too large | P2 | Pending |
| TEXT-03 | sed valid replace | P2 | Pending |
| TEXT-04 | sed with backup | P2 | Pending |
| TEXT-05 | sed tmp cleanup | P2 | Pending |
| TEXT-06 | Copy-ToClipboard pipeline | P2 | Pending |
| TEXT-07 | Copy-ToClipboard null skip | P2 | Pending |
| TEXT-08 | touch existing file | P2 | Pending |
| TEXT-09 | touch new file | P2 | Pending |
| GIT-01 | gcom add fails | P3 | Pending |
| GIT-02 | gcom commit fails | P3 | Pending |
| GIT-03 | gcom both succeed | P3 | Pending |
| GIT-04 | lazyg -Force skip confirm | P3 | Pending |
| GIT-05 | lazyg add fails | P3 | Pending |
| GIT-06 | lazyg commit fails | P3 | Pending |
| GIT-07 | lazyg push fails | P3 | Pending |
| GIT-08 | Test-InteractiveSession CI=true | P3 | Pending |
| GIT-09 | Test-InteractiveSession non-interactive | P3 | Pending |

---

## Security-Sensitive Areas

### S1 — sudo sanitization
- **What**: Null bytes (\x00) and control chars (\x00-\x08\x0B\x0C\x0E-\x1F) are stripped from EncodedCommand
- **Risk**: Incomplete sanitization could allow command injection via encoded command
- **Test coverage**: Verify strip regex, verify empty-after-strip error

### S2 — sed file handling
- **What**: 50MB file size limit, atomic write via tmp+move, tmp cleanup on error
- **Risk**: No limit = DoS via large file. No atomic write = partial file on crash. No cleanup = temp file leaks
- **Test coverage**: Size validation, atomic move, cleanup on error

### S3 — pubip endpoint fallback
- **What**: 3-endpoint chain: ipify → icanhazip → ifconfig.me; all fail → ErrorRecord
- **Risk**: Hardcoded endpoints could change; order determines reliability
- **Test coverage**: Fallback chain, all-fail error

### S4 — cache writes
- **What**: Set-Content with try/catch; silent failure on write error
- **Risk**: Silent failure means stale cache persists undetected
- **Test coverage**: Write failure path

### S5 — git command execution
- **What**: gcom/lazyg check $LASTEXITCODE after each git call
- **Risk**: Missing LASTEXITCODE check would let failures propagate silently
- **Test coverage**: Each git step fail/succeed branch

---

## Success Criteria

- [x] All 42 requirement IDs mapped to test assertions
- [x] Tests run standalone: `.\tests\Unit.Tests.ps1` without pre-loaded profile
- [x] Each sub-suite completes in <100ms
- [x] No external tool calls (git, zoxide, oh-my-posh, network)
- [x] No modifications to any module file under `modules/`
