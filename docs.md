[← Voltar para readme.md](readme.md)

# Documentação Técnica — PowerShell Profile

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![Testes](https://img.shields.io/badge/Testes-15%20suítes-brightgreen)

---

## Índice

1. [Visão Geral](#visão-geral)
2. [Arquitetura do Profile](#arquitetura-do-profile)
3. [Fluxo de Inicialização](#fluxo-de-inicialização)
4. [Sistema de Cache de Plugins](#sistema-de-cache-de-plugins)
5. [Gerenciamento de Módulos](#gerenciamento-de-módulos)
6. [Aliases — Visão Técnica](#aliases--visão-técnica)
7. [Funções — Detalhamento Técnico](#funções--detalhamento-técnico)
8. [Segurança e Robustez](#segurança-e-robustez)
9. [Compatibilidade](#compatibilidade)
10. [Performance](#performance)
11. [Integração com Testes](#integração-com-testes)
12. [Pontos Técnicos Relevantes](#pontos-técnicos-relevantes)

---

## Visão Geral

O `Microsoft.PowerShell_profile.ps1` é um perfil de inicialização para PowerShell 5.1+/7+ no Windows. Ele é carregado automaticamente em cada nova sessão via `$PROFILE` e tem como objetivos centrais:

- Minimizar o tempo de boot através de cache de plugins
- Expor um conjunto consistente de aliases e funções utilitárias
- Configurar PSReadLine para uma experiência de edição de linha de comando aprimorada
- Garantir robustez com tratamento de erros e escopos explícitos

O arquivo é estruturado em 9 seções numeradas, claramente delimitadas por comentários de cabeçalho.

---

## Arquitetura do Profile

```
Microsoft.PowerShell_profile.ps1
│
├── Seção 1: INICIALIZAÇÃO
│   ├── Stopwatch de boot
│   ├── Variáveis de escopo $script:
│   ├── Detecção de versão PS
│   └── Detecção de privilégio Admin
│
├── Seção 2: PLUGINS & CACHE
│   ├── Caminhos centralizados (CachePath, ThemePath)
│   ├── Clear-PluginCache / Clear-Cache
│   ├── Import-TerminalIcons / icons
│   ├── Get-PluginFingerprint (script-scoped)
│   ├── Update-PluginCache (script-scoped)
│   └── Lógica de carregamento/invalidação do cache
│
├── Seção 3: PSREADLINE
│   ├── Configuração de modo e histórico
│   ├── Key handlers (setas, Tab, Ctrl+*)
│   └── Predição de histórico (PS 7+ apenas)
│
├── Seção 4: NAVEGAÇÃO
│   ├── docs, dtop, home, up, up2
│   ├── la, ll
│   └── mkcd, nf
│
├── Seção 5: ARQUIVOS E TEXTO
│   ├── touch, which, unzip
│   ├── head, tail, grep
│   ├── Copy-ToClipboard / cpy, pst
│   └── sed
│
├── Seção 6: SISTEMA
│   ├── pkill / k9, pgrep
│   ├── flushdns, df
│   ├── pubip
│   └── sysinfo
│
├── Seção 7: GIT
│   ├── Carregamento condicional (requer git no PATH)
│   ├── gst/gss, ga, gcmt, gco
│   ├── gpush, gpull, glog, gundo, gdiff
│   ├── gcl, gcom, lazyg
│   └── Alias gss → gst
│
├── Seção 8: SUDO
│   └── sudo (suporte a !!, EncodedCommand, PS 5.1/7)
│
└── Seção 9: BOOT SUMMARY
    ├── Parar stopwatch
    ├── Definir título da janela (com [ADMIN] se elevado)
    └── Exibir tempo e módulos carregados
```

---

## Fluxo de Inicialização

A ordem de execução ao abrir uma nova sessão é:

```
1. PowerShell carrega $PROFILE automaticamente
2. Seção 1: Stopwatch inicia, variáveis $script: são definidas
3. Seção 2: Cache de plugins é verificado/carregado
   ├── fingerprint atual calculado (MD5)
   ├── Se igual ao cache → . $CachePath (fast path)
   └── Se diferente → Update-PluginCache + . $CachePath
4. Seção 3: PSReadLine configurado (condicionalmente)
5. Seções 4-8: Funções e aliases definidos
6. Seção 7 (Git): Carregado apenas se git estiver no PATH
7. Seção 9: Stopwatch parado, boot summary exibido
```

> As seções de definição de função (4–8) são praticamente instantâneas. O custo real de boot está na seção 2 (cache miss) e na execução do cache carregado.

---

## Sistema de Cache de Plugins

### Objetivo

Evitar o custo de inicialização de `zoxide init powershell` e `oh-my-posh init pwsh` em cada sessão. Cada um adiciona ~100ms ao boot.

### Implementação

**Fingerprint (Get-PluginFingerprint):**

```powershell
$parts = @(
    (Get-Command zoxide     -ErrorAction SilentlyContinue)?.Source
    (Get-Command oh-my-posh -ErrorAction SilentlyContinue)?.Source
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

## Integração com Testes

### Framework

O arquivo `Microsoft.PowerShell_profile.Tests_diff.ps1` implementa um framework de testes próprio com:

- `Test-Result` — registra resultado (nome, passou/falhou, mensagem)
- `Assert-Equal` — comparação por igualdade
- `Assert-True` / `Assert-False` — asserções booleanas
- `Assert-NotNull` — verificação de nulidade
- Helpers `New-MockFile` / `Remove-MockFile` — criação/limpeza de arquivos temporários

### Estratégia

O arquivo de testes carrega o profile real via `. $PROFILE` no início. Todos os testes subsequentes operam no ambiente real. Isso garante que o que é testado é exatamente o que é carregado pelo usuário.

### Suítes de teste (15 suítes)

| # | Suíte | Abordagem |
|---|---|---|
| 1 | Navigation Functions | Executa e verifica `Get-Location` |
| 2 | File Operations (mkcd, nf, touch) | Cria arquivos/diretórios temporários e verifica existência |
| 3 | Text Processing (head, tail) | Cria arquivo com 5 linhas, verifica contagem e conteúdo |
| 4 | System Functions (pkill, pgrep) | Verifica existência das funções/aliases |
| 5 | Helper Functions (which) | Executa e verifica ausência de erro |
| 6 | Clipboard Functions (cpy, pst) | Verifica existência |
| 7 | Git Functions | Verifica existência de todas as 13 funções/aliases (skip se git ausente) |
| 8 | Plugin Cache System | Verifica existência de funções e aliases de cache |
| 9 | Display Functions (la, ll) | Executa e verifica retorno não-nulo |
| 10 | Additional Navigation (dtop, up2) | Executa e verifica `Get-Location` |
| 11 | File Operation Utilities (unzip) | Verifica existência |
| 12 | System Information (df, pubip, sysinfo) | Executa (skip df no Linux) e verifica retorno |
| 13 | Advanced Text Processing (grep, sed) | Verifica existência |
| 14 | Copy-ToClipboard | Verifica existência |
| 15 | flushdns | Verifica existência |

### Tratamento de plataforma nos testes

- `docs` e `dtop`: verificam se `GetFolderPath()` retorna string vazia (Linux) e pulam o assert de localização
- `df`: executado apenas se `$PSVersionTable.OS -match 'Windows'`
- `up2`: verifica se há avô antes de executar

### Saída de testes

```
========================================
PowerShell Profile Unit Tests
========================================
  ✓ PASS: Profile loads without errors
  ✓ PASS: docs function navigates to Documents
  ...
  ✓ PASS: flushdns function exists
========================================
TEST SUMMARY
========================================
Total Tests: XX
Passed:      XX
Failed:      0
========================================
```

Exit code: `0` (sucesso) ou `1` (falha).

---

## Pontos Técnicos Relevantes

### Boas decisões

- **Fingerprint MD5 com Dispose garantido** — trata corretamente recurso não gerenciado
- **`filter` para `grep`** — processamento de pipeline correto e eficiente
- **`sed` com escrita atômica** — arquivo temporário no mesmo volume garante rename de SO
- **`$script:` explícito** — evita problemas de escopo silenciosos
- **`lazyg` com detecção de CI** — comportamento correto em ambientes automatizados
- **`gcmt` ao invés de `gcm`** — evita colisão com `Get-Command`
- **`gss` ao invés de `gs`** — evita colisão com `Get-Service`
- **`sudo !!`** — QoL feature implementada de forma robusta com histórico do PS

### Observações

- **`sudo` usa `-NoExit`** — a janela elevada não fecha após executar o comando, o que pode ser inesperado para usuários que esperam comportamento de `sudo` Unix (fechar ao terminar)
- **`pubip` sem timeout configurável** — o timeout está fixo em 3 segundos; em redes lentas pode haver delay perceptível na primeira chamada
- **Cache não tem TTL por tempo** — o cache é invalidado apenas por mudança de fingerprint, não por decurso de tempo. Se uma ferramenta for atualizada sem alterar o caminho do binário, o cache não será regenerado automaticamente
- **`sed` faz substituição simples** — não suporta regex; usa `String.Replace()` literal, diferente do `sed` Unix

### Melhorias possíveis (sem alterar comportamento atual)

- Adicionar suporte a TTL no cache de plugins (ex: expirar após N dias)
- Expor `-TimeoutSec` como parâmetro em `pubip`
- Suporte a regex em `sed` via parâmetro `-Regex`
- Adicionar `-WhatIf` em `sed` para visualizar mudanças antes de aplicar

---

*Revisão: 29/04/2026 — Compatível com PS 5.1+ / PS Core 7+ / Windows 10+*
