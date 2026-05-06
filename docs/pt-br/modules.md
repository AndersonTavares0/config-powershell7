# Módulos e Recursos

## Descrição

Este repositório contém um perfil PowerShell personalizado (`Microsoft.PowerShell_profile.ps1`) que é carregado automaticamente em cada sessão do terminal. O perfil define funções, aliases e configurações que aumentam a produtividade, padronizam o ambiente e reduzem o tempo de inicialização através de um sistema de cache de plugins.

---


## Recursos

- **Sistema de cache de plugins** — evita recarregar Zoxide e Oh My Posh a cada sessão
- **Navegação rápida** — aliases para diretórios e movimentação no sistema de arquivos
- **Funções utilitárias** — equivalentes Unix (`touch`, `which`, `grep`, `head`, `tail`, `sed`)
- **Git shortcuts** — fluxo completo de Git com funções e aliases
- **Funções de sistema** — informações, processos, disco, DNS e IP público
- **Clipboard** — copiar e colar via pipeline
- **Elevação de privilégio** — `sudo` que abre sessão elevada ou executa um comando como Admin
- **PSReadLine configurado** — histórico inteligente, navegação por teclas, autocompletar
- **Boot summary** — exibe tempo de inicialização e módulos carregados a cada sessão

---


## Uso

Ao abrir uma nova sessão do PowerShell, o perfil é carregado automaticamente e exibe um resumo de boot:

```
PS 7.4.2 · OMP:atomic · Zoxide [85ms]
```

A linha exibe: versão do PS, módulos carregados, tempo de inicialização (verde < 200ms, amarelo < 400ms, vermelho > 400ms).

---


## Aliases

Todos os aliases disponíveis no perfil:

| Alias | Função/Comando | Descrição |
|---|---|---|
| `Clear-Cache` | `Clear-PluginCache` | Remove o cache de plugins |
| `icons` | `Import-TerminalIcons` | Carrega o módulo Terminal-Icons |
| `cpy` | `Copy-ToClipboard` | Copia pipeline para clipboard |
| `k9` | `pkill` | Mata processo por nome |
| `gss` | `gst` | `git status -sb` |

---


## Funções

### Navegação

| Função | Descrição | Exemplo |
|---|---|---|
| `docs` | Navega para `~/Documents` | `docs` |
| `dtop` | Navega para `~/Desktop` | `dtop` |
| `home` | Navega para `$HOME` | `home` |
| `up` | Sobe um nível (`cd ..`) | `up` |
| `up2` | Sobe dois níveis (`cd ..\..`) | `up2` |
| `la` | Lista arquivos (sem ocultos) em tabela | `la` |
| `ll` | Lista arquivos (com ocultos) em tabela | `ll` |
| `mkcd <path>` | Cria diretório e entra nele | `mkcd projetos\novo` |
| `nf <file>` | Cria arquivo vazio | `nf config.json` |

### Arquivos e Texto

| Função | Descrição | Exemplo |
|---|---|---|
| `touch <file>` | Cria arquivo ou atualiza timestamp | `touch notes.txt` |
| `which <cmd>` | Mostra o caminho de um comando | `which git` |
| `unzip <file> [dest]` | Extrai ZIP (destino padrão: `.`) | `unzip arquivo.zip .\saida` |
| `head <file> [n]` | Mostra primeiras n linhas (padrão: 10) | `head log.txt -Lines 5` |
| `tail <file> [n]` | Mostra últimas n linhas (padrão: 10) | `tail log.txt -Lines 20` |
| `grep <pattern>` | Filtra entrada via pipeline | `Get-Content log.txt \| grep "error"` |
| `Copy-ToClipboard` / `cpy` | Copia pipeline para clipboard | `cat file.txt \| cpy` |
| `pst` | Cola conteúdo do clipboard | `pst` |
| `sed <file> <find> <replace> [-Backup]` | Substituição de texto atômica em arquivo | `sed config.txt "old" "new" -Backup` |

### Sistema

| Função | Descrição | Exemplo |
|---|---|---|
| `pkill <name>` / `k9` | Mata processo por nome | `pkill notepad` |
| `pgrep <name>` | Lista processos pelo nome com detalhes | `pgrep chrome` |
| `flushdns` | Limpa cache DNS (requer Admin) | `flushdns` |
| `df` | Mostra uso de disco por volume | `df` |
| `pubip [-Force]` | Exibe IP público (cacheado na sessão) | `pubip` / `pubip -Force` |
| `sysinfo` | Resumo de hardware, SO e uptime | `sysinfo` |

### Git

> As funções Git só são criadas se o comando `git` estiver disponível no PATH.

| Função | Equivalente Git | Exemplo |
|---|---|---|
| `gst` / `gss` | `git status -sb` | `gst` |
| `ga` | `git add .` | `ga` |
| `gcmt <msg>` | `git commit -m <msg>` | `gcmt "fix: typo"` |
| `gco <branch>` | `git checkout <branch>` | `gco main` |
| `gpush` | `git push` | `gpush` |
| `gpull` | `git pull` | `gpull` |
| `glog` | `git log --oneline --graph -15` | `glog` |
| `gundo` | `git reset --soft HEAD~1` | `gundo` |
| `gdiff` | `git diff` | `gdiff` |
| `gcl <url>` | `git clone <url>` | `gcl https://github.com/user/repo` |
| `gcom <msg>` | `git add .` + `git commit -m` (com verificação de erro) | `gcom "feat: add filter"` |
| `lazyg <msg> [-Force]` | `add` + `commit` + `push` (com confirmação interativa) | `lazyg "chore: update deps"` |

### Administração

```powershell
# Abre nova janela do PowerShell como Administrador
sudo

# Executa um comando específico como Administrador
sudo Get-Service

# Reexecuta o último comando do histórico como Admin
sudo !!
```

### Cache e Plugins

| Função | Alias | Descrição |
|---|---|---|
| `Clear-PluginCache` | `Clear-Cache` | Remove `~\.cache_pwsh_plugins.ps1` e instrui reiniciar o terminal |
| `Import-TerminalIcons` | `icons` | Carrega o módulo Terminal-Icons (com verificação de duplo carregamento) |

---


## Performance

### Sistema de Cache de Plugins

O perfil evita recarregar Zoxide e Oh My Posh do zero em cada sessão usando um arquivo de cache em `~\.cache_pwsh_plugins.ps1`.

**Como funciona:**

1. Na inicialização, o perfil calcula um fingerprint MD5 baseado nos caminhos de `zoxide`, `oh-my-posh` e do tema atual.
2. Compara o fingerprint com o registrado no cache.
3. Se forem iguais, o cache é carregado diretamente (fast path).
4. Se diferirem (ferramentas atualizadas, tema mudado), o cache é regenerado.

**Economia estimada:** ~200ms por sessão quando o cache está válido.

### PSReadLine

Configurado com histórico inteligente (sem duplicatas, até 5.000 entradas), navegação por setas e autocompletar por menu (Tab). No PS 7+, ativa também predição de histórico com ListView.

### Boot Summary

Ao final do carregamento, o perfil exibe o tempo total de boot e os módulos carregados, com código de cor:

- 🟢 Verde: < 300ms
- 🟡 Amarelo: <600
- 🔴 Vermelho: > 600ms
---


# Referência Técnica

## Visão Geral

O `Microsoft.PowerShell_profile.ps1` é um perfil de inicialização para PowerShell 5.1+/7+ no Windows. Ele é carregado automaticamente em cada nova sessão via `$PROFILE` e tem como objetivos centrais:

- Minimizar o tempo de boot através de cache de plugins
- Expor um conjunto consistente de aliases e funções utilitárias
- Configurar PSReadLine para uma experiência de edição de linha de comando aprimorada
- Garantir robustez com tratamento de erros e escopos explícitos

O arquivo é estruturado em 9 seções numeradas, claramente delimitadas por comentários de cabeçalho.

---

## Arquitetura do Profile

O perfil agora é modular, dividindo as responsabilidades em arquivos separados que são importados pelo arquivo principal.

```
config-powershell7/
├── .github/workflows/          # Automação de CI (GitHub Actions)
├── Microsoft.PowerShell_profile.ps1    # Loader principal
├── install.ps1                 # Script de instalação automatizada
├── tests/                      # Suite de testes unitários
└── modules/
    ├── cache/
    │   └── cache.ps1                   # Zoxide, Oh-My-Posh, Terminal-Icons
    ├── git/
    │   └── git.ps1                     # Aliases e funções do Git
    ├── navigation/
    │   └── navigation.ps1              # Aliases de navegação (up, mkcd, la)
    ├── system/
    │   ├── psreadline.ps1              # Configuração do PSReadLine e teclas
    │   └── system.ps1                  # Sudo, processos, DNS, IP
    └── text_utils/
        └── text_utils.ps1              # Touch, unzip, sed, grep, clipboard
```

---

## Fluxo de Inicialização

A ordem de execução ao abrir uma nova sessão é:

```
1. PowerShell carrega $PROFILE automaticamente (Microsoft.PowerShell_profile.ps1).
2. O Loader inicia o cronômetro de boot e define variáveis $script:.
3. O Loader carrega todos os submódulos usando dot-sourcing (. "$moduleDir/..."):
   ├── cache.ps1: Verifica/carrega o cache do Zoxide e Oh-My-Posh.
   ├── psreadline.ps1: Configura o terminal e predição de histórico.
   ├── navigation.ps1: Adiciona atalhos de diretório.
   ├── text_utils.ps1: Adiciona funções de manipulação de arquivo.
   ├── system.ps1: Funções do SO e Sudo.
   └── git.ps1: Carrega funções Git (apenas se 'git' estiver no PATH).
4. O Loader para o cronômetro e exibe o resumo de boot.
```

> As funções e aliases (passo 3) são carregados quase instantaneamente. O custo real de boot está no cache (cache.ps1).

---

## Sistema de Cache de Plugins

### Objetivo

Evitar o custo de inicialização de `zoxide init powershell` e `oh-my-posh init pwsh` em cada sessão. Cada um adiciona ~100ms ao boot.

### Implementação

**Fingerprint (Get-PluginFingerprint):**

```powershell
$zcmd = Get-Command zoxide -ErrorAction SilentlyContinue
$ocmd = Get-Command oh-my-posh -ErrorAction SilentlyContinue
$parts = @(
    if ($zcmd) { $zcmd.Source } else { $null }
    if ($ocmd) { $ocmd.Source } else { $null }
    $script:ThemePath
    [int](Test-Path $script:ThemePath)
)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($parts -join '|')
$md5   = [System.Security.Cryptography.MD5]::Create()
try    { [System.BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-', '' }
finally{ $md5.Dispose() }
```

O fingerprint é derivado dos caminhos dos binários e da existência do arquivo de tema. Qualquer mudança (atualização de ferramenta, troca de tema) invalida o cache.

**Regeneração (Update-PluginCache):**

O cache é um arquivo `.ps1` gerado dinamicamente via `StringBuilder`. Contém:
- Código de inicialização do Zoxide (`zoxide init powershell`)
- Código de inicialização do Oh My Posh (com tema específico se existir, ou padrão)
- Linhas `$script:StartupModules.Add(...)` para o boot summary

**Carregamento:**

```powershell
if ($script:CachedFP -ne $script:CurrentFP) { script:Update-PluginCache }
if (Test-Path $script:CachePath)             { . $script:CachePath }
```

### Localização do cache

```
$HOME\.cache_pwsh_plugins.ps1
```

### Invalidação manual

```powershell
Clear-PluginCache  # alias: Clear-Cache
# Reinicie o terminal
```

---

## Gerenciamento de Módulos

### Terminal-Icons

Carregado sob demanda pela função `Import-TerminalIcons` (alias: `icons`). Verifica se já está carregado antes de importar, evitando duplo carregamento:

```powershell
if (Get-Module Terminal-Icons) { return }
Import-Module Terminal-Icons -ErrorAction SilentlyContinue
```

### PSReadLine

Verificado com `Get-Command Set-PSReadLineOption` antes de configurar — se não estiver disponível, o bloco é ignorado silenciosamente. Funcionalidades condicionais ao PS 7+:

```powershell
if ($script:PSMajor -ge 7) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
}
```

### Zoxide e Oh My Posh

Inicializados via cache. A função `Update-PluginCache` verifica a disponibilidade com `Get-Command` antes de incluir no cache.

---

## Aliases — Visão Técnica

| Alias | Alvo | Justificativa |
|---|---|---|
| `Clear-Cache` | `Clear-PluginCache` | Nome PS-idiomático (`Verb-Noun`) mantido como preferido; alias para conveniência |
| `icons` | `Import-TerminalIcons` | Shorthand para uso interativo |
| `cpy` | `Copy-ToClipboard` | Equivalente ao `xclip`/`pbcopy` de sistemas Unix |
| `k9` | `pkill` | Convenção de containers/CLI (SIGKILL = 9) |
| `gss` | `gst` | Alternativa mnemônica para `git status --short` |

**Nota sobre `gcm`:** O alias `gcm` foi intencionalmente evitado pois já é um alias nativo do PowerShell para `Get-Command`. A função usa `gcmt` para evitar colisão.

**Nota sobre `gs`:** O alias `gs` foi evitado pois pode colidir com `Get-Service` em ambientes PS 5.1.

---

## Funções — Detalhamento Técnico

### Seção 4: Navegação

**`mkcd`**
- Parâmetro `[Parameter(Mandatory)]` — permite tab completion e previne chamada sem argumento
- Usa `try/catch` com `Write-Error` ao invés de `New-Item` sem tratamento
- `-Force` no `New-Item` cria diretórios intermediários

**`nf`**
- Aceita `ValueFromPipeline` — permite `"file.txt" | nf`
- Processado em bloco `process {}` para suporte a múltiplos itens via pipeline

### Seção 5: Arquivos e Texto

**`touch`**
- Se arquivo existe: atualiza `LastWriteTime` via `(Get-Item $File).LastWriteTime = Get-Date`
- Se não existe: cria com `New-Item -ItemType File -Force`
- Aceita `ValueFromPipeline`

**`which`**
- Usa `(Get-Command $Cmd -ErrorAction SilentlyContinue).Source`
- Emite `Write-Warning` se não encontrado (sem exceção)

**`unzip`**
- Destino padrão: `.` (diretório atual)
- Usa `Expand-Archive` com `-Force` (sobrescreve)
- `try/catch` com `Write-Error` em falha

**`head` / `tail`**
- `head`: `Get-Content -TotalCount $Lines`
- `tail`: `Get-Content -Tail $Lines`
- Parâmetro `-Lines` com valor padrão `10`

**`grep`**
- Implementado como `filter` (não `function`) — otimizado para pipeline, processa linha a linha
- Usa `Select-String -Pattern $Pattern`

**`Copy-ToClipboard` (cpy)**
- Implementado com `begin/process/end` para acumulação correta via pipeline
- Usa `StringBuilder` para eficiência
- `$null` ignorado explicitamente no `process {}`
- `TrimEnd()` no resultado final remove trailing newlines

**`sed`**
- Lê com `[System.IO.File]::ReadAllText` com encoding UTF8+BOM (compatível PS 5.1 e 7)
- Escreve em arquivo `.tmp` temporário no mesmo diretório do alvo
- `Move-Item` do `.tmp` para o alvo = operação atômica no nível do SO (rename)
- `-Backup` opcional cria `.bak` antes da substituição
- Cleanup do `.tmp` no `catch` evita arquivos órfãos

### Seção 6: Sistema

**`pgrep`**
- Usa `Where-Object { $_.ProcessName -like "*$Name*" }` ao invés de `-Name` diretamente, pois `Get-Process -Name` não aceita wildcards no meio da string
- Exibe: Id, ProcessName, CPU, Mem(MB) formatado

**`pubip`**
- Cache em `$script:CachedPublicIP` — evita múltiplas requisições por sessão
- `-Force` ignora o cache e busca novo valor
- 3 endpoints de fallback: `api.ipify.org`, `icanhazip.com`, `ifconfig.me/ip`
- Timeout de 3 segundos por endpoint
- Captura `[System.Net.WebException]` separadamente para melhor diagnóstico

**`sysinfo`**
- Primário: `Get-CimInstance Win32_OperatingSystem` + `Win32_ComputerSystem`
- Fallback (se CIM falhar): lê `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion`
- Retorna `PSCustomObject` com campos: Computer, User, OS, PS, Uptime, RAM_GB

**`flushdns`**
- Verifica `$script:IsAdmin` antes de executar `Clear-DnsClientCache`
- Falha silenciosa com `Write-Warning` se não for Admin

### Seção 7: Git

**`gcom`**
- Verifica `$LASTEXITCODE` após `git add .` — se falhar, não executa o commit

**`lazyg`**
- Detecta ambiente interativo via `[Environment]::UserInteractive` e variáveis `$env:CI`, `$IsLinux`, `$IsMacOS`
- Em ambientes não-interativos (CI, Linux, macOS): pula a confirmação (ou exige `-Force`)
- Usa `[Console]::ReadLine()` ao invés de `ReadKey()` — compatível com ambientes sem console interativo
- Verifica `$LASTEXITCODE` após `git add` e `git commit` — falha em qualquer etapa aborta as seguintes

### Seção 8: Sudo

**`sudo`**
- Detecta `!!` como argumento especial e substitui pelo último comando do histórico (`Get-History -Count 1`)
- Seleciona `pwsh` (PS 7+) ou `powershell` (PS 5.1) baseado em `$script:PSMajor`
- Usa `-EncodedCommand` com Base64 Unicode para preservar aspas e caracteres especiais em comandos complexos
- Sem argumentos: abre nova sessão elevada vazia

---

## Segurança e Robustez

### Escopo explícito `$script:`

Todas as variáveis compartilhadas entre funções usam `$script:` explicitamente, evitando vazamento para o escopo global da sessão do usuário e ambiguidade em contextos de função.

### Funções de escopo `script:`

`Get-PluginFingerprint` e `Update-PluginCache` são declaradas como `function script:...`, tornando-as invisíveis para o usuário final e limitando seu escopo ao arquivo do profile.

### Dispose garantido

O objeto MD5 em `Get-PluginFingerprint` usa `try/finally` para garantir `Dispose()` mesmo em caso de exceção, evitando leak de recursos não gerenciados.

### Boot summary em scriptblock

A seção 9 é executada em `& { ... }` para que as variáveis locais (`$ms`, `$color`, `$plugins`, `$admin`) não vazem para a sessão do usuário.

### Tratamento de erros

- `try/catch` em funções com efeitos colaterais (`mkcd`, `unzip`, `sed`, `sysinfo`, `lazyg`)
- `Write-Error` para erros fatais da função
- `Write-Warning` para condições de aviso (sem permissão, endpoint indisponível)
- `Write-Verbose` para informações de diagnóstico (sem poluição no output normal)
- `-ErrorAction SilentlyContinue` em `Get-Command` e outras verificações de existência

### ExecutionPolicy

O profile requer `RemoteSigned` ou superior no escopo `CurrentUser`. Arquivos baixados devem ser desbloqueados com `Unblock-File` para evitar o erro de assinatura digital.

### Sudo e privilégios

`flushdns` verifica `$script:IsAdmin` antes de executar. `sudo` usa `Start-Process -Verb RunAs` para solicitar elevação via UAC, sem armazenar credenciais.

---

## Compatibilidade

| Cenário | Comportamento |
|---|---|
| PS 5.1, sem PSReadLine atualizado | PSReadLine configurado sem predição de histórico |
| PS 7+, com PSReadLine | Predição de histórico ativada com ListView |
| Sem git no PATH | Seção 7 inteira ignorada; `Write-Verbose` registra o motivo |
| Sem Zoxide | Cache gerado sem inicialização do Zoxide |
| Sem Oh My Posh | Cache gerado sem inicialização do Oh My Posh |
| Sem tema `atomic.omp.json` | Oh My Posh usa tema padrão automaticamente |
| Linux/macOS (PS Core) | `lazyg` pula confirmação interativa; `df` e `flushdns` podem falhar |
| Ambiente CI (`$env:CI`) | `lazyg` detecta e pula confirmação interativa |

---

## Performance

### Medições de referência

| Cenário | Boot time esperado |
|---|---|
| Sem Oh My Posh / Zoxide, cache válido | < 100ms |
| Com Oh My Posh + Zoxide, cache válido | < 200ms |
| Com Oh My Posh + Zoxide, cache miss | < 400ms (regeneração única) |

### Técnicas aplicadas

| Técnica | Onde | Impacto |
|---|---|---|
| Cache de inicialização de plugins | Seção 2 | ~200ms economizados por sessão |
| Fingerprint MD5 incremental | `Get-PluginFingerprint` | Invalida cache apenas quando necessário |
| `StringBuilder` para geração de cache | `Update-PluginCache` | Evita concatenação de strings em loop |
| `StringBuilder` em `Copy-ToClipboard` | Seção 5 | Eficiência em pipelines longos |
| Leitura de 1 linha do cache | Seção 2 (`-TotalCount 1`) | Evita ler arquivo inteiro para verificar fingerprint |
| Carregamento condicional de Git | Seção 7 | Evita falha se git não instalado |
| `filter` para `grep` | Seção 5 | Processamento linha a linha sem buffering |
| `[System.IO.File]` para `sed` | Seção 5 | Encoding consistente entre PS 5.1 e 7 |

---
---

## Testes Automatizados e CI

O projeto conta com uma suite de testes unitários para garantir que as funções e aliases funcionem conforme o esperado em diferentes versões do PowerShell.

### Suite de Testes Local
Os testes estão localizados em `tests/Microsoft.PowerShell_profile.Tests_diff.ps1`. Eles verificam:
- Carregamento do perfil sem erros.
- Funcionalidade de navegação (`up`, `home`, `mkcd`).
- Operações de arquivo e texto (`touch`, `nf`, `head`, `tail`).
- Existência de aliases críticos e funções de sistema.

Para rodar os testes localmente:
```powershell
pwsh -c "./tests/Microsoft.PowerShell_profile.Tests_diff.ps1 -Verbose"
```

### GitHub Actions (CI)
O repositório utiliza **GitHub Actions** para validar automaticamente cada *push* ou *pull request*.
- **Ambiente:** Os testes rodam em instâncias de **Windows Server** (`windows-latest`).
- **Validação:** Garante que mudanças no código não quebrem a inicialização ou as funções principais em ambientes limpos.
