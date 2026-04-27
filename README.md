# PowerShell Profile

Perfil de inicialização do PowerShell otimizado para **mínima latência de boot**, **ergonomia no desenvolvimento** e **portabilidade**. Projetado para ser restaurado rapidamente após formatação ou migração de máquina.

> **Boot time alvo:** < 200ms em sessão limpa | < 400ms com Oh My Posh + Zoxide ativos

---

## Índice

1. [Requisitos](#requisitos)
2. [Instalação](#instalação)
3. [Comandos Disponíveis](#comandos-disponíveis)
   - [Navegação](#navegação)
   - [Arquivos e Texto](#arquivos-e-texto)
   - [Git](#git)
   - [Sistema](#sistema)
   - [Administração](#administração)
4. [Decisões Técnicas](#decisões-técnicas)
5. [Notas de Estudo](#notas-de-estudo)
6. [Estrutura do Repositório](#estrutura-do-repositório)
7. [AI-Assisted Development](#ai-assisted-development)

---

## Requisitos

| Componente | Instalação | Obrigatório |
|------------|------------|-------------|
| **PowerShell 5.1+** | Incluso no Windows 10+<br>PS 7: `winget install Microsoft.PowerShell` | ✅ |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com)<br>Recomendada: `FiraCode Nerd Font` | ✅ |
| **Git** | `winget install Git.Git` | ✅ |
| **Oh My Posh** | `winget install JanDeLaaj.oh-my-posh` | Opcional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Opcional |
| **PSReadLine** | Incluso no PS 7<br>Atualizar: `Install-Module PSReadLine -Force` | ✅ |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Opcional |

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

### 3. Aplicar o perfil

**Opção A — Cópia direta:**
```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Opção B — Link simbólico (Recomendado):**
```powershell
# Requer Admin
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

---

## Comandos Disponíveis

### Navegação

| Comando | Ação |
|---------|------|
| `docs` | Vai para `~/Documents` |
| `home` | Vai para `$HOME` |
| `up` | Sobe um nível (`cd ..`) |
| `la` | Lista arquivos em tabela |
| `mkcd <path>` | Cria diretório e entra nele |

### Arquivos e Texto

| Comando | Ação |
|---------|------|
| `touch <arq>` | Cria arquivo ou atualiza data |
| `grep <pat>` | Filtra entrada via pipeline |
| `clip` | Copia pipeline para o clipboard |
| `sed` | Substituição atômica em arquivos |

### Git

| Comando | Equivalente Git |
|---------|-----------------|
| `gst` | `git status -sb` |
| `gcom <m>` | `git add .` + `commit` |
| `lazyg <m>` | `add` + `commit` + `push` |

### Sistema

| Comando | Ação |
|---------|------|
| `df` | Uso de disco |
| `pubip` | Exibe IP público (cacheado) |
| `sysinfo` | Resumo de hardware e uptime |

### Administração

```powershell
# Abre nova janela como Administrador
sudo
```

---

## Decisões Técnicas

### Sistema de cache de plugins
O perfil gera um cache em `~\.cache_pwsh_plugins.ps1` para evitar carregar o Zoxide e o Oh My Posh do zero em cada aba, o que economiza cerca de 200ms de boot.

### Escrita atômica no sed
Utilizamos um arquivo temporário para garantir que, caso o processo seja interrompido, o arquivo original não seja corrompido.

---

## Notas de Estudo

### Execution Policy no Windows
Para rodar este perfil, é necessário permitir a execução de scripts locais:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Estrutura do Repositório

```
config-powershell7/
├── Microsoft.PowerShell_profile.ps1    # Código principal
├── Microsoft.PowerShell_profile.Tests.ps1 # Testes unitários
├── README.md                           # Documentação PT-BR
└── .gitignore                          # Filtros do Git
```

---

## AI-Assisted Development

Este projeto utiliza ferramentas de **Inteligência Artificial** para otimização de código e documentação, garantindo a aplicação de boas práticas de engenharia de software e performance.
