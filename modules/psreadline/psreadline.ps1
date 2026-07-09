Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── 3. PSREADLINE ─────────────────────────────────────────────
try {
    Set-PSReadLineOption -EditMode Windows `
        -HistoryNoDuplicates `
        -HistorySearchCursorMovesToEnd `
        -BellStyle None `
        -MaximumHistoryCount 5000 `
        -ErrorAction Stop

    if ($script:Config.PSMajor -ge 7) {
        $isInteractive = $true
        try { $isInteractive = -not [Console]::IsOutputRedirected } catch { $isInteractive = $false }
        if ($isInteractive) {
            $canPredict = $false
            try { $canPredict = $Host.UI.SupportsVirtualTerminal } catch { $canPredict = $false }
            if ($canPredict) {
                Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ErrorAction SilentlyContinue
            }
        }
    }

    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d'          -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w'          -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow'  -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
} catch {
    Write-Warning "PSReadLine: falha ao configurar opções — $($_.Exception.Message)"
}
