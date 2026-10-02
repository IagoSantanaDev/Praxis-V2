# Unificar a espera de impressão em `remessa_protocolo.ahk`

> Prompt de execução para um agente de IA. Copie do bloco abaixo, do `início` ao
> `fim`, e cole integralmente na sessão do agente. Este documento é versionado de
> propósito: ele descreve uma mudança de contrato de automação do MV2000i e as
> armadilhas que a impedem de ser feita por comparação ingênua entre scripts.

```início
# Tarefa: unificar a espera de impressão em `remessa_protocolo.ahk`

## Contexto do repositório

`Praxis` — automação de faturamento hospitalar no MV2000i (Oracle Forms 6i), app desktop AutoHotkey v2, UI em WebView2. Código, comentários e docs em **pt-BR**. A raiz do repositório e todos os caminhos **contêm espaço**: sempre entre aspas em comando.

Antes de qualquer decisão, leia `AGENTS.md` na raiz. Ele é a fonte única das regras e contém a seção **"Falha silenciosa — não ignore"**, que lista armadilhas já confirmadas neste projeto. Não contradiga nenhuma delas.

Consulte o Context7 (`/autohotkey/autohotkeydocs`, branch `v2`) antes de decidir qualquer coisa sobre API do AHK v2. **Não decida por memória** — em particular, `Array.Has()` é por índice em v2, `MouseGetCursor()` não existe (use `A_Cursor`), e prazo nunca pode ser `A_TickCount + timeout` (use decorrido).

## Objetivo

`remessa_protocolo.ahk` é o **único fluxo validado contra o MV2000i real**. Hoje a impressão do relatório de atendimentos é disparada e reportada como sucesso sem verificar nada. Você vai portar para ele duas peças de espera que já existem em outros dois scripts, **sem quebrar o fluxo de impressão que já funciona**.

Peças a portar:

1. **`CloseBackgroundReportsIfAny()`** — de `scripts/protocolar.ahk:2168`. Fecha a janela `Operação de Fundo dos Relatórios` (`RWRBE60.EXE`) com `WinClose`.
2. **A espera de conclusão de impressão** — de `WaitImpressaoConcluir()`, `scripts/fechar&xml.ahk:236`. É a única implementação no repo que realmente valida a impressão: espera a janela `Andamento do Relatório ahk_exe RWRBE60.EXE` aparecer, espera sumir, e espera o processo `RWRBE60.EXE` fechar.

## Situação atual (verificada — não rederive)

A impressão está em `ImprimirRelatorioAtendimentos()`, `remessa_protocolo.ahk:1360-1382`. Cadeia de chamada: `RunRemessaProtocolo:257` → `FinalizarSemDatas():1356` → `ImprimirRelatorioAtendimentos()`.

```ahk
ImprimirRelatorioAtendimentos() {
    if !RP_EnsureFFCVActive() { ...; return false }

    if !MV_ClickControlAt(MV_WIN_FFCV_ANY, FFCV_BTN_IMPRIMIR, FFCV_BTN_IMPRIMIR_X, FFCV_BTN_IMPRIMIR_Y) { ...; return false }

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD) { ...; return false }

    WinActivate WIN_CAPA_REMESSA
    Sleep RP_KEY_SETTLE_MS
    Send "{Enter}"
    MV_Poll(() => !WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)   ; <-- retorno DESCARTADO
    Notify("Relatório de atendimentos confirmado para impressão.") ; <-- sucesso incondicional
    return true
}
```

Pontos que motivam a tarefa:

- **`remessa_protocolo.ahk:1379` descarta o retorno de `MV_Poll`** e `:1380` notifica sucesso incondicionalmente. Se a capa não fechar, o fluxo reporta "confirmado para impressão" e segue. É falha silenciosa.
- **Não há espera do "Andamento do Relatório".** A constante `MV_WIN_ANDAMENTO` existe em `mv_session.ahk:51`, documentada, e **não é usada em lugar nenhum do repo**.
- **`CloseBackgroundReportsIfAny` também não é usada** — só existe em `protocolar.ahk`.

## Restrições (leia com atenção — são as que evitam o erro)

### R1. Não quebrar o fluxo de impressão existente

Esta é a exigência principal. Especificamente:

- **Não troque `Send "{Enter}"` por clique em botão.** Na capa da remessa o `Enter` é o que confirma a impressão, e é o caminho validado no MV real. As outras duas implementações clicam em `Button2` porque são telas diferentes — o `Enter` aqui funciona e não deve ser mexido.
- **Não mova, renomeie ou reordene** as etapas existentes de `ImprimirRelatorioAtendimentos()`. A espera nova entra **depois** do `Send "{Enter}"`.
- **Não altere** `MV_ClickControlAt`, o `ClassNN` `FFCV_BTN_IMPRIMIR`, nem as coordenadas `(567, 458)`. São o contrato validado com o MV.
- **Não mude** o `FFCV_BTN_IMPRIMIR` de `Button7` para `Button9`. Existe uma constante `MV_WIN_FFCV_BTN_RELATORIO := "Button9"` em `mv_session.ahk:60` que também não é usada — **não a introduza aqui**. Se achar que são o mesmo controle, reporte como dúvida, não resolva por conta própria.
- Se a espera nova estourar o tempo, o comportamento **não pode** ser "erro que aborta a remessa inteira" sem justificativa. A remessa já foi protocolada e as contas já estão na remessa do MV neste ponto — um falso negativo destrói trabalho já feito. Pense no que deve acontecer e justifique na resposta.

### R2. Onde o código deve morar

`scripts/mv_session.ahk` é o dono do contrato compartilhado (`MV_*`). Ele já é incluído por `remessa_protocolo.ahk:7` via `#Include mv_session.ahk`.

**`#Include` é textual e transitivo.** Não adicione outro `#Include` de `mv_session.ahk` em lugar nenhum — isso duplica todas as funções `MV_*` e o build quebra.

Como `MV_*` é o prefixo do contrato compartilhado e os dois helpers vão ser usados por mais de um fluxo, **promova-os para `mv_session.ahk` com prefixo `MV_`** — por exemplo `MV_FecharRelatoriosFundo()` e `MV_WaitImpressaoConcluir()`. Não os deixe em `remessa_protocolo.ahk`, e não copie a versão antiga para lá: helper compartilhado entre fluxos sobe para `mv_session.ahk`.

**Não edite** `scripts/protocolar.ahk` nem `scripts/fechar&xml.ahk` para "não duplicar". Eles não estão na cadeia ativa (ver R5) e mexer neles não é o escopo desta tarefa. Deixe as implementações antigas intactas e apenas **não as chame** do `remessa_protocolo.ahk`. Se a duplicação incomodar, reporte — não resolva.

### R3. Contrato de retorno — não invente um terceiro caminho

Os dois scripts de origem usam contratos **diferentes** e ambos estão errados para o `remessa_protocolo`:

- `WaitImpressaoConcluir` **lança `throw Error`** e usa `ToolTip()`.
- `CloseBackgroundReportsIfAny` **lança `throw Error`**.

O `remessa_protocolo.ahk` é um **módulo sem GUI**: por AGENTS.md, fluxo é autônomo — **sem `Gui`, `MsgBox`, `ToolTip` ou hotkey**. Saída só por `Notify()`, `Progress()`, `Done()` e o abort do módulo. Então:

- **Não copie o `ToolTip()`** para `remessa_protocolo.ahk`. Substitua por `Notify()`.
- **Não propague `throw Error`.** O estilo do arquivo é `return false` + `Notify()` + `RP_Abort()` no chamador (`remessa_protocolo.ahk:260`). Siga o padrão do **dono do arquivo**, não o do script de origem.
- **Não copie `ProcessWaitClose`** como está. Ele espera o processo `RWRBE60.EXE` inteiro morrer. Se o operador tiver **outro** relatório em spool, isso espera pela coisa errada. Avalie se essa espera faz sentido aqui e justifique.

`WinClose` é **proibido** no `ifrun60.EXE` (o Oracle Forms perde estado), e **permitido** no `RWRBE60.EXE` — a janela `Operação de Fundo dos Relatórios` é justamente `RWRBE60.EXE`, então o `WinClose` está correto ali. Não "conserte" para `^q`, e não mova o `WinClose` para janela do `ifrun60.EXE`.

### R4. Arquitetura do contrato

Para um novo helper em `mv_session.ahk`:

- Todo arquivo de primeira parte começa com o **cabeçalho proprietário de 4 linhas**. Não mexa no cabeçalho de `mv_session.ahk` ao editar.
- Comentário só para decisão **não óbvia**, restrição, contrato ou workaround. Explique **por que** a janela `Andamento do Relatório` está no `RWRBE60.EXE` e não no `ifrun60.EXE`, e por que `WinClose` é seguro nesse processo — é a informação que impede alguém de "padronizar" errado depois.
- **Constante de automação nova precisa registrar a origem** com uma linha `; Spy em <origem>` imediatamente acima do bloco. As coordenadas `FFCV_BTN_IMPRIMIR_X/Y` hoje **não têm** essa linha. Se você criar constante nova, registre. Se não puder confirmar a origem, **não invente**: deixe `PENDENTE` com o que falta. Preencher por adivinhação é pior que deixar pendente, porque o erro fica silencioso.
- Você vai reaproveitar `MV_WIN_ANDAMENTO` (`mv_session.ahk:51`) em vez de criar string nova. Isso é o certo — não duplique.

### R5. Estado do build — leia antes de prometer validação

O build **passa** hoje. Rodei o gate completo antes de escrever este prompt:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller
# → Successfully compiled as: ...\stage\Praxis.exe | Build concluído
$p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" -ArgumentList '--integrity-check' -Wait -PassThru
$p.ExitCode   # → 0
```

Isso muda o que você pode exigir de si mesmo: **o gate existe e está verde, então rode-o.**
Não é preciso inventar contorno, não é preciso compilar arquivo isolado, e não é preciso
aceitar "não deu para validar sintaxe".

Ainda assim, dois fatos que você precisa conhecer:

- **Só `remessa_protocolo.ahk` entra no EXE.** `main.ahk:27-28` mantém
  `#Include scripts\protocolar.ahk` e `#Include scripts\fechar&xml.ahk` **comentados**,
  e os `case "protocolar"` / `case "fechar_xml"` do `RunScript()` (`main.ahk:268-269`)
  também estão comentados. O motivo está documentado em `main.ahk:17-26`: `protocolar.ahk:3`
  aponta para um `lib/globals/mv/ParseUtils.ahk` inexistente, e os dois arquivos chamam
  `BuildGui()` + `return` no topo — um `return` no topo de arquivo incluído aborta o
  script inteiro e mataria o `AppInit()`.
- **Portanto o build valida sintaxe e include, não o comportamento.** Ele não prova que
  a espera de impressão funciona. Reativar esses fluxos é **fora de escopo**: não
  desembrulhe as linhas comentadas.

Se o build falhar depois da sua mudança, isso é erro seu e precisa ser corrigido — não há
falha pré-existente para culpar. Se passar, reporte que passou.

### R6. Validação — a exigência é esta e só esta

Da AGENTS.md, para automação do MV:

> build + `--integrity-check` **e** rodar contra o MV2000i real. Sem o MV, diga que não validou.

Então o mínimo aceitável é:

1. **Build + `--integrity-check` verdes**, usando exatamente os dois comandos de R5. Cole a saída real no relatório. Se quebrar, é erro seu.
2. Auditoria do diff: releia o que você escreveu procurando retorno não verificado, `throw` novo, `ToolTip` novo, e `WinClose` em `ifrun60.EXE`.
3. **Declaração explícita de que a automação não foi validada contra o MV2000i**, porque o MV não está disponível.

Escreva na resposta, em negrito: **"Não validei contra o MV2000i real."** Não escreva "funciona", "testado" ou equivalente. Se afirmar que funciona, o trabalho está errado.

## Restrições de comportamento do MV

- **Teclado primeiro.** `Send`/`SendText` e atalhos são o caminho validado. `ControlClick` só com ClassNN + ponto Client.
- **`EditN` não é contrato** — o Forms renumera. Não introduza `EditN`.
- **Coordenada é sempre Client**, nunca de tela.
- Use `MV_Poll`/`MV_WaitOracleSettled` em vez de `Sleep` fixo ao esperar janela, modal ou cursor estabilizar.
- **Estabilidade não prova transição.** O MV troca de tela no mesmo HWND sem alterar a contagem de controles. Se precisar provar que algo saiu, exija uma **assinatura de tela que inclua o título** (existente: `MV_ScreenSignature`, `mv_session.ahk:586`) — nunca reporte sucesso sem ela.
- **Fluxo é autônomo:** sem `Gui`, `MsgBox`, `ToolTip` ou hotkey.

## Ordem de execução sugerida

1. Ler `AGENTS.md`, de novo na seção "Falha silenciosa", e os trechos citados de `mv_session.ahk`, `remessa_protocolo.ahk`, `protocolar.ahk`, `fechar&xml.ahk`.
2. Consultar Context7 sobre as APIs do AHK v2 que for usar.
3. Escrever os helpers `MV_*` em `mv_session.ahk`.
4. Chamar os helpers de `ImprimirRelatorioAtendimentos()`, **depois** do `Send "{Enter}"`.
5. Corrigir o descarte de retorno em `remessa_protocolo.ahk:1379` e o `Notify` incondicional em `:1380` — é o defeito que a tarefa endereça. Faça isso **sem** mudar o que `Send "{Enter}"` faz e sem mudar os passos que já funcionam.
6. Validar como em R6.
7. Se algum aprendizado confirmado e novo surgir (armadilha que faz trabalho errado sem erro visível), propor a entrada para a seção "Falha silenciosa" do `AGENTS.md` — **propor**, não editar o `AGENTS.md` por conta própria.

## Entrega

- Resposta em **pt-BR**.
- Liste os arquivos e as linhas mudados.
- Para **cada** decisão que envolva sair do padrão existente, justifique **por que o padrão não serve**, **qual regressão a alternativa evita** e **como a consistência é preservada**.
- Termine com a declaração de validação de R6.
- Se algo ficou `PENDENTE` por falta de informação do MV, diga qual é — não preencha por dedução.
```fim

## Notas para quem envia o prompt

Estas duas notas são para o Maintainer, **não fazem parte do prompt** — não as envie ao agente.

1. **A quebra de `#Include` já foi resolvida.** Este documento foi escrito quando
   `main.ahk:19` apontava para `scripts\fechar_xml.ahk` (inexistente) e o build
   falhava. Os includes foram desligados de propósito, com o motivo documentado em
   `main.ahk:17-26`, e o gate está verde. R5 reflete o estado atual: build passa, e
   o agente **deve** rodá-lo. Reativar `protocolar.ahk` / `fechar&xml.ahk` continua
   fora de escopo — se quiser tratar, é outro prompt.

2. **R1 é o ponto que carrega o prompt inteiro.** Sem ele, o agente tem motivo aparente
   para "padronizar" com os outros dois scripts e trocar o `Send "{Enter}"` por clique
   em `Button2` — o que quebraria justamente o único fluxo que roda contra o MV real.

## Referências

- `AGENTS.md` — regras do projeto, seção "Falha silenciosa" e "Regras de automação"
- `scripts/remessa_protocolo.ahk:1360` — `ImprimirRelatorioAtendimentos()`, alvo da mudança
- `scripts/mv_session.ahk:51` — `MV_WIN_ANDAMENTO`, constante a reaproveitar
- `scripts/protocolar.ahk:2168` — `CloseBackgroundReportsIfAny()`, origem da peça 1
- `scripts/fechar&xml.ahk:236` — `WaitImpressaoConcluir()`, origem da peça 2