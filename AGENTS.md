# AGENTS.md — Praxis

Automação de faturamento hospitalar no MV2000i (Oracle Forms 6i). App desktop em AutoHotkey v2,
UI em WebView2 (HTML/CSS/JS puro em `ui/index.html`). Código, comentários e docs em **pt-BR**.

Este arquivo é a **fonte única e autossuficiente** das regras do projeto — não há spec de automação
versionado, então tudo o que um agente precisa saber para não errar está aqui. Referências
versionadas:

- Build, assinatura, artefatos e checklist de entrega: `docs/DISTRIBUTION.md`.
- App, parâmetros e público: `README.md`.

O caminho da raiz contém espaço: **sempre entre aspas** em comandos.

## Ordem de autoridade

1. Requisitos explícitos do usuário.
2. Segurança, integridade dos dados e validação.
3. Context7 para decisão externa, técnica ou versionada (regra 1).
4. Padrões existentes no repo.
5. Reutilização e padrão LEGO.
6. Simplicidade e minimalismo.

Na divergência, ganha quem está acima. Adotar o padrão existente é o padrão; sair dele exige
justificar na resposta **por que o padrão não serve**, **qual regressão a alternativa evita** e
**como a consistência é preservada**.

## 1. Context7 antes de decidir

Consulte o Context7 antes de qualquer decisão sobre framework, biblioteca, dependência, API,
ferramenta, configuração, arquitetura ou recurso de linguagem. Não decida por memória nem por
familiaridade.

Use-o para consultar a documentação da versão em uso, comparar opções e expor
incompatibilidades, limitações, riscos e recursos obsoletos, e avaliar qual solução é a mais
adequada a este projeto.

IDs que resolvem para este projeto:

| Assunto | Library ID |
|---|---|
| AutoHotkey v2 (linguagem) | `/autohotkey/autohotkeydocs` (branch `v2`), `/websites/autohotkey_v2` |
| WebView2 | `/websites/learn_microsoft_en-us_microsoft-edge_webview2` |
| Inno Setup (`installer/Praxis.iss`) | `/jrsoftware/issrc` |
| Ahk2Exe | `/autohotkey/ahk2exe` |

**Limite conhecido:** o Context7 não tem nada sobre MV2000i / Oracle Forms 6i — e **nenhum arquivo
versionado deste repo documenta o sistema do hospital**. A única fonte dessa parte é o operador e o
MV2000i real: Window Spy, captura de tela e execução real. Atalho, coordenada ou nome de tela que você
não viu na origem é `PENDENTE` — preenchê-lo por adivinhação é pior que deixar pendente, porque o
erro fica silencioso. Ver "Regras de automação" no fim do arquivo.

Avaliação do Context7 pode prevalecer sobre o padrão existente quando apontar solução com melhor
manutenibilidade, desempenho, escalabilidade, testabilidade, confiabilidade, segurança ou
compatibilidade — desde que a justificativa apareça na resposta.

## 2. O padrão existente vence

Antes de implementar UI, fluxo, endpoint, filtro, navegação, formulário, estado, layout ou
automação, procure a implementação equivalente no projeto e **reutilize**. Não troque um padrão
consolidado por primitiva de framework, biblioteca nativa ou implementação local só porque
também funciona, é menor ou parece mais rápida de escrever.

Os owners dos padrões deste repo:

| Escopo | Onde mora |
|---|---|
| Contrato de janela do MV2000i, `MV_*` | `scripts/mv_session.ahk` |
| Fluxo 01, `RP_*` | `scripts/remessa_protocolo.ahk` |
| Fluxo 02, `PR_*` | `scripts/protocolar.ahk` |
| Fluxo 03, `FX_*` | `scripts/fechar_xml.ahk` |
| UI, contrato de mensagens, forms | `ui/index.html` (arquivo único e completo) |
| Registro de scripts e params | `gScripts` em `main.ahk` |
| Primitivas de teste, `TESTE_*` | `tests/lib/teste_lib.ahk` |

`tests/` é **independente do app**: não entra na cadeia de `#Include` de `main.ahk`, não aparece em
`gScripts`, e o leak-check do staging nunca o vê. Gate próprio: `tests/teste_espera_cursor.ahk` sai
com o número de falhas (0 = passou) e não toca no MV2000i. `tests/teste_baixa_cursor.ahk` **exige o
MV2000i real** e ainda não rodou nele — treatá-lo como não validado.

## 3. Validação obrigatória

Não entregue sem a menor validação prática compatível com a mudança:

| Tipo de mudança | Validação mínima |
|---|---|
| Automação do MV | build + `--integrity-check` **e** rodar contra o MV2000i real. Sem o MV, diga que não validou |
| Bug fix | reproduzir ou rodar o check que falharia |
| Refactor | build + `--integrity-check` |
| UI / registro de script | abrir o app e conferir sidebar, formulário de cada módulo e o envio de `ready` |
| Config / script | rodar o comando afetado |
| Docs | conferir caminhos, comandos e exemplos citados no arquivo |

Gate do build (é o **único** gate automatizado — pega erro de sintaxe AHK, include duplicado e
asset faltando):

```powershell
# 1. build (pula instalador; rápido)
powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller

# 2. integridade do runtime no staging — precisa sair 0 (70 = recurso ausente/alterado, main.ahk:190)
$p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" `
     -ArgumentList '--integrity-check' -Wait -PassThru; $p.ExitCode

# 3. abrir o app em dev (lê ui\index.html do disco, pula verificação de integridade)
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" ".\main.ahk"
```

Não existe test suite, linter nem CI — e o build não prova comportamento. **Não invente um gate
novo.** Se não foi possível validar, diga exatamente por quê em vez de afirmar que funciona.

Outros builds: com instalador, `-Version 9.9.9-test`; release exige assinatura **e** árvore Git
limpa — `-Version 1.3.0 -CertificateThumbprint <THUMBPRINT> -Release`. O toolchain (AutoHotkey v2,
Ahk2Exe, ISCC, signtool) é descoberto automaticamente pelo `tools/build-praxis.ps1`; **não fixe
caminho absoluto**.

## 4. Reutilização antes da criação

Ordem: reutilizar → compor → estender de forma compatível → consolidar duplicação real → criar.

Procure primeiro em `scripts/mv_session.ahk`, `lib/` e `ui/index.html` antes de criar helper novo.
Helper compartilhado entre fluxos **sobe para `mv_session.ahk` com prefixo `MV_`** — não promova um
helper de um fluxo para o outro usar (ver armadilha do `#Include`).

## 5. Padrão LEGO

Construa em camadas: primitivas pequenas → componentes reutilizáveis → blocos estruturais → layout
→ fluxo. Elementos recorrentes (estado de loading/vazio/erro, cards, listas, filtros, formulário,
espaçamentos, cores, tipografia) vêm de componente, token ou layout compartilhado.

Componente global fica **independente de regra de negócio**; componente de domínio vive no módulo
mas compõe as primitivas compartilhadas. Quando a peça central não serve, corrija, componha ou
estenda ela — não crie variação local paralela. Não transforme componente compartilhado em API
genérica demais: adicione variação só quando houver uso real.

## 6. Simplicidade

Faça a menor mudança correta que siga o padrão do repo. Não introduza dependência, abstração,
arquitetura, cache, paralelismo, otimização ou configuração sem necessidade concreta. DRY só para
duplicação real — generalização especulativa sai.

## 7. Aprendizado contínuo

Quando um erro, comando incorreto ou abordagem falha for **identificado e corrigido**, registre:
contexto, causa raiz confirmada, solução validada e como evitar a repetição. Só registre depois de
confirmar a causa e validar a correção. Não registre hipótese, correção parcial, informação
descartável, credencial ou dado sensível.

Onde registrar, em ordem de importância:

1. Se o aprendizado é uma **armadilha que faz trabalho errado sem erro visível** — que é o caso
   deste projeto —, promova para a seção "Falha silenciosa" deste arquivo. É versionado, então
   protege toda sessão futura.
2. Rascunho local em `.agents/LEARNINGS.md`, quando o diretório existir. É **gitignored**: memória
   desta máquina, não do repo. Não versione e não dependa dele.

Atualize a entrada existente em vez de duplicar.

**`PENDENTE` não é aprendizado.** Pendência de automação do MV fica no próprio código, junto da
constante, com a origem que falta. `PENDENTE` é literal: preencher por adivinhação é pior que deixar
pendente, porque o erro fica silencioso.

## 8. Higiene do repositório

Antes de commit ou entrega, revise arquivos temporários, cache, log, build local, backup,
credencial e artefato de agente. Não versione o que é local, transitório, sensível ou gerado —
salvo o que for necessário para build, execução, documentação ou rastreabilidade.

O `.gitignore` já cobre `dist/`, `build/`, `config.ini`, `*.log`, `*.xml`, `*.exe`, `*.pfx` e
`Fluxos/`. Ele **também** ignora `.claude/`, `.cursor/`, `.codex/`, `.windsurf/`, `.roo/` e
`.mcp.json`: regra de projeto colocada nesses diretórios nunca entra no remoto. Ao achar um padrão
recorrente de arquivo que não deve ir para o remoto, atualize o `.gitignore`.

Todo arquivo de primeira parte (`.ahk` e `.ps1`) começa com o cabeçalho proprietário de 4 linhas.
Mantenha ao criar arquivo. `lib/WebView2.ahk`, `JSON.ahk`, `Promise.ahk` e `ComVar.ahk` são libs
externas (thqby) — **não edite**.

## 9. Comentários

Priorize código autoexplicativo. Comentário só para decisão não óbvia, restrição, contrato
importante, regra de negócio ou workaround cuja razão o código não expressa. Nunca para repetir o
que o código já mostra.

Exceção deste repo: constante de automação nova **precisa** registrar a origem com uma linha
`; Spy em Fluxos/<arquivo> L<n>` ou `; Spy em <captura>.png` imediatamente acima do bloco.

---

# Falha silenciosa — não ignore

Erros aqui não dão erro visível: produzem tela errada, planilha errada ou remessa errada.

- **`#Include` é textual e transitivo.** `scripts/mv_session.ahk` já vem incluído por
  `scripts/remessa_protocolo.ahk:7`. **Não re-inclua** `mv_session.ahk` em `protocolar.ahk` ou
  `fechar_xml.ahk`: duplica todas as funções `MV_*` e o build quebra.
- **`gScripts` em `main.ahk:30` está duplicado em `devSim()` dentro de `ui/index.html:425`.** Alterar
  `id`, `label`, `tipo`, `obrigatorio`, `opcoes` ou `default` de um parâmetro exige editar **os
  dois** lugares, senão a UI em modo dev mostra o formulário errado.
- **Os três fluxos existem em código; só um rodou no MV.** `remessa_protocolo.ahk` é o validado.
  `protocolar.ahk` (`PR_*`) e `fechar_xml.ahk` (`FX_*`) compilam mas **nunca rodaram contra o
  MV2000i**. Build e `--integrity-check` provam sintaxe, include e asset — não comportamento.
- **Os fluxos não se chamam.** `protocolar.ahk` não chama `RP_*` nem `FX_*`; `fechar_xml.ahk` não
  chama `RP_*` nem `PR_*`. Como o escopo do `#Include` é global, helper compartilhado novo sobe
  para `mv_session.ahk` com prefixo `MV_`.
- **Automação do MV só está validada depois de rodar contra o MV2000i real**, com o modal na tela.
  Se você não rodou, diga isso explicitamente em vez de afirmar que funciona.
- **Sair de tela no MV é Ctrl+Q**, confirmado pelo operador para **todas** as telas; no menu
  principal fecha o MV. Em AHK `^` é Ctrl, então `^q` **é** Ctrl+Q — não é valor suspeito. Uma
  constante só: `MV_SAIR_TELA_ATALHO` (`mv_session.ahk:78`). `{Esc}` foi descartado. Não "conserte"
  por adivinhação. O fluxo validado acrescenta `{Enter}` depois do `^q` na baixa
  (`Praxis_TO-DO/Protocolar/protocolar.ahk:1124`); o Praxis **não** faz isso, por decisão do
  operador. Não "conserte" para incluir o `{Enter}`.
- **No título de uma tela MDI do MV, o nome da tela aparece ENTRE COLCHETES** na raiz:
  `Movimentação de Documentos - [Protocolação de Baixa de Documentos - HOSPITAL SAO RAFAEL]`,
  classe `ui60MDIroot_W32`. Com `SetTitleMatchMode 2` (substring), um `WinExist` que procure o
  nome da child **resolve para a raiz**, e o `hwnd` devolvido tem um título que não contém mais o
  texto procurado. O `^q` é processado pela child, então ativar a raiz não fecha a tela. Para
  **saída de tela**, use a constante que casa **fora** dos colchetes (`MV_WIN_MOVDOC_ANY`,
  `MV_WIN_FFCV_ANY`); para **esperar e clicar** na tela, a que casa dentro
  (`MV_WIN_MOVDOC_BAIXA`) está correta. Confundir as duas é o que fazia o `^q` não sair da baixa
  enquanto funcionava no FFCV.
- **Verificar "a tela mudou" por estabilidade é errado.** `MV_WaitOracleSettled` usava só a
  **contagem de controles**, e o MV troca de tela no mesmo HWND sem alterar essa contagem — uma
  tecla engolida produz uma tela "perfeitamente estável". Medido: mesmo HWND, contagem 1 → 1,
  só o título mudou. Por isso `MV_FecharUltimaTela` agora compara a **assinatura de tela**
  (`MV_ScreenSignature`, inclui título) antes e depois, e `MV_WaitTelaSaiu` só aceita como
  sucesso a janela sumida **ou** a assinatura mudada. Regra geral: **estabilidade não prova
  transição**; exija uma assinatura que inclua o título, e nunca reporte sucesso sem ela.
  `PR_EsperarJanelaEstavel` (`protocolar.ahk:1271`) foi corrigido pelo mesmo motivo: comparava
  só a contagem de controles, que não muda na troca de tela do Forms.
- **`PR_JanelaVisivel` mascarava o bit errado** (`protocolar.ahk`): testava `0x1000000`, que é
  `WS_MAXIMIZE`, com o comentário dizendo `WS_VISIBLE` (que é `0x10000000`). Reprovava toda janela
  normal — inclusive o diálogo "Salvar como" — e desligava em silêncio 5 dos 6 fallbacks de
  `PR_EsperarPopupRemessa` **e** `PR_EsperarPopupMv`, que é o que detectava popup por conta no
  Protocolar: sem ele, **toda conta era contada como aceita** e `PR_TratarPopup` nunca rodava.
  Bit de estilo Win32: confira o valor, não confie no comentário. `WinGetStyle` é o único jeito
  de testar visibilidade, e o valor certo é `0x10000000`.
- **No Protocolar não existe "conta recusada".** `PR_TratarPopup` tem **dois** ramos de recuperação
  (documento pendente e setor divergente) e um de **não reconhecido** — e só esses. Não existe
  ramo de recusa, e nenhum caminho do Protocolar conta uma conta como recusada: conta sem popup é
  **aceita**. Um popup reconhecido é corrigido e reprocessado; um popup não reconhecido **trava o
  lote**. Texto que diga o contrário faz alguém "corrigir" `PR_TratarPopup` procurando um ramo de
  recusa que não existe.
- **`MV_ClickBySpec` degrada para clique cego por coordenada** quando o `ClassNN` não casa
  (`mv_session.ahk:760`): tenta `MV_ClickControlAt`, e se falhar clica no ponto `(x, y)` e devolve
  `true` do mesmo jeito. Um `ClassNN` errado vira **ação errada sem erro**. Não é possível, pelo
  retorno, distinguir clique no controle de clique na coordenada. Prefira `MV_ClickFirstControl`
  (sem coordenada) quando só o `ClassNN` importa.
- **Todo fim de fluxo fecha a última tela**, via `MV_FecharUltimaTela` (`mv_session.ahk:546`). Duas
  exceções: popup do MV aberto (não fechar — o operador precisa ler a mensagem) e
  `imprimir_salvar_envio = Não` no protocolar (deixar o MOV DOC aberto para conferência).
- **Recuperação no meio do fluxo não fecha o MV.** No `protocolar`, `PR_FecharPendencias()` limpa
  telas auxiliares; `PR_RecuperarTelas(cfg)` fecha o MV e só pode ser chamada no fim. Fechar o MV no
  meio quebra a execução.
- **`{Down 121}` em `protocolar.ahk:94` (`PR_RELATORIO_DOWN_N`) é posicional** e nunca foi
  validado: depende da ordenação do relatório na estação do hospital. Se mudar lá, o fluxo gera a
  planilha errada sem erro visível.
- **`Array.Has()` no AHK v2 é por ÍNDICE, e `Array.Contains` não existe** (medido no
  AutoHotkey64 v2.0.26: `["Wait"].Has("Wait")` devolve `0`, e `Contains` lança *"has no method
  named Contains"*). Usar `Has` para testar **valor** em lista devolve sempre falso — sem erro.
  Foi exatamente o que deixou o gate de cursor de `tests\teste_espera_cursor.ahk` responder
  "pronto" para sempre. Busca por valor em lista é `TESTE_Contem` (`tests\lib\teste_lib.ahk`),
  em laço explícito.
- **`MouseGetCursor()` não existe no AHK v2.** A API é a variável embutida **`A_Cursor`**
  (`AppStarting`, `Arrow`, `Cross`, `Help`, `IBeam`, `Icon`, `No`, `Size*`, `UpArrow`, `Wait`,
  `Unknown` — cursor de mão é `Unknown`). Confirmado pelo índice de funções do v2 e pela tabela de
  strings UTF-16 do binário instalado (0 ocorrências de `MouseGetCursor`, 1 de `MouseGetPos`).
  A única função de mouse do v2 é a de **posição**. Isso já está automatizado em
  `TESTE_GuardPadroesProibidos`.
- **Prazo de espera nunca por soma com `A_TickCount`.** `A_TickCount` zera depois de ~49,7 dias;
  uma estação que não reinicia chega lá e `"A_TickCount + timeout"` vira prazo negativo, ou seja,
  espera de **zero** — sem erro visível. Use sempre decorrido: `(A_TickCount - startedAt) >= t`.
  Coberto por guard e por teste unitário.
- **`global X := ""` no topo do script NÃO é a mesma variável que `global X` dentro de função.**
  Medido: o setter escrevia e a leitura dentro da função voltava vazia. No topo, atribuição simples
  (`X := ""`) cria a global de verdade. E **função `=>` (arrow) tem escopo local e não enxerga
  global** — para tocar em global, use função normal com `global`.
- **Um script AHK que "trava" sem saída quase sempre é o diálogo de erro, não laço infinito.**
  Rodar por duplo clique e esperar não dá diagnóstico nenhum. Dois caminhos que funcionam:
  `AutoHotkey64.exe /ErrorStdOut=UTF-8 <script>` para erro de carga, e ler o `RICHEDIT50W1` da
  janela `#32770` cujo título é o nome do script para erro de runtime. `Start-Process ... -Wait`
  em script GUI não retorna exit code: use `.WaitForExit(ms)`.
- **`#Include *i build\generated\*.ahk` é opcional e case-insensitive.** Em dev o app funciona sem
  esses arquivos. São gerados e apagados a cada build (`build/generated/` é gitignored). Não edite
  à mão e não comite.
- **`lib/FFCV_ErrorReferences.json` é gerado, mas o path default do gerador está errado.**
  `tools/build-ocr-error-references.ps1` escreve em `test_macros\ocr_error_references.json`
  (diretório que não existe no repo). Para atualizar o arquivo realmente consumido, passe
  `-OutputPath .\lib\FFCV_ErrorReferences.json`. O script marca `ok:false` quando o crop em
  `images\*.png` não existe.
- **`lib/FFCV_ErrorReferences.json` não tem referência para "remessa já fechada".** Por isso
  `fechar_xml.ahk` trata qualquer modal não reconhecido nesse ponto como pendência e segue — mais
  permissivo que o ideal. Adicionar a referência canônica é o que fecha a lacuna.
- **`images/` e `test_macros/` são citados em comentários e no README mas não existem** neste
  checkout. `Fluxos/` existe localmente (screenshots, CSVs, `OLD.ahk`, `Teste_corrigido.ahk`) e é
  ignorado pelo Git — material de referência, **não código**. Não copie `.ahk` de lá para o repo.
- **`.agents/` é gitignored** (`.gitignore:16`): é memória local de agente, não do repo. Nada
  versionado pode apontar para caminho dentro de `.agents/` — o ponteiro fica pendurado em qualquer
  clone novo. Se precisar que uma regra sobreviva, ela vai neste arquivo ou em `docs/`.
- **`config.ini` é gitignored e ausente:** o app cai no default `%USERPROFILE%\Documents\Praxis`
  (`main.ahk:107`). XMLs de remessa vão para `<WorkDir>\XML\`.
- **O app não abre nem autentica MOV DOC/FFCV.** `MV_EnsureMovDoc`/`MV_EnsureFFCV` só abortam
  pedindo abertura manual. O botão Parar só limpa `gRunning` (`main.ahk:303`) — **não cancela** um
  fluxo já rodando no MV.
- **O staging de distribuição não pode conter `.ahk`, `.ps1`, `.iss`, `.html` nem `.json`;** o build
  falha se vazar. `config.ini`, logs, XMLs e `.pfx` também não entram no pacote.

---

# Regras de automação (MV2000i / Oracle Forms 6i)

- **Teclado primeiro.** `Send`/`SendText` e atalhos (F6/F7/F8/F10, Alt+mnemonic) são o caminho
  validado. `ControlClick` só com ClassNN + ponto Client.
- **`EditN` não é contrato:** o Forms renumera conforme o estado da tela. Localize por ClassNN +
  ponto Client (`MV_FindControlByClientPoint`), ou por prefixo de classe (`ui60Drawn`).
- **Coordenada é sempre Client**, veio de Window Spy/captura. Nunca introduza coordenada de tela.
- **Leia campo de grid por `Home`+`Shift+End`+`Ctrl+C`**, com validação semântica
  (`RP_GridValueValid`), não por `ControlGetText`.
- **Use `MV_Poll`/`MV_WaitOracleSettled` em vez de `Sleep` fixo** ao esperar janela, modal ou cursor
  estabilizar.
- **Modais do Oracle Forms não expõem a mensagem** por `WinGetText`/Window Spy. A leitura de erro
  passa por OCR: `FFCV_ResolveOcrRegion` + `FFCV_RunOcrProbe` (`lib/FFCV_ErrorTemplates.ahk`) contra
  os textos canônicos de `lib/FFCV_ErrorReferences.json`. Não porte servidor OCR próprio.
- **Popups "Informações da Conta" e afins não têm título próprio:** são detectados pelo sentinela
  `ui60Drawn W323` dentro da janela FFCV (`remessa_protocolo.ahk:95`).
- **`WinClose` é proibido no `ifrun60.EXE`** (o Oracle Forms perde estado da aplicação) — mas é
  **permitido** no `RWRBE60.EXE` ("Operação de Fundo dos Relatórios"), onde é a forma correta de
  limpar os relatórios pendentes (`protocolar.ahk:1033`, `PR_FecharRelatoriosDeFundo`).
- **Fluxo é autônomo:** sem `Gui`, `MsgBox`, `ToolTip` ou hotkey. Saída só por `Notify()`,
  `Progress()`, `Done()` e o abort do módulo.
- **Toda constante nova registra a origem** (regra 9): linha `; Spy em ...` acima do bloco.

Atalhos de menu já confirmados contra o MV2000i — não rederive, não troque por mnemônico parecido:

| Atalho | Abre | Onde está no código |
|---|---|---|
| `{Alt down}mpb{Alt up}` | MOV DOC → Protocolação de Baixa | `remessa_protocolo.ahk:338`, `protocolar.ahk:876` |
| `{Alt down}lm{Alt up}{Enter}` | FFCV → Manutenção de Remessa | `remessa_protocolo.ahk:719` (só este fluxo usa; o `fechar_xml.ahk` removeu o hop) |
| `MV_TISS_ATALHO` = `{Alt down}lmm{Enter}{Alt up}` | FFCV → Monitoração de Faturamento TISS | `scripts/mv_session.ahk:67` |
| `{Alt down}l{e}{Alt up}` | FFCV → Entrega de Remessas | `MV_ENTREGA_REMESSAS_ALTALHO`, `mv_session.ahk:72`. **Alt fica pressionado durante o `e`**: soltar entre as teclas faz o mnemônico não casar e a tela não abre, sem erro visível |

## Commits

Conventional Commits em pt-BR, sem scope, linha única: `feat: ponto de mvp`, `fix: ...`.
Branch principal: `main`.
