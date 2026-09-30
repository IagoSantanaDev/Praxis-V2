# Remessa por Protocolo — ler a coluna "Devolvido" e pular a linha

> TO-DO de origem: `Praxis_TO-DO/Remessa_Protocolo/TO-DO.txt:1`
> *"Vamos adicionar uma nova verificação para a etapa no MOV DOC ( Movimentação
> de Documentos): Durante a etapa de copiar o número das contas e o número do
> convênio deverá fazer uma verificação para ver se alguma das contas está
> "Devolvida" utilizando as imagens na sub-pasta (images/1), e se tiver
> marcada como "Devolvida" o macro deve pular aquela conta/linha."*

**Natureza:** feature. Não é bug — o código nunca tentou fazer isso, e não há
comportamento atual a corrigir.
**Prioridade:** 5ª da lista — ver [README](README.md#ordem-de-ataque-sugerida).

---

## 1. A tela

`Praxis_TO-DO/Remessa_Protocolo/images/image2.png` — Baixa de Documentos, com
o Window Spy sobre a coluna "Devolvido". A grade tem as colunas:

```
Documento | Atendimento | Conta | Remessa | Data | Hora | Convênio | Movimento | Devolvido | Recebido
```

O cabeçalho "Devolvido" tem um checkbox por linha, e o tooltip do controle
explica a semântica:

> *"Selecione se o documento será devolvido e enviado em novo protocolo.
> Marcado = Sim"*

Captura 2 da mesma tela, com uma linha marcada:

`Praxis_TO-DO/Remessa_Protocolo/images/image1.png`

Na conta `15276563` / atendimento `13249866`, a coluna "Devolvido" está
marcada com um tick, enquanto as demais linhas da mesma captura estão vazias.
Essa é a evidência do estado que precisa ser detectado.

Nota sobre a referência do TO-DO: o texto diz `images/1`, e o que existe é
`Praxis_TO-DO/Remessa_Protocolo/images/` com `image1.png` a `image4.png`.

## 2. Por que não existe código

A coleta lê duas colunas por linha, e só duas:

`scripts/remessa_protocolo.ahk:375-401`

```ahk
RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos) {
    added := 0

    for _, rowY in MOVDOC_GRID_ROWS_Y {
        conta   := RP_ReadMovDocGridField(MOVDOC_CONTA_X, rowY, "conta")
        convenio := RP_ReadMovDocGridField(MOVDOC_CONVENIO_X, rowY, "convenio")
        ...
        linhas.Push(Map("protocolo", protocolo, "conta", conta, "convenio", convenio))
```

E o leitor é incapaz de ler checkbox, por construção — não por escolha:

`scripts/remessa_protocolo.ahk:534-556` chama, e `:566-577` valida:

```ahk
RP_GridValueValid(valor, campo := "") {
    valor := Trim(valor)
    if (valor = "")
        return false
    if !RegExMatch(valor, "^\d+$")
        return false
    ...
```

O caminho é clique na célula → `Home` → `Shift+End` → `Ctrl+C`, e a validação
exige `^\d+$`. Um checkbox marcado não devolve número nenhum: devolve string
vazia, e a validação a rejeita. Não há como reutilizar este helper para a
coluna "Devolvido" — ele é feito para célula de texto, e o `AGENTS.md` já
documenta que a grid do MOV DOC não expõe texto confiável:

`scripts/remessa_protocolo.ahk:36-37`

```ahk
; A grid MOV DOC não expõe texto confiável via ControlGetText: usar clique físico,
; Home, Shift+End e Ctrl+C com validação semântica.
```

## 3. Como ler a coluna — `ControlGetChecked`, pelo precedente do "Recebido"

**Decisão do operador:** usar a mesma lógica do `Button1` do checkbox
"Recebido", que também é checkbox.

O precedente já está no arquivo, e é o que torna isto viável sem nenhum
mecanismo novo:

`scripts/remessa_protocolo.ahk:45-47`

```ahk
MOVDOC_CHECK_RECEBIDO_CLASS  := "Button1"
MOVDOC_CHECK_RECEBIDO_X      := 718
MOVDOC_CHECK_RECEBIDO_Y      := 359
```

`scripts/remessa_protocolo.ahk:470-473`

```ahk
; Checkbox Recebido: estado vem do controle Button1.
checked := MV_ControlCheckedAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)
```

`scripts/mv_session.ahk:334-342`

```ahk
MV_ControlCheckedAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return ""
    try return ControlGetChecked(hwnd)
    catch
        return ""
}
```

`remessa_protocolo.ahk` **rodou contra o MV2000i** — é o fluxo validado. Logo
`ControlGetChecked` devolver `0` ou `1` real para checkbox do Oracle Forms está
demonstrado na prática, não é suposição. Isso dispensa duas alternativas que
seriam erradas por construção:

- **Leitura por pixel** — desnecessária, e teria de lidar com a linha
  selecionada em amarelo (visível em `image2.png`, primeira linha) e com
  branco, o que é fragilidade sem motivo.
- **OCR** — a `AGENTS.md` manda não portar servidor OCR próprio, e OCR de um
  tick de 19×23 px é ferramenta errada para o trabalho. O OCR do projeto
  existe para ler **texto de modal**, que o Window Spy não expõe; aqui o
  controle expõe o estado.

### 3.1 `MV_ControlCheckedAt` não serve como está

O precedente prova **que `ControlGetChecked` funciona**, não que
`MV_ControlCheckedAt` serve para esta coluna. A busca interna dele é por
**igualdade exata** de ClassNN:

`scripts/mv_session.ahk:357-358`

```ahk
if (ctrlClass != classNN)
    continue
```

Passar `"Button4"` não encontra o controle que é `Button5` na outra posição —
que é precisamente a armadilha da seção 4. Não há erro nem log quando nada
casa: a função devolve `0`, e `MV_ControlCheckedAt` converte em `""`.

**O tri-estado importa.** `""` é diferente de `0`, e o chamador precisa
preservar a distinção — o precedente faz isso em
`scripts/remessa_protocolo.ahk:474`, que testa `checked = 0 || checked = ""`.

### 3.2 O helper de geometria já existe — reusar, não criar

A busca por **prefixo de classe com tolerância geométrica** já está
implementada no mesmo arquivo:

`scripts/remessa_protocolo.ahk:860-893` — `RP_FindControlByClassPrefixAtPoint`

```ahk
RP_FindControlByClassPrefixAtPoint(winTitle, classPrefix, targetX, targetY, tolerance := 35) {
    ...
        if (SubStr(ctrlClass, 1, StrLen(classPrefix)) != classPrefix)
            continue
        try ControlGetPos &cx, &cy, &cw, &ch, hwnd
        catch
            continue
        if (targetX >= cx && targetX <= cx + cw && targetY >= cy && targetY <= cy + ch)
            return hwnd
        ...distância ao centro, aceita a mais próxima dentro de `tolerance`...
```

Ela resolve exatamente o problema: casa `Button4` **e** `Button5` pelo prefixo
`Button`, e escolhe pela geometria. O que falta é só o `ControlGetChecked` por
cima — uma função fina, no mesmo arquivo, com prefixo `RP_`.

**Uma versão anterior deste documento propôs criar um helper novo em
`mv_session.ahk`.** Isso é desnecessário: a geometria já existe, e criá-la de
novo seria duplicação real (regra 4). O helper novo é só o `ControlGetChecked`
sobre o `hwnd` que `RP_FindControlByClassPrefixAtPoint` devolve, e ele fica em
`remessa_protocolo.ahk` com prefixo `RP_` — o arquivo que já é dono da grid do
MOV DOC e que já tem o `RP_` correspondente.

**Tolerância: usar 35, o default do helper.** `MV_ControlCheckedAt` default é
`14`, e esse valor **não** serve aqui — ver seção 4.1. Os chamadores existentes
de `RP_FindControlByClassPrefixAtPoint` no arquivo já usam 35, 40 e 50, o que
é evidência em repo de que 14 não é seguro em grid.

### 3.3 O "Recebido" não é um checkbox de grid — a diferença importa

Uma correção sobre a versão anterior deste documento: o checkbox "Recebido" é o
**mesmo tipo de controle**, mas **não está na grid**.

`MOVDOC_CHECK_RECEBIDO_Y := 359` fica **abaixo** da banda da grade, que vai de
`MOVDOC_GRID_ROWS_Y[1] = 222` a `[4] = 291`. O "Recebido" é o checkbox do
formulário fixo do rodapé ("Recebimento … Devolução") — um só, sempre no mesmo
lugar — e é por isso que `ClassNN` fixo funciona nele.

O "Devolvido" é **um checkbox por linha**, dentro da área rolável, e é
exatamente por isso que o `ClassNN` dele varia. A lição do "Recebido" é
`ControlGetChecked`; a lição da grid é `prefixo + geometria`. São duas coisas
diferentes e ambas são necessárias.

## 4. A constraint real: o ClassNN do "Devolvido" é posicional

Este é o ponto que decide a implementação, e vem de comparar as duas capturas
do operador.

| Captura | Linha sob o mouse | ClassNN | Ponto Client |
|---|---|---|---|
| `images/image1.png` | 1ª | **`Button5`** | x 679, y 224 |
| `images/image2.png` | 2ª | **`Button4`** | x 679, y 247 |

**É o mesmo controle — client x 679 nas duas — com ClassNN diferente**, porque
o Oracle Forms renumera os controles conforme o estado da tela. Isto é
exatamente a armadilha que a `AGENTS.md` registra:

> **`EditN` não é contrato:** o Forms renumera conforme o estado da tela.
> Localize por ClassNN + ponto Client (`MV_FindControlByClientPoint`), ou por
> prefixo de classe (`ui60Drawn`).

Portanto **não existe constante `MOVDOC_CHECK_DEVOLVIDO_CLASS` a promover**,
do mesmo modo que não existe `Button4` ou `Button5` corretos. Qualquer valor
fixo funciona hoje e quebra quando a grade ganha, perde ou rola uma linha.

### 4.1 A banda de célula resolve, e a largura importa

A saída é localizar por **geometria dentro da banda da célula**, não por
ClassNN:

- **X**: `679`, confirmado de forma independente pelas duas capturas.
- **Y**: o mesmo `rowY` que o laço de coleta já usa, de
  `scripts/remessa_protocolo.ahk:42` — `MOVDOC_GRID_ROWS_Y := [222, 245, 268, 291]`.

A diferença de Y entre as duas capturas é 247 − 224 = **23 px**, exatamente o
espaçamento de `MOVDOC_GRID_ROWS_Y` (245 − 222 = 23). A captura 1 tem y 224
contra 222 da constante, e a captura 2 tem 247 contra 245. A diferença
consistente de 2 px indica que o Spy reporta o topo do controle e a constante
é o topo da linha. A grade, portanto, está alinhada com o que o código já usa.

**A banda tem de ser estreita.** O checkbox "Recebido" está em x 718 e usa
`Button1`. A distância horizontal entre as duas colunas é 718 − 679 = **39 px**,
e a largura do checkbox é 19 px (`w: 19` no Spy). Uma banda de célula
generosaEnough para tolerar variação de DPI pegaria o checkbox errado — e o
checkbox errado significa devolver o estado da coluna "Recebido" como se fosse
"Devolvido", que é falha silenciosa com consequência errada.

## 5. Onde pular a linha

`scripts/remessa_protocolo.ahk:391-397`

```ahk
key := protocolo "|" conta "|" convenio
if vistos.Has(key)
    continue

vistos[key] := true
linhas.Push(Map("protocolo", protocolo, "conta", conta, "convenio", convenio))
added++
```

O skip entra **antes** do `Push`, por três razones:

1. É antes de a linha entrar em `linhas`, e é de `linhas` que saem
   `RP_ConvenioMajoritario` (`:403`), `RP_FiltrarContasPorConvenio` (`:427`) e
   `protocolContas` (`:175`), que alimenta `InserirContasNaRemessa` (`:211`).
   Uma linha pulada aqui **nunca chega ao FFCV** — que é o requisito do TO-DO
   ("o macro deve pular aquela conta/linha").
2. O `vistos` já existe como mecanismo de dedupe da mesma linha, e marcar a
   linha como vista antes de seguir evita que a mesma conta devolvida, se
   reaparecer numa página seguinte da grade, seja reprocessada.
3. Pular **depois** do `Push` exigiria um segundo filtro sobre `linhas`, o que
   é duplicar o mesmo trabalho.

### 5.1 A conta pulada não pode ser pulada em silêncio

A `AGENTS.md` classifica "produz planilha errada sem erro visível" como falha
silenciosa. Uma conta devolvida que simplesmente não aparece no relatório é
exatamente isso: o operador não tem como saber se ela foi pulada de propósito
ou se o fluxo a perdeu.

O array `erros` já existe para isto e já é renderizado no relatório final:

`scripts/remessa_protocolo.ahk:115-118` e `:243-249`

```ahk
erros        := []
...
relatorio .= "`nConcluído com " erros.Length " pendência(s):`n"
relatorio .= "PROTOCOLO | CONTA | ERRO`n"
for _, e in erros
    relatorio .= "  [[red]]" e["protocolo"] " | " e["conta"] " | " e["descricao"] "[[/red]]`n"
```

O registro da conta devolvida entra nesse array, com `descricao` explícita de
que foi pulada por estar marcada como devolvida. Não há formato novo a criar.

Uma consequência a registrar: uma conta devolvida **não** conta para
`RP_ConvenioMajoritario`. Se o protocolo inteiro for devolvido, `convenioNum`
fica vazio e o fluxo aborta em `remessa_protocolo.ahk:171-173` com "Convênio
não identificado no MOV DOC". A mensagem de abort não vai explicar que a
razão foram as contas devolvidas. Vale ajustar a mensagem para mencionar a
contagem de devolvidas, porque o operador, do jeito atual, recebe um erro que
não aponta para a causa.

### 5.2 A linha-semente burla o laço — este é o ponto que passa despercebido

O skip na seção 5.1 só funciona se ele estiver no único lugar que empurra
linhas: `RP_ColetarLinhasVisiveisMovDoc:396`. Mas existe um **segundo**
caminho de entrada, e ele não passa por ali.

`scripts/remessa_protocolo.ahk:311-321`

```ahk
RP_ColetarLinhasMovDoc(protocolo, primeiraLinha := "") {
    linhas := []
    vistos := Map()

    if (primeiraLinha is Map) {
        keyInicial := primeiraLinha["protocolo"] "|" primeiraLinha["conta"] "|" primeiraLinha["convenio"]
        vistos[keyInicial] := true
        linhas.Push(primeiraLinha)          ; <-- empurra sem consultar o Devolvido
    }

    RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos)
```

A semente é montada em `RP_WaitMovDocFirstGridLineReady:523` e empurrada em
`:318`, **antes** de o laço de coleta rodar. Se a **primeira linha** da grade
estiver marcada como devolvida, ela entra em `linhas` sem verificação e vaza
inteira para o FFCV.

A semente existe porque a primeira linha já foi lida enquanto se esperava o
F8, e relê-la custaria um ciclo. A correção é checar o checkbox **no momento de
empurrar a semente**, com o mesmo helper — não na passagem seguinte, porque a
grade já pode ter rolado.

**A chave `vistos` está duplicada** em dois lugares (`:316` e `:391`) e ambos
precisam continuar iguais. Se o formato da chave mudar, os dois mudam juntos.

### 5.3 O `erros` não é alcançável a partir da coleta

`RP_ColetarLinhasVisiveisMovDoc` (`:375`) recebe apenas
`(protocolo, linhas, vistos)`. Não tem acesso a `erros`, que é declarado em
`:138` e repassado para `RP_FiltrarContasPorConvenio` (`:175`) e
`InserirContasNaRemessa` (`:211`).

Reportar a conta pulada exige **uma** destas duas formas, e a escolha é
simples:

1. acrescentar `erros` aos parâmetros da função e aos **dois** chamadores
   (`:321` e `:328`); ou
2. devolver as linhas puladas em um `Map` separado e empurrar em `erros` no
   chamador.

A primeira é menos código e segue o padrão de `RP_FiltrarContasPorConvenio`,
que já recebe `erros` como parâmetro (`scripts/remessa_protocolo.ahk:427`).

## 6. Correção proposta

### 6.1 Constante nova, com origem

```ahk
; Spy em Praxis_TO-DO/Remessa_Protocolo/images/image1.png e image2.png
; (Button5 na 1ª linha, Button4 na 2ª — ClassNN posicional, NÃO usar como contrato)
MOVDOC_CHECK_DEVOLVIDO_X := 679
```

Só a coordenada X é nova. O Y vem de `MOVDOC_GRID_ROWS_Y`, que já existe e
já está alinhado com a grade.

Conforme a regra 9 da `AGENTS.md`, a origem fica registrada acima do bloco, e
a ressalva de "ClassNN posicional" viaja junto — é o que impede alguém de
"simplificar" depois atribuindo um `ButtonN` fixo.

### 6.2 Leitura por banda, no laço de coleta

Dentro de `RP_ColetarLinhasVisiveisMovDoc`, para cada `rowY`:

1. Ler o estado do checkbox da coluna "Devolvido" na banda `(x 679, y rowY)`.
2. Se marcado, registrar a pendência no array `erros` e `continue`, sem
   `Push`.
3. Se não marcado, seguir o caminho atual sem alteração.

### 6.3 O helper — reusar o de geometria que já existe

A versão anterior deste documento propunha criar
`MV_ControlCheckedInCell` em `mv_session.ahk`. Isso é **duplicação real**
(regra 4): a parte difícil — prefixo de classe com tolerância geométrica — já
está pronta em `RP_FindControlByClassPrefixAtPoint`
(`scripts/remessa_protocolo.ahk:860-893`).

O que falta é só o `ControlGetChecked` por cima do `hwnd` que ela devolve:

```ahk
; Lê o estado de um checkbox de GRID. O ClassNN do Oracle Forms varia com a
; posição da linha (Button4/Button5...), então a busca é por prefixo + geometria,
; não por ClassNN exato. Retorna "" quando não acha o controle.
RP_CheckGridChecked(cellX, cellY, tolerance := 35) {
    hwnd := RP_FindControlByClassPrefixAtPoint(WIN_MOVDOC_BAIXA, "Button", cellX, cellY, tolerance)
    if !hwnd
        return ""
    try return ControlGetChecked(hwnd)
    catch
        return ""
}
```

Fica em `remessa_protocolo.ahk` com prefixo `RP_`, no arquivo que já é dono
da grid e que já tem o helper correspondente. Promover a `mv_session.ahk` só
faria sentido se outro fluxo precisar dele — e nenhum precisa hoje, o que é
justamente o teste da regra 5 contra abstração especulativa.

### 6.4 Tolerância: o default de `MV_ControlCheckedAt` não serve

`MV_FindControlByClientPoint` usa `tolerance := 14` como raio em torno do
centro do controle, em pixels absolutos, sem escala de DPI. Para uma coluna de
39 px de largura, 14 px de raio alcançam a coluna vizinha — e o
`MV_ControlCheckedAt` também tem um atalho por contenção do retângulo
(`scripts/mv_session.ahk:364-365`) que **ignora a tolerância** e devolve o
primeiro controle que contém o ponto.

Por isso o helper novo usa o default **35** de
`RP_FindControlByClassPrefixAtPoint`. Os chamadores existentes desse helper no
arquivo já usam 35, 40 e 50, o que é evidência em repo de que 14 não é seguro
em grid.

## 7. Validação

### 7.1 Sem o MV2000i — possível, e parcial

- **Build + `--integrity-check`**, gate do `AGENTS.md`:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller
  $p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" `
       -ArgumentList '--integrity-check' -Wait -PassThru; $p.ExitCode
  ```

- **Lógica de skip e de registro**, com um stub: a parte de pular a linha,
  marcar `vistos` e registrar em `erros` é testável sem o MV, isolando a
  leitura do estado do checkbox. Vale porque a parte Easy de errar é essa — a
  leitura em si é a que só o MV resolve.

### 7.2 Exige o MV2000i real — obrigatório, e é quase tudo

A leitura do estado do checkbox **só** pode ser validada contra o MV.

1. Protocolo com pelo menos uma conta **não** devolvida: a coluna deve ler
   desmarcada e a conta deve seguir para o FFCV como hoje.
2. Protocolo com pelo menos uma conta **devolvida** (as das capturas): a coluna
   deve ler marcada, a conta não deve aparecer no FFCV, e deve aparecer na
   lista de pendências.
3. **Teste de paginação** — o mais importante, e o que nenhuma captura prova:
   a marcação tem de ser lida corretamente na 1ª, na 2ª e na 4ª linha da
   janela visível, e o `ClassNN` de cada uma tem de ser diferente. Uma
   implementação por ClassNN fixo passa no caso 1 e falha aqui.
4. **Teste da linha-semente** — o segundo mais importante, e é o que a
   seção 5.2 descreve. Protocolo cuja **primeira** linha da grade esteja
   devolvida: a conta não pode vazar pelo caminho de `:318`. Uma
   implementação que só verifica no laço de `:396` passa no teste 2 e falha
   neste.
5. Rolagem: a mesma conta devolvida não pode reaparecer como duplicata quando
   a grade avança (`RP_AvancarGridMovDocQuatroLinhas`, `:348-373`).
6. Protocolo com **todas** as contas devolvidas: o fluxo deve abortar com
   mensagem que aponte a devolução, e não com "Convênio não identificado"
   (seção 5.1).

Sem o MV, os itens 1 a 6 ficam como PENDENTE e a feature não deve ser
declarada pronta.

## 8. PENDENTE

- **O `ClassNN` do checkbox "Devolvido" em cada posição da janela visível.**
  Só o MV2000i com Window Spy, linha por linha, fornece a verdade. Nada
  aqui depende de adivinhá-lo, porque a implementação proposta não o usa — mas
  saber o padrão ajuda a diagnosticar se a leitura por banda falhar.
- **A leitura é estável após o clique físico da célula de conta?**
  `RP_ReadMovDocGridField:543` clica na célula e move a seleção antes de o
  Devolvido ser lido. A ordem entre as duas leituras não está validada, e
  escolher a ordem errada pode ler o checkbox da linha vizinha.
- **A conta devolvida deve aparecer como pendência ou ser omitida em
  silêncio?** A proposta deste documento é pendência, por causa da seção 5.1.
  **Decisão do operador**, porque muda o relatório que ele lê todo dia.
- **O que fazer com a linha devolvida no FFCV** — a proposta é não enviar
  nenhuma vez. Confirmar que isso está no escopo deste TO-DO.
