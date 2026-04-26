#  PowerShell Profile — Otimizado para Windows

Perfil de inicialização do PowerShell 7 focado em **latência mínima de boot**, ergonomia de desenvolvimento e portabilidade. Desenvolvido para ser restaurado rapidamente em caso de formatação ou migração de máquina.

> Boot time alvo: **< 200ms** com OMP + Zoxide ativos.

---

## Índice

- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Referência de Comandos](#referência-de-comandos)
  - [Navegação](#navegação)
  - [Arquivos e Texto](#arquivos-e-texto)
  - [Git](#git)
  - [Sistema](#sistema)
  - [Admin](#admin)
- [Decisões Técnicas](#decisões-técnicas)
- [Notas de Estudo](#notas-de-estudo)

---

## Requisitos

| Componente | Instalação | Obrigatório |
|---|---|---|
| **PowerShell 7+** | [Microsoft Store](https://aka.ms/PSWindows) ou `winget install Microsoft.PowerShell` | ✅ |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com/) — Recomendado: `JetBrainsMono NF` | ✅ (para ícones) |
| **Git** | `winget install Git.Git` | ✅ |
| **Oh My Posh** | `winget install JanDeLaaj.oh-my-posh` | Opcional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Opcional |
| **PSReadLine** | Já incluso no PS 7; atualizar via `Install-Module PSReadLine -Force` | ✅ |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Opcional (lazy load) |

---

## Instalação

### 1. Clonar o repositório

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
```

### 2. Localizar o caminho do perfil

```powershell
$PROFILE
# Resultado típico: C:\Users\<usuario>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

### 3. Aplicar o perfil

**Opção A — Cópia direta** (simples):
```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Opção B — Link simbólico** (mantém o repo sincronizado com `git pull`):
```powershell
# Requer terminal com privilégios de Administrador
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

### 4. Instalar módulos necessários

```powershell
Install-Module PSReadLine      -AllowPrerelease -Force -Scope CurrentUser
Install-Module Terminal-Icons  -Repository PSGallery  -Scope CurrentUser
```

### 5. Instalar tema do Oh My Posh

O perfil espera o tema `atomic` em `~\.poshthemes\atomic.omp.json`. Para instalar:

```powershell
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh config export --output "$HOME\.poshthemes\atomic.omp.json"
# Ou baixe diretamente: https://ohmyposh.dev/docs/themes
```

### 6. Verificar o boot time

Ao abrir o terminal, o tempo de carregamento é exibido automaticamente:

```
PS 7.6.1 | OMP, Zoxide  [143ms]
```

---

## Referência de Comandos

### Navegação

| Comando | Ação |
|---|---|
| `docs` | Vai para `~/Documents` |
| `dtop` | Vai para `~/Desktop` |
| `~` | Vai para `$HOME` |
| `..` | Sobe um nível |
| `...` | Sobe dois níveis |
| `la` | Lista arquivos (formato tabela) |
| `ll` | Lista arquivos incluindo ocultos |
| `mkcd <path>` | Cria diretório e já entra nele |
| `nf <nome>` | Cria arquivo vazio |

> **Zoxide** (`z`): após alguns acessos, `z proj` navega para `~/Dev/projetos/meu-projeto` automaticamente por frequência de uso.

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
| `clip` | Copia pipeline para área de transferência |
| `cpy` | Alias de `clip` |
| `pst` | Cola da área de transferência |
| `sed <arq> <achar> <subst>` | Substituição em arquivo (UTF-8 safe) |
| `icons` | Carrega Terminal-Icons (lazy load) |

**Exemplos:**
```powershell
# Filtrar linhas com "erro" de um log
Get-Content app.log | grep "erro"

# Copiar output de um comando para a área de transferência
git log --oneline -20 | clip

# Substituição segura em arquivo UTF-8
sed .\config.json "localhost" "192.168.1.10"
```

---

### Git

| Comando | Ação equivalente |
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
| `gcom <msg>` | `git add . && git commit -m "<msg>"` |
| `lazyg <msg>` | `git add . && git commit -m "<msg>" && git push` |

**Exemplo de fluxo rápido:**
```powershell
# Commit e push em um comando
lazyg "fix: corrige validação do formulário"
```

---

### Sistema

| Comando | Ação |
|---|---|
| `df` | Uso de disco por volume |
| `pgrep <nome>` | Busca processos por nome (com uso de CPU e RAM) |
| `pkill <nome>` / `k9 <nome>` | Mata processo pelo nome |
| `flushdns` | Limpa cache DNS (requer Admin) |
| `pubip` | Exibe o IP público da máquina |
| `sysinfo` | Resumo do sistema (OS, RAM, uptime) |

---

### Admin

```powershell
# Abre nova janela PowerShell elevada
sudo

# Executa comando específico como Admin
sudo Get-EventLog -LogName System -Newest 10
```

---

## Decisões Técnicas

### Por que `filter` em vez de `function` para `grep`?

`function` em PowerShell **acumula** todos os objetos do pipeline em `$input` antes de processar. `filter` processa **cada objeto imediatamente** conforme chega, sem alocar memória para a coleção completa — essencial para pipelines com arquivos grandes.

```powershell
# filter: processa linha a linha (streaming real)
filter grep([string]$Pattern) { $_ | Select-String -Pattern $Pattern }
```

### Por que `begin/process/end` em `clip`?

Um `filter` chama `Set-Clipboard` a cada item do pipeline — **cada chamada sobrescreve a anterior**. Com 10 linhas em pipe, apenas a última seria copiada. O bloco `begin/process/end` acumula tudo em um `StringBuilder` e grava uma única vez no `end {}`.

```powershell
function clip {
    begin   { $buf = [System.Text.StringBuilder]::new() }
    process { [void]$buf.AppendLine($_) }
    end     { $buf.ToString().TrimEnd() | Set-Clipboard }
}
```

### Por que `Get-Command` em vez de `Get-Module -ListAvailable`?

`Get-Module -ListAvailable` varre **todos os diretórios** do `$env:PSModulePath` em disco. `Get-Command` consulta apenas o que já está resolvido no PATH — aproximadamente 100ms mais rápido no boot.

### Por que Terminal-Icons é lazy load?

O módulo custa entre 80ms e 150ms para importar. Como ícones só importam em sessões interativas de exploração de arquivos, ele é carregado sob demanda com `icons`:

```powershell
# Carrega ícones apenas quando necessário
icons
```

### Encoding UTF-8 explícito no `sed`

O PS 5.1 usa encoding `Default` (ANSI/Windows-1252) e o PS 7 usa `UTF8` sem BOM por padrão em algumas operações. Sem `-Encoding UTF8` explícito na leitura e escrita, arquivos com caracteres especiais podem ser corrompidos entre versões.

---

## Notas de Estudo

### O perfil é um script executado a cada abertura

Tudo no `Microsoft.PowerShell_profile.ps1` roda toda vez que o terminal inicia. Se o boot estiver lento, o culpado é quase sempre um módulo pesado sendo importado de forma bloqueante. Use o timer embutido para medir:

```
PS 7.6.1 | OMP, Zoxide  [543ms]  ← lento: investigar o que está bloqueando
PS 7.6.1 | OMP, Zoxide  [143ms]  ← dentro do alvo
```

### Conceitos abordados neste perfil

| Conceito | Onde aparece no perfil |
|---|---|
| **Aliases** | `gs`, `k9`, `cpy` — atalhos para funções e cmdlets |
| **Funções customizadas** | `lazyg`, `sysinfo`, `mkcd` — blocos reutilizáveis |
| **Filter vs Function** | `grep` usa `filter` para streaming real no pipeline |
| **begin/process/end** | `clip` — controle fino do ciclo de vida do pipeline |
| **Lazy Loading** | `icons` — importação sob demanda |
| **Caching de estado** | `$PSMajor`, `$IsAdmin` — evita recalcular a cada uso |
| **Módulos externos** | PSReadLine, Terminal-Icons, Oh My Posh, Zoxide |
| **Execution Policy** | No Windows: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |

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

*Revisão: 2026-04 — PS 7.6+ / Windows 10+*
