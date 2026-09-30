# Fechar&XML — a data é passada em formato americano

> TO-DO de origem: `Praxis_TO-DO/Fechar&XML/TO-DO.txt:2`
> *"Também o código está passando a data em formato americano ao invés de formato
> brasileiro"*

**Natureza:** bug. **Causa raiz:** fechada e **confirmada pelo operador**.
**Prioridade:** 1ª da lista — ver [README](README.md#ordem-de-ataque-sugerida).

---

## 1. Sintoma e escopo real

O operador confirmou que **o MV2000i não aceita `YYYY-MM-DD`**: o campo da tela
`Cadastro: Fatas e Remessas` exige `dd/mm/aaaa`, e o valor em ISO é recusado.

Isso fecha a questão de gravidade, e a resposta é melhor do que a hipótese mais
pesada deste documento previa. Três sintomas eram possíveis:

1. O MV **rejeita** a data e a remessa não fecha. ← **é este**
2. O MV **aceita** a data e a remessa fecha com a data errada. — descartado
3. O MV **aceita** a data e o XML sai com a data errada. — descartado

Os casos 2 e 3 eram os preocupantes: falha silenciosa no sentido do `AGENTS.md`,
com a data errada indo para o faturamento e para o XML enviado à operadora.
**Estão descartados.** O defeito é um fluxo que falha, não um dado que mente.

### 1.1 A consequência real é mais grave que o sintoma

O caso 1 tem um efeito que o TO-DO não menciona: **o módulo Fechar&XML não
consegue concluir execução nenhuma.**

`main.ahk:82-88`

```ahk
Map(
    "id",        "fechar_xml",
    ...
    "params", [
        Map("id","remessas",      "label","Número das Remessas",
            "tipo","text", "obrigatorio",true, ...),
        Map("id","data_entrega",  "label","Data de Entrega",
            "tipo","date", "obrigatorio",true),
        Map("id","data_vencimento","label","Data de Vencimento",
            "tipo","date", "obrigatorio",true)
    ]
)
```

As duas datas são **obrigatórias**. Não existe caminho em que o operador
execute o Fechar&XML sem preenchê-las, nem caminho em que a data chegue ao
FFCV no formato aceito. Com o defeito presente, o módulo está bloqueado por
completo — não degradado.

Duas consequência que valem explicitar:

- **A correção é a menor possível e o retorno é o maior possível**: uma função
  de string. Nenhuma outra parte do Fechar&XML precisa mudar para o módulo
  voltar a funcionar. Por isso este documento sobe para 1ª prioridade.
- **A recusa provavelmente mascarou a divergência 4** do
  [doc 02](02-fechar-xml-divergencia-do-validado.md). Ver seção 1.2.

### 1.2 A data errada provavelmente explica a confusão da divergência 4

Esta é a ligação mais útil entre os dois documentos, e muda o que deve ser
observado no MV depois da correção do formato.

O Fechar&XML envia a data ISO e o MV a recusa. **Onde** ele recusa, e o que
aparece na tela em seguida, não está verificado. Duas possibilidades, com
consequências bem diferentes:

- **A recusa acontece no campo**, ao sair dele com `Enter` — que é o que
  `scripts/fechar_xml.ahk:225` faz logo depois de `SendText dataEntrega`. Nesse
  caso o modal **abre antes** de `FX_ConfirmarFechamento` chegar lá, e essa
  função não checa modal durante o preenchimento (`:195-232`). O modal ficaria
  aberto, e `FX_EsperarQualquerModal` em `:260` o encontraria;
  `FX_ResponderNaoModal` (`:304-315`) então clicaria `Button2` ("Não") **num
  modal de erro**, não numa confirmação.
- **A recusa acontece no `Button10`**, já na confirmação da entrega. Aí o fluxo
  se comporta como projetado e o modal cai no tratamento de "recusada"
  (`:291-299`), que registra pendência e segue para a próxima remessa.

Em ambos os casos, a tela que o operador está vendo **não é a tela para a qual
o código foi escrito**. É por isso que a divergência 4 do
[doc 02](02-fechar-xml-divergencia-do-validado.md#23-a-divergência-4-depende-do-doc-03-e-não-pode-ser-alinhada-antes)
parece contraditória: talvez não seja o modal de sucesso com `Button1` que o
validado espera, nem o Sim/Não que o Praxis espera, e sim um terceiro diálogo
que só existe por causa do formato da data.

**Isso é hipótese, não conclusão**, e está na seção de PENDENTE. Mas muda a
ordem de trabalho: corrigir o formato primeiro e só então observar qual tela
aparece depois do `Button10`. A pergunta da divergência 4 pode se responder
sozinha, ou revelar que estava mal formulada.

**O defeito não é exclusivo do Fechar&XML.** O mesmo parâmetro alimenta o
fluxo Remessa por Protocolo. Ver seção 4.

## 2. Causa raiz

### 2.1 A UI entrega ISO 8601, por especificação

`ui/index.html:329-332`

```js
} else {
    input = `<input class="form-input" type="${p.tipo}" id="p-${p.id}"
             ${req?'required':''} ${hint?`placeholder="${esc(hint)}"`:''}>`;
}
```

Com `tipo` = `"date"` (declarado em `main.ahk:46-49` e `main.ahk:84-87`), isto
produz `<input type="date">`.

O atributo `value` de um `<input type="date">` é **sempre** `YYYY-MM-DD`, por
especificação HTML, **independente do locale do navegador**. O WebView2 exibe
o seletor em português (`<html lang="pt-BR">`, `ui/index.html:2`) e continua
entregando `2026-09-30`. O que o operador vê no seletor e o que o AHK recebe
não são o mesmo formato, e o cache não é a fonte do problema.

### 2.2 O valor atravessa três camadas sem transformação

`ui/index.html:347-360`

```js
function collectParams() {
  const params = {};
  for (const p of current.params) {
    const el  = document.getElementById(`p-${p.id}`);
    const val = el?.value?.trim() ?? '';
    ...
    params[p.id] = val;
  }
  return params;
}
```

`main.ahk:266` repassa o objeto cru para `RunScript`, e
`scripts/fechar_xml.ahk:48-49` só aplica `Trim`:

```ahk
dataEntrega    := Trim(params["data_entrega"])
dataVencimento := Trim(params["data_vencimento"])
```

`Trim("2026-09-30")` é `"2026-09-30"`.

### 2.3 A string ISO é digitada no campo de data do Oracle Forms

`scripts/fechar_xml.ahk:221-228`

```ahk
Send("{Tab}")
Sleep MV_KEY_SETTLE_MS
SendText dataEntrega          ; "2026-09-30"
Sleep MV_KEY_SETTLE_MS
Send("{Enter}")
Sleep MV_KEY_SETTLE_MS
SendText dataVencimento       ; "2026-09-30"
```

O campo do Oracle Forms espera `dd/mm/aaaa`. É isso que o operador vê.

### 2.4 Por que o fluxo validado não tinha esse problema

O `Fechar&XML.ahk` validado **não usava seletor de data**. Usava um campo de
texto comum, com o formato no tooltip:

`Praxis_TO-DO/Fechar&XML/Fechar&XML.ahk:42-47`

```ahk
gGui.AddText("xm y+12", "Data de pagamento:")
gPagamento := gGui.AddEdit("x+8 w120")
gPagamento.ToolTip := "Formato: dd/mm/aaaa"
gGui.AddText("x+18", "Data de vencimento:")
gVencimento := gGui.AddEdit("x+8 w120")
gVencimento.ToolTip := "Formato: dd/mm/aaaa"
```

Ou seja: no fluxo validado, **o contrato do parâmetro era "`dd/mm/aaaa`
digitado por uma pessoa"**, e o operador simplesmente não podia errar o
formato, porque o campo aceitaria e ele via o que digitou.

**A causa raiz é essa:** a migração da UI de `Gui` do AutoHotkey para WebView2
trocou a origem do parâmetro de "texto digitado por humano" para "data escolhida
em seletor nativo", e o contrato do parâmetro não foi re-especificado. O
consumidor (`SendText` no campo do Forms) continuou esperando `dd/mm/aaaa`
porque era isso que recebia antes. A divergência não está no AHK nem no HTML:
está na fronteira, no momento em que o valor muda de dono.

## 3. A evidência de que não há defesa em lugar nenhum

Vale registrar o que **não** existe, porque a ausência é o que permite o
defeito chegar até o FFCV:

- **Nenhuma validação de formato** no `RunFecharXML`. As checagens em
  `scripts/fechar_xml.ahk:51-56` verificam apenas se a string está vazia.
- **Nenhuma asserção de leitura de volta das datas.** O padrão já existe no
  arquivo para o número da remessa (`scripts/fechar_xml.ahk:208-219`) e é
  justamente ele que teria pegado isto:

  ```ahk
  if (remessaTela = remessaParam)
      Notify("Conferência: a tela de datas mostra a remessa " remessaTela ".")
  else
      Notify("Atenção: parâmetro " remessaParam " x tela de datas " remessaTela ...)
  ```

  O número da remessa tem conferência de ida e volta. As duas datas, não.
- **Nenhuma rejeição pelo MV** é garantida. Não se pode afirmar que o MV
  sempre rejeite ISO; pode em parte dos casos, pode nunca. Não verificado.

## 4. Alcance: dois de três módulos

O mesmo defeito de contrato existe em `Remessa por Protocolo`.

`main.ahk:46-49` — parâmetros de `remessa_protocolo`:

```ahk
Map("id","data_entrega",   "label","Data de Entrega",
    "tipo","date",   "obrigatorio",false),
Map("id","data_vencimento","label","Data de Vencimento",
    "tipo","date",   "obrigatorio",false)
```

`main.ahk:84-87` — parâmetros de `fechar_xml`, ambos `"tipo","date"`,
ambos obrigatórios.

O consumo em `remessa_protocolo.ahk`:

`scripts/remessa_protocolo.ahk:129-130`

```ahk
dataEntrega  := params["data_entrega"]
dataVenc     := params["data_vencimento"]
```

que chega a `FinalizarComDatas` (`:220`) → `RP_PreencherDatasEntregaPorTeclado`
(`:1168`), com a mesma mecânica de `SendText` no mesmo campo do FFCV.

`protocolar` não é afetado: não tem parâmetro de data.

## 5. Correção proposta

### 5.1 Onde normalizar: camada compartilhada, não no módulo

A correção é um helper único em `scripts/mv_session.ahk`, chamado antes de
qualquer escrita em campo de data do Oracle Forms:

```ahk
; Converte a data que chega da UI (HTML <input type="date">) para o formato
; que o Oracle Forms espera nos campos de data.
MV_NormalizarDataBr(valor) { ... }
```

**Por que no AHK e não no JavaScript.** A alternativa é converter no
`collectParams` (`ui/index.html:347`). Ela foi descartada por duas razões:

1. **A definição de parâmetro está duplicada.** `gScripts` em `main.ahk:30` e
   `devSim()` em `ui/index.html:423` descrevem os mesmos scripts. Uma regra de
   formatação no JS precisaria ser aplicada nos dois lugares, e a
   `AGENTS.md` regra 4 manda procurar área compartilhada antes de criar, e a
   regra 2 proíbe padrão paralelo. Normalizando no AHK, a entrada duplicada
   continua irrelevante: os dois lados entregam a mesma string ISO e uma função
   a trata.
2. **O date picker nativo é uma coisa boa.** `type="date"` dá validação e
   navegação por teclado no WebView, que um `AddText`+`AddEdit` do AutoHotkey
   não daria. Trocar o controle para preservar a formatação no cliente seria
   voltar atrás na qualidade de UI para tapar um bug de string.

A normalização pertence ao contrato de janela do MV, que é o owner do formato
dos campos do Oracle Forms — daí o prefixo `MV_` (regra 4 da `AGENTS.md`).

### 5.2 Onde chamar

Nos dois consumidores, imediatamente antes do preenchimento:

- `scripts/fechar_xml.ahk` — em `FX_PreencherDatasPorTeclado` (`:195`),
  sobre os dois parâmetros, antes do `SendText` de `:223` e `:227`.
- `scripts/remessa_protocolo.ahk` — em `RP_PreencherDatasEntregaPorTeclado`
  (`:1224`), chamado por `FinalizarComDatas` (`:1168`).

Um helper só, dois chamadores — o que a regra 1 da `AGENTS.md` pede e o que a
regra 5 proíbe parcelar.

**Regra de robustez do helper:** aceitar `dd/mm/aaaa` sem alterar. Um
`config.ini` antigo, um `RunFecharXML` disparado por outro caminho ou um futuro
`<input type="text">` não podem passar a falhar por causa de uma normalização
introduzida para corrigir a UI. Se o valor já estiver em `dd/mm/aaaa`,
devolvê-lo inalterado.

### 5.3 A defesa que faltava: asserção de leitura de volta

O padrão de `scripts/fechar_xml.ahk:208-219` deve ser estendido às duas datas.
A tela `Cadastro: Fatas e Remessas` já é focada e o valor pode ser lido depois
do preenchimento.

Sem isso, uma futura regressão de formato volta a ser silenciosa. Com o padrão
já existente no arquivo, o custo é pequeno e a proteção é real: o operador vê
no log `parâmetro 2026-09-30 x tela 30/09/2026` no momento da divergência, em
vez de descobrir na remessa.

Esta é a parte da correção que pertence à regra 3 da `AGENTS.md` — o problema
de validação, não o de formatação.

## 6. Validação

### 6.1 Sem o MV2000i — possível, e com folga

Este é o único documento desta análise em que dá para provar o defeito inteiro
**sem o MV2000i**, porque o defeito está inteiramente entre a WebView e a
string, e não no MV.

- **Comprovação do formato na UI**, no app em modo dev
  (`& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" ".\main.ahk"`,
  que lê `ui\index.html` do disco e usa `devSim()`): selecionar 30/09/2026 nos
  campos de data e conferir em `devtools` — ou, sem devtools, no log, que hoje
  já mostra o valorcru em `Notify` (`scripts/fechar_xml.ahk:230`):
  `Datas enviadas por teclado: entrega 2026-09-30, vencimento 2026-09-30.`
  Essa linha é a evidência mais barata que existe do defeito.
- **Teste do helper isolado**, sem UI: o `MV_NormalizarDataBr` é função pura de
  string, sem dependência de MV nem de janela. Rodar a tabela de casos
  diretamente no interpretador.
- **Build + `--integrity-check`**, gate do `AGENTS.md`:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller
  $p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" `
       -ArgumentList '--integrity-check' -Wait -PassThru; $p.ExitCode
  ```

### 6.2 Exige o MV2000i real — obrigatório

O build e a leitura do log provam que a string estava errada. **Não provam que
a data gravada ficou errada**, e essa é a parte que importa.

1. Fechar uma remessa de teste com data conhecida e conferir no FFCV, na tela
   de consulta, qual data de entrega e de vencimento foram efetivamente
   gravadas.
2. Gerar o XML e abrir o arquivo: a data no XML é a esperada?
3. Fazer o mesmo pelo Remessa por Protocolo, que é o segundo consumidor.
4. Conferir que a asserção de leitura de volta dispara quando a data está de
   fato errada — um teste que só passa com o dado bom não prova que a
   verificação funciona.

## 7. PENDENTE

**Respondido — registrado aqui para não ser perguntado de novo:** o MV2000i
**não aceita** `YYYY-MM-DD` em campo `dd/mm/aaaa`. Confirmado pelo operador. A
correção da seção 5 está confirmada como necessária; o caso grave de dado
errado em silêncio está descartado.

- **Onde exatamente o MV recusa a data** — no campo, ao sair com `Enter`, ou no
  `Button10`? Isso é o que decide se o modal de erro aparece antes ou depois de
  `FX_ConfirmarFechamento`, e portanto se a divergência 4 do
  [doc 02](02-fechar-xml-divergencia-do-validado.md) é uma pergunta real ou um
  artefato deste bug. Ver seção 1.2. **Só o MV responde.**
- **O FFCV mostra a data reinterpretada ou a string crua na tela?** Se mostrar
  a string crua, a leitura de volta da seção 5.3 funciona sem ambiguidade. Se
  reinterpretar, a leitura de volta precisa de validação semântica, como o
  `RP_GridValueValid` faz para as grid do MOV DOC
  (`scripts/remessa_protocolo.ahk:566-577`). **Só o MV responde.**
- **O que o `Protocolar` envia para o FFCV** não passa por este caminho e não
  foi verificado. Fora do escopo deste documento.
