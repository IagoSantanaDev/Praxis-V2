# 03 — Fechar e Gerar XML

Script: `scripts/fechar_xml.ahk` — **implementado, não validado no MV2000i**  |  Registro: `gScripts` id `fechar_xml`

> Base: `Fluxos/Teste_corrigido.ahk` (594 l.). A versão de 1 remessa `Fluxos/OLD.ahk` (309 l.) está
> superada. As fases de fechamento e XML são as mesmas do
> [workflow 01](01-remessa-protocolo.md) — usar aquele spec como referência de coordenadas.

## Objetivo

Fechar uma lista de remessas com data de entrega e vencimento, e gerar o XML de cada uma.

## Entrada

| id | Label | tipo | obrigatório | notas |
|----|-------|------|--------------|-------|
| `remessas` | Número das Remessas | text | sim | vírgula. Ex: `511458, 514015` |
| `data_entrega` | Data de Entrega | date | sim | `dd/mm/aaaa` |
| `data_vencimento` | Data de Vencimento | date | sim | `dd/mm/aaaa` |

Ambas as datas são obrigatórias: sem elas o fechamento não tem sentido.

O original ainda tinha os checkboxes *Fechar remessa* e *Gerar XML*, independentes. Aqui as duas
fases são **sempre** executadas. Para fechar sem gerar, use o
[workflow 01](01-remessa-protocolo.md) sem preencher as datas.

## Pré-condições

- **FFCV aberto e autenticado** pelo operador. O app não abre nem autentica.
- Remessas já existente e ainda **abertas** no FFCV.
- Nenhum relatório do Oracle Reports pendente na janela de fundo (`RWRBE60.EXE`).

## Constantes

Idênticas às do workflow 01 — hoje chamam `MV_DATAS_*` e `MV_XML_*` em `scripts/mv_session.ahk`.
Não duplicar aqui nem no script; o bloco de coordenadas é único.

```ahk
; Tela "Cadastro: Faturas e Remessas". Coordenadas Client vindas de Window Spy.
MV_DATAS_CAMPO_ENTREGA    := "Edit1"    ; 146, 101
MV_DATAS_CAMPO_VENCIMENTO := "Edit1"    ; 244, 227
MV_DATAS_CHECKBOX         := "Button3"  ; 541, 242
MV_DATAS_BTN_CONFIRMAR    := "Button10" ; 30, 426
```

## Fases

### Fase 1 — Abrir a tela de entrega

A partir do menu principal do FFCV, `MV_EnsureFFCV` e abrir **instância nova** da Manutenção de
Remessa (`{Alt down}lm{Alt up}{Enter}`), depois clicar `FFCV_BTN_ABRIR_DATAS`
(`Button6`, 464, 458) e esperar `MV_WIN_FFCV_DATAS`.

> O original (`Teste_corrigido.ahk` L138) imprimia um relatório **antes** de abrir a entrega,
> pelo `Button9` "Relatório Atend.". **Decisão: não incluir.** O próprio original avisa em L136 que
> esse botão só existe em algumas telas e que a navegação não pode depender dele.

### Fase 2 — Fechar a remessa

Idêntica à Fase 3 do workflow 01, com duas diferenças:

1. O número da remessa vem do **parâmetro** (`remessas[i]`), não é copiado da tela com
   `Shift+Tab`+`Ctrl+C`. O valor copiado serve só para conferência.
2. É a última remessa, então **não há** `Remessa Existente` nem criação de remessa nova aqui.

Preencher entrega/vencimento por teclado, na ordem validada, **sem Ctrl+A**: clicar em Data de
Entrega → `{+Tab}` (confere o nº) → `{Tab}` → `SendText dataEntrega` → `{Enter}` →
`SendText dataVenc`. Marcar o checkbox, `MV_DATAS_BTN_CONFIRMAR`, responder **Não** ao modal de
confirmação, `{Enter}` na capa de impressão, e sair com `MV_ENTREGA_SAIR_ATALHO`.

### Fase 3 — Gerar o XML

Idêntica à Fase 4 do workflow 01: `MV_TISS_ATALHO` → campo remessa → `{F8}` →
`MV_WaitOracleSettled` → `MV_XML_BTN_FATURAMENTO` → caminho `<gWorkDir>\XML\<remessa>.xml` →
`MV_XML_FORM_BTN_SALVAR` → modais → `MV_XML_FORM_BTN_VOLTAR` → `MV_XML_BTN_SAIR_TELA`.

**Antes de gerar**, checar se o arquivo já existe. Se existir, **pular esta remessa** e logar
`XML já existe, não sobrescrito`. É a mesma política do modal de substituição, que já responde
`Não` — mas checar antes evita o processamento pesado do relatório.

### Fase 4 — Próxima remessa

O `Teste_corrigido.ahk` reabre a tela de entrega a cada iteração. Fazer o mesmo: fechar a tela de
datas (`^q`) e voltar ao menu do FFCV antes da próxima. O MV reaproveita o mesmo HWND ao voltar ao
menu, então **não** use "a janela sumiu" como prova isolada de que a entrega terminou.

## Idempotência e recuperação

- **XML já existe** → pula e reporta. Nunca sobrescreve.
- **Remessa já fechada** → o MV recusa; o modal é classificado e a execução **segue** para a
  próxima remessa em vez de abortar a lista inteira.
- **A tela de entrega que não fecha** com o atalho de saída → erro explícito, sem `WinClose`
  forçado. `WinClose` no Forms perde estado e foi justamente o que o original tentou evitar.
- O `finally` sempre executa a saída das telas, para o FFCV voltar ao menu e a próxima execução
  começar de um estado limpo.

## Critérios de sucesso

- Por remessa: tela de datas fechou e o FFCV estabilizou.
- XML: modais consumidos, `Voltar` acionado, arquivo presente em `<gWorkDir>\XML\`.
- Final: lista de remessas processadas com a contagem de fechadas / puladas / com pendência.

## Pendências

| Item | Situação |
|------|----------|
| `MV_XML_BTN_SAIR_TELA` | `^q` (Ctrl+Q), confirmado pelo operador. Antes usava `{Esc}`. |
| Saída da Manutenção de Remessa | **não mapeada em lugar nenhum do projeto.** Ao voltar ao menu o Forms pode reabrir a tela; se o `finally` não conseguir sair, o operador precisa fechar a tela à mão antes da próxima execução. Não há constante para ela. |
| Referência OCR de "remessa já fechada" | não existe em `lib/FFCV_ErrorReferences.json`. Ver "Não validado" abaixo. |

## Não validado

**Nada deste spec foi executado.** `scripts/fechar_xml.ahk` está implementado, mas nunca rodou
contra o MV2000i real. Todos os passos vêm de `Fluxos/Teste_corrigido.ahk`, que rodava como script
autônomo com GUI e `ToolTip` próprios. No Praxis não existe `ToolTip`: o progresso vai por
`Notify`/`Progress`/`Done`. A sequência das fases foi validada no script original, mas **não**
dentro do app.

Não validados: a sequência de teclado para preencher as datas, todas as
coordenadas `MV_DATAS_*` e `MV_XML_*`, e o `MV_TISS_ATALHO` (cujo valor veio do operador).

Um desvio consciente do spec: **"remessa já fechada" não é detectável**. O
`lib/FFCV_ErrorReferences.json` só tem 5 referências OCR (`conta_ja_digitada`, `conta_aberta`,
`conta_em_remessa`, `agrupamento_diferente`, `conta_tipo_diferente`) e nenhuma para esse texto.
Hoje qualquer modal não reconhecido nesse ponto vira **pendência** e a execução segue para a
próxima remessa — o que é mais permissivo que o ideal, porque uma falha real de digitação também
passa. Adicionar a referência canônica ao JSON é o que fecha essa lacuna.
