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
        try {
            $isInteractive = -not [Console]::IsOutputRedirected
        } catch {
            $isInteractive = $false
        }
        if ($isInteractive) {
            try { Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -ErrorAction Stop } catch { Write-Warning "PSReadLine: predição de histórico indisponível — $($_.Exception.Message)" }
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
