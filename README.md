# PowerShell Profile

Perfil de inicialização do PowerShell otimizado para **mínima latência de boot**, **ergonomia no desenvolvimento** e **portabilidade**. Projetado para ser restaurado rapidamente após formatação ou migração de máquina.

> **⏱️ Boot time alvo:** < 200ms em sessão limpa | < 400ms com Oh My Posh + Zoxide ativos

---

## 📑 Índice

1. [Requisitos](#-requisitos)
2. [Instalação](#-instalação)
3. [Comandos Disponíveis](#-comandos-disponíveis)
4. [Testes Unitários](#-testes-unitários)
5. [Decisões Técnicas](#-decisões-técnicas)
6. [Notas de Estudo](#-notas-de-estudo)
7. [Estrutura do Repositório](#-estrutura-do-repositório)

---

## 🛠️ Requisitos

| Componente | Instalação | Obrigatório |
|------------|------------|-------------|
| **PowerShell 5.1+** | Incluso no Windows 10+<br>PS 7: `winget install Microsoft.PowerShell` | ✅ |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com)<br>Recomendada: `FiraCode Nerd Font` | ✅ (para ícones) |
| **Git** | `winget install Git.Git` | ✅ |
| **Oh My Posh** | `winget install JanDeLaaj.oh-my-posh` | Opcional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Opcional |
| **PSReadLine** | Incluso no PS 7<br>Atualizar: `Install-Module PSReadLine -Force` | ✅ |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Opcional (lazy load) |

---

## 📥 Instalação

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

**Opção A — Cópia direta (simples):**

```powershell
Copy-Item .\Microsoft.PowerShell_profile.ps1 $PROFILE -Force
```

**Opção B — Link simbólico (mantém sincronizado com `git pull`):**

```powershell
# Requer terminal como Administrador
New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
```

---

## 📚 Comandos Disponíveis

### Navegação

| Comando | Ação |
|---------|------|
| `docs` | Vai para `~/Documents` |
| `dtop` | Vai para `~/Desktop` |
| `home` | Vai para `$HOME` |
| `up` | Sobe um nível (`cd ..`) |
| `la` | Lista arquivos em formato tabela |
| `mkcd <path>` | Cria diretório e entra nele |
| `nf <nome>` | Cria arquivo(s) vazio(s) |

### Git

| Comando | Equivalente Git |
|---------|-----------------|
| `gst` / `gs` | `git status -sb` |
| `gcom <msg>` | `git add .` + `git commit -m "<msg>"` |
| `lazyg <msg>` | `git add .` + `commit` + `push` (pede confirmação) |

---

## 🧪 Testes Unitários

Para garantir que todas as funções e aliases estão operando corretamente e que nenhuma alteração quebrou o sistema, o projeto inclui uma suíte de testes automatizados.

### Como executar os testes

1. **Permitir a execução de scripts** (necessário apenas uma vez):
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **Carregar o perfil atual** (garante que as funções estão na memória):
   ```powershell
   . $PROFILE
   ```

3. **Executar o script de teste**:
   ```powershell
   .\Microsoft.PowerShell_profile.Tests.ps1
   ```

### O que é validado?
O script executa **36 testes de unidade**, verificando:
* **Integridade de Navegação:** Se `home`, `docs` e `up` acessam os diretórios corretos.
* **Operações de Arquivo:** Validação de criação de diretórios com `mkcd` e manipulação de arquivos com `nf` e `touch`.
* **Processamento de Texto:** Verificação da lógica de `head` e `tail`.
* **Sistema de Cache:** Checagem se as funções de limpeza de cache de plugins estão registradas.
* **Disponibilidade de Comandos:** Garante que todos os aliases de Git, Sistema e Administração (Sudo) foram carregados com sucesso.

---

## 🧠 Decisões Técnicas

### Sistema de cache de plugins
Na primeira execução, o perfil inicializa Zoxide e Oh My Posh, captura o output e grava em `~\.cache_pwsh_plugins.ps1`. Nas execuções seguintes, apenas faz dot-source desse arquivo, reduzindo drasticamente o tempo de boot.

### Escrita atômica no `sed`
O comando `sed` utiliza um arquivo temporário para processamento. O arquivo original só é substituído após a conclusão da escrita no `.tmp`, prevenindo corrupção de dados em caso de falha no processo.

---

## 📖 Notas de Estudo

### Execution Policy no Windows
O Windows bloqueia scripts por padrão. Para usar este perfil e rodar os testes unitários, você deve configurar a política para `RemoteSigned`:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 📁 Estrutura do Repositório

```
config-powershell7/
├── Microsoft.PowerShell_profile.ps1        # Perfil principal
├── Microsoft.PowerShell_profile.Tests.ps1  # Suíte de testes unitários
├── README.md                               # Documentação em português
├── README.en.md                            # Documentação em inglês
├── .gitignore                              # Filtros de arquivos para o Git
├── LICENSE                                 # Licença MIT (EN)
└── LICENÇA.pt-BR                           # Licença MIT (PT-BR)
```

---

*Revisão: 2026-04 — Compatível com PS 5.1+ / PS Core 7+ / Windows 10+*
