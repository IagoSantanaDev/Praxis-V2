# Fechar&XML — o módulo não segue o fluxo validado

> TO-DO de origem: `Praxis_TO-DO/Fechar&XML/TO-DO.txt:1`
> *"Percebo que o Fechar&XML do Praxis não utiliza o fluxo correto do
> Fechar&XML.ahk, todo seu fluxo foi validado"*

**Natureza:** bug. **Causa raiz:** 7 divergências independentes.
**Direção:** alinhar `scripts/fechar_xml.ahk` ao fluxo validado.
**Prioridade:** 4ª da lista — ver [README](README.md#ordem-de-ataque-sugerida).

---

## 1. Quem manda

`Praxis_TO-DO/Fechar&XML/Fechar&XML.ahk` é a **referência validada** e a
**fonte da verdade** deste módulo. Foi testado contra o MV2000i pelo operador.

Duas consequências, e as duas valem para todo o resto deste documento:

- **O arquivo de referência não é editado.** Ele é consultado; o que muda é
  `scripts/fechar_xml.ahk`. Se a referência precisar mudar, isso é outro
  trabalho, com validação própria.
- **A direção do alinhamento é sempre referência → Praxis.** Onde o Praxis
  diverge, a divergência é o defeito. Não o contrário.

Isto vale porque o TO-DO está certo e a constatação é verificável: são 594
linhas de fluxo validado contra 646 de reimplementação, e elas resolvem a
mesma tela de sete maneiras diferentes.

Uma ressalva sobre o peso da evidência: **as capturas em
`Praxis_TO-DO/Fechar&XML/images/` são do caminho de erro** ("Log do Evento",
XML inválido) e, por decisão do operador, **estão fora de escopo por agora**
(seção 6). Nenhuma conclusão deste documento depende delas.

## 2. As sete divergências

| # | Etapa | Referência validada (`Fechar&XML.ahk`) | Praxis (`fechar_xml.ahk`) | Alinhamento |
|---|---|---|---|---|
| 1 | Ordem das fases | fecha **todas** as remessas, depois gera XML (`:121-126`) | ~~intercala: fecha a *n*, gera o XML dela~~ — **corrigido**, agora em dois laços | **feito** |
| 2 | Navegação | menu → `Alt+L+E` direto (`:140`) | menu → `Alt+L+M{Enter}` (`:168`) → clique `Button6` (`:181`) | **conflito — ver 2.1** |
| 3 | Preenchimento | clipboard: `^a` `^v`, `Tab`, `^v`, `Tab`, `^v` (`:154-159`, `:430-446`) | clique, `+{Tab}`, `Tab`, `SendText`, **`{Enter}`**, `SendText` (`:203-228`) | adotar teclado + clipboard, remover o `{Enter}` |
| 4 | Modal de confirmação | clica **`Button1`** (OK) em "Sistema de Faturamento de Contas de Convênio"; erro se o texto contiver "Erro"/"Log de Erro" (`:260-279`) | clica **`Button2` (Não)** esperando Sim/Não (`:304-315`) | adotar a referência — **depois** do doc 03 |
| 5 | Relatório de entrega | imprime antes e depois de cada remessa (`Button9` + relatório + `Andamento do Relatório` + `RWRBE60.EXE`, `:220-234`) | removido de propósito (`:161-162`) | reintroduzir |
| 6 | Fase XML | `{Tab 5}` + `SendInput` + caminho por teclado (`:328`, `:396-399`) | cliques por coordenada (`:373`, `:393`) | adotar teclado |
| 7 | Confirmação do salvamento | exige que o popup "Mensagem ao Usuário do MV 2000" **tenha aparecido**; senão lança erro (`:405-422`) | aceita "nenhum popup apareceu" como sucesso (`:489-515`) | adotar a exigência de prova |

### 2.1 D2 e D5: a referência já responde

Os dois pontos que eu havia deixado em PENDENTE estão respondidos no arquivo
de referência. Não é preciso observação no MV para decidir nenhum dos dois.

**D2 — navegação.** A referência abre a Entrega de Remessas direto do menu
principal do FFCV, com `Alt+L+E`, e **repete o mesmo atalho para cada
remessa** seguinte:

`Fechar&XML.ahk:140` e `:175`

```ahk
Send("{Alt down}l{e}{Alt up}")
entrega := WaitWindowReady(gJanelaEntrega, ["Edit1", "Button10"], 20)
```

Não há passagem por Manutenção de Remessa em nenhum ponto de
`ProcessDelivery`. **Alinhar significa remover o hop** — `FX_AbrirManutencaoRemessa`
(`:160-174`) e o clique em `FX_BTN_ABRIR_DATAS` (`FX_AbrirTelaEntrega`, `:176-189`)
saem, e a navegação passa a ser o atalho mais uma espera de prontidão.

Sobre o conflito que eu havia registrado: ele não se sustenta. `remessa_protocolo.ahk`
usa `Alt+L+M{Enter}` + `Button6` porque é **outro módulo, com outra tela de
entrada** — ele precisa preparar setores e convênio antes. O Fechar&XML não
precisa disso, e a referência deste módulo vai direto. Os dois podem estar
corretos porque **são telas diferentes**. O conflito era aparente, criado por
eu ter comparado um caminho de entrada com um caminho de chegada.

### 2.2 D5 — a objeção que motivou a divergência já está resolvida na referência

Isto é o achado mais útil de ler o arquivo com atenção.

`scripts/fechar_xml.ahk:215-219` justifica o tratamento do relatório assim:

```ahk
; O relatório de atendimentos (Button9) é impresso ANTES, e só se o botão
; existir. O validado faz exatamente esta checagem (`:136-139`): o botão
; não está em todas as telas, e a navegação para entrega não pode depender
; dele. Era a objeção que motivou a remoção do relatório no spec 03, e ela
; já está resolvida na referência.
```

> Texto atual. Na época desta análise o relatório estava removido; o
> alinhamento posterior do commit `0892358` reintroduziu a impressão com a
> checagem de prontidão do botão.

O receio é real. E a referência **reconheceu exatamente o mesmo receio e o
resolveu**:

`Fechar&XML.ahk:136-139`

```ahk
; O botão de relatório só existe em algumas telas do MV. A navegação
; para entrega não pode depender dele.
if AreControlsReady(mv, ["Button9"])
    PrintDeliveryReport(mv, "Impressão inicial em andamento...")
Send("{Alt down}l{e}{Alt up}")
```

E, para cada remessa, `WaitAndPrintDeliveryReport` (`:166`, implementado em
`:229-234`) imprime depois da confirmação.

Ou seja: **não é "o relatório some" ou "não é seguro"** — é uma verificação de
prontidão do controle, com fallback silencioso quando o botão não existe. A
postura defensiva que faltava no Praxis está pronta para copiar.

### 2.3 A divergência 4 depende do doc 03, e não pode ser alinhada antes

A ordem aqui não é preferência metodológica, é mecânica.

O [doc 03](03-fechar-xml-data-formato-americano.md) estabelece que **o MV2000i
recusa `YYYY-MM-DD`** e que o módulo hoje envia exatamente isso. A recusa abre
um diálogo, e **não se sabe qual** — seção 1.2 do doc 03.

Enquanto a data estiver errada, a tela que aparece depois do `Button10` **não é
nem** a janela de sucesso com `Button1` que a referência espera, **nem** o
Sim/Não que o Praxis espera. Alinhar a divergência 4 antes de corrigir a data
seria alinhar contra um diálogo que ainda vai mudar.

Por isso a sequência é: **doc 03 primeiro**, depois observar qual diálogo
aparece, e só então alinhar. É plausível que a observação dispense a decisão.

**O que a referência manda, para quando a observação vier:** `Button1` (OK) na
janela de sucesso, e erro se o texto contiver "Erro" ou "Log de Erro"
(`:260-279`). O alvo do alinhamento não está em dúvida — só o momento de
aplicá-lo.

### 2.4 A divergência 1 foi corrigida — e o detalhe que importava

**Corrigido em dois laços** (`scripts/fechar_xml.ahk`): primeiro fecha todas as
remessas, depois gera o XML das que efetivamente fecharam. `FX_ProcessarRemessa`
foi dividida em `FX_FecharRemessa` (só o fechamento) e `FX_GerarXml` (só o XML).

O detalhe que a divisão expôs vale mais que a reordenação em si: **um `fatal`
no meio do laço de fechamento não pode abortar o módulo.** As remessas já
fechadas estão fechadas no MV, e sem XML elas entram num estado de mão única —
numa segunda tentativa o MV recusa fechar de novo, a remessa nunca mais entra
na lista das fechadas, e o XML nunca é gerado. Por isso o `fatal` vira
**pendência** e o laço apenas `break`, deixando a fase 2 rodar.

**Uma divergência do alinhamento, e ela é real:** a referência **não** filtra
quais remessas recebem XML — `ProcessXml(remessas)` recebe o array inteiro e o
percorre sem filtro (`:325`). O Praxis só gera XML das que fecharam, o que é
melhor que a referência — e é exatamente a razão de o `fatal` não poder
abortar.

## 3. Por que as divergências existem

`scripts/fechar_xml.ahk:16-18` declara:

```ahk
; Spec previsto: .agents\workflows\03-fechar-xml.md — NÃO EXISTE no repositório
```

Esse caminho está no `.gitignore` (`.gitignore:16`, `.agents/`) e **não existe
neste checkout** — o único arquivo sob `.agents/` é `LEARNINGS.md`, local.

Duas divergências têm justificativa escrita no código, e ambas apontam para o
mesmo lugar:

`scripts/fechar_xml.ahk:215-219`

```ahk
; O relatório de atendimentos (Button9) é impresso ANTES, e só se o botão
; existir. O validado faz exatamente esta checagem (`:136-139`): o botão
; não está em todas as telas, e a navegação para entrega não pode depender
; dele. Era a objeção que motivou a remoção do relatório no spec 03, e ela
; já está resolvida na referência.
```

`scripts/fechar_xml.ahk:16-18`

```ahk
; As 7 divergências contra o fluxo validado foram deliberadas contra esse spec,
; e a direção definida foi alinhar ao validado.
```

As divergências foram deliberadas, contra um spec que não está versionado. Isso
não torna o spec errado — torna **impossível revisar a decisão**. Na prática,
as sete divergências são indistinguíveis de erro até alguém ler o spec que as
originou, e ninguém pode.

Isto é o mecanismo geral do
[doc 06](06-sistematico-origem-das-constantes.md), e aqui tem o efeito mais
grave do projeto: as duas fases mais críticas do módulo financeiro foram
especificadas contra um documento que não sobrevive a um clone.

**A direção já está definida** — seguir a referência validada, seção 1. O spec
importa menos agora, porque ele só explicaria *por que* o Praxis divergiu, e a
resposta passa a ser "não precisa mais ser seguido". Ele continua valendo
para as justificativas que o alinhamento vai exigir, especialmente a da
divergência 5 (relatório de entrega), que é a mais difícil de argumentar sem o
documento original.

## 4. Divergência a não tratar como parte do alinhamento

A fase 1 de `FX_RecuperarTelas` desliga a tela de XML com `Send
MV_SAIR_TELA_ATALHO` (`:597-601`, `:414`) e a entrega com o mesmo atalho
(`:603-614`). A referência usa `CloseDeliveryIfOpen` (`:188-218`) e `Send("^q")`.

**Não faz parte do alinhamento.** `^q` puro foi confirmado pelo operador como
correto para todas as telas, e está registrado na seção "Falha silenciosa" da
`AGENTS.md`. O que está errado no `MV_FecharUltimaTela` é a *verificação*, não
o atalho — ver [doc 04](04-remessa-protocolo-ctrl-q-nao-sai.md).

A divergência aqui é de **helper de espera**, não de tecla: `CloseDeliveryIfOpen`
verifica que a tela saiu e lança erro se não saiu, enquanto
`MV_FecharUltimaTela` não verifica nada. Esse é o mesmo defeito do doc 04, e
corrigir por lá resolve as duaspontas de uma vez.

## 5. Correção proposta

Uma divergência por ciclo de validação, na ordem abaixo. O critério de
"pronto" é sempre o mesmo: rodar contra o MV2000i e o comportamento ser o da
referência.

### 5.1 Sequência

| Ordem | Item | Depende de |
|---|---|---|
| 1 | **doc 03** — corrigir o formato da data | nada |
| 2 | observar qual diálogo aparece após `Button10` | doc 03 corrigido |
| 3 | **D3** — preenchimento por teclado, remover o `{Enter}` | doc 03 |
| 4 | **D7** — exigir prova da confirmação do salvamento | nada |
| 5 | **D6** — fase XML por teclado | D7 |
| 6 | **D4** — modal de confirmação | observação do passo 2 |
| 7 | **D1** — ordem das fases | D3, D4, D6 |
| 8 | **D5** — relatório de entrega, com verificação de prontidão | D2 |
| 9 | **D2** — navegação por `Alt+L+E` | nada — pode ser feito antes |

D3 e D7 vêm antes de D4 e D1 porque são as de menor risco e maior valor
próprio: D3 remove um `{Enter}` que a referência não tem, e D7 troca um falso
positivo por uma verificação real. As duas podem ser validadas sem esperar
nada dos outros módulos.

D2 passou para o fim da tabela por depender de D5, mas o item em si não
depende de nada e pode ser feito em qualquer momento.

### 5.2 Notas por item

**D3 — preenchimento** (`scripts/fechar_xml.ahk:301-312`). **Aplicado**: a
navegação é por `Tab` + colar, como a referência, e o `Send("{Enter}")` entre os
campos de data foi removido.

```ahk
; Navegação e escrita por Tab + colar, como o fluxo validado
; (Fechar&XML.ahk:154-158). O Enter entre os campos de data foi removido:
; o validado não o usa, e no Oracle Forms ele commitava o campo e podia
; disparar a validação antes do segundo campo estar preenchido.
```

> **Conflito registrado, e a referência vence.** A referência usa `^a` nos
> **três** campos, inclusive os dois de data — `PasteFocused(remessa, true)`,
> `PasteFocused(pagamento, true)`, `PasteFocused(vencimento, true)`
> (`Fechar&XML.ahk:154-158`), e é o argumento `selectAll` que dispara o
> `SendInput("^a")` em `:440`. O comentário do Praxis em
> `scripts/fechar_xml.ahk:305` — *"Colar em vez de digitar porque o Forms trata
> digitação longa de forma inconsistente nos campos de data"* — **contradiz a
> referência validada**, e nesse caso específico a referência tem prioridade: ela rodou, o
> comentário é herança de um spec que não existe mais (seção 3).
>
> A observação original pode ter sido real, mas foi feita contra outra versão
> da tela. Vale **testar o `^a` no campo de data** como parte da validação do
> D3; se o Forms rejeitar, registrar aqui como PENDENTE de validação — não de
> projeto.

**D7 — confirmação do salvamento** (`:489-515`). `FX_TratarModaisXmlSalvo` hoje
retorna `ok` quando nenhum modal aparece. A referência exige que o popup
"Mensagem ao Usuário do MV 2000" tenha aparecido e lança erro se não
(`:405-422`). A troca é pequena e fecha um falso positivo: hoje o módulo só
descobre a problema depois, por `FileExist` (`:417-418`), quando o que está em
questão é a *confirmação*, não a existência do arquivo.

**D6 — fase XML** (`:373`, `:393`). Trocar os cliques por coordenada pela
navegação por teclado da referência: `{Tab 5}` para chegar ao campo da remessa
(`:328`) e `SendInput("{Tab}")` + colar o caminho (`:396-399`). Alinhamento
duplo: segue a referência e obedece à regra de automação da `AGENTS.md`
("teclado primeiro"), já que coordenada de Forms é a fonte da
renumeração que trava metade deste projeto.

**D5 — relatório de entrega** (`:161-162`). Reintroduzir `Button9` +
`Relatório de Atendimentos da Remessa` + `Andamento do Relatório` +
`RWRBE60.EXE` (referência `:220-234`), **com a verificação de prontidão** de
`:138`. A objeção que motivou a remoção já está resolvida na referência
(seção 2.2), então não é mais decisão do operador — é alinhamento. É o item
que mais muda o que o operador vê durante a execução, o que justifica ficar
no fim da lista.

**D1 — ordem das fases** (`:68-94`, `:126-152`). Separar `ProcessDelivery` e
`ProcessXml` como na referência (`:121-126`) e remover `FX_RecuperarTelas` do
laço. Última da lista porque é a de maior alcance e a que só faz sentido com
D3, D4 e D6 já alinhados.

Detalhe que a leitura da referência esclarece: `ProcessDelivery` **reabre a
tela de entrega para cada remessa** (`Fechar&XML.ahk:168-182`) — fecha com
`CloseDeliveryIfOpen` e reenvia `Alt+L+E`. Então a alinhamenta de D1 não
implica reutilizar uma tela só; implica só separar as **fases**, deixando o
laço de remessas dentro de `ProcessDelivery`.

**D2 — navegação** (`:160-189`). Remover o hop por Manutenção de Remessa e
passar a usar `Alt+L+E` direto, como a referência (seção 2.1). Elimina
`FX_AbrirManutencaoRemessa` e `FX_AbrirTelaEntrega` do caminho, e com elas as
constantes `FX_BTN_ABRIR_DATAS`, `FX_BTN_ABRIR_DATAS_X` e
`FX_BTN_ABRIR_DATAS_Y` (`:33-35`).

### 5.3 O que não muda

- `MV_SAIR_TELA_ATALHO` e a tecla `^q` (seção 4).
- `gWorkDir\XML` como destino do XML. A referência grava em
  `C:\Users\<user>\Documents\xml\` (`:392`); o destino do Praxis é
  configurável e melhor. Alinhar isso seria uma regressão.
- A checagem de idempotência (`:364-368`, `pulado`): a referência não tem. Com
  as fases separadas, ela volta a ter efeito limpo.

## 6. Capturas em images — fora de escopo

As duas imagens mostram a tela "Log do Evento":

```
MV2000i - Faturamento - [WIN_PRINCIPAL]
ahk_class ui60MDIroot_W32
Crítica:  XML Inválido

[ Atualizar ] [ Detalhe Técnico ] [ Visualizar XML ] [ Sair ]
```

**Decisão do operador: ignorar por agora.** Duas razões técnicas sustentam a
decisão, e é por isso que nada se perde:

1. **São do caminho de erro.** O "Log do Evento" com "XML Inválido" não é a
   tela do caminho de sucesso que o fluxo percorre.
2. **Não dão `ClassNN` de nada útil.** O Window Spy está sobre "Detalhe
   Técnico" na primeira e sobre a própria janela do Spy na segunda.

Uma observação fica registrada, sem ação e sem promessa de captura: a barra
de botões mostrada não tem "Voltar", e o contrato compartilhado declara
`MV_XML_FORM_BTN_VOLTAR := "Button7" ; Voltar`
(`scripts/mv_session.ahk:121`). Como `MV_ClickBySpec` cai em clique cego por
coordenada quando o `ClassNN` não casa (ver
[doc 06, seção 3](06-sistematico-origem-das-constantes.md#3-mv_clickbyspec-clique-cego-por-coordenada)),
uma constante errada ali vira ação errada sem erro.

**Isto não é proposta de mudança.** Com o alinhamento de D6, o uso de
`MV_ClickBySpec` na fase XML diminui, e com ele o risco. A constante só precisa
de atenção se o clique por coordenada sobreviver ao alinhamento. Fica na
seção 7 como PENDENTE de baixa prioridade.

## 7. Validação

### 7.1 Sem o MV2000i — possível

- **Build + `--integrity-check`**, gate da `AGENTS.md`:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller
  $p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" `
       -ArgumentList '--integrity-check' -Wait -PassThru; $p.ExitCode
  ```

- **Conferência de que nenhum trecho de divergência sobreviveu ao
  alinhamento.** Busca pelos padrões da referência no arquivo alinhado:
  `{Tab 5}`, `PasteFocused`, `SendInput`, `Button1` no modal de confirmação,
  `popupEncontrado`, `Andamento do Relatório`.
- **Coerência do resumo e das pendências** após a mudança de ordem das fases
  (D1) — é leitura, não execução.

### 7.2 Exige o MV2000i real — obrigatório, e é quase tudo

O build não diz nada sobre este módulo, que mexe em dado financeiro. Um ciclo
por divergência, na ordem da seção 5.1:

1. **D3 e D7** — fechar uma remessa de teste e confirmar que as datas gravadas
   no FFCV são as esperadas, e que o salvamento do XML só é declarado sucesso
   com confirmação visível.
2. **D6** — gerar o XML e confirmar o arquivo em `WorkDir\XML` e a navegação
   por teclado.
3. **D4** — observar qual diálogo aparece após `Button10` com a data já
   correta, e só então alinhar. Este passo **pode invalidar a premissa** da
   seção 2.2, e isso é o resultado esperado.
4. **D1** — só com as anteriores prontas. Testar com **mais de uma** remessa,
   porque a ordem das fases só aparece da segunda iteração em diante.
5. **D5** — confirmar que o `RWRBE60.EXE` fecha corretamente e que a
   impressão sai. `WinClose` é permitido ali e proibido no `ifrun60.EXE`.
6. **D2** — confirmar que a tela de Entrega de Remessas abre por `Alt+L+E` a
   partir do menu e que o `Button6` não é mais acionado.

## 8. PENDENTE

**Respondido pela leitura da referência — não precisa de mais nada:**

| Questão | Resposta | Onde está na referência |
|---|---|---|
| **D2** — qual navegação? | `Alt+L+E` direto, repetido por remessa | `:140`, `:175` |
| **D5** — o relatório volta, e é seguro? | Sim, com `AreControlsReady(mv, ["Button9"])` antes | `:136-139`, `:166`, `:229-234` |
| **D4** — o que clicar no modal? | `Button1` (OK) na janela de sucesso; erro se o texto tiver "Erro" | `:260-279` |
| **D6** — como fazer a fase XML? | `{Tab 5}` + `SendInput("{Tab}")` + colar o caminho | `:328`, `:396-399` |
| **D7** — o que conta como sucesso? | o popup "Mensagem ao Usuário do MV 2000" **tem** de aparecer | `:405-422` |

**Continua aberto, e nenhum destes se resolve por leitura:**

| Questão | Quem responde | Bloqueia |
|---|---|---|
| Qual diálogo aparece após `Button10`, **com a data já correta**? O alvo do alinhamento é `Button1`; falta saber se é isso que aparece | MV2000i, passo 3 | D4 |
| Existe o `spec 03` em algum lugar? Não muda a direção, mas explica as 7 divergências | operador | contexto |
| `MV_XML_FORM_BTN_VOLTAR := "Button7"` corresponde à tela real? | MV2000i, só se o clique por coordenada sobreviver a D6 | D6 |
| O `^a` funciona no campo de data do Forms? A referência usa e rodou, mas o comentário do Praxis diz que não | MV2000i, passo 1 | D3 |

A quarta linha é um PENDENTE de **validação**, não de projeto: a referência
tem prioridade, e se o Forms rejeitar o `^a` é um dado novo contra uma
referência validada, o que vale mais que o comentário.
