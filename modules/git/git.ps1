# ── 7. GIT ────────────────────────────────────────────────────
if (Get-Command git -ErrorAction SilentlyContinue) {
    function gst { git status -sb }
    function ga  { git add . }

    # gcmt em vez de gcm: `gcm` e alias nativo do PS para Get-Command - colisao critica
    function gcmt {
        param([Parameter(Mandatory)][string]$Message)
        git commit -m $Message
    }

    # gco com [Parameter(Mandatory)]: git checkout sem branch imprime usage em vez de erro claro
    function gco {
        param([Parameter(Mandatory)][string]$Branch)
        git checkout $Branch
    }

    function gpush { git push }
    function gpull { git pull }
    function glog  { git log --oneline --graph -15 }
    function gundo { git reset --soft HEAD~1 }
    function gdiff { git diff }

    function gcl {
        param([Parameter(Mandatory)][string]$URL)
        git clone $URL
    }

    # gcom verifica $LASTEXITCODE: falha em git add não deve chegar ao commit
    function gcom {
        param([Parameter(Mandatory)][string]$Message)
        git add .
        if ($LASTEXITCODE -ne 0) { Write-Error "gcom: git add falhou."; return }
        git commit -m $Message
    }

    # lazyg verifica cada passo: commit falho nao dispara push
    # Compativel com Linux e Windows: usa ReadLine() em vez de ReadKey() para ambientes sem console interativo
    function lazyg {
        param(
            [Parameter(Mandatory)][string]$Message,
            [switch]$Force
        )
        git status --short
        $isInteractive = [Environment]::UserInteractive -and -not $env:CI -and -not $IsLinux -and -not $IsMacOS

        if (-not $Force -and $isInteractive) {
            Write-Host "Stage all, commit e push? [s/N]: " -NoNewline -ForegroundColor Yellow
            try {
                $userInput = [Console]::ReadLine()
                if ($userInput -notmatch '^[sS]$') {
                    Write-Host "Abortado." -ForegroundColor Red
                    return
                }
            } catch {
                Write-Verbose "lazyg: erro ao ler entrada do usuario - $_"
                Write-Host "Abortado (erro de leitura)." -ForegroundColor Red
                return
            }
        } elseif (-not $Force -and ($IsLinux -or $IsMacOS)) {
            # Em Linux/Mac, ReadKey pode falhar; pula confirmacao interativa
            Write-Verbose "lazyg: modo nao-interativo detectado (Linux/Mac ou CI)"
        }

        git add .
        if ($LASTEXITCODE -ne 0) { Write-Error "lazyg: git add falhou.";    return }
        git commit -m $Message
        if ($LASTEXITCODE -ne 0) { Write-Error "lazyg: git commit falhou."; return }
        git push
    }

    # gss em vez de gs: `gs` pode colidir com Get-Service em alguns ambientes PS 5.1
    Set-Alias gss gst
} else {
    Write-Verbose "Git nao encontrado - aliases Git nao carregados."
}
