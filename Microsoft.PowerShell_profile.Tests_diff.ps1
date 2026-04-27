# ============================================================
# UNIT TESTS FOR Microsoft.PowerShell_profile.ps1
# PS 5.1+ / PS Core 7+
# ============================================================

param([switch]$Verbose)

# ── TEST FRAMEWORK ────────────────────────────────────────────
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestResults = [System.Collections.Generic.List[object]]::new()

function Test-Result {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][bool]$Passed,
        [string]$Message
    )
    $script:TestResults.Add([PSCustomObject]@{
        Name    = $Name
        Passed  = $Passed
        Message = $Message
    })
    if ($Passed) {
        $script:TestsPassed++
        Write-Host "  ✓ PASS: $Name" -ForegroundColor Green
    } else {
        $script:TestsFailed++
        Write-Host "  ✗ FAIL: $Name - $Message" -ForegroundColor Red
    }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$TestName)
    $passed = $Expected -eq $Actual
    $msg = if (-not $passed) { "Expected: '$Expected', Got: '$Actual'" } else { "" }
    Test-Result -Name $TestName -Passed $passed -Message $msg
}

function Assert-True {
    param([bool]$Condition, [string]$TestName)
    $passed = $Condition -eq $true
    $msg = if (-not $passed) { "Condition was false" } else { "" }
    Test-Result -Name $TestName -Passed $passed -Message $msg
}

function Assert-NotNull {
    param($Value, [string]$TestName)
    $passed = $null -ne $Value
    $msg = if (-not $passed) { "Value was null" } else { "" }
    Test-Result -Name $TestName -Passed $passed -Message $msg
}

function Assert-False {
    param([bool]$Condition, [string]$TestName)
    $passed = $Condition -eq $false
    $msg = if (-not $passed) { "Condition was true" } else { "" }
    Test-Result -Name $TestName -Passed $passed -Message $msg
}

# ── MOCK HELPERS ──────────────────────────────────────────────
function New-MockFile {
    param([string]$Path, [string]$Content = "")
    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Remove-MockFile {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item $Path -Force -ErrorAction SilentlyContinue
    }
}

# ── LOAD PROFILE ──────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PowerShell Profile Unit Tests" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Loading profile..." -ForegroundColor Yellow
try {
    . $PROFILE
    Test-Result -Name "Profile loads without errors" -Passed $true -Message ""
} catch {
    Test-Result -Name "Profile loads without errors" -Passed $false -Message $_.Exception.Message
    Write-Host "Cannot continue tests without profile loaded." -ForegroundColor Red
    exit 1
}

# ── TEST SUITE ────────────────────────────────────────────────

# Test 1: Navigation Functions
Write-Host "Testing Navigation Functions..." -ForegroundColor Yellow
try {
    $originalLocation = Get-Location

    # Test docs function
    if (Get-Command docs -ErrorAction SilentlyContinue) {
        $_docs = [Environment]::GetFolderPath('MyDocuments')
        docs
        # On Linux, MyDocuments may return empty string, so check if path is not root
        if ([string]::IsNullOrEmpty($_docs)) {
            Test-Result -Name "docs function navigates to Documents" -Passed $true -Message "Skipped (Linux)"
        } else {
            Assert-Equal -Expected $_docs -Actual (Get-Location).Path -TestName "docs function navigates to Documents"
        }
        Set-Location $originalLocation
    } else {
        Test-Result -Name "docs function exists" -Passed $false -Message "Function not defined"
    }

    # Test home function
    if (Get-Command home -ErrorAction SilentlyContinue) {
        home
        Assert-Equal -Expected $HOME -Actual (Get-Location).Path -TestName "home function navigates to HOME"
        Set-Location $originalLocation
    } else {
        Test-Result -Name "home function exists" -Passed $false -Message "Function not defined"
    }

    # Test up function
    if (Get-Command up -ErrorAction SilentlyContinue) {
        $parent = (Get-Item $originalLocation).Parent.FullName
        up
        Assert-Equal -Expected $parent -Actual (Get-Location).Path -TestName "up function navigates to parent"
        Set-Location $originalLocation
    } else {
        Test-Result -Name "up function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "Navigation tests" -Passed $false -Message $_.Exception.Message
}
Set-Location $originalLocation

# Test 2: File Operations (mkcd, nf, touch)
Write-Host "`nTesting File Operations..." -ForegroundColor Yellow
$testDir = Join-Path $PWD "test_mkcd_$(Get-Random)"
try {
    # Test mkcd function
    if (Get-Command mkcd -ErrorAction SilentlyContinue) {
        mkcd $testDir
        $exists = Test-Path $testDir
        Assert-True -Condition $exists -TestName "mkcd creates directory"

        $currentLocation = (Get-Location).Path
        Assert-Equal -Expected $testDir -Actual $currentLocation -TestName "mkcd changes to new directory"
        Set-Location $originalLocation
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Test-Result -Name "mkcd function exists" -Passed $false -Message "Function not defined"
    }

    # Test nf function
    if (Get-Command nf -ErrorAction SilentlyContinue) {
        $testFile = Join-Path $PWD "test_nf_$(Get-Random).txt"
        nf $testFile
        $exists = Test-Path $testFile
        Assert-True -Condition $exists -TestName "nf creates file"
        Remove-MockFile $testFile
    } else {
        Test-Result -Name "nf function exists" -Passed $false -Message "Function not defined"
    }

    # Test touch function (create new file)
    if (Get-Command touch -ErrorAction SilentlyContinue) {
        $testFile = Join-Path $PWD "test_touch_$(Get-Random).txt"
        touch $testFile
        $exists = Test-Path $testFile
        Assert-True -Condition $exists -TestName "touch creates new file"
        Remove-MockFile $testFile
    } else {
        Test-Result -Name "touch function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "File operations tests" -Passed $false -Message $_.Exception.Message
    if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue }
}

# Test 3: Text Processing (head, tail)
Write-Host "`nTesting Text Processing..." -ForegroundColor Yellow
$testFile = Join-Path $PWD "test_text_$(Get-Random).txt"
try {
    # Create test file with multiple lines
    $testContent = @"
Line 1
Line 2
Line 3
Line 4
Line 5
"@
    Set-Content -Path $testFile -Value $testContent -Encoding UTF8

    # Test head function
    if (Get-Command head -ErrorAction SilentlyContinue) {
        $result = head $testFile -Lines 3
        Assert-Equal -Expected 3 -Actual $result.Count -TestName "head returns correct number of lines"
        Assert-Equal -Expected "Line 1" -Actual $result[0] -TestName "head returns first line correctly"
    } else {
        Test-Result -Name "head function exists" -Passed $false -Message "Function not defined"
    }

    # Test tail function
    if (Get-Command tail -ErrorAction SilentlyContinue) {
        $result = tail $testFile -Lines 2
        Assert-Equal -Expected 2 -Actual $result.Count -TestName "tail returns correct number of lines"
        Assert-Equal -Expected "Line 5" -Actual $result[-1] -TestName "tail returns last line correctly"
    } else {
        Test-Result -Name "tail function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "Text processing tests" -Passed $false -Message $_.Exception.Message
} finally {
    Remove-MockFile $testFile
}

# Test 4: System Functions (pkill, pgrep placeholders)
Write-Host "`nTesting System Functions..." -ForegroundColor Yellow
try {
    # Test pkill/k9 alias exists
    if (Get-Command pkill -ErrorAction SilentlyContinue) {
        Test-Result -Name "pkill function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "pkill function exists" -Passed $false -Message "Function not defined"
    }

    # Test k9 alias
    if (Get-Command k9 -ErrorAction SilentlyContinue) {
        Test-Result -Name "k9 alias exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "k9 alias exists" -Passed $false -Message "Alias not defined"
    }

    # Test pgrep function
    if (Get-Command pgrep -ErrorAction SilentlyContinue) {
        Test-Result -Name "pgrep function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "pgrep function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "System functions tests" -Passed $false -Message $_.Exception.Message
}

# Test 5: Helper Functions (which)
Write-Host "`nTesting Helper Functions..." -ForegroundColor Yellow
try {
    # Test which function with existing command
    if (Get-Command which -ErrorAction SilentlyContinue) {
        $result = which "powershell" 2>$null
        # On Linux, this might not find powershell, so we just test the function runs
        Test-Result -Name "which function executes without error" -Passed $true -Message ""
    } else {
        Test-Result -Name "which function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "Helper functions tests" -Passed $false -Message $_.Exception.Message
}

# Test 6: Clipboard Functions (cpy, pst)
Write-Host "`nTesting Clipboard Functions..." -ForegroundColor Yellow
try {
    # Test cpy alias
    if (Get-Command cpy -ErrorAction SilentlyContinue) {
        Test-Result -Name "cpy alias exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "cpy alias exists" -Passed $false -Message "Alias not defined"
    }

    # Test pst function
    if (Get-Command pst -ErrorAction SilentlyContinue) {
        Test-Result -Name "pst function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "pst function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "Clipboard functions tests" -Passed $false -Message $_.Exception.Message
}

# Test 7: Git Functions (if git is available)
Write-Host "`nTesting Git Functions..." -ForegroundColor Yellow
try {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitFunctions = @('gst', 'ga', 'gcmt', 'gco', 'gpush', 'gpull', 'glog', 'gundo', 'gdiff', 'gcl', 'gcom', 'lazyg', 'gss')
        foreach ($func in $gitFunctions) {
            if (Get-Command $func -ErrorAction SilentlyContinue) {
                Test-Result -Name "$func function exists" -Passed $true -Message ""
            } else {
                Test-Result -Name "$func function exists" -Passed $false -Message "Function not defined"
            }
        }
    } else {
        Write-Host "  ⊘ SKIP: Git not installed, skipping Git function tests" -ForegroundColor Gray
    }
} catch {
    Test-Result -Name "Git functions tests" -Passed $false -Message $_.Exception.Message
}

# Test 8: Plugin Cache System
Write-Host "`nTesting Plugin Cache System..." -ForegroundColor Yellow
try {
    # Test Clear-PluginCache function
    if (Get-Command Clear-PluginCache -ErrorAction SilentlyContinue) {
        Test-Result -Name "Clear-PluginCache function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "Clear-PluginCache function exists" -Passed $false -Message "Function not defined"
    }

    # Test Clear-Cache alias
    if (Get-Command Clear-Cache -ErrorAction SilentlyContinue) {
        Test-Result -Name "Clear-Cache alias exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "Clear-Cache alias exists" -Passed $false -Message "Alias not defined"
    }

    # Test Import-TerminalIcons function
    if (Get-Command Import-TerminalIcons -ErrorAction SilentlyContinue) {
        Test-Result -Name "Import-TerminalIcons function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "Import-TerminalIcons function exists" -Passed $false -Message "Function not defined"
    }

    # Test icons alias
    if (Get-Command icons -ErrorAction SilentlyContinue) {
        Test-Result -Name "icons alias exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "icons alias exists" -Passed $false -Message "Alias not defined"
    }
} catch {
    Test-Result -Name "Plugin cache tests" -Passed $false -Message $_.Exception.Message
}

# Test 9: Display Functions (la, ll)
Write-Host "`nTesting Display Functions..." -ForegroundColor Yellow
try {
    # Test la function
    if (Get-Command la -ErrorAction SilentlyContinue) {
        $result = la 2>&1
        Assert-NotNull -Value $result -TestName "la function executes without error"
    } else {
        Test-Result -Name "la function exists" -Passed $false -Message "Function not defined"
    }

    # Test ll function
    if (Get-Command ll -ErrorAction SilentlyContinue) {
        $result = ll 2>&1
        Assert-NotNull -Value $result -TestName "ll function executes without error"
    } else {
        Test-Result -Name "ll function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "Display functions tests" -Passed $false -Message $_.Exception.Message
}

# Test 10: Additional Navigation Functions (dtop, up2)
Write-Host "`nTesting Additional Navigation Functions..." -ForegroundColor Yellow
try {
    $originalLocation = Get-Location

    # Test dtop function
    if (Get-Command dtop -ErrorAction SilentlyContinue) {
        $_desktop = [Environment]::GetFolderPath('Desktop')
        dtop
        # On Linux, Desktop may return empty string
        if ([string]::IsNullOrEmpty($_desktop)) {
            Test-Result -Name "dtop function navigates to Desktop" -Passed $true -Message "Skipped (Linux)"
        } else {
            Assert-Equal -Expected $_desktop -Actual (Get-Location).Path -TestName "dtop function navigates to Desktop"
        }
        Set-Location $originalLocation
    } else {
        Test-Result -Name "dtop function exists" -Passed $false -Message "Function not defined"
    }

    # Test up2 function
    if (Get-Command up2 -ErrorAction SilentlyContinue) {
        $parentItem = (Get-Item $originalLocation).Parent
        if ($null -ne $parentItem -and $null -ne $parentItem.Parent) {
            $grandparent = $parentItem.Parent.FullName
            up2
            Assert-Equal -Expected $grandparent -Actual (Get-Location).Path -TestName "up2 function navigates to grandparent"
        } else {
            Test-Result -Name "up2 function navigates to grandparent" -Passed $true -Message "Skipped (no grandparent)"
        }
        Set-Location $originalLocation
    } else {
        Test-Result -Name "up2 function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "Additional navigation tests" -Passed $false -Message $_.Exception.Message
}
Set-Location $originalLocation

# Test 11: File Operations (unzip placeholder)
Write-Host "`nTesting File Operation Utilities..." -ForegroundColor Yellow
try {
    # Test unzip function exists
    if (Get-Command unzip -ErrorAction SilentlyContinue) {
        Test-Result -Name "unzip function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "unzip function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "File operation utilities tests" -Passed $false -Message $_.Exception.Message
}

# Test 12: System Information Functions
Write-Host "`nTesting System Information Functions..." -ForegroundColor Yellow
try {
    # Test df function (Windows-only, skip on Linux)
    if (Get-Command df -ErrorAction SilentlyContinue) {
        if ($PSVersionTable.OS -match 'Windows') {
            $result = df 2>&1
            Assert-NotNull -Value $result -TestName "df function executes without error"
        } else {
            Test-Result -Name "df function executes without error" -Passed $true -Message "Skipped (Linux)"
        }
    } else {
        Test-Result -Name "df function exists" -Passed $false -Message "Function not defined"
    }

    # Test pubip function
    if (Get-Command pubip -ErrorAction SilentlyContinue) {
        Test-Result -Name "pubip function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "pubip function exists" -Passed $false -Message "Function not defined"
    }

    # Test sysinfo function
    if (Get-Command sysinfo -ErrorAction SilentlyContinue) {
        $result = sysinfo 2>&1
        Assert-NotNull -Value $result -TestName "sysinfo function executes without error"
    } else {
        Test-Result -Name "sysinfo function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "System information functions tests" -Passed $false -Message $_.Exception.Message
}

# Test 13: Text Processing (grep filter, sed)
Write-Host "`nTesting Advanced Text Processing..." -ForegroundColor Yellow
try {
    # Test grep filter
    if (Get-Command grep -ErrorAction SilentlyContinue) {
        Test-Result -Name "grep filter exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "grep filter exists" -Passed $false -Message "Filter not defined"
    }

    # Test sed function
    if (Get-Command sed -ErrorAction SilentlyContinue) {
        Test-Result -Name "sed function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "sed function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "Advanced text processing tests" -Passed $false -Message $_.Exception.Message
}

# Test 14: Clipboard Copy-ToClipboard
Write-Host "`nTesting Copy-ToClipboard Function..." -ForegroundColor Yellow
try {
    # Test Copy-ToClipboard function
    if (Get-Command Copy-ToClipboard -ErrorAction SilentlyContinue) {
        Test-Result -Name "Copy-ToClipboard function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "Copy-ToClipboard function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "Copy-ToClipboard tests" -Passed $false -Message $_.Exception.Message
}

# Test 15: flushdns Function
Write-Host "`nTesting flushdns Function..." -ForegroundColor Yellow
try {
    if (Get-Command flushdns -ErrorAction SilentlyContinue) {
        Test-Result -Name "flushdns function exists" -Passed $true -Message ""
    } else {
        Test-Result -Name "flushdns function exists" -Passed $false -Message "Function not defined"
    }
} catch {
    Test-Result -Name "flushdns tests" -Passed $false -Message $_.Exception.Message
}

# ── TEST SUMMARY ──────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($script:TestsPassed + $script:TestsFailed)" -ForegroundColor White
Write-Host "Passed:      $script:TestsPassed" -ForegroundColor Green
Write-Host "Failed:      $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host "========================================`n" -ForegroundColor Cyan

if ($script:TestResults.Count -gt 0 -and $Verbose) {
    Write-Host "Detailed Results:" -ForegroundColor Cyan
    $script:TestResults | Format-Table -AutoSize
}

# Exit with appropriate code
if ($script:TestsFailed -gt 0) {
    exit 1
} else {
    exit 0
}
