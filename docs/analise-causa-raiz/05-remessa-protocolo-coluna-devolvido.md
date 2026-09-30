# Remessa por Protocolo — ler a coluna "Devolvido" e não enviar a conta

> TO-DO de origem: `Praxis_TO-DO/Remessa_Protocolo/TO-DO.txt:1`
> *"Vamos adicionar uma nova verificação para a etapa no MOV DOC ( Movimentação
> de Documentos): Durante a etapa de copiar o número das contas e o número do
> convênio deverá fazer uma verificação para ver se alguma das contas está
> "Devolvida" utilizando as imagens na sub-pasta (images/1), e se tiver
> marcada como "Devolvida" o macro deve pular aquela conta/linha."*

**Natureza:** feature. **Status:** implementada. **Correção do operador:** a
conta devolvida é um **AVISO**, não um erro — não impede a execução.

---

## 1. Decisões do operador

Três pontos foram definidos pelo operador e mudam a implementação:

1. **O `ClassNN` do checkbox é fixo por linha.** Não é renumerado; o Forms
   numera de baixo para cima uma única vez. O mapa está na seção 2.
2. **A verificação acontece ANTES de copiar as linhas.** Ler os 4 checkboxes
   primeiro, e só depois copiar conta/convênio das linhas que não são devolvidas.
3. **É aviso, não erro.** A conta devolvida é registrada e exibida no fim da
   execução, em **amarelo**, e não interrompe nada.

O ponto 2 não é estilo: é o que impede a linha 1 de escapar. Ver seção 4.

## 2. O mapa linha → ClassNN

Medido pelo Window Spy do operador, uma captura por linha, todas com
`client x 679`, `w 19`, `h 23`:

| Linha | `MOVDOC_GRID_ROWS_Y` | Y medido | ClassNN |
|---|---|---|---|
| 1ª | 222 | 224 | `Button5` |
| 2ª | 245 | 247 | `Button4` |
| 3ª | 268 | 270 | `Button3` |
| 4ª | 291 | 293 | `Button2` |

```ahk
MOVDOC_CHECK_DEVOLVIDO_CLASSES := ["Button5", "Button4", "Button3", "Button2"]
MOVDOC_CHECK_DEVOLVIDO_X := 679
MOVDOC_CHECK_DEVOLVIDO_TOL := 12
```

O Y medido é sempre `MOVDOC_GRID_ROWS_Y + 2`, porque o Spy reporta o topo do
controle e a constante é o topo da linha. A diferença de 2 px fica dentro da
tolerância de 12.

**Por que a tolerância é 12 e não o default 35.** A coluna "Recebido" fica em
x 718, a 39 px. Com 35, `MV_FindControlByClientPoint` poderia aceitar o
checkbox da coluna vizinha — e devolver o estado da coluna errada, que é falha
silenciosa com consequência errada.

**O mapa é do operador e vale mais que dedução.** Uma versão anterior deste
documento propôs prefixo de classe + geometria, partindo da premissa de que o
`ClassNN` variava com a rolagem. Não varia. A premissa estava errada e a
implementação também.

## 3. A leitura

`RP_CheckGridDevolvido(indiceLinha)` (`scripts/remessa_protocolo.ahk`)

```ahk
hwnd := MV_FindControlByClientPoint(
    WIN_MOVDOC_BAIXA,
    MOVDOC_CHECK_DEVOLVIDO_CLASSES[indiceLinha],
    MOVDOC_CHECK_DEVOLVIDO_X,
    MOVDOC_GRID_ROWS_Y[indiceLinha],
    MOVDOC_CHECK_DEVOLVIDO_TOL)
if !hwnd
    return ""
try return ControlGetChecked(hwnd)
catch
    return ""
```

Busca por **igualdade exata** de `ClassNN` — `MV_FindControlByClientPoint` já
existia no contrato compartilhado e compara com `if (ctrlClass != classNN)`.
A coordenada serve só para confirmar que o controle é o da linha certa.

`ControlGetChecked` funciona em checkbox do Oracle Forms: é o mesmo mecanismo
do checkbox "Recebido" (`MOVDOC_CHECK_RECEBIDO_CLASS`, lido por
`MV_ControlCheckedAt`), e `remessa_protocolo.ahk` rodou contra o MV2000i.
Isso dispensa leitura por pixel e OCR — o tick é desenhado pelo Forms, mas o
estado do controle é exposto.

### 3.1 Três estados, e o ilegível não é devolvida

| Retorno | Significado | O que o fluxo faz |
|---|---|---|
| `1` | devolvida | não envia; registra **aviso** |
| `0` | não devolvida | segue normal |
| `""` | não encontrou / não leu | segue como **não** devolvida + aviso no log |

O `""` ser tratado como "não devolvida" é deliberado e o motivo é o custo do
erro em cada direção. Tratar como devolvida **descartaria uma conta válida** —
o operador perderia faturamento sem o sistema avisar. Tratar como não devolvida
deixa passar um caso, e ele aparece no log. O erro caro é o do lado que descarta
dinheiro sem sinal.

## 4. Por que ler os 4 antes de copiar

A grid entra no fluxo por **dois** caminhos, e a linha 1 é um deles.

**A semente.** Depois do F8, `RP_WaitMovDocFirstGridLineReady` espera a
primeira linha ficar legível e monta o Map dela. Esse Map é empurrado em
`RP_ColetarLinhasMovDoc`, **fora** do laço que lê as 4 linhas visíveis. Um
`if` de Devolvido colocado só dentro desse laço **não alcança** a linha 1: ela
já entrou em `linhas` antes.

**O laço.** `RP_ColetarLinhasVisiveisMovDoc` lê as 4 linhas visíveis, pagina,
e repete até 100 vezes.

Ler os 4 checkboxes no topo de `RP_ColetarLinhasMovDoc` **e** no topo de
`RP_ColetarLinhasVisiveisMovDoc` cobre os dois caminhos, e satisfaz a ordem
exigida: nenhuma conta é copiada antes de os 4 estados serem conhecidos.

A chave de dedupe `vistos` usa `protocolo "|" conta "|" convenio` e é montada em
dois lugares (a semente e o laço). Os dois precisam continuar iguais.

## 5. Onde a conta devolvida é registrada

Num array `avisos`, **separado** de `erros`.

`erros` são pendências de convênio/setor — a remessa ficou incompleta e o
operador precisa intervir. `avisos` são decisões do MV: o documento foi
devolvido, e não houve erro. Misturar os dois faz o operador não saber se
precisa agir.

No relatório final as seções são separadas e coloridas:

```
AVISOS (2) — contas devolvidas, não enviadas à remessa
PROTOCOLO | CONTA | AVISO
  [[aviso]]3331330 | 15276563 | não enviada à remessa: documento marcado como devolvido no MOV DOC[[/aviso]]
```

A tag `[[aviso]]` é convertida em `ui/index.html:414` para
`<span class="laviso">`, com a cor em `ui/index.html:157`. Não é a mesma tag
`[[red]]` das pendências.

**DevSim não precisa ser alterado.** O `AGENTS.md` alerta que `gScripts` e
`devSim()` duplicam a lista de scripts, e é verdade — mas `appendLog` e as tags
existem em um lugar só. A duplicação não é tocada.

## 6. Validação

### 6.1 Sem o MV2000i — possível

- **Build + `--integrity-check`**, gate do `AGENTS.md`:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller
  $p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" `
       -ArgumentList '--integrity-check' -Wait -PassThru; $p.ExitCode
  ```

- **O mapa das 4 linhas** é dado do operador, confirmado por Window Spy. Não há
  o que validar em código sem o MV.

### 6.2 Exige o MV2000i real — obrigatório

1. Protocolo com **nenhuma** devolvida: nada muda, todas as contas seguem.
2. Protocolo com **uma** devolvida na 3ª linha (é o caso das capturas): a conta
   não aparece no FFCV e a linha aparece em AVISOS, em amarelo.
3. Protocolo com a devolvida na **1ª linha**: é o caso que a linha-semente
   esconderia. Precisa aparecer em AVISOS.
4. As quatro linhas: cada `ClassNN` da seção 2 tem de ler a linha certa. Uma
   leitura trocada entre linhas 3 e 4 passa nos testes 1 e 2 e falha aqui.
5. Rolagem: a conta devolvida não pode reaparecer como duplicata quando a grade
   avança (`RP_AvancarGridMovDocQuatroLinhas`).
6. Todas devolvidas: o fluxo aborta com a mensagem que lista os avisos, e não com
   "Convênio não identificado" genérico.

## 7. PENDENTE

- **A largura real da banda em outras resoluções e escalas de DPI.** X = 679 e a
  tolerância de 12 vêm das capturas em uma máquina. O `MOVDOC_CHECK_DEVOLVIDO_TOL`
  é o ajuste mais provável de ser necessário em outra estação.
- **A leitura é estável depois do clique na conta.** O Devolvido é lido antes de
  qualquer clique na conta, o que é a ordem correta por construção — mas se o
  Forms só atualizar o checkbox após o foco passar pela linha, a leitura vem
  adiantada. Observar na primeira execução.
- **O que fazer quando a conta devolvida também é a única do convênio.** Hoje o
  fluxo aborta. É o comportamento correto, mas vale confirmar com o operador.
