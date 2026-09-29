# Prompt — implementar `fechar_xml` e `protocolar` (sequencial, via subagents)

> Cole o bloco abaixo num prompt novo do agente orquestrador.

---

Implemente, de forma **SEQUENCIAL**, as 4 fases do plano de implementação dos módulos
`fechar_xml` e `protocolar` do **Praxis** (automação hospitalar no MV2000i / Oracle Forms 6i,
escrita em AutoHotkey v2).

Uma fase por subagent. **NUNCA rode dois subagents em paralelo** — todas as fases tocam
`scripts/mv_session.ahk` e `scripts/remessa_protocolo.ahk`.

## Passo 0 — leia você mesmo antes de delegar

Você tem o contexto completo; subagent começa do zero. Leia para orchestrar com precisão, mas
**rePasse o conteúdo relevante no prompt de cada subagent**:

- `.agents/AGENTS.md` — regras completas do projeto
- `.agents/workflows/README.md` — índice, template e quadro "Estado atual vs. estado descrito"
- `.agents/workflows/01-remessa-protocolo.md` — único fluxo validado; fonte das coordenadas
- `.agents/workflows/02-protocolar.md` — spec a implementar
- `.agents/workflows/03-fechar-xml.md` — spec a implementar
- `AGENTS.md` (raiz) — armadilhas de falha silenciosa

## Bloco de contexto — repita em TODOS os prompts de subagent

```
Projeto: Praxis em T:\Projetos\Praxis Desatualizado. Caminho da raiz tem espaço: sempre entre
aspas. AutoHotkey v2, app de desktop, UI em WebView2. Código e comentários em pt-BR.

REGRAS QUE QUEBRAM SILENCIOSAMENTE (não violate):
- #Include é textual e transitivo. scripts/mv_session.ahk JÁ é incluído por
  scripts/remessa_protocolo.ahk. NÃO adicione #Include mv_session.ahk em nenhum outro arquivo:
  duplica todas as funções MV_* e o build quebra. Esta é a armadilha nº 1 deste projeto.
- gScripts em main.ahk está DUPLICADO em devSim() dentro de ui/index.html. Mudar id, label,
  tipo ou obrigatorio de um parâmetro exige editar os DOIS arquivos.
- Todo .ahk de primeira parte começa com o cabeçalho proprietário de 4 linhas. Preserve.
- Automação do MV só está validada depois de rodar contra o MV2000i real. Você NÃO tem o MV.
  Não afirme que algo funciona. Marque como PENDENTE o que não foi confirmado, e diga
  explicitamente o que não validou.

PREFIXOS DE FUNÇÃO (evita colisão de escopo — #Include é textual, função duplicada = erro):
  MV_  -> só para o que sobe para scripts/mv_session.ahk (contrato de janela compartilhado)
  RP_  -> scripts/remessa_protocolo.ahk (já existe, não renomeie sem necessidade)
  FX_  -> scripts/fechar_xml.ahk
  PR_  -> scripts/protocolar.ahk

REGRAS DE AUTOMAÇÃO MV2000i:
- Teclado primeiro: Send/SendText e atalhos (F6/F7/F8/F10, Alt+mnemonic).
- EditN NÃO é contrato: o Forms renumera conforme o estado da tela. Localize por ClassNN +
  ponto Client, ou por prefixo de classe (ui60Drawn, ui60Viewcore_W3211).
- Coordenada é SEMPRE Client. Nunca coordenada de tela.
- Use MV_Poll / MV_WaitOracleSettled em vez de Sleep fixo ao esperar janela, modal ou cursor.
- Toda constante nova registra a origem com uma linha `; Spy em Fluxos/<arquivo> L<n>`
  imediatamente acima do bloco.
- PENDENTE é literal. Preencher constante pendente por adivinhação de coordenada é PIOR que
  deixar pendente, porque o erro fica silencioso.
- Modais do Oracle Forms não expõem a mensagem por WinGetText/Window Spy. Leitura de erro passa
  por OCR: FFCV_ResolveOcrRegion + FFCV_RunOcrProbe, de lib/FFCV_ErrorTemplates.ahk (já embutido
  no build). Não porte servidor OCR próprio.
- Fluxos são autônomos: sem Gui, sem MsgBox, sem ToolTip, sem hotkey. Saída só por Notify(),
  Progress(), Done() e o Abort do módulo.

VALIDAÇÃO (obrigatória antes de reportar):
  powershell -ExecutionPolicy Bypass -File "T:\Projetos\Praxis Desatualizado\tools\build-praxis.ps1" -Version 9.9.9-test -SkipInstaller
Depois, no staging:
  $p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" -ArgumentList
        '--integrity-check' -Wait -PassThru; $p.ExitCode     # precisa ser 0
O build é o ÚNICO gate automatizado: pega erro de sintaxe AHK, include duplicado e asset
faltando. Não existe test suite, linter nem CI. Não invente um gate novo.
```

## Fase 1 — extrair primitivas para `scripts/mv_session.ahk`

> Subagent com escopo **apenas** em `scripts/mv_session.ahk` e `scripts/remessa_protocolo.ahk`.

Promova para `mv_session.ahk`, com prefixo `MV_` e **sem mudar valor nenhum**:

- Constantes: `MV_WIN_FFCV_DATAS`, `MV_WIN_CAPA_REMESSA`, `MV_WIN_XML_TISS`,
  `MV_WIN_XML_PATH_FORM`, `MV_WIN_MSG_USER`, o bloco `DATAS_*`, o bloco `XML_*`,
  `MV_FORMS_MODAL`, `MV_TISS_ATALHO`.
- Renomeie `RP_ENTREGA_SAIR_ATALHO` → `MV_ENTREGA_SAIR_ATALHO` e `XML_BTN_SAIR_TELA` →
  `MV_XML_BTN_SAIR_TELA`.
- `MV_TISS_ATALHO := "{Alt down}lmm{Enter}{Alt up}"` — este valor **já foi confirmado** contra o
  MV2000i pelo operador. Não reintroduza `!lt{Enter}`.
- Funções: `MV_EnsureWindowActive`, `MV_WaitOracleSettled`, `MV_WaitWindowGone`,
  `MV_WaitModalGone`, `MV_ActiveModalTitle`, `MV_ClickModalButtonByText`, `MV_ModalHasButton`,
  `MV_ClickBySpec`, `MV_SetTextByClickAt`, `MV_SetTextByClickNoClear`, `MV_ControlAtReady`,
  `MV_PollMs`, `MV_FormatDuration`, `MV_Abort`.
- Em `remessa_protocolo.ahk`, troque só os nomes. **Nenhuma lógica, coordenada ou fluxo muda.**

Exija do subagent: `RP_Abort` vira wrapper de uma linha delegando para `MV_Abort` (as ~15 chamadas
existentes ficam intactas). Ao final, `git diff --stat` deve mostrar só 2 arquivos, e o build +
integrity-check precisam passar.

## Fase 2 — registrar os params de `protocolar`

> Subagent com escopo **apenas** em `main.ahk` e `ui/index.html`.

Em `gScripts`, id `protocolar` (main.ahk L52-68), adicionar:

- `tipo` — select, obrigatório, opções `["Ambulatorial", "Hospitalar"]`
- `imprimir_salvar_envio` — select, obrigatório, opções `["Sim", "Não"]`, default `Sim`

Espelhar **exatamente** os dois em `devSim()` dentro de `ui/index.html` (L439-446). Build +
integrity-check.

## Fase 3 — implementar `scripts/fechar_xml.ahk`

> Só **depois** das Fases 1 e 2 verdes. Um subagent só nesta fase.

Substituir o stub pela implementação de `.agents/workflows/03-fechar-xml.md`. Fases do spec:
abrir tela de entrega → fechar remessa com datas → gerar XML → próxima remessa.

Regras específicas: número da remessa vem do **parâmetro** (não copiar da tela); antes de gerar
o XML, se `<gWorkDir>\XML\<remessa>.xml` já existir, **pular e logar**; remessa já fechada vira
pendência e a execução segue para a próxima; sempre sair das telas no `finally`; **nunca**
`WinClose` no Forms. Use `MV_*` da Fase 1. Renomeie `FecharXML_ParseRemessas` → `FX_ParseRemessas`
e `FecharXML_Abort` → `FX_Abort`. Build + integrity-check.

## Fase 4 — implementar `scripts/protocolar.ahk`

> Só **depois** da Fase 3 verde. Um subagent só nesta fase.

Substituir o stub pela implementação de `.agents/workflows/02-protocolar.md`: gerar planilha no
FFCV → ler CSV → enviar contas no MOV DOC → tratar popup por OCR → finalizar.

Pontos que exigem atenção: coluna **`CD_REG_AMB`** buscada **por nome**, CSV separado por `;`
(o `MV_SplitSemicolonCsvLine` do original vem de `lib/globals/mv/ParseUtils.ahk`, que **não
existe** neste repo — escreva o splitter local); dedupe de contas; `{Down 121}` é posicional e
**não validado** — deixe marcado; corrigir setor e baixar protocolo são operações
compensatórias, com critério de ação sempre pelo **conteúdo** do popup; popup não reconhecido
**aborta**, nunca segue. Use `MV_*` da Fase 1 e os params da Fase 2. Build + integrity-check.

## Gate entre fases

Depois de cada fase, antes de iniciar a seguinte:

1. Confirme que o subagent rodou o build e colou o exit code do integrity-check (`0`).
2. `git diff --stat` — só os arquivos previstos daquela fase.
3. Se o build **falhar**: **PARE**. Não peça para o próximo subagent corrigir, não tente
   consertar e seguir. Reporte o erro e devolva o controle.

## Relatório final

Ao terminar, reporte:

- O que cada fase mudou (arquivo + essencial)
- Estado do build e do integrity-check **por fase**
- **O que não foi validado** — com destaque: nenhuma das automações foi rodada contra o
  MV2000i real. Atalhos de menu, `{Down 121}` e qualquer coordenada nova continuam
  **não validados**, mesmo com o build passando.
- O que ficou `PENDENTE` e por quê
- Nada commitado, a menos que eu peça
