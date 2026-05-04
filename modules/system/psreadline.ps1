# ── 3. PSREADLINE ─────────────────────────────────────────────
if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
    Set-PSReadLineOption -EditMode Windows `
        -HistoryNoDuplicates `
        -HistorySearchCursorMovesToEnd `
        -BellStyle None `
        -MaximumHistoryCount 5000

    if ($script:PSMajor -ge 7) {
        Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
    }

    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d'          -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w'          -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow'  -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
}
