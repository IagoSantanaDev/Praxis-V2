# Análise de causa raiz — TO-DO do Praxis

> Resultado da análise dos apontamentos de `Praxis_TO-DO/` contra o código do
> repositório, o fluxo validado de referência e as capturas de tela do operador.

Cada documento responde a um item do `Praxis_TO-DO/`, com evidência citada
(`arquivo:linha`, print de Window Spy, linha de log), causa raiz, correção
proposta e validação separada entre o que dá para provar sem o MV2000i e o que
exige o sistema real.

**Esta análise não validou automação.** Nenhum documento aqui é resultado de
execução contra o MV2000i. São leitura de código, das capturas fornecidas e
comparação com o fluxo validado. A validação de automação continua sendo a do
`AGENTS.md`: build + `--integrity-check` **e** execução contra o MV real.

## Documentos

| Doc | TO-DO de origem | Assunto | Natureza |
|---|---|---|---|
| [01](01-protocolar-salvar-como-nao-detectado.md) | `Protocolar/TO-DO.txt:1` | diálogo "Salvar como" nunca detectado | bug, causa fechada |
| [02](02-fechar-xml-divergencia-do-validado.md) | `Fechar&XML/TO-DO.txt:1` | alinhar ao Fechar&XML validado | bug, 7 divergências |
| [03](03-fechar-xml-data-formato-americano.md) | `Fechar&XML/TO-DO.txt:2` | data em formato americano | bug, causa fechada e confirmada |
| [04](04-remessa-protocolo-ctrl-q-nao-sai.md) | `Remessa_Protocolo/Erro.txt:11` | `^q` não sai da tela de baixa | bug, causa fechada |
| [05](05-remessa-protocolo-coluna-devolvido.md) | `Remessa_Protocolo/TO-DO.txt:1` | coluna "Devolvido" | feature, não é bug |
| [06](06-sistematico-origem-das-constantes.md) | transversal | origem das constantes não é versionada | sistêmico |

## A fonte da verdade de cada fluxo

Onde existe um fluxo validado pelo operador, ele **manda**, e o módulo do
Praxis é que se alinha. O arquivo de referência não é editado.

| Fluxo | Referência validada | Alvo do alinhamento |
|---|---|---|
| Fechar&XML | `Praxis_TO-DO/Fechar&XML/Fechar&XML.ahk` | `scripts/fechar_xml.ahk` |
| Protocolar | `Praxis_TO-DO/Protocolar/protocolar.ahk` | `scripts/protocolar.ahk` |
| Remessa por Protocolo | `Praxis_TO-DO/Protocolar/protocolar.ahk` (seção MovDoc) | `scripts/remessa_protocolo.ahk` — já é o fluxo validado |

Os dois primeiros têm divergências a alinhar. Cada uma delas é respondida pelo
próprio arquivo de referência — inclusive as duas que primeiro ficaram em
PENDENTE por parecerem decisão de projeto (navegação e relatório de entrega) e
se resolveram na leitura.
por parecerem decisão de projeto (navegação e relatório de entrega) e se
resolveram na leitura.
[doc 02, seção 8](02-fechar-xml-divergencia-do-validado.md#8-pendente).

## O item 2 do TO-DO do Protocolar: não há divergência de fluxo

`Praxis_TO-DO/Protocolar/TO-DO.txt:2` reclama que o Protocolar "não está
funcionando igual ao `Protocolsr.ahk`". As duas fases foram comparadas com o
validado, e **as duas batem estruturalmente**:

| Fase | Projeto | Validado | Veredito |
|---|---|---|---|
| FFCV | `PR_Fase1GerarPlanilha:214` — `!e`, `Enter 2`, `Down 121`, `!1`, popup, remessas, `TBitBtn2` | `RunFFCV:211-276` — mesma sequência, mesmas coordenadas `(548, 91)` | **equivalente** |
| MOV DOC | `PR_AbrirTelaEnvio:639` / `PR_EnsureTelaEnvio:656` / `PR_ConfigurarTelaEnvio:669` — `mpe`, `Button2`, `{Tab 2}`, ajuste Hospitalar | `OpenEnvioScreen:311` / `EnsureEnvioScreen:360` / `SetupEnvioScreen:328` — idêntico | **equivalente** |
| Envio da conta | `PR_EnviarConta:702` (`SendText` + `Enter`) | `ProcessConta:390` (cola + `Enter`) | **equivalente** |
| Finalização | `PR_Fase5Finalizar:927` — exclui registro em branco, depois `!1` se imprimir | `FinalizarProtocoloMovDoc:511` / `FinalizarSemImprimirSalvarEnvio:407` — mesma bifurcação | **equivalente** |

**Conclusão: o sintoma do item 2 tem a mesma causa do item 1** — o bit de
visibilidade em [doc 01](01-protocolar-salvar-como-nao-detectado.md), e
principalmente a consequência não relatada da seção 3.1 daquele documento:
`PR_EsperarPopupMv` sempre devolve `0`, então toda conta é contada como
aceita e `PR_TratarPopup` **nunca executa**. O operador *parece* ver o fluxo
funcionar, mas nenhuma conta é validada.

Por isso **não há um documento de alinhamento para o Protocolar**: não há o que
alinhar. O que existe é o [doc 01](01-protocolar-salvar-como-nao-detectado.md).

## Ordem de ataque sugerida

A ordem não é por número de documento. É por custo de não agir.

### 1º — doc 03, a data em formato americano

Causa fechada **e confirmada pelo operador**: o MV2000i não aceita `YYYY-MM-DD`.
Como as duas datas são obrigatórias (`main.ahk:82-88`), isso significa que o
módulo Fechar&XML **não conclui execução nenhuma** enquanto o defeito
existir. A correção é uma função de string, e o retorno é o maior possível de
toda esta lista.

### 2º — doc 01, o bit de visibilidade

Correção de um caractere, e o único item com **prova empírica** de execução.
Além do "Salvar como" relatado, ele tem duas consequências não relatadas que
são piores que o sintoma original: o **fluxo de tratamento de erro por conta
está morto** (toda conta é contada como aceita) e as **janelas de relatório em
segundo plano nunca são fechadas**.

### 3º — doc 04, o `^q`

Duas correções independentes, e a segunda é a que explica o sintoma. A
constante de janela do MOV DOC (`MV_WIN_MOVDOC_BAIXA`) casa **dentro dos
colchetes** do título MDI e resolve para a raiz, enquanto a do FFCV casa fora e
resolve certo — é por isso que `^q` funciona numa etapa e não na outra. Além
disso, a verificação é estruturalmente incapaz de reportar a falha, então o log
mente sobre o resultado.

### 4º — doc 02, o alinhamento ao Fechar&XML validado

Maior volume de trabalho, e **não é paralelo**: D3 e D4 mexem no mesmo trecho
de preenchimento de datas do doc 03, e a divergência 4 depende de observar o
diálogo *depois* da data estar correta. Um ciclo de validação por divergência,
na ordem da seção 5.1 do próprio doc.

### 5º — doc 05, a coluna "Devolvido"

Feature, não correção. Depende de uma captura de Spy para promover a
coordenada X a constante.

### 6º — doc 06, a origem das constantes

Não é bug, é a condição que permitiu os demais. Trate como trabalho de
manutenção contínua, não como entrega.

## Convenções usadas nos documentos

Os documentos marcam o grau de certeza de cada afirmação, e o vocabulário é
deliberado:

- **Provado** — decorre do código, de uma execução ou de uma captura do
  operador. Não depende do MV2000i.
- **Inferido** — a evidência aponta para uma explicação, mas outra também
  explicaria o mesmo sintoma.
- **PENDENTE** — só o MV2000i real decide. Registrado com a pergunta
  específica a responder, nunca com um palpite preenchido.

Nenhuma constante de automação é promovida a fato a partir de dedução. Onde a
evidencia é uma captura parcial, o documento diz qual é a lacuna.

## Divergência deliberada em relação ao fluxo validado

Um ponto que não é bug e que este conjunto de documentos registra de propósito,
porque a leitura natural dos arquivos induz ao erro:

O `Praxis_TO-DO/Protocolar/protocolar.ahk` (validado) fecha a tela da baixa
com `^q` **e depois** `{Enter}` (`protocolar.ahk:1124-1134`, comentário
explícito "Fluxos como a baixa usam Ctrl+Q e depois Enter"). O Praxis envia
**`^q` puro**. Isso está confirmado pelo operador como correto e **não deve ser
"corrigido"** para incluir o `Enter`. Ver [doc 04](04-remessa-protocolo-ctrl-q-nao-sai.md).

## Material de origem

`Praxis_TO-DO/` e `Praxis_TO-DO.zip` são material de referência local e
continuam fora do versionamento (regra 8 do `AGENTS.md`). Este diretório passa
a ser o registro dos achados; o `Praxis_TO-DO/` é a fonte de evidência bruta.
