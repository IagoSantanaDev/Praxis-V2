# Protocolar — o diálogo "Salvar como" nunca é detectado

> TO-DO de origem: `Praxis_TO-DO/Protocolar/TO-DO.txt:1`
> *"Utilizando as imagens em "images/Salvar Como/", verifique porque não está
> detectando a tela de "Salva Como"."*

**Natureza:** bug. **Causa raiz:** fechada e com prova empírica.
**Prioridade:** 1ª da lista — ver [README](README.md#ordem-de-ataque-sugerida).

---

## 1. Sintoma relatado

`Praxis_TO-DO/Protocolar/log.txt:9`

```
[09:27:38]ERRO: O diálogo 'Salvar como' do EXECUTASQL.exe não apareceu em 45s.
[09:27:38]Execução finalizada.
```

As duas linhas anteriores mostram que o fluxo chegou a acionar "Gerar Arquivo"
(`log.txt:7`) e que o operador escolheu `imprimir_salvar_envio = Não`
(`log.txt:3`).

## 2. Causa raiz

`PR_JanelaVisivel` testa o bit errado da estilo de janela.

`scripts/protocolar.ahk:1390-1401`

```ahk
PR_JanelaVisivel(hwnd) {
    if !hwnd
        return false
    try return WinGetStyle("ahk_id " hwnd) & 0x1000000   ; WS_VISIBLE
    catch
        return false
}
```

O comentário diz `WS_VISIBLE`. O valor não é o de `WS_VISIBLE`:

| Constante | Valor | Significado |
|---|---|---|
| `WS_MAXIMIZE` | `0x01000000` (= `0x1000000`) | o que o código testa |
| `WS_VISIBLE` | `0x10000000` | o que o comentário nomeia |

Falta um zero. A função, portanto, não pergunta "a janela está visível?";
pergunta "a janela está maximizada?".

O fluxo validado de referência usa o valor correto, e é a única outra
implementação de visibilidade no material do operador:

`Praxis_TO-DO/Protocolar/protocolar.ahk:897-902`

```ahk
IsWindowVisible(hwnd) {
    try {
        style := WinGetStyle("ahk_id " hwnd)
        return (style & 0x10000000) != 0
    } catch {
```

Um diálogo "Salvar como" nunca é maximizado. Logo `PR_JanelaVisivel` devolve
`false` para **toda** janela, sempre.

### 2.1 Prova empírica

Reproduzindo o gate do `PR_JanelaVisivel` contra uma janela de diálogo comum
e não maximizada, com o próprio AutoHotkey v2 desta máquina:

```
classe ............: AutoHotkeyGUI
titulo ............: Salvar como
style (hex) .......: 0x94CA0000
WinGetMinMax ......: 0   (0 = normal, nao maximizada)

bit do codigo 0x1000000 (WS_MAXIMIZE) .......: inativo
bit correto  0x10000000 (WS_VISIBLE) ........: ATIVO

PR_JanelaVisivel() com o codigo atual .......: FALSE  <-- o gate reprova a janela
PR_JanelaVisivel() com o bit corrigido ......: true  <-- o gate aprova
```

O bit `0x1000000` está inativo numa janela normal e visível. O gate nunca
aprova nada. A classe do diálogo real (`#32770`, confirmada na captura do
operador) é irrelevante para este resultado: o que falha é o teste de estilo,
e ele falha para qualquer janela de diálogo.

### 2.2 O caminho de detecção

`scripts/protocolar.ahk:454-474`

```ahk
PR_EsperarJanelaSaveAs(timeoutSec) {
    startedAt := A_TickCount
    Loop {
        ...
        try lista := WinGetList("ahk_class #32770 ahk_exe " PR_EXE_SQL)
        catch
            lista := []

        for w in lista {
            if PR_JanelaVisivel(w)
                return w
        }
        ...
```

Este é o **único** filtro. Não há alternativa: o `for` itera a lista, o gate
sempre falha, o laço externo só termina por timeout, e o chamador converte
`0` em erro fatal.

`scripts/protocolar.ahk:291-293`

```ahk
salvar := PR_EsperarJanelaSaveAs(PR_SALVAR_TIMEOUT_SEG)
if (salvar = 0)
    return PR_Erro("O diálogo 'Salvar como' do EXECUTASQL.exe não apareceu em " PR_SALVAR_TIMEOUT_SEG "s.")
```

O filtro de classe estava certo. A captura do operador confirma:

`Praxis_TO-DO/Protocolar/images/Salvar Como/image1.png`

```
Window Title, Class and Process:  Salvar como
                                   ahk_class #32770
                                   ahk_exe EXECUTASQL.exe
Control Under Mouse Position:     ClassNN: Edit1
```

O diálogo realmente é `#32770` e realmente pertence ao `EXECUTASQL.exe`. Se o
gate de visibilidade estivesse correto, a detecção teria funcionado na
primeira iteração. **O bit é a causa, não a classe.**

## 3. Alcance do defeito

`PR_JanelaVisivel` é um gate de visibilidade reaproveitado em sete pontos.
Os cinco primeiros não têm alternativa:

| Linha | Função | Efeito com o gate quebrado |
|---|---|---|
| `341`, `350`, `359`, `368`, `379` | `PR_EsperarPopupRemessa` | fallbacks 2 a 6 do popup de remessa do FFCV ficam permanentemente mortos |
| `445` | `PR_EsperarJanelaSaveAs` | detecção do diálogo "Salvar como" morre (sintoma relatado) |
| `718` | `PR_EsperarPopupMv` | **fluxo de erro por conta morre** — ver abaixo |
| `994` | `PR_FecharRelatoriosDeFundo` | **janelas de relatório em segundo plano nunca são fechadas** |

Só o primeiro fallback de `PR_EsperarPopupRemessa` sobrevive, porque ele não
passa pelo gate:

`scripts/protocolar.ahk:349-355`

```ahk
try hwnd := WinExist(PR_WIN_FFCV_REMESSASQL)
catch
    hwnd := 0
if hwnd {
    try WinActivate("ahk_id " hwnd)
    return hwnd
}
```

É exatamente por isso que o fluxo chegou até "Gerar Arquivo" (`log.txt:7`) e
só morreu na etapa seguinte: a detecção do popup de remessa usou o único caminho
que ainda funciona, e a do "Salvar como" não tem caminho nenhum.

### 3.1 Consequência não relatada: toda conta é contada como aceita

Este é o item mais grave desta análise e **não está no TO-DO**.

`scripts/protocolar.ahk:631-644`

```ahk
PR_EnviarConta(conta)

popup := PR_EsperarPopupMv(PR_POPUP_CONTA_TIMEOUT_MS)
if (popup = 0) {
    ; Conta aceita: o MV não abre popup.
    resultado["aceitas"]++
    Progress(25 + Round(55 * indice / total))
    continue
}

; ── Fase 4 ─────────────────────────────────────────────
classificacao := PR_TratarPopup(cfg, conta, popup)
```

`PR_EsperarPopupMv` (`scripts/protocolar.ahk:747-764`) faz o mesmo
`if PR_JanelaVisivel(w)` e por isso **devolve `0` sempre**. A consequência é
direta: a linha `resultado["aceitas"]++` roda para **toda** conta, e
`PR_TratarPopup` — a Fase 4, que classifica documento pendente e setor recebido
e trata o popup não reconhecido — **nunca executa**.

Uma conta que o MV recusou com popup (documento pendente, setor não recebido) é
reportada como aceita, sem erro e sem pendência no relatório. Os contadores
`aceitas`/`pendentes`/`setores` do resumo_final não descrevem o que aconteceu
no MV.

> **Não existe "conta recusada" no Protocolar.** `PR_TratarPopup` tem dois ramos
> de recuperação (documento pendente, setor divergente) e um de não reconhecido,
> e só esses. Não há ramo de recusa: uma conta sem popup é **aceita**, e um popup
> reconhecido é corrigido e reprocessado. A palavra "recusada" neste documento
> descreve o efeito observável — conta que não devia ter entrado e entrou —, não
> um ramo do código.

Isto é falha silenciosa no sentido do `AGENTS.md`: produz resultado errado sem
erro visível, e a automação continua como se estivesse saudável.

## 4. Correção proposta

### 4.1 Correção mínima, obrigatória

`scripts/protocolar.ahk:1398` — um caractere:

```ahk
    try return WinGetStyle("ahk_id " hwnd) & 0x10000000   ; WS_VISIBLE
```

Confirma a correção contra o fluxo validado, que é a fonte da origem correta
do valor. Nenhum outro ponto do arquivo precisa mudar: os sete chamadores
passam a funcionar como sempre pretenderam.

### 4.2 Correção de robustez, recomendada junto

O TO-DO pede para "verificar por que não está detectando". Corrigir o bit
resolve esta estação, mas deixa a detecção com uma estratégia só, apoiada em
`ahk_class #32770` + `ahk_exe`. O fluxo validado tem cinco, e a justificativa
dele está no próprio código:

`Praxis_TO-DO/Protocolar/protocolar.ahk:239-240`

> *"O popup de Remessa do FFCV pode ficar com título/classe inconsistentes no
> Windows Server. Por isso ele é localizado pelos controles reais do popup, não
> só por ahk_class/ahk_exe."*

O `PR_EsperarPopupRemessa` (`scripts/protocolar.ahk:333-412`) preserva essa
filosofia com cinco fallbacks; o `PR_EsperarJanelaSaveAs` não. Propõe-se
portar a mesma estrutura: um predicado único de identificação do diálogo
equivalente ao `IsSaveAsWindow` validado
(`Praxis_TO-DO/Protocolar/protocolar.ahk:1013-1051`), mais a cadeia:

1. janela ativa, se casar com o predicado;
2. `WinExist("Salvar como ahk_exe " PR_EXE_SQL)`, se casar;
3. varredura das janelas do `EXECUTASQL.exe`, se casar;
4. busca por controles (`Edit1` + `Button2`/`Button3` + texto "Salvar em:").

O predicado é o owner do contrato de janela, então vive em `mv_session.ahk`
com prefixo `MV_` (regra 4 do `AGENTS.md`) se acabar servindo a outro fluxo; caso
contrário, `PR_IsSaveAsWindow` em `protocolar.ahk` basta. Não decidir isso sem
ver se `fechar_xml.ahk` também precisa do predicado.

Justificativa para sair do padrão de "uma estratégia só": o padrão existente
**é** a cadeia de fallbacks, e ela foi preservada no `PR_EsperarPopupRemessa`.
O `PR_EsperarJanelaSaveAs` é a exceção, não o padrão.

### 4.3 Constantes do diálogo — sem mudança

`scripts/protocolar.ahk:81-82`

```ahk
PR_SALVAR_CAMPO_NOME    := "Edit1"
PR_SALVAR_BTN_CONFIRMAR := "Button2"   ; botão Salvar do diálogo clássico
```

A captura do operador confirma `Edit1` no campo de nome. Não alterar.

## 5. Validação

### 5.1 Sem o MV2000i — possível

- **Prova empírica do gate**, já executada: reproduzir `PR_JanelaVisivel` contra
  uma janela de diálogo comum e observar que o bit `0x1000000` está inativo e
  o `0x10000000` ativo. É o caminho reproduzível que originou a seção 2.1.
- **Build e integridade**, conforme o gate do `AGENTS.md`:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller
  $p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" `
       -ArgumentList '--integrity-check' -Wait -PassThru; $p.ExitCode
  ```

  Precisa sair `0` (`70` = recurso ausente ou alterado).

- **Conferência estática** de que nenhum outro gate de visibilidade ficou com
  o bit antigo:

  ```powershell
  Select-String -Path scripts\*.ahk -Pattern 'WinGetStyle'
  ```

### 5.2 Exige o MV2000i real — obrigatório

O build e o `--integrity-check` **não** provam comportamento; provam sintaxe,
include e asset. Este bug é de execução e não aparece em nenhum dos dois.

Checklist no MV, com o Protocolar e `imprimir_salvar_envio = Sim`:

1. O diálogo "Salvar como" é detectado e preenchido; o CSV é gerado.
2. **`PR_EsperarPopupMv` passa a devolver o hwnd quando há popup.** Este é o
   item que valida a seção 3.1 e **não** aparece no sintoma original — se
   continuar devolvendo `0`, o gate não foi o único problema.
3. O `Fase 4` (`PR_TratarPopup`) executa: uma conta que o MV barra com popup de
   documento pendente ou de setor divergente aparece como pendência/setor
   corrigido no relatório, e não como aceita.
4. `PR_FecharRelatoriosDeFundo` fecha a janela do `RWRBE60.EXE`.
5. Os cinco fallbacks de `PR_EsperarPopupRemessa` respondem, se a cadeia de
   4.2 foi implementada.

Sem o MV, o que está escrito aqui permanece análise de código, e é assim que
deve ser tratado.

## 6. PENDENTE

- **Nenhum para a causa raiz.** O bit está provado por execução.
- Se a cadeia de 4.2 for implementada: o predicado `MV_IsSaveAsWindow` aceita
  **apenas** `#32770`, ou também janela de outra classe? O validado
  (`IsSaveAsWindow`, linha 1046-1048) tem um fallback por geometria que aceita
  janela sem exigir a classe. Confirmar com o operador antes de promover esse
  fallback, porque aceitar classe errada abre a porta para o
  `MV_ClickBySpec` clicar no lugar errado (ver
  [doc 06](06-sistematico-origem-das-constantes.md#3-mv_clickbyspec-clique-cego-por-coordenada)).
