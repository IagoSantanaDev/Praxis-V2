# Remessa por Protocolo — ler "Devolvido" e "Recebido" por linha

> TO-DO de origem: `Praxis_TO-DO/Remessa_Protocolo/TO-DO.txt:1`
> *"Vamos adicionar uma nova verificação para a etapa no MOV DOC ( Movimentação
> de Documentos): Durante a etapa de copiar o número das contas e o número do
> convênio deverá fazer uma verificação para ver se alguma das contas está
> "Devolvida" utilizando as imagens na sub-pasta (images/1), e se tiver
> marcada como "Devolvida" o macro deve pular aquela conta/linha."*

**Natureza:** feature. **Status:** implementada; a validação comportamental
depende de execução no MV2000i real.

---

## 1. Decisões do operador

As regras definidas pelo operador:

1. **O `ClassNN` do checkbox é fixo por linha.** Não é renumerado; o Forms
   numera de baixo para cima uma única vez. Os mapas estão na seção 2.
2. Em cada página, ler primeiro os quatro estados **Devolvido**. Só depois ler
   **Recebido** nas linhas não devolvidas. O controle Recebido de uma linha
   devolvida nunca é consultado nem clicado.
3. Uma linha devolvida não vai ao FFCV; as demais continuam no fluxo, inclusive
   as que já estavam recebidas.
4. Se uma leitura de estado não for `0` ou `1`, interromper o lote sem salvar o
   protocolo atual. Não assumir um estado seguro.
5. Marcar como recebidas somente as linhas não devolvidas e ainda não recebidas.
   O protocolo continua sendo salvo uma única vez com `F10`, depois da coleta.
6. Contas devolvidas seguem como avisos, não como erro. Contas já recebidas são
   registradas somente no log operacional.

Ler os estados antes de copiar a grid impede que a linha-semente escape das
verificações. Ver seção 4.

## 2. O mapa linha → ClassNN

O mapa foi confirmado pelo Window Spy do operador, com uma captura por linha.
O fluxo usa o `ClassNN` exato da janela do MOV DOC; não usa coordenadas para
localizar esses checkboxes.

| Linha | ClassNN |
|---|---|
| 1ª | `Button5` |
| 2ª | `Button4` |
| 3ª | `Button3` |
| 4ª | `Button2` |

```ahk
MOVDOC_CHECK_DEVOLVIDO_CLASSES := ["Button5", "Button4", "Button3", "Button2"]
```

**O mapa é do operador e vale mais que dedução.** Uma versão anterior deste
documento propôs prefixo de classe + geometria, partindo da premissa de que o
`ClassNN` variava com a rolagem. Não varia. A premissa estava errada e a
implementação também.

O mapa de **Recebido**, confirmado pelo operador no Window Spy:

| Linha | ClassNN |
|---|---|
| 1ª | `Button9` |
| 2ª | `Button8` |
| 3ª | `Button7` |
| 4ª | `Button6` |

```ahk
MOVDOC_CHECK_RECEBIDO_CLASSES := ["Button9", "Button8", "Button7", "Button6"]
```

O clique de Recebido usa `MV_ClickFirstControl` com o `ClassNN` exato. É a
exceção solicitada pelo operador ao padrão de clique com ponto Client; não se
usa fallback para coordenada.

## 3. A leitura

`RP_CheckGridDevolvido(indiceLinha)` (`scripts/remessa_protocolo.ahk`)

```ahk
classNN := MOVDOC_CHECK_DEVOLVIDO_CLASSES[indiceLinha]
try hwnds := WinGetControlsHwnd(WIN_MOVDOC_BAIXA)
catch
    return ""

for hwnd in hwnds {
   try ctrlClass := ControlGetClassNN(hwnd)
   catch
      continue
   if (ctrlClass != classNN)
      continue
   try return ControlGetChecked(hwnd)
   catch
      return ""
}
return ""
```

`RP_CheckGridDevolvido` enumera os controles de `WIN_MOVDOC_BAIXA` e compara o
`ClassNN` por igualdade exata antes de ler o estado. Não depende de coordenada,
posição, tolerância ou prefixo de classe.

`ControlGetChecked` é usado para ler os dois estados. Isso dispensa leitura por
pixel e OCR — o tick é desenhado pelo Forms, mas o estado do controle é exposto.

### 3.1 Estados e falhas de leitura

| Retorno | Significado | O que o fluxo faz |
|---|---|---|
| `1` em Devolvido | linha devolvida | não lê Recebido, não clica e não envia ao FFCV; registra aviso |
| `0` em Devolvido | linha não devolvida | lê o estado Recebido |
| `1` em Recebido | já recebida | não clica; segue ao FFCV e registra no log |
| `0` em Recebido | ainda não recebida | clica no controle correspondente; segue ao FFCV |
| `""` ou outro estado | não encontrou / não leu | interrompe o lote sem enviar `F10` para o protocolo atual |

Contas já recebidas continuam sendo enviadas ao FFCV; esse estado só evita um
segundo clique. A falha de leitura é fatal porque prosseguir poderia marcar ou
enviar uma linha com estado desconhecido.

## 4. Leitura e processamento da página

Depois do F8, `RP_WaitMovDocFirstGridLineReady` lê os quatro estados Devolvido
antes de ler conta e convênio da primeira linha. Quando a linha está legível,
lê Recebido somente nas linhas não devolvidas. Os estados iniciais e a linha
semente são passados a `RP_ColetarLinhasMovDoc`.

Em cada página, `RP_ColetarLinhasVisiveisMovDoc` repete a sequência: lê
Devolvido para todas as quatro linhas; valida esses estados; lê Recebido apenas
para as não devolvidas; lê conta/convênio; então clica somente o Recebido que
estava desmarcado. Uma falha de leitura retorna ao chamador e interrompe o lote
antes do `F10`.

Após cada rolagem, os estados são lidos novamente. Contas já recebidas são
identificadas no log depois da leitura da conta. Linhas recebidas e não
devolvidas permanecem na lista que alimenta o FFCV. A chave de dedupe `vistos`
usa `protocolo "|" conta "|" convenio` e impede cliques repetidos nas linhas
que reapareçam durante a paginação.

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

1. Protocolo sem devolvidas e com todas já recebidas: nenhum clique, todas as
   contas seguem ao FFCV.
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
7. Recebida já marcada: não clicar, registrar no log e continuar incluindo a
   conta no FFCV.
8. Recebida desmarcada: clicar somente no botão mapeado à linha.
9. Devolvida: não ler nem clicar Recebido nessa linha; a conta não segue ao
   FFCV.
10. Leitura ilegível de Devolvido ou Recebido: interromper o lote sem executar
    `F10` para o protocolo atual.
11. Confirmar um único `F10` por protocolo, mesmo que várias linhas sejam
    marcadas individualmente.

## 7. PENDENTE

- Executar os casos da seção 6.2 no MV2000i real, principalmente a correlação
  entre linha visível e `Button9`…`Button6`, a paginação e a persistência após
  `F10`. Build e integrity-check não provam o comportamento do Oracle Forms.
