# Solução de Problemas e Testes

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

O projeto inclui três suítes de teste:

### 1. Testes Pester (CI)

`tests/Pester.Tests.ps1` — Suíte Pester de alta integridade usada no CI/CD. Cobre módulos de platform, config, cache, git, system e text_utils com testes de violação de invariantes (princípio Crash > Corrupt).

```powershell
Invoke-Pester tests/Pester.Tests.ps1
```

### 2. Profile Installation Health Check

`tests/Test-ProfileInstallation.ps1` — Verificação pós-instalação abrangente usando framework customizado (compatível com Strict-Mode).

```powershell
cd config-powershell7
.\tests\Test-ProfileInstallation.ps1

# Com saída detalhada
.\tests\Test-ProfileInstallation.ps1 -Detailed

# Ou após carregar o perfil:
Test-ProfileInstallation
```

#### Cobertura

| Categoria | Itens Testados |
|---|---|
| **Integridade do Perfil** | Verifica a lógica de dot-source no `$PROFILE` |
| **Sintaxe dos Módulos** | Faz o parser estrito de todos os scripts |
| **Carregamento (Boot)** | Mede o tempo de boot (WARN aos 200ms, FAIL aos 400ms) |
| **Funções e Aliases** | Verifica existência de 26 funções + 5 aliases |
| **Sistema de Config** | Valida `$script:Config` e todas as 8 propriedades |
| **Sistema de Cache** | Valida header TTL (fingerprint + timestamp) |

#### Saída esperada

```
  ╔══════════════════════════════════════════════╗
  ║   Profile Installation Health Check          ║
  ╚══════════════════════════════════════════════╝

  Profile Integrity
  ✔ Profile/Type — Profile dot-sources the config
  ...
  ════════════════════════════════════════════
  Results: 63 PASS, 0 FAIL, 0 WARN, 0 SKIP (64 total)
  ════════════════════════════════════════════
```

### 3. Testes Unitários (Framework Customizado)

`tests/Microsoft.PowerShell_profile.Tests.ps1` — Suíte com framework customizado cobrindo performance, config, cache TTL, navegação, operações de arquivo, processamento de texto, funções de sistema, Git e tratamento estruturado de erros.

```powershell
.\tests\Microsoft.PowerShell_profile.Tests.ps1 -Verbose
```

---

## Integração de Testes

### Pipeline CI/CD

O repositório utiliza **GitHub Actions** com um pipeline:

| Pipeline | Arquivo | Gatilhos |
|---|---|---|
| **CI Original** | `.github/workflows/test.yml` | push/PR para `main` |

O pipeline copia perfil + módulos para `$PROFILE` e executa as suítes de teste customizadas.

### Framework

- `tests/Test-ProfileInstallation.ps1` implementa framework customizado (funções: `Test-Result`, `Test-Skip`, `Assert-True`, `Assert-Equal`, etc.) otimizado para saída diagnóstica.
- `tests/Pester.Tests.ps1` usa Pester 5.x para CI — inclui testes de violação de invariantes que injetam estados ilegais para verificar o princípio "Crash > Corrupt".
- `tests/Microsoft.PowerShell_profile.Tests.ps1` usa o mesmo framework customizado para testes de integração comportamental.

### Estratégia de Testes

Os arquivos de teste verificam dinamicamente `$env:__PROFILE_LOADED` e avaliam o perfil em isolamento para prevenir efeitos colaterais, garantindo zero falsos-positivos sob `Set-StrictMode -Version Latest`.

### Tratamento de plataforma nos testes

- `docs` e `dtop`: verificam se `GetFolderPath()` retorna string vazia (Linux) e pulam o assert de localização
- `df`: executado apenas em Windows
- `up2`: verifica se há diretório avô antes de executar
- `pubip`: trata indisponibilidade de rede com graça (pula, não falha)

---

## Pontos Técnicos Relevantes

### Boas decisões

- **Fingerprint SHA256 com Dispose garantido** — trata corretamente recurso não gerenciado via `try/finally`
- **`filter` para `grep`** — processamento de pipeline eficiente linha a linha
- **`sed` com escrita atômica + limite de tamanho** — arquivo temporário no mesmo volume garante rename de SO; limite de 50MB previne DoS
- **`$script:` explícito** — evita problemas de escopo silenciosos
- **`lazyg` com detecção de CI** — comportamento correto em ambientes automatizados
- **`gcmt` ao invés de `gcm`** — evita colisão com alias nativo `Get-Command`
- **`gss` ao invés de `gs`** — evita colisão com `Get-Service` no PS 5.1
- **`sudo !!`** — feature QoL implementada de forma robusta com histórico do PS
- **Cache TTL (60 min)** — hot path ignora `Get-Command` e SHA256 completamente; recálculo de fingerprint apenas quando TTL expira
- **`sudo` cross-platform** — elevação Windows via `Start-Process -Verb RunAs`, Linux/macOS via `/usr/bin/sudo` nativo

### Observações

- **`sudo` usa `-NoExit`** — a janela elevada não fecha após executar o comando, o que pode ser inesperado para usuários que esperam comportamento de `sudo` Unix (fechar ao terminar)
- **`pubip` sem timeout configurável** — o timeout está fixo em 3 segundos por endpoint; em redes lentas pode haver delay perceptível na primeira chamada
- **Cache TTL é por tempo (60 min)** — o cache é invalidado por mudança de fingerprint OU expiração do TTL, o que ocorrer primeiro
- **`sed` faz substituição literal** — não suporta regex; usa `String.Replace()` literal, diferente do `sed` Unix
- **`sed` tem limite de 50MB** — arquivos maiores são rejeitados para proteção DoS

### Melhorias possíveis (sem alterar comportamento atual)

- Expor `-TimeoutSec` como parâmetro em `pubip`
- Suporte a regex em `sed` via parâmetro `-Regex`
- Adicionar `-WhatIf` em `sed` para visualizar mudanças antes de aplicar

---

*Revisão: 05/2026 — Compatível com PS 5.1+ / PS Core 7+ / Windows 10+ / Linux / macOS*
