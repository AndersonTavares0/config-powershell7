# PowerShell Profile 
Perfil de inicialização do PowerShell focado em latência mínima de boot, ergonomia de desenvolvimento e portabilidade. Desenvolvido para ser restaurado rapidamente em caso de formatação ou migração de máquina.

> **Boot time alvo:** < 200ms em sessão limpa; < 400ms com OMP + Zoxide ativos.

---

## Índice

1. [Requisitos](#requisitos)
2. [Instalação](#instalação)
3. [Referência de Comandos](#referência-de-comandos)
   - [Navegação](#navegação)
   - [Arquivos e Texto](#arquivos-e-texto)
   - [Git](#git)
   - [Sistema](#sistema)
   - [Admin](#admin)
4. [Decisões Técnicas](#decisões-técnicas)
5. [Notas de Estudo](#notas-de-estudo)

---

## Requisitos

| Componente | Instalação | Obrigatório |
|---|---|---|
| PowerShell 5.1+ | Incluso no Windows 10+; PS 7: `winget install Microsoft.PowerShell` | ✅ |
| Nerd Font | [nerdfonts.com](https://www.nerdfonts.com) — Recomendado: `FiraCode Nerd Font` | ✅ (para ícones) |
| Git | `winget install Git.Git` | ✅ |
| Oh My Posh | `winget install JanDeLaaj.oh-my-posh` | Opcional |
| Zoxide | `winget install ajeetdsouza.zoxide` | Opcional |
| PSReadLine | Incluso no PS 7; atualizar via `Install-Module PSReadLine -Force` | ✅ |
| Terminal-Icons | `Install-Module Terminal-Icons -Repository PSGallery` | Opcional (lazy load) |

> **Compatibilidade:** PS 5.1 (Windows PowerShell) e PS Core 7+. Recursos exclusivos do PS 7 (ex.: `PredictionViewStyle`) são ativados condicionalmente via `$PSMajor`.

---

## Instalação

### 1. Clonar o repositório

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
```

### 2. Localizar o caminho do perfil

```powershell
$PROFILE
# PS 7  → C:\Users\<usuario>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
# PS 5.1 → C:\Users\<usuario>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

### 3. Aplicar o perfil

**Opção A — Cópia direta (simples):**

```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Opção B — Link simbólico (mantém o repo sincronizado com `git pull`):**

```powershell
# Requer terminal com privilégios de Administrador
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

### 4. Instalar módulos necessários

```powershell
Install-Module PSReadLine     -AllowPrerelease -Force -Scope CurrentUser
Install-Module Terminal-Icons -Repository PSGallery  -Scope CurrentUser
```

### 5. Instalar tema do Oh My Posh

O perfil procura o tema `atomic` em `~\.poshthemes\atomic.omp.json`.
Se o arquivo não existir, o OMP sobe com o tema padrão automaticamente.

```powershell
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh config export --output "$HOME\.poshthemes\atomic.omp.json"
# Ou baixe diretamente: https://ohmyposh.dev/docs/themes
```

### 6. Limpar o cache de plugins (quando necessário)

O perfil gera um cache em `~\.cache_pwsh_plugins.ps1` na primeira execução para evitar reinicializar OMP e Zoxide a cada boot. Se você instalar, remover ou atualizar esses componentes, limpe o cache:

```powershell
Limpar-Cache
# Reinicie o terminal em seguida
```

### 7. Verificar o boot time

Ao abrir o terminal, o tempo de carregamento é exibido automaticamente:

```
PS 7.6.1 · OMP:atomic, Zoxide  [143ms]   ← dentro do alvo (verde)
PS 7.6.1 · OMP:atomic, Zoxide  [287ms]   ← aceitável (amarelo)
PS 7.6.1 · OMP:atomic, Zoxide  [543ms]   ← investigar (vermelho)
```

---

## Referência de Comandos

### Navegação

| Comando | Ação |
|---|---|
| `docs` | Vai para `~/Documents` |
| `dtop` | Vai para `~/Desktop` |
| `home` | Vai para `$HOME` |
| `up` | Sobe um nível (`cd ..`) |
| `up2` | Sobe dois níveis (`cd ../..`) |
| `la` | Lista arquivos em formato tabela |
| `ll` | Lista arquivos incluindo ocultos |
| `mkcd <path>` | Cria diretório e entra nele |
| `nf <nome>` | Cria arquivo(s) vazio(s) |

> **Nota:** `home` e `up` substituem os atalhos `~` e `..` que em alguns contextos conflitam com operadores nativos do PowerShell.

> **Zoxide (`z`):** após alguns acessos, `z proj` navega para `~/Dev/projetos/meu-projeto` automaticamente por frequência de uso.

---

### Arquivos e Texto

| Comando | Ação |
|---|---|
| `touch <arquivo>` | Cria arquivo ou atualiza timestamp |
| `which <cmd>` | Mostra o path do executável |
| `unzip <arquivo> [dest]` | Extrai `.zip` (padrão: pasta atual) |
| `head <arquivo> [n]` | Primeiras N linhas (padrão: 10) |
| `tail <arquivo> [n]` | Últimas N linhas (padrão: 10) |
| `grep <pattern>` | Filtra entrada via pipeline |
| `clip` | Copia pipeline inteiro para a área de transferência |
| `cpy` | Alias de `clip` |
| `pst` | Cola da área de transferência |
| `sed <arq> <achar> <subst> [-Backup]` | Substituição atômica em arquivo (UTF-8 safe) |
| `icons` | Carrega Terminal-Icons (lazy load) |
| `Limpar-Cache` | Remove o cache de plugins e solicita reinício |

**Exemplos:**

```powershell
# Filtrar linhas com "erro" de um log
Get-Content app.log | grep "erro"

# Copiar output de um comando para a área de transferência
git log --oneline -20 | clip

# Substituição segura em arquivo UTF-8 (com backup automático)
sed .\config.json "localhost" "192.168.1.10" -Backup

# Criar múltiplos arquivos via pipeline
"index.html","style.css","app.js" | nf

# Atualizar timestamp de múltiplos arquivos via pipeline
"index.html","style.css","app.js" | touch
```

---

### Git

| Comando | Equivalente Git |
|---|---|
| `gst` / `gs` | `git status -sb` |
| `ga` | `git add .` |
| `gco <msg>` | `git commit -m "<msg>"` |
| `gpush` | `git push` |
| `gpull` | `git pull` |
| `glog` | `git log --oneline --graph -15` |
| `gundo` | `git reset --soft HEAD~1` (desfaz último commit, mantém alterações) |
| `gdiff` | `git diff` |
| `gcl <url>` | `git clone <url>` |
| `gcom <msg>` | `git add .`; `git commit -m "<msg>"` |
| `lazyg <msg>` | `git add .`; `git commit -m "<msg>"`; `git push` (pede confirmação) |

**Exemplo de fluxo rápido:**

```powershell
# Visualiza status, depois stage + commit + push com confirmação interativa
lazyg "fix: corrige validação do formulário"

# Bypass da confirmação (útil em scripts ou CI)
lazyg "chore: bump version" -Force
```

> ⚠️ **`lazyg` é destrutivo** — faz stage de *tudo*, comita e empurra em sequência. Sempre revise o `git status` exibido antes de confirmar com `s`.

> **Nota:** Os comandos são encadeados com `;` (ponto e vírgula), não com `&&`. O operador `&&` só existe no PowerShell 7+. Como o perfil suporta PS 5.1, o `;` garante compatibilidade universal.

---

### Sistema

| Comando | Ação |
|---|---|
| `df` | Uso de disco por volume (tamanho, livre, % livre) |
| `pgrep <nome>` | Busca processos por nome (exibe ID, CPU e RAM em MB) |
| `pkill <nome>` / `k9 <nome>` | Encerra processo pelo nome (`Stop-Process -Force`) |
| `flushdns` | Limpa cache DNS (requer privilégio de Administrador) |
| `pubip [-Force]` | Exibe o IP público (usa cache de sessão; `-Force` ignora o cache) |
| `sysinfo` | Resumo do sistema: host, usuário, OS, versão do PS, uptime, RAM |

---

### Admin

```powershell
# Abre nova janela PowerShell elevada
sudo

# Executa comando específico como Administrador
sudo netsh interface reset
```

> O `sudo` detecta automaticamente se está no PS 5.1 ou PS 7 e abre a versão correta com `-Verb RunAs`.

---

## Decisões Técnicas

### Sistema de cache de plugins

Na primeira execução, o perfil inicializa Zoxide e Oh My Posh, captura o output de inicialização deles em um `StringBuilder` e grava o resultado em `~\.cache_pwsh_plugins.ps1`. Nas execuções seguintes, o perfil simplesmente faz dot-source desse arquivo — eliminando o custo de invocar os executáveis externos a cada boot.

```
Primeiro boot  → gera cache  → ~200–400ms
Boots seguintes → lê cache   → custo mínimo
```

Quando instalar, remover ou atualizar OMP ou Zoxide, execute `Limpar-Cache` para regenerar.

---

### Por que `filter` em vez de `function` para `grep`?

`function` acumula todos os objetos do pipeline em `$input` antes de processar. `filter` processa cada objeto imediatamente conforme chega — essencial para pipelines com arquivos grandes ou streams contínuos.

```powershell
# filter: processa linha a linha (streaming real, sem alocação de coleção)
filter grep([string]$Pattern) { $_ | Select-String -Pattern $Pattern }
```

---

### Por que `begin/process/end` em `clip`?

Um `filter` chamaria `Set-Clipboard` a cada item do pipeline — cada chamada sobrescreveria a anterior. Com 10 linhas em pipe, apenas a última seria copiada. O bloco `begin/process/end` acumula tudo em um `StringBuilder` e grava **uma única vez** no `end {}`.

```powershell
function clip {
    begin   { $buf = [System.Text.StringBuilder]::new() }
    process { [void]$buf.AppendLine($_) }
    end     { $buf.ToString().TrimEnd() | Set-Clipboard }
}
```

---

### Escrita atômica no `sed`

O `sed` nunca sobrescreve o arquivo original diretamente. O fluxo é:

```
Lê original → processa → grava em .tmp → Move-Item substitui atomicamente
```

Se qualquer etapa falhar, o `.tmp` é removido e o original permanece intacto. O parâmetro `-Backup` cria uma cópia `.bak` antes da substituição.

---

### Por que `Get-Command` em vez de `Get-Module -ListAvailable`?

`Get-Module -ListAvailable` varre todos os diretórios do `$env:PSModulePath` em disco. `Get-Command` consulta apenas o que já está resolvido no PATH — aproximadamente **100ms mais rápido** no boot, onde cada milissegundo importa.

---

### Por que Terminal-Icons é lazy load?

O módulo custa entre 80ms e 150ms para importar. Como ícones só importam em sessões interativas de exploração de arquivos, ele é carregado sob demanda:

```powershell
# Carrega ícones apenas quando necessário
icons
```

---

### Encoding UTF-8 explícito no `sed`

O PS 5.1 usa encoding `Default` (ANSI/Windows-1252) e o PS 7 usa UTF-8 sem BOM por padrão em algumas operações. Sem `-Encoding UTF8` explícito, arquivos com caracteres especiais podem ser corrompidos entre versões. O `sed` deste perfil usa `[System.IO.File]::WriteAllText` com `[System.Text.Encoding]::UTF8` para garantir consistência em ambas as versões.

---

### Cache de sessão no `pubip`

A primeira chamada a `pubip` consulta `https://api.ipify.org` e armazena o resultado em `$script:CachedPublicIP`. Chamadas subsequentes retornam o valor em memória sem nova requisição de rede. Use `-Force` para forçar uma nova consulta.

---

### Escopo `$script:` nas variáveis globais

Variáveis como `$script:BootTimer`, `$script:StartupModules` e `$script:CachedPublicIP` usam o escopo `$script:` explicitamente para evitar colisão com variáveis que o usuário possa definir na sessão interativa.

---

### Por que `;` e não `&&` no encadeamento de comandos?

O operador `&&` (pipeline chain operator) foi introduzido no PowerShell 7.0. Como este perfil declara compatibilidade com PS 5.1 (`#Requires -Version 5.1`), todos os encadeamentos usam `;` (ponto e vírgula), que executa o próximo comando incondicionalmente. Funções como `lazyg` e `gcom` dependem desse padrão para funcionar em ambas as versões.

---

## Notas de Estudo

### O perfil é um script executado a cada abertura

Tudo no `Microsoft.PowerShell_profile.ps1` roda toda vez que o terminal inicia. Se o boot estiver lento, o culpado é quase sempre um módulo pesado sendo importado de forma bloqueante. Use o timer embutido para diagnosticar:

```
PS 7.6.1 · OMP:atomic, Zoxide  [143ms]   ← dentro do alvo  ✅
PS 7.6.1 · OMP:atomic, Zoxide  [387ms]   ← aceitável       🟡
PS 7.6.1 · OMP:atomic, Zoxide  [543ms]   ← investigar      🔴
```

---

### Conceitos abordados neste perfil

| Conceito | Onde aparece no perfil |
|---|---|
| Aliases | `gs`, `k9`, `cpy` — atalhos para funções e cmdlets |
| Funções customizadas | `lazyg`, `sysinfo`, `mkcd` — blocos reutilizáveis |
| Filter vs Function | `grep` usa `filter` para streaming real no pipeline |
| `begin/process/end` | `clip` — controle fino do ciclo de vida do pipeline |
| Lazy Loading | `icons` — importação sob demanda |
| Cache de sessão | `pubip`, `$script:CachedPublicIP` — evita requisições repetidas |
| Cache em disco | `~\.cache_pwsh_plugins.ps1` — evita reinicializar OMP/Zoxide |
| Caching de estado | `$PSMajor`, `$IsAdmin` — evita recalcular a cada uso |
| Escopo explícito | `$script:` — isola variáveis do perfil da sessão do usuário |
| Escrita atômica | `sed` — protege o original contra falhas parciais |
| Módulos externos | PSReadLine, Terminal-Icons, Oh My Posh, Zoxide |
| Execução condicional | Features do PS 7 ativadas via `if ($PSMajor -ge 7)` |
| Encadeamento com `;` | `gcom`, `lazyg` — compatível com PS 5.1 e 7+ |

---

### Execution Policy no Windows

Diferente do Linux, o Windows bloqueia scripts não assinados por padrão. Para habilitar a execução do perfil:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Estrutura do Repositório

```
config-powershell7/
├── Microsoft.PowerShell_profile.ps1   # Perfil principal
└── README.md                          # Esta documentação
```

---

*Revisão: 2026-04 — PS 5.1+ / PS Core 7+ / Windows 10+*
