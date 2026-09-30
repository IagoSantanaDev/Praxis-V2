# AGENTS.md — Praxis

Automação de faturamento hospitalar no MV2000i (Oracle Forms 6i). App desktop em AutoHotkey v2 com UI em WebView2 (HTML/CSS/JS puro dentro de `ui/index.html`). Código, comentários e docs em pt-BR.

## Ambiente

- O projeto vive num SSD de dados (`T:\Projetos\Praxis Desatualizado`), **sem sistema operacional**. O OS é um Windows 11 modificado em outra unidade. Não assuma que `T:` é bootável nem instale ferramentas nele.
- O caminho da raiz contém espaço: sempre entre aspas em comandos.
- Toolchain do build é descoberta automaticamente por `tools/build-praxis.ps1` (AutoHotkey v2, Ahk2Exe, ISCC, signtool via PATH, `%LOCALAPPDATA%\Programs\AutoHotkey`, `%ProgramFiles%`, Windows Kits). Não fixe caminhos absolutos.
- Sem test suite, sem linter, sem CI. Git tem 2 commits, branch `main`.

## Comandos

```powershell
# rodar em desenvolvimento (lê ui\index.html do disco, pula verificação de integridade)
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" ".\main.ahk"

# build de teste (gera EXE + instalador)
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test

# build sem instalador
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller

# release: exige assinatura + árvore Git limpa
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 1.0.0 -CertificateThumbprint <THUMBPRINT> -Release

# único gate automatizado: integridade do runtime (0 = ok, 70 = recurso ausente/alterado)
.\Praxis.exe --integrity-check
```

`README.md` cobre o app; `docs/DISTRIBUTION.md` é o runbook de build, assinatura, artefatos e checklist de entrega. Leia antes de gerar qualquer build.

## Arquitetura

- `main.ahk` é o entrypoint: GUI, WebView2, registro de scripts (`gScripts`), dispatcher `RunScript`, e o manifesto de integridade. Todo o app é um único binário compilado — não existe runtime de módulo.
- `#Include` é textual e transitivo. Ordem real: `main.ahk` → `scripts/*.ahk` → `scripts/mv_session.ahk` + `lib/FFCV_ErrorTemplates.ahk` → `lib/WebView2.ahk` → `lib/ComVar.ahk`/`Promise.ahk`.
- `scripts/mv_session.ahk` concentra o contrato de janela do MV2000i (títulos, `ifrun60.EXE`, `MV_Poll`, `MV_WaitWindowStable`, `MV_FindControlByClientPoint`). Qualquer fluxo novo deve reusar essas funções, não criar paralelas.
- `scripts/remessa_protocolo.ahk` é o fluxo validado no MV (fases MOV DOC → FFCV → datas → XML). `scripts/protocolar.ahk` (`PR_*`) e `scripts/fechar_xml.ahk` (`FX_*`) **também estão implementados**, mas nunca foram rodados contra o MV2000i — não os trate como validados.
- **Os três fluxos são isolados por prefixo e não se chamam.** `protocolar.ahk` não chama `RP_*` nem `FX_*`; `fechar_xml.ahk` não chama `RP_*` nem `PR_*`. Como `#Include` é textual e de escopo global, um helper compartilhado novo sobe para `mv_session.ahk` com prefixo `MV_` — não promova um helper de um fluxo só para o outro usar.
- `scripts/mv_session.ahk`, `protocolar.ahk` e `fechar_xml.ahk` dependem de globais de `main.ahk` (`gRunning`, `gWorkDir`, `SendToUI`). Não rodam standalone.
- UI: `ui/index.html` é arquivo único e completo. Contrato de mensagens: JS→AHK `{action: ready|run_script|stop_script|exit}`; AHK→JS `{type: app_ready|status|log|progress|done|error}`.
- `lib/FFCV_ErrorTemplates.ahk` classifica modais de erro do FFCV por OCR do Windows (`tools/ocr-probe.ps1`) contra textos canônicos em `lib/FFCV_ErrorReferences.json`. `WinGetText`/Window Spy não expõem a mensagem desses modais — não tente substituir o OCR por leitura de controle.

## Armadilhas que custaram tempo

- **`gScripts` em `main.ahk` está duplicado em `devSim()` dentro de `ui/index.html`.** Alterar id, label, `tipo` ou `obrigatorio` de um parâmetro exige editar os dois lugares, senão a UI em modo dev mostra o formulário errado.
- **`#Include *i build\generated\*.ahk` é opcional e case-insensitive.** Em dev o app funciona sem esses arquivos. Eles são gerados e apagados a cada build (`build/generated/` é gitignored). Não edite à mão e não comite.
- `lib/FFCV_ErrorReferences.json` é gerado por `tools/build-ocr-error-references.ps1`, mas o output padrão do script é `test_macros\ocr_error_references.json` (diretório que não existe no repo). Para atualizar o arquivo realmente consumido, passe `-OutputPath .\lib\FFCV_ErrorReferences.json`. O script marca `ok:false` quando o crop em `images\*.png` não existe.
- `images/` e `test_macros/` são citados em comentários e no README mas **não existem** neste checkout. `Fluxos/` existe localmente (screenshots, CSVs, `OLD.ahk`, `Teste_corrigido.ahk`) e é ignorado pelo Git — é material de referência, não código.
- `config.ini` é gitignored e ausente: o app cai no default `%USERPROFILE%\Documents\Praxis`. XMLs de remessa vão para `<WorkDir>\XML\`.
- O app **não abre nem autentica** MOV DOC/FFCV. `MV_EnsureMovDoc`/`MV_EnsureFFCV` só abortam com mensagem pedindo abertura manual. O botão Parar só limpa `gRunning`; não cancela um fluxo já em execução no MV.
- **Sair de tela no MV é Ctrl+Q** (confirmado pelo operador, todas as telas; no menu fecha o MV). Em AHK `^` é Ctrl, então `^q` **é** Ctrl+Q — não é valor suspeito. Uma constante só: `MV_SAIR_TELA_ATALHO`. `{Esc}` foi descartado.
- **Todo fim de fluxo fecha a última tela** via `MV_FecharUltimaTela` (`mv_session.ahk`). Exceções: popup do MV aberto (não fechar) e `imprimir_salvar_envio = Não` no protocolar (mantém o MOV DOC aberto).
- **Recuperação no meio do fluxo não fecha o MV.** No `protocolar`, `PR_FecharPendencias()` limpa telas auxiliares e `PR_RecuperarTelas(cfg)` fecha o MV — só no fim.
- `{Down 121}` em `protocolar.ahk` (`PR_RELATORIO_DOWN_N`) é **posicional** e nunca validado: depende da ordenação do relatório na estação do hospital. Se mudar lá, o fluxo gera a planilha errada sem erro visível.
- `lib/FFCV_ErrorReferences.json` não tem referência para **"remessa já fechada"**. Por isso `fechar_xml.ahk` trata qualquer modal não reconhecido nesse ponto como pendência e segue — mais permissivo que o ideal. Adicionar a referência canônica é o que fecha a lacuna.
- As coordenadas nos comentários de `mv_session.ahk` apontam para `.agents/workflows/01-remessa-protocolo.md` como fonte versionada. As capturas originais estão em `Fluxos/`, que é gitignored e não existe em todo checkout — quem for reconferir contra o MV precisa do MV real.
- O staging de distribuição não pode conter `.ahk`, `.ps1`, `.iss`, `.html` nem `.json`; o build falha se vazar. `config.ini`, logs, XMLs e `.pfx` também não entram no pacote.
- Todo arquivo de primeira parte (`.ahk` e `.ps1`) começa com o cabeçalho proprietário de 4 linhas. Mantenha ao criar arquivos. `lib/WebView2.ahk`, `JSON.ahk`, `Promise.ahk` e `ComVar.ahk` são libs externas (thqby) — não edite.

## Regras de automação (MV2000i / Oracle Forms 6i)

- Teclado primeiro. `Send`/`SendText` e atalhos (F6/F7/F8/F10, Alt+mnemonic) são o caminho validado.
- `EditN` não é contrato: o Forms renumera conforme estado da tela. Localize por ClassNN + ponto Client, ou por prefixo de classe (`ui60Drawn`).
- Coordenadas são Client e vieram de Window Spy/captura. Não introduzir coordenadas de tela.
- Leia campo de grid por `Home`+`Shift+End`+`Ctrl+C` com validação semântica (`RP_GridValueValid`), não por `ControlGetText`.
- Use `MV_Poll`/`MV_WaitOracleSettled` em vez de `Sleep` fixo quando esperar janela, modal ou cursor estabilizar.
- Popups "Informações da Conta" e afins não têm título próprio: são detectados pelo sentinela `ui60Drawn W323` dentro da janela FFCV.
- Ao documentar uma constante nova, registre de qual tela/screenshot ela veio (o padrão é uma linha `; Spy em ...` acima do bloco).

## Validação

Não existe verificação automática do comportamento no MV. O que dá para checar sem o sistema do hospital:

1. `powershell ... -File .\tools\build-praxis.ps1 -Version 9.9.9-test` — falha em erro de sintaxe AHK, include quebrado ou asset faltante.
2. `.\Praxis.exe --integrity-check` no staging — precisa sair com `0`.
3. Abrir o app e confirmar que a sidebar, o formulário de cada módulo e o envio de `ready` funcionam.

Mudança de automação do MV só está validada depois de rodar contra o MV2000i real com o modal na tela. Se você não rodou, diga isso explicitamente em vez de afirmar que funciona.

## Commits

Conventional Commits em pt-BR, sem scope, linha única (`feat: ponto de mvp`, `fix: ...`).
