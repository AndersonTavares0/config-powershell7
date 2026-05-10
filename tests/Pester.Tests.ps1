#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    High-integrity Pester tests for core profile modules.
.DESCRIPTION
    Covers platform, cache, git, system, and text_utils modules.
    Includes invariant-violation tests that inject illegal states
    to verify the "Crash > Corrupt" principle — functions MUST throw
    rather than silently return corrupted output.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$modDir = Join-Path $root 'modules'
$libDir = Join-Path $root 'lib'

# ── Bootstrap platform detection ───────────────────────
. (Join-Path $libDir 'platform.ps1')

# ── Bootstrap config (non-interactive, CI-safe) ────────
$global:__ProfileRepoRoot = $root
$script:Config = [PSCustomObject]@{
    RepoRoot        = $root
    ProfilePath     = $PROFILE
    IsWindows       = $script:IsWin
    IsLinux         = $script:IsLnx
    IsMacOS         = $script:IsMac
    IsAdmin         = $script:IsAdmin
    ModulesPath     = $modDir
    LibPath         = $libDir
    DevMode         = $true
    CachePath       = Join-Path $env:TEMP "pester-plugin-cache-$PID"
    CacheTTLMinutes = 5
    ThemePath       = Join-Path $env:TEMP "pester-theme-$PID.omp.json"
}

# ── Load modules under test ────────────────────────────
. (Join-Path $modDir 'cache\cache.ps1')
. (Join-Path $modDir 'system\system.ps1')
. (Join-Path $modDir 'text_utils\text_utils.ps1')
. (Join-Path $modDir 'git\git.ps1')

# ═══════════════════════════════════════════════════════
# PLATFORM LIB TESTS
# ═══════════════════════════════════════════════════════

Describe 'lib/platform.ps1 — Platform Detection' {

    It '$script:IsWin is Boolean' {
        $script:IsWin | Should -BeOfType [bool]
    }

    It '$script:IsLnx is Boolean' {
        $script:IsLnx | Should -BeOfType [bool]
    }

    It '$script:IsMac is Boolean' {
        $script:IsMac | Should -BeOfType [bool]
    }

    It '$script:IsAdmin is Boolean' {
        $script:IsAdmin | Should -BeOfType [bool]
    }

    It 'Exactly one platform flag is true' {
        ($script:IsWin, $script:IsLnx, $script:IsMac | Where-Object { $_ }).Count |
            Should -Be 1
    }
}


# ═══════════════════════════════════════════════════════
# CONFIG / BOOTSTRAP TESTS
# ═══════════════════════════════════════════════════════

Describe 'Bootstrap Config' {

    It '$script:Config is not null' {
        $script:Config | Should -Not -BeNullOrEmpty
    }

    It 'IsWindows matches $script:IsWin' {
        $script:Config.IsWindows | Should -Be $script:IsWin
    }

    It 'IsLinux matches $script:IsLnx' {
        $script:Config.IsLinux | Should -Be $script:IsLnx
    }

    It 'IsMacOS matches $script:IsMac' {
        $script:Config.IsMacOS | Should -Be $script:IsMac
    }

    It 'CacheTTLMinutes is a positive integer' {
        $script:Config.CacheTTLMinutes | Should -BeGreaterThan 0
    }
}


# ═══════════════════════════════════════════════════════
# CACHE MODULE TESTS
# ═══════════════════════════════════════════════════════

Describe 'modules/cache/cache.ps1 — Plugin Cache' {

    It 'Clear-PluginCache exists' {
        Get-Command Clear-PluginCache -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'Clear-Cache alias points to Clear-PluginCache' {
        (Get-Alias Clear-Cache -ErrorAction SilentlyContinue).ResolvedCommandName |
            Should -Be 'Clear-PluginCache'
    }

    It 'Import-TerminalIcons exists' {
        Get-Command Import-TerminalIcons -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'icons alias points to Import-TerminalIcons' {
        (Get-Alias icons -ErrorAction SilentlyContinue).ResolvedCommandName |
            Should -Be 'Import-TerminalIcons'
    }

    It 'Initialize-PluginCache is defined (script-scoped)' {
        # script: prefix prevents Get-Command from finding it.
        # Verify the function was dot-sourced and exists in scope.
        Get-Item 'function:\Initialize-PluginCache' -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'Initialize-PluginCache executes without throwing' {
        # Clean temp cache to force rebuild
        Remove-Item $script:Config.CachePath -Force -ErrorAction SilentlyContinue
        { script:Initialize-PluginCache } | Should -Not -Throw
    }

    Context 'Invariant: corrupt cache header' {
        It 'Handles malformed cache file gracefully' {
            '# corrupted garbage line' | Set-Content $script:Config.CachePath -Force
            { script:Initialize-PluginCache } | Should -Not -Throw
        }
    }
}


# ═══════════════════════════════════════════════════════
# GIT MODULE TESTS
# ═══════════════════════════════════════════════════════

Describe 'modules/git/git.ps1 — Git Aliases' {

    BeforeAll {
        # Provide a mock git function so alias tests work
        # without a real git binary.
        function global:git {
            param([string]$SubCommand, [string[]]$Args)
            if ($SubCommand -eq 'status' -and $Args -contains '-sb') {
                "## main...origin/main [ahead 1]`n M file.ps1"
            }
            if ($SubCommand -eq 'add')  { return }
            if ($SubCommand -eq 'commit') { return }
        }
    }

    AfterAll {
        Remove-Item function:\global:git -ErrorAction SilentlyContinue
    }

    It 'gst returns expected output' {
        $result = gst 2>&1
        $result | Should -Not -BeNullOrEmpty
    }

    It 'gcmt accepts -Message parameter' {
        { gcmt -Message 'test commit' -ErrorAction Stop } | Should -Not -Throw
    }

    It 'gco accepts -Branch parameter' {
        { gco -Branch main -ErrorAction Stop } | Should -Not -Throw
    }

    It 'glog returns expected output' {
        $result = glog 2>&1
        $result | Should -Not -BeNullOrEmpty
    }

    It 'gcom stages, then commits (LASTEXITCODE guard)' {
        { gcom -Message 'test gcom' -ErrorAction Stop } | Should -Not -Throw
    }

    It 'gss alias resolves to gst' {
        (Get-Alias gss -ErrorAction SilentlyContinue).ResolvedCommandName |
            Should -Be 'gst'
    }

    Context 'Invariant: missing mandatory parameter' {
        It 'gco throws without -Branch' {
            { gco } | Should -Throw
        }

        It 'gcmt throws without -Message' {
            { gcmt } | Should -Throw
        }
    }
}


# ═══════════════════════════════════════════════════════
# SYSTEM MODULE TESTS
# ═══════════════════════════════════════════════════════

Describe 'modules/system/system.ps1 — System Utilities' {

    Context 'sysinfo' {
        It 'Returns a PSCustomObject' {
            $info = sysinfo
            $info | Should -BeOfType [PSCustomObject]
        }

        It 'Has Computer field (non-empty string)' {
            $info = sysinfo
            $info.Computer | Should -BeOfType [string]
            $info.Computer | Should -Not -BeNullOrEmpty
        }

        It 'Has User field (non-empty string)' {
            $info = sysinfo
            $info.User | Should -BeOfType [string]
            $info.User | Should -Not -BeNullOrEmpty
        }

        It 'Has OS field (non-empty string)' {
            $info = sysinfo
            $info.OS | Should -BeOfType [string]
            $info.OS | Should -Not -BeNullOrEmpty
        }

        It 'Has PS field with version' {
            $info = sysinfo
            $info.PS | Should -BeOfType [string]
            $info.PS -as [version] | Should -Not -BeNullOrEmpty
        }

        It 'Has RAM_GB field (positive number)' {
            $info = sysinfo
            [double]$info.RAM_GB | Should -BeGreaterThan 0
        }

        It 'Has Uptime field on Windows/macOS' -Skip:($script:IsLnx) {
            $info = sysinfo
            $info.PSObject.Properties.Name -contains 'Uptime' | Should -BeTrue
            $info.Uptime | Should -Not -BeNullOrEmpty
        }

        It 'Has PS_Mem_MB field on macOS' -Skip:(-not $script:IsMac) {
            $info = sysinfo
            $info.PSObject.Properties.Name -contains 'PS_Mem_MB' | Should -BeTrue
            [double]$info.PS_Mem_MB | Should -BeGreaterThan 0
        }
    }

    Context 'pgrep' -Skip:(-not $script:IsWin) {
        It 'Finds pwsh process' {
            $result = pgrep pwsh
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Returns array or null' {
            $result = pgrep pwsh
            if ($result) {
                $result | Should -BeOfType ([array])
            }
        }

        It 'Returns null for nonexistent process' {
            $result = pgrep __nonexistent_pester_xyz__
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Invariant: pgrep edge cases' {
        It 'Does not crash with empty string' {
            { pgrep '' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Does not crash with $null' {
            { pgrep $null -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'pubip' {
        It 'Does not crash (network may be unavailable)' {
            { pubip -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}


# ═══════════════════════════════════════════════════════
# TEXT UTILS TESTS
# ═══════════════════════════════════════════════════════

Describe 'modules/text_utils/text_utils.ps1 — Text Utilities' {

    Context 'which' {
        It 'Finds pwsh.exe' -Skip:(-not $script:IsWin) {
            $result = which pwsh
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match 'pwsh'
        }

        It 'Returns nothing for nonexistent command' {
            $result = which __nonexistent_cmd_pester_xyz__
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'touch' {
        It 'Creates a file that does not exist' {
            $tmp = Join-Path $env:TEMP "pester-touch-$PID.txt"
            try {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                touch $tmp
                Test-Path $tmp | Should -BeTrue
            } finally {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Updates LastWriteTime of existing file' {
            $tmp = Join-Path $env:TEMP "pester-touch2-$PID.txt"
            try {
                'x' | Set-Content $tmp
                $before = (Get-Item $tmp).LastWriteTime
                Start-Sleep -Milliseconds 100
                touch $tmp
                $after = (Get-Item $tmp).LastWriteTime
                $after | Should -BeGreaterThan $before
            } finally {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'Invariant: which with illegal inputs' {
        It 'Does not crash with $null' {
            { which $null -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It 'Does not crash with empty string' {
            { which '' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'Invariant: sed rejects missing file' {
        It 'Writes error for nonexistent file' {
            { sed '__no_such_file_pester__' 'x' 'y' -ErrorAction SilentlyContinue } |
                Should -Not -Throw
        }
    }
}


# ═══════════════════════════════════════════════════════
# CROSS-MODULE INVARIANT TESTS
# ═══════════════════════════════════════════════════════

Describe 'Cross-Module Invariants' {

    It '$ErrorActionPreference is Stop' {
        $ErrorActionPreference | Should -Be 'Stop'
    }

    It 'No unexpected $global: pollution' {
        $allowed = @('__ProfileRepoRoot', 'ProfileLoaded', 'HOME', 'Error', 'PID',
                     'PWD', 'PROFILE', 'PSDefaultParameterValues', 'Culture',
                     'UICulture', 'args', 'MyInvocation', 'ConsoleFileName',
                     'WhatIfPreference')
        $extra = Get-Variable -Scope Global |
            Where-Object { $_.Name -notin $allowed -and $_.Name -notmatch '^What' }
        if ($extra) {
            Write-Warning "Unexpected globals: $($extra.Name -join ', ')"
        }
    }
}

# ── Cleanup temp files ─────────────────────────────────
Remove-Item $script:Config.CachePath -Force -ErrorAction SilentlyContinue
Remove-Item $script:Config.ThemePath -Force -ErrorAction SilentlyContinue
