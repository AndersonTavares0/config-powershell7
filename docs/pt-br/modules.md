# Módulos e Recursos

## Descrição

Este repositório contém um perfil PowerShell personalizado (`Microsoft.PowerShell_profile.ps1`) que é carregado automaticamente em cada sessão do terminal. O perfil define funções, aliases e configurações que aumentam a produtividade, padronizam o ambiente e reduzem o tempo de inicialização através de um sistema de cache de plugins baseado em TTL.

---

## Recursos

- **Cache TTL de Plugins** — Time-To-Live de 60 minutos para Zoxide e Oh My Posh; hot path ignora `Get-Command` e MD5 completamente (~5ms)
- **Navegação rápida** — aliases para diretórios e movimentação no sistema de arquivos
- **Funções utilitárias** — equivalentes Unix (`touch`, `which`, `grep`, `head`, `tail`, `sed`)
- **Git shortcuts** — fluxo completo de Git com funções e aliases (condicional à disponibilidade do git)
- **Funções de sistema** — informações cross-platform, processos, disco, DNS e IP público
- **Clipboard** — copiar e colar via pipeline
- **Elevação de privilégio** — `sudo` no Windows (UAC), Linux e macOS
- **PSReadLine configurado** — histórico inteligente, navegação por teclas, autocompletar, predição
- **Boot summary** — exibe tempo de inicialização, módulos e status admin a cada sessão

---

## Uso

Ao abrir uma nova sessão do PowerShell, o perfil é carregado automaticamente e exibe um resumo de boot:

```
PS 7.4.2 · OMP:atomic · Zoxide [85ms]
```

A linha exibe: versão do PS, módulos carregados, tempo de inicialização com código de cor (verde < 300ms, amarelo < 600ms, vermelho > 600ms). Sessões admin exibem `[ADMIN]`.

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
| `sed <file> <find> <replace> [-Backup]` | Substituição atômica de texto (limite 50MB) | `sed config.txt "old" "new" -Backup` |

### Sistema

| Função | Descrição | Exemplo |
|---|---|---|
| `pkill <name>` / `k9` | Mata processo por nome (cross-platform) | `pkill notepad` |
| `pgrep <name>` | Lista processos pelo nome com detalhes | `pgrep chrome` |
| `flushdns` | Limpa cache DNS (cross-platform) | `flushdns` |
| `df` | Mostra uso de disco por volume | `df` |
| `pubip [-Force]` | Exibe IP público (cache de 5 min por sessão) | `pubip` / `pubip -Force` |
| `sysinfo` | Resumo de hardware, SO, plataforma e uptime | `sysinfo` |

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

# Executa um comando específico como Administrador (Windows) ou root (Linux/macOS)
sudo Get-Service

# Reexecuta o último comando do histórico como Admin
sudo !!
```

### Cache e Plugins

| Função | Alias | Descrição |
|---|---|---|
| `Clear-PluginCache` | `Clear-Cache` | Remove o arquivo de cache e instrui reiniciar o terminal |
| `Import-TerminalIcons` | `icons` | Carrega o módulo Terminal-Icons (com verificação de duplo carregamento) |

---

## Performance

### Sistema de Cache TTL de Plugins

O perfil evita recarregar Zoxide e Oh My Posh do zero em cada sessão usando um arquivo de cache com Time-To-Live de 60 minutos.

**Como funciona:**

1. Na inicialização, lê a primeira linha do cache (`# fp:<hash> ts:<unix_epoch>`).
2. Se o TTL ainda é válido (< 60 min), carrega o cache diretamente — **ignora `Get-Command` e MD5 completamente** (~5ms hot path).
3. Se o TTL expirou, recalcula o fingerprint MD5. Se não mudou, apenas atualiza o timestamp (sem rebuild).
4. Se o fingerprint diferir (ferramentas atualizadas, tema mudado), regenera o cache.

**Economia estimada:** ~200–300ms por sessão quando o cache está válido (dependendo dos custos de `Get-Command` e init de plugins).

### PSReadLine

Configurado com histórico inteligente (sem duplicatas, até 5.000 entradas), navegação por setas e autocompletar por menu (Tab). No PS 7+, ativa também predição de histórico com ListView.

### Boot Summary

Ao final do carregamento, o perfil exibe o tempo total de boot e os módulos carregados, com código de cor:

- 🟢 Verde: < 300ms
- 🟡 Amarelo: 300–600ms
- 🔴 Vermelho: > 600ms

---

# Referência Técnica

## Visão Geral

O `Microsoft.PowerShell_profile.ps1` é um perfil de inicialização para PowerShell 5.1+/7+ no Windows, Linux e macOS. Ele é carregado automaticamente em cada nova sessão via `$PROFILE` e tem como objetivos centrais:

- Minimizar o tempo de boot através de cache de plugins com TTL
- Expor um conjunto consistente de aliases e funções utilitárias
- Configurar PSReadLine para uma experiência de edição de linha de comando aprimorada
- Garantir robustez com tratamento de erros, escopos explícitos e registros de erro estruturados

O perfil é modular: arquivos `.ps1` individuais são carregados via dot-sourcing em ordem estrita (config → cache → navigation → git → system → psreadline → text_utils).

---

## Arquitetura do Profile

O perfil é modular, separando responsabilidades em arquivos individuais importados pelo loader principal.

```
config-powershell7/
├── .github/workflows/          # Automação CI/CD (2 pipelines)
├── Microsoft.PowerShell_profile.ps1    # Loader principal
├── install.ps1                 # Script de instalação automatizada
├── uninstall.ps1               # Script de desinstalação segura
├── install.cmd                 # Instalador dois-cliques (Windows)
├── uninstall.cmd               # Desinstalador dois-cliques (Windows)
├── lib/                        # Utilitários Compartilhados
│   ├── platform.ps1            # Detecção cross-platform + verificação de elevação
│   ├── ux-helpers.ps1          # Output do console (Write-Ok, Write-Warn, etc.)
│   └── profile-paths.ps1       # Resolução de caminho do profile
├── tests/                      # Suítes de teste (custom + Pester)
│   ├── Test-ProfileInstallation.ps1    # Health check pós-instalação
│   ├── Microsoft.PowerShell_profile.Tests.ps1  # Testes unitários (framework custom)
│   └── Pester.Tests.ps1               # Testes Pester para CI
└── modules/
    ├── config/
    │   └── config.ps1                  # Configuração centralizada (crítica — carregada primeiro)
    ├── cache/
    │   └── cache.ps1                   # Cache TTL: Zoxide, Oh-My-Posh, Terminal-Icons
    ├── navigation/
    │   └── navigation.ps1              # Aliases de navegação (up, mkcd, la)
    ├── git/
    │   └── git.ps1                     # Aliases e funções do Git (condicional)
    ├── system/
    │   └── system.ps1                  # Sudo, processos, DNS, IP, sysinfo
    ├── psreadline/
    │   └── psreadline.ps1              # Configuração do PSReadLine e teclas
    └── text_utils/
        └── text_utils.ps1              # Touch, unzip, sed, grep, clipboard
```

---

## Fluxo de Inicialização

A ordem de execução ao abrir uma nova sessão:

```
1. PowerShell carrega $PROFILE automaticamente (Microsoft.PowerShell_profile.ps1).
2. Guard: verifica $global:ProfileLoaded para evitar carregamento duplo.
3. Stopwatch inicia para medição de performance.
4. Resolve a raiz do repositório via $global:__ProfileRepoRoot ou $PSScriptRoot.
5. Carrega módulo config (crítico — deve ter sucesso, retorna em falha).
6. Carrega módulos restantes em try/catch (não-críticos — falha em um não bloqueia os outros):
   ├── cache/cache.ps1:       Verificação TTL → hot path ou rebuild → dot-source do cache.
   ├── navigation/navigation.ps1: Atalhos de diretório (docs, dtop, up, mkcd).
   ├── git/git.ps1:           Funções Git (apenas se git estiver no PATH).
   ├── system/system.ps1:     Utilitários de sistema + sudo (conscientes de plataforma).
   ├── psreadline/psreadline.ps1: Terminal, histórico, keybindings.
   └── text_utils/text_utils.ps1: Manipulação de arquivos (touch, sed, grep).
7. Stopwatch para e o resumo de boot é exibido.
```

> As funções e aliases (passo 6) são carregados quase instantaneamente. O custo real de boot está na inicialização dos plugins (`cache.ps1`).

---

## Sistema de Cache de Plugins (TTL)

### Objetivo

Evitar o custo de inicialização de `zoxide init powershell` e `oh-my-posh init pwsh` em cada sessão. Cada um adiciona ~100ms ao boot.

### Implementação

**Formato do cache (linha de header):**
```
# fp:<md5_hash> ts:<unix_timestamp>
```

**Fluxo TTL (`Initialize-PluginCache`):**

1. **Cache existe + TTL válido (< 60 min):** Carrega cache diretamente — **~5ms hot path** (sem `Get-Command`, sem MD5).
2. **Cache existe + TTL expirado:** Recalcula fingerprint. Se não mudou, apenas atualiza timestamp. Se mudou, reconstrói cache.
3. **Sem cache:** Rebuild completo (Get-Command zoxide + oh-my-posh, fingerprint MD5, StringBuilder).

**Fingerprint (`Get-PluginFingerprint`):**

O fingerprint é derivado dos caminhos dos binários, versões dos arquivos (via `VersionInfo`), caminho do tema, existência do tema e hash do conteúdo do tema (MD5). Qualquer mudança (atualização de ferramenta, troca de tema, edição do tema) invalida o cache.

```powershell
$parts = @(
    $zcmd.Source                     # Caminho do binário zoxide
    $zcmd.VersionInfo.FileVersion    # Versão do zoxide
    $ocmd.Source                     # Caminho do binário oh-my-posh
    $ocmd.VersionInfo.FileVersion    # Versão do oh-my-posh
    $script:Config.ThemePath         # Caminho do arquivo de tema
    [int](Test-Path $ThemePath)      # Existência do tema
    (Get-FileHash $ThemePath).Hash   # Hash do conteúdo do tema
)
# MD5 com Dispose garantido via try/finally
```

**Regeneração (`Update-PluginCache`):**

O cache é um arquivo `.ps1` gerado dinamicamente via `StringBuilder`. Contém:
- Header: `# fp:<hash> ts:<unix_epoch>`
- Código de inicialização do Zoxide (`zoxide init powershell`)
- Código de inicialização do Oh My Posh (com tema específico se existir, ou padrão)
- Linhas `$script:StartupModules.Add(...)` para o boot summary

**Carregamento:**

```powershell
if ($needRebuild) { script:Update-PluginCache -zcmd $zcmd -ocmd $ocmd }
if (Test-Path $script:Config.CachePath) { . $script:Config.CachePath }
```

### Localização do cache

- **Windows:** `$HOME\.cache_pwsh_plugins.ps1`
- **Linux/macOS (XDG):** `$XDG_CACHE_HOME/pwsh/plugins_cache.ps1` (fallback: `$HOME/.cache/pwsh/plugins_cache.ps1`)

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

Verificado com `Get-Command Set-PSReadLineOption` antes de configurar — se não estiver disponível, o bloco é ignorado silenciosamente. Funcionalidades de predição são condicionais ao PS 7+:

```powershell
if ($script:Config.PSMajor -ge 7) {
    Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
}
```

Keybindings: UpArrow (HistorySearchBackward), DownArrow (HistorySearchForward), Tab (MenuComplete), Ctrl+D (DeleteChar), Ctrl+W (BackwardDeleteWord), Ctrl+Left/Right (navegação por palavras).

### Zoxide e Oh My Posh

Inicializados via cache TTL. `Update-PluginCache` verifica a disponibilidade com `Get-Command` antes de incluir no cache. Falhas são registradas com `Write-Warning`.

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

### Navegação

**`mkcd`**
- Parâmetro `[Parameter(Mandatory)]` — permite tab completion e previne chamada sem argumento
- Usa `try/catch` com `Write-Error` ao invés de `New-Item` sem tratamento
- `-Force` no `New-Item` cria diretórios intermediários

**`nf`**
- Aceita `ValueFromPipeline` — permite `"file.txt" | nf`
- Processado em bloco `process {}` para suporte a múltiplos itens via pipeline

### Arquivos e Texto

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
- `ErrorRecord` estruturado via `$PSCmdlet.WriteError()`

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
- **Limite de 50MB** — arquivos maiores são rejeitados com erro estruturado (proteção DoS)
- Escreve em arquivo `.tmp` com nome aleatório no mesmo diretório do alvo
- `Move-Item` do `.tmp` para o alvo = operação atômica no nível do SO (rename)
- `-Backup` opcional cria `.bak` antes da substituição
- Cleanup do `.tmp` no `catch` evita arquivos órfãos
- Suporta `-WhatIf` via `SupportsShouldProcess`

### Sistema

**`pkill`**
- Cross-platform: usa `Stop-Process` no Windows, `/usr/bin/pkill -f` nativo no Linux/macOS
- Suporta `-WhatIf` via `SupportsShouldProcess`
- `ErrorRecord` estruturado em falha

**`pgrep`**
- Cross-platform: usa `Where-Object` no Windows, `/usr/bin/pgrep -f` nativo no Linux/macOS
- No Windows: usa `Where-Object { $_.ProcessName -like "*$Name*" }` porque `Get-Process -Name` não aceita wildcards no meio da string
- Exibe: Id, ProcessName, CPU, Mem(MB) formatado
- `ErrorRecord` estruturado em falha

**`pubip`**
- Cache em `$script:CachedPublicIP` com TTL de 5 minutos — evita múltiplas requisições por sessão
- `-Force` ignora o cache e busca novo valor
- 3 endpoints de fallback: `api.ipify.org`, `icanhazip.com`, `ifconfig.me/ip`
- Timeout de 3 segundos por endpoint
- Captura `[System.Net.WebException]` separadamente para melhor diagnóstico
- `ErrorRecord` estruturado se todos os endpoints falharem

**`sysinfo`**
- Cross-platform: despacha para funções específicas de plataforma
  - Windows: `Get-WindowsSystemInfo` — usa `Get-CimInstance Win32_OperatingSystem` + `Win32_ComputerSystem`
  - Linux: `Get-LinuxSystemInfo` — lê `/etc/os-release`, `/proc/meminfo`
  - macOS: `Get-MacSystemInfo` — usa `sysctl` para memória e boot time
- macOS uptime: faz parse de `sysctl -n kern.boottime` com regex `sec\s*=\s*(\d+)`, converte via `[DateTimeOffset]::FromUnixTimeSeconds()`
- Retorna `PSCustomObject` com campos específicos da plataforma
- Fallback gera objeto genérico com dados best-effort

**`flushdns`**
- Cross-platform: `Clear-DnsClientCache` (Windows Admin), `systemd-resolve --flush-caches` / `nscd -i hosts` (Linux), `dscacheutil -flushcache` + `killall -HUP mDNSResponder` (macOS)
- Windows: verifica `$script:Config.IsAdmin` antes de executar; falha silenciosa com `Write-Warning` se não for Admin

**`df`**
- Cross-platform: `Get-Volume` no Windows, `df -h` nativo no Linux/macOS
- `ErrorRecord` estruturado em falha

### Git

**`gcom`**
- Verifica `$LASTEXITCODE` após `git add .` — se falhar, não executa o commit

**`lazyg`**
- Detecta ambiente interativo via `[Environment]::UserInteractive`, `$env:CI`, `$IsLinux`, `$IsMacOS`
- Em ambientes não-interativos (CI, Linux, macOS): pula a confirmação (ou exige `-Force`)
- Usa `[Console]::ReadLine()` ao invés de `ReadKey()` — compatível com ambientes sem console interativo
- Verifica `$LASTEXITCODE` após cada etapa (`git add`, `git commit`, `git push`) — falha em qualquer etapa aborta as seguintes

### Sudo

**`sudo`**
- Cross-platform: detecta Linux/macOS e delega para `/usr/bin/sudo` nativo se disponível
- Windows: `Start-Process -Verb RunAs` com elevação UAC
- Detecta `!!` como argumento especial e substitui pelo último comando do histórico (`Get-History -Count 1`)
- Windows: seleciona `pwsh` (PS 7+) ou `powershell` (PS 5.1) baseado em `$script:Config.PSMajor`
- Usa `-EncodedCommand` com Base64 Unicode para preservar aspas e caracteres especiais em comandos complexos
- Sanitiza comandos: remove null bytes e caracteres de controle (U+0000–U+001F exceto tab/newline)
- Suporta `-WhatIf` via `SupportsShouldProcess`
- `ErrorRecord` estruturado em falha

---

## Segurança e Robustez

### Escopo explícito `$script:`

Todas as variáveis compartilhadas entre funções usam `$script:` explicitamente, evitando vazamento para o escopo global da sessão do usuário e ambiguidade em contextos de função.

### Funções de escopo `script:`

Funções internas (`Get-PluginFingerprint`, `Update-PluginCache`, `Initialize-PluginCache`, `Get-WindowsSystemInfo`, `Get-LinuxSystemInfo`, `Get-MacSystemInfo`, `Test-InteractiveSession`) são declaradas como `function script:...`, tornando-as invisíveis para o usuário final e limitando seu escopo ao módulo.

### Tratamento de erros estruturado

Funções críticas usam `[CmdletBinding()]` com `$PSCmdlet.WriteError()` para objetos `ErrorRecord` estruturados, permitindo suporte adequado a `-ErrorAction` e integração com a variável `$Error`:

- `pkill`, `pgrep`, `flushdns`, `df`, `pubip` — `ErrorRecord` estruturado com IDs de erro descritivos
- `sed`, `unzip` — `ErrorRecord` estruturado com categorias de erro específicas

### Zero falhas silenciosas

- Todos os blocos `catch` registram no mínimo `Write-Verbose` (informativo) ou `Write-Warning` (falhas reais)
- Zero blocos `catch {}` vazios no código
- Falhas de inicialização de plugins escrevem `Write-Warning` (visível ao usuário)
- Falha ao salvar cache escreve `Write-Warning`

### Dispose garantido

O objeto MD5 em `Get-PluginFingerprint` usa `try/finally` para garantir `Dispose()` mesmo em caso de exceção, evitando leak de recursos não gerenciados.

### Boot summary em escopo local

O resumo de boot executa dentro do arquivo loader com variáveis locais (`$bootMs`, `$color`, `$moduleList`, `$adminTag`) que não vazam para a sessão do usuário.

### `$ErrorActionPreference = 'Stop'`

Reforçado em todos os scripts standalone (`install.ps1`, `uninstall.ps1`, arquivos de teste, pipeline CI).

### ExecutionPolicy

O perfil requer `RemoteSigned` ou superior no escopo `CurrentUser`. Arquivos baixados devem ser desbloqueados com `Unblock-File` para evitar o erro de assinatura digital.

### Sudo e privilégios

`flushdns` verifica `$script:Config.IsAdmin` antes de executar. `sudo` usa mecanismos de elevação apropriados para cada plataforma sem armazenar credenciais.

---

## Compatibilidade

| Cenário | Comportamento |
|---|---|
| Windows 10+ | Suporte completo — todas as funcionalidades ativas |
| Linux (Fedora) | Suporte completo — `sudo` nativo, caminhos XDG, ferramentas nativas |
| macOS | Suporte completo — `sudo` nativo, `sysctl`, detecção de plataforma |
| PS 5.1, sem PSReadLine atualizado | PSReadLine configurado sem predição de histórico |
| PS 7+, com PSReadLine | Predição de histórico ativada com ListView |
| Sem git no PATH | Módulo Git inteiramente ignorado; `Write-Verbose` registra o motivo |
| Sem Zoxide | Cache gerado sem inicialização do Zoxide; `Write-Warning` na falha de init |
| Sem Oh My Posh | Cache gerado sem inicialização do Oh My Posh; `Write-Warning` na falha de init |
| Sem tema `atomic.omp.json` | Oh My Posh usa tema padrão automaticamente |
| Ambiente CI (`$env:CI`) | `lazyg` pula confirmação interativa; `sudo` pula prompts `ShouldProcess` |
| Sessão Windows sem Admin | `flushdns` avisa; `sudo` abre prompt UAC |

---

## Performance

### Medições de referência

| Cenário | Boot time esperado |
|---|---|
| Com Oh My Posh + Zoxide, cache válido (hot path TTL) | < 150ms |
| Com Oh My Posh + Zoxide, TTL expirado, fingerprint inalterado | < 200ms |
| Com Oh My Posh + Zoxide, cache miss (rebuild completo) | < 400ms |

### Técnicas aplicadas

| Técnica | Onde | Impacto |
|---|---|---|
| Cache TTL com hot path | cache.ps1 (`Initialize-PluginCache`) | ~5ms quando válido (ignora `Get-Command` e MD5) |
| Fingerprint MD5 incremental com versões | `Get-PluginFingerprint` | Invalida cache em atualizações de ferramentas |
| Hash do conteúdo do tema no fingerprint | `Get-PluginFingerprint` | Invalida em edições do tema |
| `StringBuilder` para geração de cache | `Update-PluginCache` | Evita concatenação de strings em loop |
| `StringBuilder` em `Copy-ToClipboard` | text_utils.ps1 | Eficiência em pipelines longos |
| Leitura de 1 linha do cache | `Initialize-PluginCache` (`-TotalCount 1`) | Evita ler arquivo inteiro para verificação TTL |
| Carregamento condicional de Git | git.ps1 | Evita falha se git não instalado |
| `filter` para `grep` | text_utils.ps1 | Processamento linha a linha sem buffering |
| `[System.IO.File]` para `sed` | text_utils.ps1 | Encoding consistente entre PS 5.1 e 7 |
| TTL de 5 min no `pubip` | system.ps1 | Evita chamadas de rede na mesma sessão |
| Early return antes de `Get-Command` | cache.ps1 (hot path `Initialize-PluginCache`) | Economiza 40–100ms adiando `Get-Command zoxide`/`oh-my-posh` para o cold path |
| Lazy-init de navegação (`docs`, `dtop`) | navigation.ps1 | Economiza 2–6ms adiando `[Environment]::GetFolderPath` para o primeiro uso |

---

---

## Testes Automatizados e CI

### Três Suítes de Teste

| Suíte de Teste | Framework | Uso |
|---|---|---|
| `tests/Pester.Tests.ps1` | Pester 5.x | Pipeline CI — testes estritos de invariantes, metas de cobertura |
| `tests/Test-ProfileInstallation.ps1` | Customizado | Health check pós-instalação — 64 verificações em 6 categorias |
| `tests/Microsoft.PowerShell_profile.Tests.ps1` | Customizado | Integração comportamental — navegação, operações de arquivo, tratamento de erros |

### Executando Testes

```powershell
# Testes Pester (CI)
Invoke-Pester tests/Pester.Tests.ps1

# Health check pós-instalação
.\tests\Test-ProfileInstallation.ps1 -Detailed
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose

# Após carregar o perfil:
Test-ProfileInstallation
```

### GitHub Actions (CI/CD)

Dois pipelines validam automaticamente cada push ou pull request para `main`:

- **`test.yml`** — copia perfil + módulos para `$PROFILE`, executa suítes de teste customizadas
- **`powershell-pipeline.yml`** — pipeline estrito de 5 estágios:
  1. PSScriptAnalyzer (regras estritas)
  2. Auditoria de segurança (credenciais, `$ErrorActionPreference = 'Stop'`)
  3. Testes Pester (cobertura nos módulos principais)
  4. Validação ambiental (sessão limpa)
  5. Deploy/artefato (empacotamento zip)

Ambiente: **Windows Server** (`windows-latest`).
