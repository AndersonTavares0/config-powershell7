# PowerShell Profile

> Perfil de inicialização do PowerShell otimizado para **mínima latência de boot**, **ergonomia no desenvolvimento** e **portabilidade**.  
> Projetado para ser restaurado rapidamente após formatação ou migração de máquina.

![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-10%2B-blue?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

> **Boot time alvo:** < 200ms em sessão limpa | < 400ms com Oh My Posh + Zoxide ativos

[Ver documentação técnica → docs.md](docs.md)

---

## Índice

1. [Descrição](#descrição)
2. [Recursos](#recursos)
3. [Compatibilidade](#compatibilidade)
4. [Instalação](#instalação)
5. [Uso](#uso)
6. [Aliases](#aliases)
7. [Funções](#funções)
8. [Performance](#performance)
9. [Troubleshooting](#troubleshooting)
10. [Testes](#testes)
11. [Estrutura do Repositório](#estrutura-do-repositório)
12. [Uso de IA](#uso-de-ia)

---

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

## Compatibilidade

| Componente | Versão mínima |
|---|---|
| Windows | 10 ou superior |
| PowerShell | 5.1+ (funcionalidades completas no PS 7+) |
| Oh My Posh | Qualquer versão atual (opcional) |
| Zoxide | Qualquer versão atual (opcional) |

> O perfil detecta automaticamente a versão do PowerShell e ativa funcionalidades avançadas do PSReadLine apenas no PS 7+.

---

## Instalação

### Pré-requisitos

| Componente | Instalação | Obrigatório |
|---|---|---|
| **PowerShell 5.1+** | Incluso no Windows 10+<br>PS 7: `winget install Microsoft.PowerShell` | ✅ |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com)<br>Recomendada: `FiraCode Nerd Font` | ✅ |
| **Git** | `winget install Git.Git` | ✅ |
| **Oh My Posh** | `winget install JanDeDobbeleer.OhMyPosh` | Opcional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Opcional |
| **PSReadLine** | Incluso no PS 7<br>Atualizar: `Install-Module PSReadLine -Force` | ✅ |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Opcional |

### 1. Configurar a Execution Policy

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. Clonar o repositório

```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
```

### 3. Desbloquear os arquivos

Arquivos baixados do GitHub podem ser bloqueados pelo Windows. Execute antes de aplicar o perfil:

```powershell
Get-ChildItem *.ps1 | Unblock-File
```

> ⚠️ **Erro comum:** Se você receber *"The file is not digitally signed"*, execute `Unblock-File` primeiro.

### 4. Localizar o caminho do perfil

```powershell
$PROFILE
```

### 5. Aplicar o perfil

**Opção A — Cópia direta:**

```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Opção B — Link simbólico (Recomendado — requer Admin):**

```powershell
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

### 6. Instalar o tema Oh My Posh (opcional)

O perfil espera o tema em `$HOME\.poshthemes\atomic.omp.json`. Se o arquivo não existir, o tema padrão do Oh My Posh é usado automaticamente.

```powershell
# Criar diretório e baixar o tema
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh font install
```

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

- 🟢 Verde: < 200ms
- 🟡 Amarelo: 200–400ms
- 🔴 Vermelho: > 400ms

---

## Troubleshooting

### Profile não carrega

**Sintoma:** nenhum alias ou função disponível após abrir o terminal.

**Solução:**

```powershell
# Verificar se o perfil existe
Test-Path $PROFILE

# Verificar qual arquivo está sendo carregado
$PROFILE

# Recarregar manualmente
. $PROFILE
```

### Erro de Execution Policy

**Sintoma:** `"File cannot be loaded because running scripts is disabled on this system."`

**Solução:**

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Arquivo bloqueado pelo Windows

**Sintoma:** `"The file is not digitally signed."`

**Solução:**

```powershell
Get-ChildItem *.ps1 | Unblock-File
```

### Comando não reconhecido após instalação

**Sintoma:** `"The term 'gst' is not recognized..."`

**Causa:** Git não está no PATH, ou o perfil não foi recarregado.

**Solução:**

```powershell
# Verificar se git está disponível
Get-Command git -ErrorAction SilentlyContinue

# Recarregar o perfil
. $PROFILE
```

### Módulos não encontrados

**Sintoma:** Terminal-Icons ou PSReadLine não carregam.

**Solução:**

```powershell
Install-Module -Name Terminal-Icons -Scope CurrentUser
Install-Module -Name PSReadLine -Scope CurrentUser -Force
```

### Cache corrompido ou desatualizado

**Sintoma:** Oh My Posh ou Zoxide não inicializam corretamente.

**Solução:**

```powershell
Clear-Cache
# Reinicie o terminal após executar
```

### flushdns não funciona

**Sintoma:** `"flushdns requer privilégios de Administrador."`

**Solução:** Execute o terminal como Administrador ou use `sudo flushdns`.

---

## Testes

O projeto inclui testes unitários em `Microsoft.PowerShell_profile.Tests_diff.ps1`, implementados com framework próprio (sem dependências externas).

### Executar

```powershell
cd config-powershell7
.\Microsoft.PowerShell_profile.Tests_diff.ps1

# Com saída detalhada
.\Microsoft.PowerShell_profile.Tests_diff.ps1 -Verbose
```

### Cobertura

| Categoria | Itens testados |
|---|---|
| **Navegação** | `docs`, `dtop`, `home`, `up`, `up2`, `la`, `ll`, `mkcd`, `nf` |
| **Arquivos e Texto** | `touch`, `which`, `unzip`, `head`, `tail`, `grep`, `cpy`, `pst`, `Copy-ToClipboard`, `sed` |
| **Sistema** | `pkill`, `k9`, `pgrep`, `flushdns`, `df`, `pubip`, `sysinfo` |
| **Git** | `gst`, `gss`, `ga`, `gcmt`, `gco`, `gpush`, `gpull`, `glog`, `gundo`, `gdiff`, `gcl`, `gcom`, `lazyg` |
| **Administração** | `sudo` |
| **Plugin Cache** | `Clear-PluginCache`, `Clear-Cache`, `Import-TerminalIcons`, `icons` |

### Resultado esperado

```
========================================
TEST SUMMARY
========================================
Total Tests: XX
Passed:      XX
Failed:      0
========================================
```

- ✅ Todos passaram: perfil funcionando corretamente.
- ❌ Algum falhou: verifique dependências e Execution Policy.

---

## Estrutura do Repositório

```
config-powershell7/
├── Microsoft.PowerShell_profile.ps1           # Código principal do perfil
├── Microsoft.PowerShell_profile.Tests_diff.ps1 # Testes unitários
├── readme.md                                   # Documentação PT-BR
├── readme.en.md                                # Documentação EN
├── docs.md                                     # Documentação técnica PT-BR
├── docs.en.md                                  # Documentação técnica EN
├── LICENSE                                     # Licença MIT (EN)
├── LICENÇA.pt-BR                               # Licença MIT (PT-BR)
└── .gitignore                                  # Filtros do Git
```

---

## Uso de IA

Este projeto utilizou ferramentas de **Inteligência Artificial** para auxiliar na documentação, revisão de código e refatoração, garantindo boas práticas de engenharia de software, consistência e performance.

---

*Revisão: 29/04/2026 — Compatível com PS 5.1+ / PS Core 7+ / Windows 10+*
