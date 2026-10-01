# Remessa por Protocolo — o `^q` não sai da tela de baixa

> TO-DO de origem: `Praxis_TO-DO/Remessa_Protocolo/Erro.txt:11`
> *"Está dizendo que enviou ctrl + q, mas não está enviando realmente."*
> TO-DO de origem: `Praxis_TO-DO/Remessa_Protocolo/TO-DO.txt` não menciona este item.

**Natureza:** bug. **Causa raiz:** fechada para a *verificação* e para o
*janela-alvo* (seção 5, com prova empírica). **Prioridade:** 3ª da lista — ver
[README](README.md#ordem-de-ataque-sugerida).

**Resumo da causa:** o `^q` funciona no FFCV e não no MOV DOC porque as duas
saídas usam constantes de janela diferentes. A do FFCV casa **fora** dos
colchetes do título MDI; a do MOV DOC casa **dentro**, e resolve para a raiz em
vez da child onde o Oracle Forms processa o acelerador.

---

## 1. O relato

`Praxis_TO-DO/Remessa_Protocolo/Erro.txt:9-11`

```
[10:21:11]⏱ MOV DOC consultar, coletar e baixar: 20.5s | 1 protocolo(s), 41 linha(s)
[10:21:12]Saída de MOV DOC (tela de baixa): ^q enviado
[10:21:12]Está dizendo que enviou ctrl + q, mas não está enviando realmente.
```

O operador leu o log e viu a tela continuar na Protocolação de Baixa.

O intervalo entre as duas linhas é de **1 segundo**, e isso importa: uma
espera real de 800 ms de estabilidade mais o polling de ativação de janela
cabe nesse segundo. Ou seja, a função voltou por caminho **rápido**, e o
caminho rápido é o que devolve `true` sem ter visto nada acontecer.

## 2. Ponto de chamada

`scripts/remessa_protocolo.ahk:219-231` — **estado na época da análise**. A
chamada usava `MV_WIN_MOVDOC_BAIXA`:

```ahk
; Contas coletadas no MOV DOC: fechar a tela de baixa antes de passar ao FFCV.
; Precisa vir antes de MV_EnsureFFCV, que ativa o FFCV e tornaria o Ctrl+Q ambíguo
; entre as duas janelas.
MV_FecharUltimaTela(MV_WIN_MOVDOC_BAIXA, "MOV DOC (tela de baixa)")
```

> **Corrigido.** Hoje a linha é `MV_FecharUltimaTela(MV_WIN_MOVDOC_ANY, ...)`
> (`scripts/remessa_protocolo.ahk:231`) — a raiz MDI, e não a child, que é a
> parte 2 da causa raiz deste documento.

O comentário está certo e a ordem está certa. O problema está dentro de
`MV_FecharUltimaTela`.

## 3. Causa raiz (parte 1): a verificação que nunca falha

Este documento tem **duas** causas independentes, e elas se somam. Esta seção
trata a primeira — a verificação, que faz o log mentir. A segunda, que explica
*por que* o `^q` não funciona só no MOV DOC, é a
[seção 5](#5-causa-raiz-parte-2-o-título-da-tela-de-baixa-está-entre-colchetes).

`scripts/mv_session.ahk:546-580`

```ahk
MV_FecharUltimaTela(winTitle, rotulo) {
    if (MV_ActiveModalTitle() != "") { ... return false }
    if !WinExist(winTitle) { ... return true }
    if !MV_EnsureWindowActive(winTitle, MV_TIMEOUT_ACOE) { ... return false }

    Send MV_SAIR_TELA_ATALHO
    if !MV_WaitOracleSettled(winTitle, MV_FINAL_STABLE_MS, MV_FINAL_ACTION_TIMEOUT_MS)
        MV_LogSaidaTela(rotulo, MV_SAIR_TELA_ATALHO " enviado, mas a janela não confirmou estabilidade.")

    MV_LogSaidaTela(rotulo, MV_SAIR_TELA_ATALHO " enviado.")
    return true
}
```

`MV_WaitOracleSettled` é chamado, mas o que ele verifica não responde à
pergunta que precisa ser respondida.

`scripts/mv_session.ahk:563-576`

```ahk
MV_WaitOracleSettled(winTitle, stableMs := 800, timeoutMs := 30000) {
    ...
        if exists {
            try hwnds := WinGetControlsHwnd(winTitle)
            catch
                hwnds := []
            count := hwnds.Length
        }

        if (exists && modalClear && cursorReady && count = lastCount) {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= stableMs)
                return true
        } else {
```

O sinal de estabilidade é `count := hwnds.Length` — **a contagem de controles
da janela, e nada mais**. Não participa o título, nem a classe, nem o hwnd.

### 3.1 Por que isso não detecta uma tecla engolida

Uma tecla que não chega ao destino não muda nada: a mesma janela, a mesma
classe, o mesmo título, o mesmo número de controles. O `count` é
trivialmente igual a `lastCount` desde o primeiro poll, `stableSince` é
armado, e 800 ms depois a função devolve `true`.

O caso inverso também é verdade, e é mais grave para a confiabilidade futura:
mesmo quando o `^q` **funciona**, se a contagem de controles der acidentalmente igual
nas duas telas, a função é cega para a transição que acabou de acontecer.

No Oracle Forms, a troca de tela interna troca o **conteúdo desenhado** — a
tela é uma superfície `ui60Drawn`. A árvore de controles do MDI child pode
permanecer com o mesmo tamanho entre a tela de baixa e a tela que a substitui.
Ou seja: contagem de controles é um proxy fraco para "a tela mudou", e é
exatamente o proxy que esta função escolheu.

### 3.2 Não existe caminho de código que reporte a falha

Este é o ponto que transforma o relato em diagnóstico.

O único ramo de erro de `MV_FecharUltimaTela` é o da linha 531-532, e ele só
dispara quando `MV_WaitOracleSettled` devolve `false` — isto é, quando a tela
ficou **instável** (modal apareceu, cursor em `Wait`, contagem de controles
oscilando). Instabilidade é o **oposto** da falha observada: aqui nada
aconteceu, e "nada aconteceu" é um estado perfeitamente estável.

Depois dele, a linha 534 loga `MV_SAIR_TELA_ATALHO " enviado."`
**incondicionalmente**. A string `"^q enviado."` é um registro de **intenção**,
não de resultado. A função não tem como emitir "não saiu", porque não tem como
saber.

É por isso que o log engana o operador: ele está lendo um registro de
intenção como se fosse confirmação.

### 3.3 O fluxo validado faz as duas coisas que esta não faz

`Praxis_TO-DO/Protocolar/protocolar.ahk:1116-1134`

```ahk
CloseByCtrlQAndWait(context := "") {
    ; Fecha a tela atual e aguarda a tela resultante estabilizar.
    LogLine("Ctrl+Q: fechando janela" (context != "" ? " (" context ")" : ""))
    SendKeys("^q")
    WaitCurrentScreenStableAfterCtrlQ(context)
}

CloseByCtrlQEnterAndWait(context := "") {
    ; Fluxos como a baixa usam Ctrl+Q e depois Enter.
    CloseByCtrlQAndWait(context " antes do Enter")
    LogLine("Ctrl+Q: tela detectada; enviando Enter" ...)
    SendKeys("{Enter}")
    Sleep Delay.AfterCtrlQEnter
    WaitCurrentScreenStableAfterCtrlQ(context " depois do Enter")
    WaitMovDocOrEnvioReadyAfterClose(context)
}
```

Duas diferenças que importam:

**A assinatura inclui o título.** `Praxis_TO-DO/Protocolar/protocolar.ahk:1216-1227`

```ahk
ActiveScreenSignature(hwnd) {
    try title := WinGetTitle("ahk_id " hwnd)
    ...
    try cls := WinGetClass("ahk_id " hwnd)
    ...
    return hwnd "|" proc "|" cls "|" title
}
```

Com o título na assinatura, a transição de tela **aparece** como mudança de
assinatura, e o `stableSince` é zerado — a função percebe que algo mudou.
Com `hwnds.Length`, não percebe.

**Existe uma asserção positiva.** `Praxis_TO-DO/Protocolar/protocolar.ahk:1213`

```ahk
throw Error("Após Ctrl+Q, a tela do MovDoc/Envio não estabilizou no tempo esperado" ...)
```

O validado não deduz o resultado da estabilidade: ele **verifica que a tela
esperada está lá** e falha alto se não estiver. É a afirmação positiva que o
Praxis não tem.

## 4. O que **não** é a causa

### 4.1 O atalho

`^q` puro está **confirmado pelo operador** e não deve ser alterado. A
`AGENTS.md` registra isso na seção "Falha silenciosa":

> **Sair de tela no MV é Ctrl+Q**, confirmado pelo operador para **todas** as
> telas […] Em AHK `^` é Ctrl, então `^q` **é** Ctrl+Q — não é valor suspeito.
> Uma constante só: `MV_SAIR_TELA_ATALHO` (`mv_session.ahk:78`).

**Divergência deliberada, registrada aqui de propósito.** O fluxo validado
acrescenta um `{Enter}` depois do `^q` na baixa
(`Praxis_TO-DO/Protocolar/protocolar.ahk:1124-1134`). O Praxis **não** faz
isso, por decisão do operador. Alguém comparando os dois arquivos vai concluir
que falta o `Enter` e vai "corrigir". **Não é para corrigir.** Se a execução
real exigir algo além de `^q`, o sintoma volta a aparecer aqui e a conclusão
deve ser a oposta: a verificação é que precisa melhorar, como nas seções 3.1
e 3.2.

### 4.2 O `WinClose`

`WinClose` está corretamente ausente. A regra de automação do `AGENTS.md`
proíbe `WinClose` no `ifrun60.EXE` porque o Oracle Forms perde o estado da
aplicação. O código segue a regra.

### 4.3 O envio da tecla (`Send` vs `SendInput`)

**Hipótese que a observação do operador derrubou.** Havia aqui a suspeita de que
`Send` (`mv_session.ahk:570`) não esperasse o MV processar a tecla, enquanto o
fluxo validado usa `ActivateWindow` com `WinRestore` e `WinWaitActive`
(`Praxis_TO-DO/Protocolar/protocolar.ahk:1075-1081`).

Isso explicaria uma falha, mas **não explicaria por que o FFCV funciona**. Se o
problema fosse o envio da tecla, as duas etapas falhariam — elas usam a mesma
função, o mesmo `Send` e o mesmo `SetKeyDelay 0, 0` (`mv_session.ahk:12`).
A diferença observada entre as duas etapas é **o título alvo** (seção 5), e é o
que explica a diferença.

Registrado aqui para não ser retomado: se a correção da seção 5.5 não resolver,
esta hipótese volta a ser válida como segunda causa, e aí `SendInput` +
`WinRestore` passam a ter base para teste.

## 5. Causa raiz (parte 2): o título da tela de baixa está entre colchetes

**Esta seção substitui as duas hipóteses genéricas que estavam aqui antes.** A
observação do operador de que o `^q` **funciona no FFCV e não funciona no MOV
DOC** elimina a hipótese de problema de envio de tecla: se fosse o `Send` ou o
`SetKeyDelay`, quebraria nas duas etapas. A diferença está no **título alvo**.

### 5.1 As duas saídas, lado a lado

| Etapa | Chamada | Constante | Valor |
|---|---|---|---|
| FFCV | `MV_FecharUltimaTela(MV_WIN_FFCV_ANY, "FFCV")` — `remessa_protocolo.ahk:291` | `MV_WIN_FFCV_ANY` (`mv_session.ahk:29`) | `"Faturamento ahk_exe ifrun60.EXE"` |
| MOV DOC | `MV_FecharUltimaTela(MV_WIN_MOVDOC_BAIXA, ...)` — `remessa_protocolo.ahk:231` | `MV_WIN_MOVDOC_BAIXA` (`mv_session.ahk:32`) | `"Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"` |

As duas passam pela **mesma função**, com o **mesmo atalho**, na **mesma
máquina**. A única diferença é a string de título.

### 5.2 A diferença real: uma casa fora dos colchetes, a outra dentro

O título real da tela de baixa, segundo a captura do operador
(`Praxis_TO-DO/Remessa_Protocolo/images/image2.png`):

```
Movimentação de Documentos - [Protocolação de Baixa de Documentos - HOSPITAL SAO RAFAEL]
ahk_class ui60MDIroot_W32
ahk_exe ifrun60.EXE
```

O nome da tela está **dentro dos colchetes** — é a notação do MDI do Windows
para a *child* ativa dentro de uma raiz. E `SetTitleMatchMode 2` é substring
(`mv_session.ahk:8`), então:

- `MV_WIN_FFCV_ANY` = `"Faturamento"` casa com `MV2000i - Faturamento`, **fora**
  dos colchetes → resolve para a janela que de fato é o FFCV.
- `MV_WIN_MOVDOC_BAIXA` = `"Protocolação de Baixa de Documentos"` casa **dentro**
  dos colchetes do título da raiz do MOV DOC → resolve para a **raiz**, e o
  `hwnd` devolvido tem um título que **não contém mais o texto procurado**.

### 5.3 Prova empírica

Reproduzindo a estrutura de títulos com duas janelas reais abertas ao mesmo
tempo, como as duas telas do MV estão:

```
=== Reproduzindo MV_FecharUltimaTela(MV_WIN_MOVDOC_BAIXA) ===

MV_WIN_MOVDOC_BAIXA casa em hwnd ...: 394198
  esse hwnd e a raiz FFCV? ...........: NAO
  esse hwnd e a raiz MOV DOC? ........: SIM
  titulo real desse hwnd .............: Movimentacao de Documentos - [Protocolacao de Baixa de Documentos - HOSPITAL SAO RAFAEL]

=== Reproduzindo MV_FecharUltimaTela(MV_WIN_FFCV_ANY) ===

MV_WIN_FFCV_ANY casa em hwnd .......: 4196350
  esse hwnd e a raiz FFCV? ...........: SIM - CORRETO
  esse hwnd e a raiz MOV DOC? ........: NAO
  titulo real desse hwnd .............: MV2000i - Faturamento
```

O texto procurado está dentro dos colchetes; o `WinExist` (substring) resolve
para a **raiz**, e o título do `hwnd` resolvido não contém mais o que se
procurava. No FFCV, casa fora dos colchetes, resolve certo.

### 5.4 Por que isso impede o `^q` de funcionar

O `^q` é processado pelo **canvas do Oracle Forms, que vive na MDI child**, não
pela raiz. `MV_FecharUltimaTela` ativa a raiz
(`WinActivate winTitle`, `mv_session.ahk:558`) e envia `Send "^q"`. Com o foco
na raiz e o Forms escutando na child, o acelerador é entregue à janela que não
o trata, e a tela não sai.

Isso é coerente com o `Erro.txt` inteiro: o `MV_WaitOracleSettled` seguinte
vê a raiz do MOV DOC **permanece igual** — mesma janela, mesma contagem de
controles, nenhum modal — e retorna `true` por stability, como a seção 3.1
descreve. A tela de baixa nunca saiu, e a função(reporta que saiu.

**Ainda não é prova completa, e o que falta é honesto:** os probes provam a
resolução de título, não o comportamento de foco dentro do MDI do Oracle
Forms — isso exige o MV. Mas a hipótese agora é única, específica, e explica
a diferença observada entre as duas etapas, o que as hipóteses anteriores
(`Send`/`SetKeyDelay`) não explicavam.

### 5.5 Correção proposta

**Reaproveitar `MV_WIN_MOVDOC_ANY`, que já existe e já tem o valor da raiz**
(`mv_session.ahk:27`):

```ahk
MV_WIN_MOVDOC_ANY := "Movimentação ahk_exe ifrun60.EXE"
```

Nenhuma constante nova. É literalmente o que `protocolar.ahk:1435` já usa na
saída do MOV DOC, e o que a etapa que funciona (FFCV) faz.

**A constante `MV_WIN_MOVDOC_BAIXA` NÃO é alterada.** Uma versão anterior deste
documento propunha trocá-la inteira; isso está **errado** e foi corrigido. Ela
tem quatro consumidores que dependem do título da *child*:

| Consumidor | O que faz |
|---|---|
| `scripts/protocolar.ahk:878` | `PR_EsperarJanela` — espera a tela de baixa |
| `scripts/protocolar.ahk:881` | `MV_EnsureWindowActive` — ativa a tela de baixa |
| `scripts/protocolar.ahk:889` | `PR_ClicarControle(..., PR_BAIXA_BTN_RECEBIDO)` — **clica** o `Button1` "Recebido" |
| `scripts/remessa_protocolo.ahk:23` | `WIN_MOVDOC_BAIXA := MV_WIN_MOVDOC_BAIXA`, usada na **leitura da grid** |

A troca fica restrita a **um** ponto:

```ahk
; scripts/remessa_protocolo.ahk:231
MV_FecharUltimaTela(MV_WIN_MOVDOC_ANY, "MOV DOC (tela de baixa)")
```

Risco zero para os outros quatro consumidores, porque nenhum deles é tocado.

**Antes de aplicar, confirmar no MV** qual tela o `^q` deve fechar quando ambas
estão no título — a raiz ou a child. O `^q` fecha a **child** ativa; ativar a
raiz pode reativar outra child. Se a raiz do MOV DOC tiver mais de uma child, a
correção pode precisar de outro caminho. A instrumentação da seção 7.2 — qual
`hwnd` está com foco antes do `Send` — é o que decide.

**Independente disso, a correção da verificação (seção 7.1) continua válida e
necessária.** Mesmo com a janela certa, a função não prova que a tela saiu. As
duas correções são complementares: uma diz *para onde* mandar, a outra diz se
*funcionou*.

## 6. Bug adjacente na mesma função: unidade de tempo

`scripts/mv_session.ahk:128`

```ahk
MV_TIMEOUT_ACOE     := 100
```

O nome sugere milissegundos, ao lado de `MV_POLL_MS := 100` e
`MV_MODULE_STABLE_MS`. Mas ele é passado como **segundos** para `MV_Poll`, cujo
segundo parâmetro é `timeoutSecs`:

`scripts/mv_session.ahk:412-418`

```ahk
MV_Poll(condFn, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
```

E `MV_EnsureWindowActive` repassa direto:

`scripts/mv_session.ahk:510-515`

```ahk
MV_EnsureWindowActive(winTitle, timeoutSecs := 3) {
    if !WinExist(winTitle)
        return false
    WinActivate winTitle
    return MV_Poll(() => WinActive(winTitle), timeoutSecs)
}
```

Resultado: `scripts/mv_session.ahk:572`, dentro de `MV_FecharUltimaTela`,
espera **100 segundos** em vez de 0,1 s pela ativação da janela. Se a janela não
ativar, o fluxo **pendura 100 segundos** antes de logar "a janela existe mas
não ficou ativa".

O mesmo valor é usado de forma **correta** em outros pontos, multiplicado por
1000 para quem espera em milissegundos — `scripts/fechar_xml.ahk:636`, `:681`,
`:726`:

```ahk
FX_EsperarModalFechar(MV_TIMEOUT_ACOE * 1000)
```

Ou seja, a constante vale 100 e cada consumidor precisa declarar em que unidade
trabalha. Os consumidores que passam a constante cru para uma função de
**segundos** esperam 100 s em vez de 0,1 s:

| Local | Passado como | Espera real |
|---|---|---|
| `scripts/mv_session.ahk:558` | segundos (`MV_EnsureWindowActive`) | 100 s |
| `scripts/fechar_xml.ahk:478` | segundos (`MV_Poll`) | 100 s |
| `scripts/fechar_xml.ahk:787` | segundos (`MV_Poll`) | 100 s |
| `scripts/remessa_protocolo.ahk:1386` | segundos (`MV_Poll`) | 100 s |
| `scripts/fechar_xml.ahk:636`, `:681`, `:726` | `× 1000` → ms | 100 ms |

Isto é mais que lentidão: no `fechar_xml.ahk`, `MV_Poll(() => !WinExist(...),
MV_TIMEOUT_ACOE)` em `:478` e `:787` é justamente a **verificação de que a
tela de entrega saiu** — ou seja, a mesma verificação insuficiente de que trata
a seção 3, agora com um timeout que só falha 100 segundos depois. E
`remessa_protocolo.ahk:1386` é `RP_SairTelaEntrega`, a saída da tela de
Entrega de Remessas, que é a mesma família de verificação.

Isto reforça a recomendação central: **o que falta não é um `Sleep` maior, é
uma asserção de que a tela mudou.**

## 7. Correção proposta

### 7.1 Tornar o resultado verificável (prioridade)

Em `scripts/mv_session.ahk`:

1. **Adicionar uma assinatura de tela**, espelhando a do validado, com título e
   classe — não só contagem de controles. Vive no contrato de janela, prefixo
   `MV_`.
2. **`MV_FecharUltimaTela` passa a exigir evidência de que a tela saiu**:
   capturar a assinatura antes do `Send`, e depois do `Send` aceitar como
   sucesso **apenas** se a janela alvo não existir mais **ou** a assinatura
   tiver mudado. Se nenhuma das duas acontecer dentro do timeout, logar
   falha — e não sucesso.
3. **O log passa a refletir o resultado.** Substituir o
   `MV_LogSaidaTela(rotulo, MV_SAIR_TELA_ATALHO " enviado.")` incondicional da
   linha 534 por mensagens distintas para "saiu", "não saiu" e "já não
   existia". Hoje não há como o log mentir, porque ele não afirma nada que a
   função tenha medido.

Justificativa contra o padrão existente: a regra 2 da `AGENTS.md` manda seguir
o padrão, e o padrão **é** o `ActiveScreenSignature` + asserção positiva do
fluxo validado. O que o Praxis faz diverge do padrão sem ganho — só ganho em
velocidade, e velocidade aqui é o que produziu o defeito.

### 7.2 Instrumentar a resolução de título (barato, fazer junto)

Na mesma função, imediatamente antes do `Send` e depois dele, registrar:

- `WinGetID("A")` — a janela **realmente** focada, não a resolvida por título;
- `WinGetTitle` e `WinGetClass` dessa janela;
- o `hwnd` que `WinExist(winTitle)` devolveu, e o título desse `hwnd`;
- o título da janela alvo antes e depois do `Send`.

O quarto item é o que fecha a questão da seção 5.3 no MV: se o `hwnd`
devolvido por `WinExist` tiver título **diferente** do que foi procurado, é a
resolução de título da seção 5 que está confirmada como causa. Se o `hwnd`
focado real for diferente do que o `WinExist` devolveu, é divergência de
foco.

Isso é barato, e converte a única inferência que resta em dado na **próxima
execução**.

### 7.3 Corrigir a unidade de `MV_TIMEOUT_ACOE` (separado)

Ou a constante passa a ser usada consistentemente em milissegundos, com
`* 1000` em todos os chamadores de `MV_Poll`; ou ganha um nome e uma unidade
que não admitam ambiguidade. **A escolha entre as duas é do `AGENTS.md`:** o
nome `MV_TIMEOUT_ACOE` sem sufixo é exatamente a ambiguidade que produziu o
problema.

Enquanto isso não for decidido, ao menos registrar que a espera de 100 s é
intencional em `fechar_xml.ahk:478` e `:787`, onde pode ser a diferença entre
"o Forms não estabilizou" e "o Forms nunca vai estabilizar".

## 8. Validação

### 8.1 Sem o MV2000i — possível

- **Prova do defeito de verificação, sem MV.** Este é o teste mais importante
  do documento e é barato: uma janela de teste que **não reage** a `^q`.
  Chamar `MV_FecharUltimaTela` contra ela. Com o código atual, a função
  devolve `true` e loga `"^q enviado."`. Isso reproduz o relato do operador
  **inteiro** — inclusive a mensagem de log enganosa — sem precisar do MV2000i.
  Depois da correção, a mesma janela tem de produzir falha.
- **Conferência de unidades**, leitura estática:

  ```powershell
  Select-String -Path scripts\*.ahk -Pattern 'MV_TIMEOUT_ACOE'
  ```

  Cada ocorrência tem de ser `MV_Poll` com segundos ou `MV_PollMs` com
  milissegundos, nunca os dois.
- **Build + `--integrity-check`**, gate do `AGENTS.md`:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller
  $p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" `
       -ArgumentList '--integrity-check' -Wait -PassThru; $p.ExitCode
  ```

### 8.2 Exige o MV2000i real — obrigatório

O teste da 8.1 prova que a **verificação** estava errada. Não prova que o `^q`
falha, nem por quê.

1. Com a instrumentação da 7.2, rodar Remessa por Protocolo e conferir se o
   `hwnd` devolvido por `WinExist(MV_WIN_MOVDOC_BAIXA)` tem título **diferente**
   do texto procurado. Isso confirma a resolução de título da seção 5.3 como
   causa, e é o teste que decide.
2. Confirmar qual `hwnd` está **realmente focado** antes do `Send` — a raiz ou
   a child — e se ele difere daquele que o `WinExist` devolveu.
3. Aplicar a correção da seção 5.5 (título-alvo = raiz, como o FFCV já usa) e
   ver se a tela de baixa passa a sair. Esta é a confirmação de que a causa
   está certa, não só de que a hipótese era plausível.
4. Confirmar que, quando o `^q` **funciona**, a verificação nova reporta
   "saiu" e não "não saiu" — um teste que só passa no caminho ruim não prova
   nada.
5. Conferir o tempo total do fluxo: com `MV_TIMEOUT_ACOE` corrigido, o tempo
   em falha deve cair de ~100 s para ~0,1 s, e essa diferença é observável no
   log.

## 9. PENDENTE

- **A resolução de título da seção 5.3 é a causa, ou só coincidência?** Os
  probes provam que o `WinExist` resolve para a raiz; falta o MV para provar
  que isso quebra o `^q`. A instrumentação da 7.2 e o passo 3 da 8.2 resolvem.
- **Qual tela o `^q` deve fechar: a raiz ou a child?** Se a raiz do MOV DOC
  tiver mais de uma child, ativar a raiz pode reativar outra child, e aí o
  `^q` sai da tela errada. Só o MV responde, e a resposta muda a correção da
  seção 5.5.
- **A resolução por substring em MDI atinge outros pontos do contrato de
  janela?** `MV_WIN_MOVDOC_ANY` e `MV_WIN_FFCV_ANY` (`mv_session.ahk:27-29`)
  casam **fora** dos colchetes, então estão seguras — e é exatamente por isso
  que funcionam. Mas vale varrer as constantes restantes: `MV_WIN_XML_TISS`
  (`:47`), `MV_WIN_CAPA_REMESSA` (`:46`) e `MV_WIN_FFCV_DATAS` (`:45`) podem
  ter o mesmo formato de título entre colchetes. **Não verificado.**
- **`^q` puro foi confirmado pelo operador** e está registrado na `AGENTS.md`.
  Se a execução real mostrar que precisa de algo além, a conclusão é rever a
  janela-alvo e a verificação **antes** de mexer no atalho, conforme a
  seção 4.1.
