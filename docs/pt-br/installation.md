# Instalação e Compatibilidade

## Como funciona a Modularização

O perfil utiliza uma arquitetura modular para facilitar a manutenção e organização. O arquivo principal `Microsoft.PowerShell_profile.ps1` atua como um **Loader (Carregador)**:

1.  Ele identifica a raiz do repositório via `$global:__ProfileRepoRoot` (definido pelo instalador) ou `$PSScriptRoot` como fallback.
2.  Carrega automaticamente os scripts de `modules/` via *dot-sourcing* em ordem estrita: **config → cache → navigation → git → system → psreadline → text_utils**.
3.  Cada módulo é encapsulado em `try/catch` para que uma falha em um módulo não-crítico não bloqueie o resto do perfil.

> [!IMPORTANT]
> Você deve manter os arquivos `modules/`, `lib/` e `Microsoft.PowerShell_profile.ps1` juntos no repositório clonado para que o carregamento funcione corretamente.

---

## Compatibilidade

| Componente | Versão mínima |
|---|---|
| Windows | 10 ou superior |
| Linux | Fedora (qualquer distro moderna com PS 7+) |
| macOS | Qualquer versão com PS 7+ |
| PowerShell | 5.1+ (funcionalidades completas no PS 7+) |
| Oh My Posh | Qualquer versão atual (opcional) |
| Zoxide | Qualquer versão atual (opcional) |

> O perfil detecta automaticamente a plataforma e a versão do PowerShell, ativando funcionalidades avançadas do PSReadLine apenas no PS 7+.

---

## Instalação

### Pré-requisitos

| Componente | Instalação | Obrigatório |
|---|---|---|
| **PowerShell 7+** | `winget install Microsoft.PowerShell` (Win)<br>`sudo dnf install powershell` (Fedora) | ✅ |
| **Nerd Font** | [nerdfonts.com](https://www.nerdfonts.com)<br>Recomendada: `FiraCode Nerd Font` | ✅ |
| **Git** | `winget install Git.Git` | ✅ |
| **Oh My Posh** | `winget install JanDeDobbeleer.OhMyPosh` | Opcional |
| **Zoxide** | `winget install ajeetdsouza.zoxide` | Opcional |
| **PSReadLine** | Incluso no PS 7<br>Atualizar: `Install-Module PSReadLine -Force` | ✅ |
| **Terminal-Icons** | `Install-Module Terminal-Icons -Repository PSGallery` | Opcional |

---

### Passo 1: Configurar a Política de Execução
Abra o PowerShell e execute:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Passo 2: Clonar o repositório
```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
```

### Passo 3: Instalação Automatizada (Zero-UAC)

> **Windows:** Você também pode dar dois cliques no arquivo `install.cmd`.

O instalador cria um arquivo `$PROFILE` leve que carrega o perfil do repositório via `$global:__ProfileRepoRoot`. Sem symlinks, sem necessidade de Administrador.

**Execute em um terminal normal:**
```powershell
.\install.ps1
```

**Não-interativo (CI):**
```powershell
.\install.ps1 -NonInteractive
```

O instalador executa 5 etapas:
1. **ExecutionPolicy** — define `RemoteSigned` no escopo `CurrentUser` (apenas Windows)
2. **Verificação de dependências** — valida versão do PowerShell, ferramentas e módulos opcionais
3. **Backup** — se existir um perfil que não seja o nosso, faz backup com timestamp único
4. **Link** — escreve o arquivo de perfil dot-source no `$PROFILE`
5. **Validação** — verifica sintaxe dos arquivos principais e confirma que o link está correto

---

### Instalação Manual (Alternativa)

Se preferir não usar o script, siga estes passos:

1. **Desbloquear arquivos baixados:**
   ```powershell
   Get-ChildItem -Recurse *.ps1 | Unblock-File
   ```
2. **Linkar via Dot-Source:**
   Adicione as seguintes linhas dentro do `$PROFILE`:
   ```powershell
   $global:__ProfileRepoRoot = "C:\Caminho\Para\Seu\config-powershell7"
   . "C:\Caminho\Para\Seu\config-powershell7\Microsoft.PowerShell_profile.ps1"
   ```

---

## Desinstalação

Para remover o perfil e restaurar seu ambiente anterior:

1.  Navegue até a pasta do repositório.
2.  Execute o script de desinstalação:
    ```powershell
    .\uninstall.ps1
    ```

> **Windows:** Você também pode dar dois cliques no arquivo `uninstall.cmd`.

O desinstalador:
- Detecta se `$PROFILE` foi criado por este projeto (só remove o nosso)
- Oferece restauração interativa de backup (mais recente primeiro); use `-NonInteractive` para pular prompts
- Limpa o cache de plugins (`~\.cache_pwsh_plugins.ps1` ou equivalente XDG)
- Fornece orientações de limpeza manual para módulos e ferramentas opcionais

---

## Configuração Adicional

### Oh My Posh Theme
O perfil espera o tema em `$HOME\.poshthemes\atomic.omp.json` (Windows) ou `$XDG_DATA_HOME/poshthemes/atomic.omp.json` (Linux).
```powershell
# Criar diretório e baixar o tema
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh font install
```
