# 01 — Remessa por Protocolo

Script: `scripts/remessa_protocolo.ahk` (~1.740 l.)  |  Registro: `gScripts` id `remessa_protocolo`

> **Único fluxo implementado e validado contra o MV2000i real.** Os workflows 02 e 03 reusam as
> fases de FFCV, datas e XML descritas aqui. Ao mexer neste spec, afeta os três.

## Objetivo

Baixar protocolos no MOV DOC, coletar as contas do convênio, monta a remessa no FFCV e —
opcionalmente — fechar a remessa com datas e gerar o XML.

## Entrada

| id | Label | tipo | obrigatório | notas |
|----|-------|------|--------------|-------|
| `protocolos` | Protocolos | text | sim | vírgula. Ex: `12345, 67890` |
| `tipo_conta` | Tipo de Conta | select | sim | `Internamento` \| `Ambulatório` \| `Emergência` |
| `num_remessa` | Remessa Existente | text | não | vazio = criar nova |
| `data_entrega` | Data de Entrega | date | não | as duas datas juntas ligam a fase de fechamento |
| `data_vencimento` | Data de Vencimento | date | não | idem |

## Pré-condições

- **FFCV aberto e autenticado** pelo operador. O app não abre nem autentica nada:
  `MV_EnsureMovDoc`/`MV_EnsureFFCV` abortam pedindo abertura manual.
- App em execução com `gRunning` livre (só um fluxo por vez).
- Sem modal de identificação (`MV_WIN_IDENTIFICACAO`) na tela.

## Constantes

Todas em coordenadas **Client**, vindas de Window Spy/captura.

```ahk
; Spy em captures do fluxo de baixa no MOV DOC
MOVDOC_PROTOCOLO_X := 21      MOVDOC_PROTOCOLO_Y := 106
MOVDOC_CONTA_X     := 252     MOVDOC_CONVENIO_X  := 491
MOVDOC_GRID_ROWS_Y := [222, 245, 268, 291]
MOVDOC_CHECK_RECEBIDO_CLASS := "Button1"
MOVDOC_CHECK_RECEBIDO_X := 718   MOVDOC_CHECK_RECEBIDO_Y := 359

; Spy em Fluxos/Fluxo_FecharRemessa: tela "Cadastro: Faturas e Remessas"
DATAS_CAMPO_REMESSA    := "Edit5"   ; 59, 101
DATAS_CAMPO_ENTREGA    := "Edit1"   ; 146, 101
DATAS_CAMPO_VENCIMENTO := "Edit1"   ; 244, 227  ← mesmo ClassNN do anterior, ponto diferente
DATAS_CHECKBOX         := "Button3" ; 541, 242
DATAS_BTN_CONFIRMAR    := "Button10"; 30, 426

; Spy em Fluxos/Fluxo_XML: tela "Monitoração de Faturamento - TISS"
MV_TISS_ATALHO          := "{Alt down}lmm{Enter}{Alt up}"  ; CONFIRMADO no MV pelo operador
XML_CAMPO_REMESSA       := "Edit1" ; 272, 89
XML_BTN_FATURAMENTO     := "Button7"; 12, 446  ; 1 Faturamento
XML_FORM_CAMPO_PATH     := "Edit1" ; 267, 467
XML_FORM_BTN_SALVAR     := "Button4"; 623, 471
XML_FORM_BTN_VOLTAR     := "Button7"; 731, 470

; Popups sem título próprio: detectados por sentinela dentro da janela FFCV
FFCV_POPUP_CONTA_SENTINEL_CLASS := "ui60Drawn W323"  ; 432, 109
POPUP_DROPDOWN_1 := "ComboBox2"  ; 84, 143
POPUP_DROPDOWN_2 := "ComboBox1"  ; 190, 143
POPUP_CAMPO_CONTA := "Edit2"      ; 298, 143
```

`ClassNN` marcado `CLASSNN` em `FFCV_BTN_*` são **placeholders deliberados**: o campo de remessa é
`EditN` variável conforme a quantidade de remessas do convênio, então o fluxo usa F6/F7/F8/F10 em
vez de clicar num `EditN` que pode renumerar. Não troque por coordenada sem nova validação.

## Fases

### Fase 1 — MOV DOC: consultar e baixar protocolos

1. `MV_EnsureMovDoc`. Abrir **instância nova** da tela: `Send "{Alt down}mpb{Alt up}"` e esperar
   `WIN_MOVDOC_BAIXA` ("Protocolação de Baixa de Documentos"). Não reaproveitar tela já aberta.
2. Por protocolo: clicar no campo Protocolo (`MOVDOC_PROTOCOLO_X+40`, `MOVDOC_PROTOCOLO_Y+10`) e
   `SendText`.
3. `Send "{F8}"` para consultar. **Critério de sucesso da consulta** não é o clique ter sido
   aceito — é `RP_WaitMovDocFirstGridLineReady`: a primeira linha da grid ficar legível com conta
   e convênio válidos (12 s).
4. Coletar as linhas visíveis lendo por `Home`+`Shift+End`+`Ctrl+C` com validação semântica
   (`RP_GridValueValid`). O Forms **não** expõe texto de grid por `ControlGetText`.
5. Paginar a grid: clicar na última linha, `{Down}` 4×, reler. Parar quando aparecer o popup de
   último registro, ou após **dois** blocos consecutivos sem linha nova (o Forms pode atrasar a
   atualização da grid e um único bloco vazio é leitura transitória).
6. Finalizar a baixa: checkbox Recebido por estado — `0` → clique simples, `1` → **duplo** clique
   (regra validada pelo operador). Depois `{F10}`, clicar no campo Protocolo e `{F7}` para
   rearmar a consulta. Não há popup de confirmação neste passo.

### Fase 2 — FFCV: montar a remessa

1. `MV_EnsureFFCV`. Abrir **instância nova** de Manutenção de Remessa:
   `Send "{Alt down}lm{Alt up}{Enter}"`.
2. Carregar convênio: `{F7}` → `SendText convenio` → `{F8}`.
3. `PosicionarAreaRemessas`: `{Tab 3}`.
4. Remessa existente: `{F7}` → número → `{F8}`. Nova: `{F6}` → data de hoje → `{Tab 3}` →
   código do tipo (`Emergência=1`, `Internamento=2`, `Ambulatório=3`) → `{F10}`.
5. Inserir contas: clicar `FFCV_BTN_ADICIONAR` (`Button10`, 24, 458) e esperar o popup pelo
   **sentinela** `ui60Drawn W323` (432, 109) — o popup "Informações da Conta" não tem título
   próprio.
6. Configurar dropdowns por teclado uma única vez, popup **mantido aberto** durante o lote:
   - `Internamento`: `{Tab 3}` → `{Down 2}` → `{Tab}` → `{Tab 2}`
   - `Emergência`/`Ambulatório`: `{Tab 3}` → `{Down 2}` → `{Tab 2}` → `{Up 2}` → `{Tab}`
7. Por conta: clicar no campo (298+15, 143+8), `{Home}{Shift down}{End}{Shift up}{Backspace}`,
   `SendText conta`, `{Enter}`.
8. Desfecho do envio — `RP_WaitContaSubmitOutcome`: ou o campo esvaziou (conta aceita) ou o popup
   estabilizou sem modal, ou apareceu modal.
9. Modal de erro: `FFCV_ClassifyErrorModal` (OCR, `lib/FFCV_ErrorTemplates.ahk`). Se classificado
   como `conta_ja_digitada`, é **continuável** — fecha o modal e segue no mesmo popup. Qualquer
   outro erro vira pendência e a execução continua.
10. Fechar o lote com `Alt+2` + `{Enter}`, **só ao final**.

### Fase 3 — Fechar remessa com datas (`FinalizarComDatas`)

Só roda quando `data_entrega` **e** `data_vencimento` vieram preenchidas.

1. Clicar `FFCV_BTN_ABRIR_DATAS` (`Button6`, 464, 458) e esperar `WIN_FFCV_DATAS`.
2. Preencher por teclado, na ordem validada — **não usar Ctrl+A**:
   - clicar em Data de Entrega (146+15, 101+8)
   - `{+Tab}` → lê o nº da remessa com `Ctrl+C` (fallback do campo `Edit5`)
   - `{Tab}` → volta para Data de Entrega → `SendText dataEntrega` → `{Enter}` → `SendText dataVenc`
3. Checkbox "Fechar contas sem imprimir faturas" (`Button3`, 541, 242): ler estado com
   `MV_ControlCheckedAt`; clicar só se `0`. Estado vazio = erro, não siga.
4. Confirmar: `DATAS_BTN_CONFIRMAR` (`Button10`, 30, 426).
5. Modal de confirmação → clicar **Não** (`RP_ClickNaoModal`).
6. Tela de impressão (`WIN_CAPA_REMESSA`) → `MV_WaitOracleSettled` → `{Enter}` → esperar fechar.
7. Sair da tela de Entrega: `RP_ENTREGA_SAIR_ATALHO` (atual `^q`), depois estabilizar o FFCV.

### Fase 4 — Gerar XML (`GerarXML`)

1. Abrir **instância nova** de TISS: `Send MV_TISS_ATALHO`, esperar `WIN_XML`.
2. `RP_SetTextByClickNoClear` no campo remessa (272, 89) → `SendText` → `{F8}`.
3. `RP_WaitXmlQueryReady`: sem modal, botão `XML_BTN_FATURAMENTO` habilitado, cursor não em
   `Wait`, estável por `RP_FINAL_STABLE_MS` (800 ms), e no mínimo `RP_XML_QUERY_MIN_WAIT_MS`
   (1.200 ms) desde o F8.
4. Clicar `XML_BTN_FATURAMENTO` (`Button7`, 12, 446) → `RP_WaitXmlFormOrModal`. Modal pós-clique
   é continuável: fecha por `&OK` e segue.
5. Caminho: `<gWorkDir>\XML\<remessa>.xml`; criar o diretório se faltar. `gWorkDir` vem de
   `config.ini` (`Paths/WorkDir`), default `%USERPROFILE%\Documents\Praxis`.
6. Preencher caminho → estabilizar → `XML_FORM_BTN_SALVAR` (`Button4`, 623, 471).
7. `RP_HandleXmlSaveModals`, até 5 rodadas: modal com `&Sim`+`&Não` → **Não** (política: não
   sobrescrever); modal só com `&OK` → `&OK`. Sem botão seguro → abortar.
8. Estabilizar → `XML_FORM_BTN_VOLTAR` (`Button7`, 731, 470) → `RP_SairTelaAtual` (`{Esc}`).

## Idempotência e recuperação

- **Fase 1** é reexecutável: `{F10}` + `{F7}` rearma a consulta do protocolo, e a grade é percorrida
  por estado, não por posição.
- **Fase 2** — `conta_ja_digitada` é tratada como sucesso: reexecutar não duplica conta, o MV
  recusa. Demais erros de conta viram **pendência** na lista final, não abortam o lote.
- **Fase 3** — remessa já fechada é recusada pelo MV; o modal é classificado e reportado.
- **Fase 4** — política de não sobrescrever: arquivo existente é preservado e o modal de
  substituição é respondido com `Não`.
- `Progress()`, `Notify()`, `Done()`, `RP_Abort` são o único canal de saída. Nada de `MsgBox`,
  `ToolTip` ou `Gui` — o fluxo é autónomo.
- O botão Parar do app só limpa `gRunning`; **não cancela** um fluxo já em execução no MV.

## Critérios de sucesso

- Fechamento: `RP_SairTelaEntregaPendente` retornou verdadeiro e o FFCV estabilizou.
- XML: `RP_HandleXmlSaveModals` consumiu os modais e o `Voltar` foi acionado.
- Relatório final: `RP_FormatTimingReport` com os tempos por fase e, se houver, a tabela
  `PROTOCOLO | CONTA | ERRO` das pendências.

## Pendências

| Item | Situação |
|------|----------|
| `RP_ENTREGA_SAIR_ATALHO` | preenchido com `^q`; **não validado** contra o MV. `Esc` foi descartado por não sair da tela. |
| `XML_BTN_SAIR_TELA` | vazio. A saída usa `{Esc}` em `RP_SairTelaAtual`. Atalho correto nunca foi descoberto. |
| `FFCV_BTN_*` (`CLASSNN`) | placeholders. Não mapear sem nova captura de Window Spy. |

## Não validado

As fases acima foram validadas contra o MV2000i real.

**Confirmado pelo operador:** o atalho de abertura do TISS é `{Alt down}lmm{Enter}{Alt up}`.
Já aplicado em `RP_AbrirTelaTISS` (`scripts/remessa_protocolo.ahk`). Antes enviava `!lt{Enter}`.

**Continua sem validação:** o **renomeamento** das `RP_*` para `MV_*` ao subir para
`scripts/mv_session.ahk`. A renomeação é mecânica e não muda valor de coordenada, mas acontece em
um fluxo que funciona; rode uma execução real depois da extração.
