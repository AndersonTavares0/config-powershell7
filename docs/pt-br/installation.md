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

### Passo 1: Configurar a Execution Policy
Abra o PowerShell e execute:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Passo 2: Clonar o repositório
```powershell
git clone https://github.com/AndersonTavares0/config-powershell7.git
cd config-powershell7
```

### Passo 3: Instalação Automatizada (Recomendado)
O repositório inclui um script que automatiza a criação do link simbólico e o desbloqueio dos arquivos.

**Execute como Administrador:**
```powershell
.\install.ps1
```
*Este script criará um link simbólico no seu `$PROFILE` apontando para a pasta do repositório e fará o backup do perfil antigo se ele existir.*

---

### Instalação Manual (Alternativa)

Se preferir não usar o script, siga os passos:

1. **Desbloquear arquivos:**
   ```powershell
   Get-ChildItem -Recurse *.ps1 | Unblock-File
   ```
2. **Criar Link Simbólico (Admin):**
   ```powershell
   New-Item -ItemType SymbolicLink -Path $PROFILE -Target "$PWD\Microsoft.PowerShell_profile.ps1" -Force
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
