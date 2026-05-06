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

O projeto inclui uma suíte de testes unitários avançada e compatível com **Strict-Mode** em `tests/Test-ProfileInstallation.ps1`.

### Executar

```powershell
cd config-powershell7
.\tests\Test-ProfileInstallation.ps1

# Com saída detalhada
.\tests\Test-ProfileInstallation.ps1 -Verbose
```

### Cobertura

| Categoria | Itens Testados |
|---|---|
| **Integridade do Perfil** | Garante a lógica correta de injeção dot-source |
| **Sintaxe dos Módulos** | Faz o parser estrito de todos os scripts |
| **Carregamento (Boot)** | Valida o tempo de performance extrema (< 200ms) |
| **Funções e Aliases** | Verifica a existência das lógicas (Git, Sistema, Arquivos) |
| **Sistema de Config** | Verifica a presença de objetos e variáveis |
| **Sistema de Cache** | Valida os timestamps de Time-To-Live (TTL) |

### Saída esperada

```
  ╔══════════════════════════════════════════════╗
  ║   Profile Installation Health Check          ║
  ╚══════════════════════════════════════════════╝

  Profile Integrity
  ✔ Profile/Type - Profile dot-sources the config
  ...
  ════════════════════════════════════════════
  Results: 57 PASS, 0 FAIL, 0 WARN, 0 SKIP (57 total)
  ════════════════════════════════════════════
```

- 🟢 Todos passaram: o perfil está funcionando perfeitamente.
- 🔴 Algum falhou: verifique as dependências e a Política de Execução.

---

# Integração de Testes

## Integração com Testes

### Framework

O arquivo `tests/Test-ProfileInstallation.ps1` implementa um framework de testes customizado otimizado para ambientes de CI/CD.

### Estratégia

O arquivo de testes verifica dinamicamente `$global:ProfileLoaded` e avalia o perfil em isolamento para prevenir efeitos colaterais (side-effects), garantindo zero falsos-positivos mesmo sob a bandeira imperdoável de `Set-StrictMode -Version Latest`.

### Suítes de teste (15 suítes)

| # | Suíte | Abordagem |
|---|---|---|
| 1 | Navigation Functions | Executa e verifica `Get-Location` |
| 2 | File Operations (mkcd, nf, touch) | Cria arquivos/diretórios temporários e verifica existência |
| 3 | Text Processing (head, tail) | Cria arquivo com 5 linhas, verifica contagem e conteúdo |
| 4 | System Functions (pkill, pgrep) | Verifica existência das funções/aliases |
| 5 | Helper Functions (which) | Executa e verifica ausência de erro |
| 6 | Clipboard Functions (cpy, pst) | Verifica existência |
| 7 | Git Functions | Verifica existência de todas as 13 funções/aliases (skip se git ausente) |
| 8 | Plugin Cache System | Verifica existência de funções e aliases de cache |
| 9 | Display Functions (la, ll) | Executa e verifica retorno não-nulo |
| 10 | Additional Navigation (dtop, up2) | Executa e verifica `Get-Location` |
| 11 | File Operation Utilities (unzip) | Verifica existência |
| 12 | System Information (df, pubip, sysinfo) | Executa (skip df no Linux) e verifica retorno |
| 13 | Advanced Text Processing (grep, sed) | Verifica existência |
| 14 | Copy-ToClipboard | Verifica existência |
| 15 | flushdns | Verifica existência |

### Tratamento de plataforma nos testes

- `docs` e `dtop`: verificam se `GetFolderPath()` retorna string vazia (Linux) e pulam o assert de localização
- `df`: executado apenas se `$PSVersionTable.OS -match 'Windows'`
- `up2`: verifica se há avô antes de executar

### Saída de testes

```
========================================
PowerShell Profile Unit Tests
========================================
  ✓ PASS: Profile loads without errors
  ✓ PASS: docs function navigates to Documents
  ...
  ✓ PASS: flushdns function exists
========================================
TEST SUMMARY
========================================
Total Tests: XX
Passed:      XX
Failed:      0
========================================
```

Exit code: `0` (sucesso) ou `1` (falha).

---

## Pontos Técnicos Relevantes

### Boas decisões

- **Fingerprint MD5 com Dispose garantido** — trata corretamente recurso não gerenciado
- **`filter` para `grep`** — processamento de pipeline correto e eficiente
- **`sed` com escrita atômica** — arquivo temporário no mesmo volume garante rename de SO
- **`$script:` explícito** — evita problemas de escopo silenciosos
- **`lazyg` com detecção de CI** — comportamento correto em ambientes automatizados
- **`gcmt` ao invés de `gcm`** — evita colisão com `Get-Command`
- **`gss` ao invés de `gs`** — evita colisão com `Get-Service`
- **`sudo !!`** — QoL feature implementada de forma robusta com histórico do PS

### Observações

- **`sudo` usa `-NoExit`** — a janela elevada não fecha após executar o comando, o que pode ser inesperado para usuários que esperam comportamento de `sudo` Unix (fechar ao terminar)
- **`pubip` sem timeout configurável** — o timeout está fixo em 3 segundos; em redes lentas pode haver delay perceptível na primeira chamada
- **Cache não tem TTL por tempo** — o cache é invalidado apenas por mudança de fingerprint, não por decurso de tempo. Se uma ferramenta for atualizada sem alterar o caminho do binário, o cache não será regenerado automaticamente
- **`sed` faz substituição simples** — não suporta regex; usa `String.Replace()` literal, diferente do `sed` Unix

### Melhorias possíveis (sem alterar comportamento atual)

- Adicionar suporte a TTL no cache de plugins (ex: expirar após N dias)
- Expor `-TimeoutSec` como parâmetro em `pubip`
- Suporte a regex em `sed` via parâmetro `-Regex`
- Adicionar `-WhatIf` em `sed` para visualizar mudanças antes de aplicar

---

*Revisão: 29/04/2026 — Compatível com PS 5.1+ / PS Core 7+ / Windows 10+*