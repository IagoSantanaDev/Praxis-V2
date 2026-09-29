# 02 — Protocolar

Script: `scripts/protocolar.ahk` — **stub**, valida parâmetros e aborta  |  Registro: `gScripts` id `protocolar`

> Base: `Fluxos/protocolar.ahk` (2.200 l., 2026-06-22). A versão anterior
> `Fluxos/Protocolar_recuperado.ahk` diverge em `CorrigirSetorDaContaEBaixar` (inverte os setores);
> quando divergirem, **o `protocolar.ahk` manda** por ser mais recente.

## Objetivo

Gerar a planilha de contas das remessas no FFCV e movimentar cada conta de um setor para outro
pelo MOV DOC, dando baixa nos protocolos pendentes que o MV recusar.

## Entrada

| id | Label | tipo | obrigatório | notas |
|----|-------|------|--------------|-------|
| `remessas` | Número das Remessas | text | sim | vírgula. Ex: `511458, 514015` |
| `setor_atual` | Setor Atual | text | sim | Ex: `34` |
| `setor_envio` | Setor de Envio | text | sim | Ex: `365` — tem de ser ≠ `setor_atual` |
| `tipo` | Tipo | select | sim | `Ambulatorial` \| `Hospitalar`. **Muda a sequência de teclas** da tela de envio |
| `imprimir_salvar_envio` | Imprimir/Salvar Envio | select | sim | `Sim` \| `Não`. Decide entre `Alt+1`+Imprimir ou só excluir o registro em branco |

`tipo` e `imprimir_salvar_envio` existem no original e ainda **não** estão em `gScripts`. Ao
adicioná-los, editar **os dois** lugares: `main.ahk` e `devSim()` em `ui/index.html`.

## Pré-condições

- **FFCV e MOV DOC abertos e autenticados** pelo operador. O app não abre nenhum dos dois.
- Ambos sem modal de identificação na tela.
- Nenhum relatório do Oracle Reports pendente na janela de fundo (`RWRBE60.EXE`).

## Constantes

O fluxo roda quase todo por **atalho de menu** e por janela. O que é ClassNN vem do original:

```ahk
; Janelas
MV_WIN_FFCV_RELATORIO   := "Relatórios Personalizado"        ; ui60Modal_W32
MV_WIN_FFCV_REMESSASQL  := "ahk_class TFPrincipal ahk_exe EXECUTASQL.exe"
MV_WIN_FFCV_INFO        := "Information ahk_exe EXECUTASQL.exe"
MV_WIN_MOVDOC_ENVIO    := "Protocolação de Envio de Documentos"
MV_WIN_MOVREL_ENVIO    := "Relatório de Registro de Envio"
MV_WIN_MV_MSG          := "Mensagem ao Usuário do MV 2000"
MV_EXE_MV              := "ifrun60.EXE"
MV_EXE_REPORTS         := "RWRBE60.EXE"
MV_EXE_SQL             := "EXECUTASQL.exe"

; Controles
FFCV_BTN_GERAR_ARQUIVO := "TBitBtn2"   ; Gerar Arquivo, client 548, 91
SQL_BTN_OK             := "TButton1"   ; popup Information
ENVIO_BTN_CONFIRMAR    := "Button2"    ; confirma setor atual/envio
ENVIO_BTN_EXCLUIR      := "ui60Viewcore_W3211"  ; excluir registro em branco
ENVIO_CAMPO_PROTOCOLO_X := 60
ENVIO_CAMPO_PROTOCOLO_Y := 115
BAIXA_BTN_RECEBIDO     := "Button1"    ; tela de baixa
```

`ENVIO_BTN_EXCLUIR` é prefixo de classe (`ui60Viewcore_W3211`), não ClassNN exato — o Forms
renumera a viewcore. Buscar por prefixo.

## Fases

### Fase 1 — FFCV: gerar a planilha de contas

1. `MV_EnsureFFCV`. Apagar os CSVs antigos antes de gerar (re-executável).
2. Abrir o relatório: `Send "!e"` → `{Enter 2}` → esperar `MV_WIN_FFCV_RELATORIO`.
3. Selecionar o relatório: `Send "{Down 121}"` → `Send "!1"`.
   ⚠️ **Posicional.** 121 dependem da ordenação do relatório na estação do hospital. Se mudar lá,
   este fluxo gera a planilha errada sem erro visível.
4. Achar o popup de remessa (`MV_WIN_FFCV_REMESSASQL`) e informar as remessas.
5. `FFCV_BTN_GERAR_ARQUIVO` (`TBitBtn2`) → diálogo *Save As* → nome
   `<gWorkDir>\Envio.csv` → salvar.
6. Popup "Information" do `EXECUTASQL.exe` → `SQL_BTN_OK`.
7. Fechar o popup "Relatórios Personalizado" (`Button1`).
8. Esperar o arquivo existir no disco (o `EXECUTASQL.exe` às vezes confirma antes de terminar).

### Fase 2 — Ler a planilha

CSV separado por **`;`**, coluna de contas **`CD_REG_AMB`**. Cabeçalho real, de
`Fluxos/ffcv/1.CSV`:

```
CD_REMESSA;CD_CONVENIO;NM_CONVENIO;INICIO;TERMINO;CD_REG_AMB;ATENDIMENTO;NM_PACIENTE;CARTEIRA;GUIA;VALOR
512220;934;CAIXA ECONOMICA CBHPM-TUSS S.A;11/06/2026;11/06/2026;13023847;15092781;...
```

- **Buscar a coluna por nome**, nunca por índice fixo.
- Descartar o cabeçalho, linhas vazias e valores não numéricos.
- Deduplicar contas (`DEDUPLICAR_CONTAS`).

> O original chama `MV_SplitSemicolonCsvLine`, vindo de `lib/globals/mv/ParseUtils.ahk` — arquivo
> que **não existe** neste repo. Escrever o splitter local.

### Fase 3 — MOV DOC: enviar as contas

1. `MV_EnsureMovDoc`. Abrir a tela: `SendMenuPath("mpe")` → esperar `MV_WIN_MOVDOC_ENVIO`.
2. Configurar: `SendText setorAtual` → `{Enter}` → `SendText setorEnvio` → `ENVIO_BTN_CONFIRMAR`
   (`Button2`) → `{Tab 2}`.
3. Se `tipo = Hospitalar`: `{+Tab 2}` → `{Up 2}` → `{+Tab 2}`.
4. Por conta: reaproveitar a tela de envio se ainda estiver aberta, reabrindo com a config original
   se o fluxo caiu para o menu. Colar a conta e `{Enter}`.
5. Detectar o popup `MV_WIN_MV_MSG` (timeout curto, ~300 ms — conta aceita não abre popup).
6. Ler a mensagem e classificar (ver Fase 4).

### Fase 4 — Tratar o popup do MV

A mensagem **não** é confiável por `WinGetText`/Window Spy. Usar OCR:
`FFCV_ResolveOcrRegion` + `FFCV_RunOcrProbe` de `lib/FFCV_ErrorTemplates.ahk` (já embutido no
build como `Praxis_OcrProbe.ahk`). **Não portar o servidor OCR persistente do original.**

Depois, em texto normalizado (minúsculo, sem acento, tolerante a ruído de OCR):

**Documento pendente** — precisa ter os três sinais: `pendente` + (`devolu`|`receb`|`document`)
+ número de 4+ dígitos depois de `protoc*`:

```
"o documento esta pendente de recebimento. protocolo n. 1234567"
```

Ação: fechar o popup, `BaixarProtocolo(protocolo)` → MOV DOC `{Alt down}mp{Alt up}b` →
`SendText protocolo` → `{F8}` → `BAIXA_BTN_RECEBIDO` (`Button1`) → `{F10}` → `^q` + `{Enter}`.

**Setor divergente** — precisa ter `setor` + `diferente` + `conta` (o OCR lê `canta`/`cont4`):

```
"O Setor no 34 esta diferente do Setor recebido: 356 para conta: 13023847"
```

Ação: fechar o popup, `CorrigirSetorDaContaEBaixar` → reabre a tela de envio **invertendo** os
setores (`setorRecebido` como atual, `setorAtual` como envio) → `{Alt down}1{Alt up}` →
"Relatório de Registro de Envio" → `Button1` → lê o protocolo novo copiando o campo
(`60, 115`) → `^q` → `BaixarProtocolo(protocoloNovo)`.

Correção de OCR: se o setor lido tem **o mesmo tamanho** do `setor_envio` configurado e difere em
**1 dígito**, e a mensagem menciona o `setor_atual` antes de "diferente", usar o valor configurado.
É o caso real "356" lido como "336". Não aplicar a correção em qualquer número solto.

**Mensagem não reconhecida** → abortar. Nunca seguir operhando em popup que não se entendeu.

### Fase 5 — Finalizar

1. Excluir o registro em branco criado pelo último `{Enter}` (`ENVIO_BTN_EXCLUIR`).
2. Se `imprimir_salvar_envio = Sim`: `{Alt down}1{Alt up}` → "Relatório de Registro de Envio" →
   `Button2` (Imprimir) → `^q` no MOV DOC.
   Se `Não`: **parar aqui**, antes do `Alt+1` — o registro em branco fica excluído e o MOV DOC
   aberto.

## Idempotência e recuperação

- Fase 1 apaga os CSVs anteriores antes de gerar, então re-executar não lê planilha velha.
- Fase 3 reaproveita a tela de envio aberta; reabre com a config original se perdeu o contexto.
- A ação da Fase 4 é sempre escolhida pelo **conteúdo** do popup, não por posição: documento
  pendente tem precedência sobre setor divergente.
- Corrigir setor e baixar protocolo são operações compensatórias: se uma falha no meio, a próxima
  execução reencontra a tela e reexecuta a partir do popup que ficou.
- `gRunning` éCooperativo: a checagem de cancelamento vai dentro das esperas longas, senão o botão
  Parar só age depois do próximo ponto de checagem.

## Critérios de sucesso

- CSV existe no disco e tem ao menos 2 linhas (cabeçalho + 1 conta).
- Todas as contas foram enviadas e nenhum popup ficou sem tratamento.
- Com `imprimir_salvar_envio = Sim`: impressão concluída e MOV DOC fechado.

## Pendências

| Item | Situação |
|------|----------|
| `{Down 121}` | posicional, não validado. Registrar a ordenação real do relatório |
| `FFCV_BTN_GERAR_ARQUIVO` client `548, 91` | vem do original; `TBitBtn2` é do `EXECUTASQL.exe`, não do `ifrun60.EXE` |
| Cadeia de fallback do popup de remessa | o original tem 4 fallbacks porque `EXECUTASQL.exe` é instável. É o ponto mais frágil do fluxo |
| `params.tipo` e `params.imprimir_salvar_envio` | não existem em `gScripts` ainda |

## Não validado

**Nada deste spec foi executado.** O `scripts/protocolar.ahk` atual é stub e aborta antes de
qualquer ação. Todos os passos acima vêm de `Fluxos/protocolar.ahk`, que rodava como script
autônomo com GUI própria — não dentro do Praxis, sem WebView2 e sem `gRunning`. Mover para o
dispatcher do Praxis muda o contexto de teclado e de timing. **Só considere este fluxo validado
depois de uma execução real no MV2000i.**
