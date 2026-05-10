# ── 7. GIT ────────────────────────────────────────────────────
# Verificação de existência do binário antes de carregar aliases
$gitCmd = Get-Command git -ErrorAction SilentlyContinue

if ($gitCmd) {
    function gst {
        try { git status -sb 2>&1 }
        catch { Write-Warning "gst: git não disponível - $_" }
    }

    function ga {
        try { git add . 2>&1 }
        catch { Write-Warning "ga: falha no git add - $_" }
    }

    # gcmt em vez de gcm: `gcm` é alias nativo do PS para Get-Command - colisão crítica
    function gcmt {
        param([Parameter(Mandatory)][string]$Message)
        try { git commit -m $Message 2>&1 }
        catch { Write-Warning "gcmt: falha no commit - $_" }
    }

    # gco com [Parameter(Mandatory)]: git checkout sem branch imprime usage em vez de erro claro
    function gco {
        param([Parameter(Mandatory)][string]$Branch)
        try { git checkout $Branch 2>&1 }
        catch { Write-Warning "gco: falha no checkout - $_" }
    }

    function gpush {
        try { git push 2>&1 }
        catch { Write-Warning "gpush: falha no push - $_" }
    }

    function gpull {
        try { git pull 2>&1 }
        catch { Write-Warning "gpull: falha no pull - $_" }
    }

    function glog {
        try { git log --oneline --graph -15 2>&1 }
        catch { Write-Warning "glog: falha no log - $_" }
    }

    function gundo {
        try { git reset --soft HEAD~1 2>&1 }
        catch { Write-Warning "gundo: falha no reset - $_" }
    }

    function gdiff {
        try { git diff 2>&1 }
        catch { Write-Warning "gdiff: falha no diff - $_" }
    }

    function gcl {
        param([Parameter(Mandatory)][string]$URL)
        try { git clone $URL 2>&1 }
        catch { Write-Warning "gcl: falha no clone - $_" }
    }

    # gcom verifica $LASTEXITCODE: falha em git add não deve chegar ao commit
    function gcom {
        param([Parameter(Mandatory)][string]$Message)
        git add .
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "gcom: git add falhou."
            return
        }
        git commit -m $Message
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "gcom: git commit falhou."
        }
    }

    # Detecção cross-platform de sessão interativa
    function script:Test-InteractiveSession {
        if ($env:CI) { return $false }
        if (-not [Environment]::UserInteractive) { return $false }
        if ($PSVersionTable.PSVersion.Major -ge 6 -and ($IsLinux -or $IsMacOS)) { return $false }
        return $true
    }

    # lazyg verifica cada passo: commit falho não dispara push
    function lazyg {
        param(
            [Parameter(Mandatory)][string]$Message,
            [switch]$Force
        )
        git status --short

        if (-not $Force -and (script:Test-InteractiveSession)) {
            Write-Host "Stage all, commit e push? [s/N]: " -NoNewline -ForegroundColor Yellow
            try {
                $userInput = [Console]::ReadLine()
                if ($userInput -notmatch '^[sS]$') {
                    Write-Host "Abortado." -ForegroundColor Red
                    return
                }
            } catch {
                Write-Warning "lazyg: erro ao ler entrada do usuário - $_"
                Write-Host "Abortado (erro de leitura)." -ForegroundColor Red
                return
            }
        } elseif (-not $Force) {
            Write-Verbose "lazyg: modo não-interativo detectado (Linux/Mac ou CI)"
        }

        git add .
        if ($LASTEXITCODE -ne 0) { Write-Warning "lazyg: git add falhou.";    return }
        git commit -m $Message
        if ($LASTEXITCODE -ne 0) { Write-Warning "lazyg: git commit falhou."; return }
        git push
        if ($LASTEXITCODE -ne 0) { Write-Warning "lazyg: git push falhou." }
    }

    # gss em vez de gs: `gs` pode colidir com Get-Service em alguns ambientes PS 5.1
    Set-Alias gss gst
} else {
    Write-Verbose "Git não encontrado - aliases Git não carregados."
}
