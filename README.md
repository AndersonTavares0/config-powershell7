# PowerShell Profile

Perfil de inicialização do PowerShell otimizado para **mínima latência de boot**, **ergonomia no desenvolvimento** e **portabilidade**. Projetado para ser restaurado rapidamente após formatação ou migração de máquina.

> **Boot time alvo:** < 200ms em sessão limpa | < 400ms com Oh My Posh + Zoxide ativos

---

## Índice

1. [Requisitos](#-requisitos)
2. [Instalação](#-instalação)
3. [Comandos Disponíveis](#-comandos-disponíveis)
   - [Navegação](#navegação)
   - [Arquivos e Texto](#arquivos-e-texto)
   - [Git](#git)
   - [Sistema](#sistema)
   - [Administração](#administração)
4. [Decisões Técnicas](#-decisões-técnicas)
5. [Notas de Estudo](#-notas-de-estudo)
6. [Estrutura do Repositório](#-estrutura-do-repositório)
7. [Desenvolvimento Assistido por IA](#ai-assisted-development)

---

## Requisitos

| Componente | Instalação | Obrigatório |
|------------|------------|-------------|
| **PowerShell 5.1+** | Incluso no Windows 10+<br>PS 7: `winget install Microsoft.PowerShell` | ✅ |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com)<br>Recomendada: `FiraCode Nerd Font` | ✅ (para ícones) |
| **Git** | `winget install Git.Git` | ✅ |
| **Oh My Posh** | `winget install JanDeLaaj.oh-my-posh` | Opcional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Opcional |
| **PSReadLine** | Incluso no PS 7<br>Atualizar: `Install-Module PSReadLine -Force` | ✅ |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Opcional (lazy load) |

> **Compatibilidade:** Funciona no PS 5.1 (Windows PowerShell) e PS Core 7+. Recursos exclusivos do PS 7 são ativados condicionalmente.

---

## Instalação

### 1. Clonar o repositório

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
```

### 2. Localizar o caminho do perfil

```powershell
$PROFILE
```

Saída esperada:
- **PS 7:** `C:\Users\<usuario>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`
- **PS 5.1:** `C:\Users\<usuario>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`

### 3. Aplicar o perfil

**Opção A — Cópia direta (simples):**

```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Opção B — Link simbólico (mantém sincronizado com `git pull`):**

```powershell
# Requer terminal como Administrador
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

### 4. Instalar módulos necessários

```powershell
Install-Module PSReadLine     -AllowPrerelease -Force -Scope CurrentUser
Install-Module Terminal-Icons -Repository PSGallery  -Scope CurrentUser
```

### 5. Configurar tema do Oh My Posh

O perfil procura o tema `atomic` em `~\.poshthemes\atomic.omp.json`. Se não existir, usa o tema padrão.

```powershell
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh config export --output "$HOME\.poshthemes\atomic.omp.json"
```

Ou baixe diretamente de: [https://ohmyposh.dev/docs/themes](https://ohmyposh.dev/docs/themes)

### 6. Limpar cache de plugins (quando necessário)

O perfil gera um cache em `~\.cache_pwsh_plugins.ps1` na primeira execução. Se instalar, remover ou atualizar OMP/Zoxide:

```powershell
Limpar-Cache
# Reinicie o terminal em seguida
```

### 7. Verificar o boot time

Ao abrir o terminal, o tempo de carregamento é exibido automaticamente:

```
PS 7.6.1 · OMP:atomic, Zoxide  [143ms]   ← dentro do alvo
PS 7.6.1 · OMP:atomic, Zoxide  [287ms]   ← aceitável
PS 7.6.1 · OMP:atomic, Zoxide  [543ms]   ← investigar
```

---

## Comandos Disponíveis

### Navegação

| Comando | Ação |
|---------|------|
| `docs` | Vai para `~/Documents` |
| `dtop` | Vai para `~/Desktop` |
| `home` | Vai para `$HOME` |
| `up` | Sobe um nível (`cd ..`) |
| `up2` | Sobe dois níveis (`cd ../..`) |
| `la` | Lista arquivos em formato tabela |
| `ll` | Lista arquivos incluindo ocultos |
| `mkcd <path>` | Cria diretório e entra nele |
| `nf <nome>` | Cria arquivo(s) vazio(s) |
| `z <path>` | Navegação inteligente por frequência (Zoxide) |

> **Nota:** `home` e `up` substituem `~` e `..` para evitar conflitos com operadores nativos do PowerShell.

> **Zoxide:** Após alguns acessos, `z proj` navega automaticamente para `~/Dev/projetos/meu-projeto` baseado na frequência de uso.

---

### Arquivos e Texto

| Comando | Ação |
|---------|------|
| `touch <arquivo>` | Cria arquivo ou atualiza timestamp |
| `which <cmd>` | Mostra o path do executável |
| `unzip <arquivo> [dest]` | Extrai `.zip` (padrão: pasta atual) |
| `head <arquivo> [n]` | Primeiras N linhas (padrão: 10) |
| `tail <arquivo> [n]` | Últimas N linhas (padrão: 10) |
| `grep <pattern>` | Filtra entrada via pipeline |
| `clip` / `cpy` | Copia pipeline inteiro para clipboard |
| `pst` | Cola do clipboard |
| `sed <arq> <achar> <subst> [-Backup]` | Substituição atômica em arquivo (UTF-8 safe) |
| `icons` | Carrega Terminal-Icons (lazy load) |
| `Limpar-Cache` | Remove cache de plugins |

**Exemplos de uso:**

```powershell
# Filtrar linhas com "erro" de um log
Get-Content app.log | grep "erro"

# Copiar output para clipboard
git log --oneline -20 | clip

# Substituição segura em arquivo UTF-8 (com backup)
sed .\config.json "localhost" "192.168.1.10" -Backup

# Criar múltiplos arquivos via pipeline
"index.html","style.css","app.js" | nf

# Atualizar timestamp de múltiplos arquivos
"index.html","style.css","app.js" | touch
```

---

### Git

| Comando | Equivalente Git |
|---------|-----------------|
| `gst` / `gs` | `git status -sb` |
| `ga` | `git add .` |
| `gco <msg>` | `git commit -m "<msg>"` |
| `gpush` | `git push` |
| `gpull` | `git pull` |
| `glog` | `git log --oneline --graph -15` |
| `gundo` | `git reset --soft HEAD~1` |
| `gdiff` | `git diff` |
| `gcl <url>` | `git clone <url>` |
| `gcom <msg>` | `git add .` + `git commit -m "<msg>"` |
| `lazyg <msg>` | `git add .` + `commit` + `push` (pede confirmação) |

**Fluxo rápido:**

```powershell
# Visualiza status e pede confirmação antes de stage+commit+push
lazyg "fix: corrige validação do formulário"

# Bypass da confirmação (útil em scripts/CI)
lazyg "chore: bump version" -Force
```

> **Atenção:** `lazyg` é destrutivo — faz stage de *tudo*. Sempre revise o `git status` antes de confirmar.

> **Nota:** Os comandos usam `;` (ponto e vírgula) para compatibilidade com PS 5.1 e 7+.

---

### Sistema

| Comando | Ação |
|---------|------|
| `df` | Uso de disco por volume (tamanho, livre, %) |
| `pgrep <nome>` | Busca processos por nome (ID, CPU, RAM em MB) |
| `pkill <nome>` / `k9 <nome>` | Encerra processo pelo nome |
| `flushdns` | Limpa cache DNS (requer Admin) |
| `pubip [-Force]` | Exibe IP público (usa cache de sessão) |
| `sysinfo` | Resumo do sistema (host, usuário, OS, uptime, RAM) |

---

### Administração

```powershell
# Abre nova janela PowerShell elevada
sudo

# Executa comando específico como Administrador
sudo netsh interface reset
```

> O `sudo` detecta automaticamente se está no PS 5.1 ou PS 7 e abre a versão correta.

---

## Decisões Técnicas

### Sistema de cache de plugins

Na primeira execução, o perfil inicializa Zoxide e Oh My Posh, captura o output em um `StringBuilder` e grava em `~\.cache_pwsh_plugins.ps1`. Nas execuções seguintes, apenas faz dot-source desse arquivo.

```
Primeiro boot  → gera cache  → ~200–400ms
Boots seguintes → lê cache    → custo mínimo
```

Use `Limpar-Cache` ao instalar/remover/atualizar OMP ou Zoxide.

---

### Por que `filter` em vez de `function` para `grep`?

`function` acumula todos os objetos do pipeline em `$input` antes de processar. `filter` processa cada objeto imediatamente conforme chega — essencial para pipelines grandes ou streams contínuos.

```powershell
# filter: processa linha a linha (streaming real, sem alocação)
filter grep([string]$Pattern) { $_ | Select-String -Pattern $Pattern }
```

---

### Por que `begin/process/end` em `clip`?

Um `filter` chamaria `Set-Clipboard` a cada item do pipeline — cada chamada sobrescreveria a anterior. O bloco `begin/process/end` acumula tudo e grava **uma única vez**:

```powershell
function clip {
    begin   { $buf = [System.Text.StringBuilder]::new() }
    process { [void]$buf.AppendLine($_) }
    end     { $buf.ToString().TrimEnd() | Set-Clipboard }
}
```

---

### Escrita atômica no `sed`

O `sed` nunca sobrescreve o original diretamente:

```
Lê original → processa → grava em .tmp → Move-Item substitui atomicamente
```

Se qualquer etapa falhar, o `.tmp` é removido e o original permanece intacto. Use `-Backup` para criar uma cópia `.bak` antes da substituição.

---

### Por que `Get-Command` em vez de `Get-Module -ListAvailable`?

`Get-Module -ListAvailable` varre todos os diretórios do `$env:PSModulePath` em disco. `Get-Command` consulta apenas o que já está resolvido no PATH — aproximadamente **100ms mais rápido** no boot.

---

### Por que Terminal-Icons é lazy load?

O módulo custa entre 80ms e 150ms para importar. Como ícones só importam em sessões interativas, ele é carregado sob demanda:

```powershell
icons  # Carrega apenas quando necessário
```

---

### Encoding UTF-8 explícito no `sed`

PS 5.1 usa encoding `Default` (ANSI/Windows-1252) e PS 7 usa UTF-8 sem BOM. Sem `-Encoding UTF8` explícito, arquivos com caracteres especiais podem ser corrompidos. O `sed` usa `[System.IO.File]::WriteAllText` com `[System.Text.Encoding]::UTF8` para consistência.

---

### Cache de sessão no `pubip`

A primeira chamada consulta `https://api.ipify.org` e armazena em `$script:CachedPublicIP`. Chamadas subsequentes retornam o valor em memória. Use `-Force` para forçar nova consulta.

---

### Escopo `$script:` nas variáveis globais

Variáveis como `$script:BootTimer`, `$script:StartupModules` e `$script:CachedPublicIP` usam `$script:` explicitamente para evitar colisão com variáveis do usuário na sessão interativa.

---

### Por que `;` e não `&&` no encadeamento?

O operador `&&` foi introduzido no PowerShell 7.0. Como este perfil suporta PS 5.1 (`#Requires -Version 5.1`), todos os encadeamentos usam `;` para garantir compatibilidade universal.

---

## Notas de Estudo

### O perfil é um script executado a cada abertura

Tudo no `Microsoft.PowerShell_profile.ps1` roda toda vez que o terminal inicia. Se o boot estiver lento, o culpado é quase sempre um módulo pesado sendo importado de forma bloqueante.

Use o timer embutido para diagnosticar:

```
PS 7.6.1 · OMP:atomic, Zoxide  [143ms]   ← dentro do alvo
PS 7.6.1 · OMP:atomic, Zoxide  [387ms]   ← aceitável
PS 7.6.1 · OMP:atomic, Zoxide  [543ms]   ← investigar
```

---

### Conceitos abordados neste perfil

| Conceito | Onde aparece |
|----------|--------------|
| Aliases | `gs`, `k9`, `cpy` — atalhos para funções e cmdlets |
| Funções customizadas | `lazyg`, `sysinfo`, `mkcd` — blocos reutilizáveis |
| Filter vs Function | `grep` usa `filter` para streaming real |
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
├── README.md                          # Documentação em português
├── README.en.md                       # Documentação em inglês
├── LICENSE                            # Licença MIT (EN)
└── LICENÇA.pt-BR                      # Licença MIT (PT-BR)
```

---

*Revisão: 2026-04 — Compatível com PS 5.1+ / PS Core 7+ / Windows 10+*

---

## AI-Assisted Development

Este projeto foi refatorado, revisado e documentado com a assistência de **modelos LLM/AI** para aprimorar a qualidade do código, clareza da documentação e implementação de boas práticas.

> **Nota:** As ferramentas de IA foram utilizadas como apoio na refatoração, revisão e documentação, mas todas as decisões técnicas e implementações foram validadas e aprovadas por desenvolvedores humanos.
