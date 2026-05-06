# Instalação e Compatibilidade

## Como funciona a Modularização

O perfil agora utiliza uma arquitetura modular para facilitar a manutenção e organização. O arquivo principal `Microsoft.PowerShell_profile.ps1` atua como um **Loader (Carregador)**:

1.  Ele identifica o diretório onde o repositório foi clonado (`$PSScriptRoot`).
2.  Carrega automaticamente os scripts localizados em `modules/` através de *dot-sourcing*.
3.  Isso garante que cada funcionalidade (Git, Sistema, Navegação) fique em seu próprio arquivo, mantendo o perfil principal limpo e rápido.

> [!IMPORTANT]
> Devido a essa estrutura, **você deve manter a pasta `modules/` no mesmo local do arquivo de perfil** para que o carregamento funcione corretamente.

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
O repositório inclui um script inteligente que automatiza a criação do link sem requerer privilégios de Administrador.

**Execute em um terminal normal:**
```powershell
.\install.ps1
```
*Este script vai carregar o seu novo perfil de forma segura via "dot-source" injetando o caminho do repositório no `$PROFILE`, e fará um backup caso você já tenha um perfil antigo. Ele roda inteiramente no espaço do usuário, sem pedir telas de Administrador (UAC).*

---

### Instalação Manual (Alternativa)

Se preferir não usar o script, siga estes passos:

1. **Desbloquear arquivos baixados:**
   ```powershell
   Get-ChildItem -Recurse *.ps1 | Unblock-File
   ```
2. **Linkar via Dot-Source:**
   Adicione as seguintes linhas dentro do arquivo do seu `$PROFILE`:
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
*O script removerá o link simbólico e oferecerá a opção de restaurar o backup (`.bak`) e limpar o cache de plugins.*

---

## Configuração Adicional

### Oh My Posh Theme
O perfil espera o tema em `$HOME\.poshthemes\atomic.omp.json`. 
```powershell
# Criar diretório e baixar o tema
New-Item -ItemType Directory -Force "$HOME\.poshthemes" | Out-Null
oh-my-posh font install
```
