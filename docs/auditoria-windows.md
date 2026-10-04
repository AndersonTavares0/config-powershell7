# Auditoria de compatibilidade Windows

Revisões em 3 e 4 de outubro de 2026, com foco em Windows 10 e Windows 11.

Os testes confirmam as correções descritas aqui. Ainda falta testar a instalação
completa e a interface gráfica em máquinas limpas dos dois sistemas. O instalador
aceita Windows x64 e recusa ARM64 e x86.

Para usar o projeto, é preciso confiar nos fornecedores dos downloads. O
instalador usa HTTPS, mas não verifica por conta própria as assinaturas ou os
checksums dos arquivos baixados. Esse limite está descrito em `SECURITY.md`.

## Problemas corrigidos

| Área | Problema observado | Correção |
| --- | --- | --- |
| Perfil | `$$` no caminho era interpretado na substituição regex ao atualizar o bloco gerenciado | Inserção literal com `MatchEvaluator` |
| Caminhos | Colchetes eram interpretados como curingas no perfil e na detecção/lançamento do repositório local | Operações com `-LiteralPath` |
| Perfil | Um caminho relativo era gravado no perfil e dependia do diretório da próxima sessão | Resolução do caminho absoluto antes de criar o vínculo |
| Windows Terminal | Ausência de `schemes` ou `profiles.defaults` causava falha com modo estrito | Verificação explícita das propriedades opcionais e criação de defaults |
| Windows Terminal | Adicionar um tema a uma lista não vazia sem esse tema acessava o índice zero de uma lista vazia | Verificação da quantidade de correspondências antes de acessar o índice |
| Instalação headless | `-NonInteractive` não impedia perguntas de elevação ou instalação do Scoop nos módulos | Estado compartilhado de execução não interativa; CI também usa o dispatcher headless |
| Scoop | A pergunta usava `$DisplayName?`, interpretado como variável inexistente | Interpolação delimitada com `${DisplayName}` |
| Módulos | Erros de `Install-Module` eram registrados, mas o resultado final era sucesso | Resultado agregado de falha e exigência da versão mínima no download |
| PSGallery | Exceções durante a descoberta de módulos podiam deixar a galeria confiável | Restauração da confiança em `finally`, com falha registrada se a restauração não funcionar |
| Testes | Teste de desinstalação apagava o cache real do usuário | HOME e cache temporários, restaurados em `finally` |

As leituras do perfil gerenciado também passaram a interromper a operação em
caso de erro, evitando tratar um arquivo ilegível como um perfil vazio. A busca
de backups agora acompanha o nome real do perfil (`profile.ps1`, por exemplo).

## Evidência de regressão

Os testes reproduzem tarefas de uso: instalar, atualizar e remover o perfil em
caminhos Windows válidos, configurar um Terminal recém-inicializado e informar
falhas de dependências durante uma execução sem interação.

Os nove casos iniciais da nova suíte foram executados **antes** das correções:
`0 passed, 9 failed`. O caso adicional do bootstrapper em caminho com colchetes
também falhou antes de corrigir a detecção. A suíte final tem 12 cenários,
incluindo módulos já instalados e restauração da confiança após exceção.

```powershell
pwsh -NoProfile -File .\tests\WindowsCompatibility.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\WindowsCompatibility.Tests.ps1
```

O `Bypass` acima vale somente para o processo de teste: o Windows PowerShell 5.1
local recusou inicialmente executar scripts pela política efetiva. Nenhuma
política persistente foi alterada. Os testes usam arquivos temporários e mocks
para não instalar pacotes ou alterar configurações reais do Terminal.

## Verificações executadas

Ambiente local: Windows x64, versão `10.0.26300.0`, PowerShell `7.6.6` e
Windows PowerShell `5.1`.

| Verificação | Resultado |
| --- | --- |
| `tests/Unit.Tests.ps1` | 126 passaram, 0 falharam |
| `tests/Setup.Tests.ps1` | 202 passaram, 0 falharam |
| `tests/ThemeOverride.Tests.ps1` | 6 passaram, 0 falharam |
| `tests/Microsoft.PowerShell_profile.Tests.ps1` | 81 passaram, 0 falharam |
| `tests/WindowsCompatibility.Tests.ps1` em PS7 | 12 passaram, 0 falharam |
| `tests/WindowsCompatibility.Tests.ps1` em PS5.1 | 12 passaram, 0 falharam |
| `tests/Test-ProfileInstallation.ps1` | 68 PASS, 0 FAIL, 1 WARN |
| PSScriptAnalyzer 1.25.0, repositório completo | 0 erros, 331 warnings |
| `git diff --check` | Sem erros de whitespace |

As suítes de tema, integração e diagnóstico foram executadas com HOME/cache
temporários e `$PROFILE` apontando para o arquivo do repositório, sem substituir
o perfil instalado do usuário. O diagnóstico avisou sobre boot frio de 643 ms;
a integração mediu 793 ms no primeiro carregamento e 228 ms no segundo, dentro
dos limites atuais dessa suíte. Esses valores são medições locais, não metas
garantidas para outras máquinas.

O framework personalizado não fornece relatório de cobertura de linhas;
nenhuma porcentagem de cobertura foi medida. Os warnings do analisador incluem
convenções do projeto e testes com mocks, além de pontos a revisar, e não são
tratados como prova de defeito automaticamente.

## CI e homologação

`validate.yml` foi ampliado para `windows-2022` e `windows-2025`, com a nova
suíte em PS7 e PS5.1. Acompanhe os resultados remotos no
[PR #129](https://github.com/AndersonTavares0/config-powershell7/pull/129).
São runners Windows Server, não instalações de Windows 10 e Windows 11 desktop.

A homologação de instalação real, GUI, UAC, OneDrive, ausência de WinGet e
políticas corporativas deve seguir [a matriz de VMs](validacao-vm.md) nos dois
sistemas desktop. Não houve instalação real de dependências nem validação
visual da GUI nesta auditoria. Portanto, os testes aprovados demonstram as
correções reproduzidas, mas não certificam todas as edições/builds de Windows.

## Segunda auditoria: segurança, funcionamento e documentação

As tabelas acima registram a primeira rodada. Na segunda revisão, encontramos
problemas que os testes iniciais não cobriam e os reproduzimos antes de corrigir:

- **Retorno falso-positivo:** stdout de Scoop, npm, scripts de fornecedores e
  launcher poluía o resultado booleano. Logs agora seguem fluxo separado;
  exit codes são verificados, e a CLI devolve falhas ao dispatcher.
- **Preservação:** a migração antiga removia dot-sources só pelo nome do arquivo.
  Agora reconhece apenas o stub contíguo gerado com caminho correspondente ao
  repositório declarado, preserva código alheio e migra CurrentHost para AllHosts
  com backup. Um stub cuja autoria não é reconhecida é preservado.
- **Atualização de repositório:** os dois caminhos de download recusam diretórios
  alheios, validam arquivos obrigatórios, usam ZIPs temporários únicos e mantêm
  a árvore anterior em `.config-powershell7-previous-<guid>`. Isso evita rollback
  usando um backup já parcialmente apagado.
- **Perfil real:** teste em processo filho expôs curingas no loader/cache e
  fingerprints incompatíveis com espaços. As operações usam caminhos literais
  e o cache com espaço não é mais reconstruído em toda inicialização.
- **PS5.1:** o carregamento real expôs leitura ANSI de fonte Unicode sem BOM;
  os arquivos afetados receberam BOM e a convenção está em `.editorconfig`.
- **GUI:** workers inicializam preferências explicitamente e foram exercitados
  em runspaces reais com loader ausente. Isso não equivale a teste visual WPF.
- **Docs:** corrigidas instruções de desinstalação, AllHosts, tema no momento
  do carregamento, contagem de testes, Windows suportado e alegações de garantia
  ou rollback global que o código não oferece.

Resultado local da suíte ampliada: **22 passaram em PS7 e 22 em PS5.1**.
Na última execução local, passaram também 126 testes unitários, 202 de setup,
81 de integração e 6 de tema. O diagnóstico teve 68 PASS, nenhum FAIL e um
aviso de boot frio (600 ms). O analisador apontou zero erros e 347 warnings;
os warnings continuam registrados para revisão, sem correções automáticas em massa.
Houve uma ocorrência de `Stream was not readable` no PS5.1 durante escrita de
fixture, não reproduzida nas execuções posteriores; acompanhar na CI.

A documentação oficial consultada confirmou as regras de saída/retorno e
política de execução. As varreduras de segredos e antipadrões passaram; são
verificações heurísticas, não uma certificação de segurança.

Referências consultadas:
- [PowerShell: about_Return](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_return)
- [PowerShell: Set-ExecutionPolicy](https://learn.microsoft.com/powershell/module/microsoft.powershell.security/set-executionpolicy)
- [Claude Code: instalação oficial](https://code.claude.com/docs/en/setup)
- [Codex CLI: instalação oficial](https://developers.openai.com/codex/cli/)

Antes de publicar uma nova versão, execute `docs/validacao-vm.md` em Windows 10
e Windows 11 limpos. Registre os resultados de instalação, interface gráfica,
UAC, OneDrive e políticas corporativas. Esses cenários ainda não passaram por
essa validação.
