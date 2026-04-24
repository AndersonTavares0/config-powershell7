# Configuração do PowerShell 7 
Este repositório contém os arquivos de configuração para o PowerShell 7, focados em otimizar o fluxo de trabalho em Engenharia de Software e facilitar a restauração do ambiente em caso de formatação ou migração de sistema.

## 1. Requisitos do Sistema

Para o funcionamento correto destas configurações, os seguintes componentes devem estar instalados no sistema:

* **PowerShell 7:** Instalado via repositório oficial da Microsoft (DNF).
* **Nerd Fonts:** Necessário para a renderização correta de ícones (Recomendado: JetBrainsMono Nerd Font).
* **Git:** Para versionamento e uso dos aliases de comando.
* **Módulos do PowerShell:**
    * `PSReadLine`: Para preenchimento inteligente e histórico.
    * `Terminal-Icons`: Para exibição de ícones no comando ls/dir.
    * `OhMyPosh`: Motor de temas para o prompt.

## 2. Como Baixar

Clone este repositório para sua pasta local de documentos ou diretamente para o diretório de configurações do usuário:

```bash
git clone [https://github.com/AndersonTavares0/config-powershell7.git](https://github.com/AndersonTavares0/config-powershell7.git)
```

## 3. Como Aplicar

1. **Identificar o caminho do perfil:**
   No PowerShell, verifique o local do arquivo de inicialização:
   ```powershell
   $PROFILE
   ```
   Geralmente no Fedora em: `~/.config/powershell/Microsoft.PowerShell_profile.ps1`

2. **Criar o diretório de configuração (caso não exista):**
   ```bash
   mkdir -p ~/.config/powershell/
   ```

3. **Vincular o arquivo:**
   Copie o conteúdo do arquivo baixado para o caminho do `$PROFILE` ou crie um link simbólico para manter o repositório sincronizado:
   ```bash
   ln -s ~/caminho-do-repositorio/profile.ps1 ~/.config/powershell/Microsoft.PowerShell_profile.ps1
   ```

4. **Instalar Módulos Necessários:**
   Abra o PowerShell e execute:
   ```powershell
   Install-Module -Name PSReadLine -AllowPrerelease -Force
   Install-Module -Name Terminal-Icons -Repository PSGallery
   ```

## 4. Lógica e Conteúdos para Estudo

Este setup utiliza conceitos fundamentais de shell scripting que servem de base para outras linguagens:

* **Aliases:** Atalhos para comandos complexos (ex: atalhos para git e comandos de sistema).
* **Variáveis de Ambiente:** Configuração do caminho de executáveis no sistema.
* **Módulos (Import-Module):** Lógica de importação de bibliotecas externas para expandir funcionalidades.
* **Previsão de Comandos (Predictor):** Configuração do PSReadLine para utilizar o histórico como sugestão (similar ao que é visto no Zsh).
* **Funções Customizadas:** Blocos de código que executam tarefas compostas, funcionando como pequenos scripts dentro do perfil.

 O que deve lembrar ao revisar este código:
1. **O Perfil é um Script:** Tudo o que você coloca no arquivo `.ps1` é executado toda vez que o terminal abre. Se o terminal demorar para abrir, a culpa geralmente é de algum módulo pesado sendo importado.
2. **Caminhos no Linux:** No Fedora, o PowerShell respeita o padrão XDG, por isso as configurações ficam dentro de `.config`.
3. **Segurança:** O PowerShell possui "Execution Policies". No Linux isso é mais flexível, mas no Windows você precisaria de um `Set-ExecutionPolicy RemoteSigned`.
