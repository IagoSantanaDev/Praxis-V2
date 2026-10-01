# Sistêmico — a origem das constantes não é versionada, e há um amplificador cego

> TO-DO de origem: transversal. Não está no `Praxis_TO-DO/`; emerge da leitura
> dos outros quatro documentos.
>
> **Natureza:** condição sistêmica, não bug isolado. **Prioridade:** 6ª — ver
> [README](README.md#ordem-de-ataque-sugerida).

---

## 1. O problema

### 1.1 As 34 citações de origem apontam para caminhos ignorados pelo Git

A regra 9 da `AGENTS.md` exige que toda constante de automação registre a
origem, e o padrão do repositório é exemplar nesse ponto. O problema é para onde
a origem aponta.

| Arquivo versionado | Citações a `.agents/` ou `Fluxos/` |
|---|---|
| `scripts/protocolar.ahk` | 25 |
| `scripts/mv_session.ahk` | 5 |
| `scripts/fechar_xml.ahk` | 3 |
| `scripts/remessa_protocolo.ahk` | 1 |
| **total** | **34** |

E os dois caminhos estão no `.gitignore`:

- `.gitignore:16` — `.agents/`
- `.gitignore:35` — `Fluxos/`

Neste checkout existe exatamente **um** arquivo sob `.agents/`:
`LEARNINGS.md`, que é memória local de agente e não faz parte do repositório
por desenho. `Fluxos/` não existe.

Resultado: **em um clone novo, nenhuma das 34 origens pode ser conferida.** Não
há como responder "de onde veio esta coordenada" sem a máquina de quem
escreveu. A `AGENTS.md` já sinaliza isso para `.agents/`, mas o código continua
citando esses caminhos como "fonte versionada", e essa é a incoerência que
importa:

`scripts/mv_session.ahk:60-62`

```ahk
; ── Controles tela de datas ───────────────────────────────────
; Tela "Cadastro: Faturas e Remessas". Coordenadas Client vindas de Window Spy.
; Fonte versionada: .agents/workflows/01-remessa-protocolo.md (seção Constantes).
; Capturas originais stão em Fluxos/, que é gitignored e não existe neste checkout.
```

O terceiro aviso está certo. O segundo chama de versionada uma coisa que não é.

O caso mais consequente é o spec que originou as sete divergências do Fechar&XML:

`scripts/fechar_xml.ahk:16`

```ahk
; Spec: .agents\workflows\03-fechar-xml.md
```

Documento de especificação do módulo **financeiro**, citado como autoridade das
decisões, inexistente para qualquer pessoa que não seja o autor. Ver
[doc 02](02-fechar-xml-divergencia-do-validado.md#3-por-que-as-divergências-existem).

### 1.2 Por que isso é a condição que produziu os outros achados

O padrão de citação de origem é bom, e é justamente isso que faz o problema
agudo. Uma constante com origem verificável é auditável: alguém abre a captura,
confere o pixel, e o erro aparece antes de rodar. Uma constante cuja origem
morreu com o clone só pode ser aceita por confiança.

A cadeia é a seguinte, e cada elo existe neste repositório:

1. A constante tem uma origem declarada, mas a origem não é versionada.
2. A constante não pode ser auditada, então ninguém a audita.
3. O valor errado sobrevive à revisão, ao build e ao `--integrity-check`, que
   verificam sintaxe e hash de recurso — nunca semântica de automação.
4. O valor errado só se manifesta contra o MV2000i, com um sintoma que nem
   sempre é óbvio.

Os quatro bugs com causa fechada desta análise são instances desse caminho.
O mais barato de corrigir foi o `0x1000000` de
[doc 01](01-protocolar-salvar-como-nao-detectado.md) — uma constante com origem
viva, o fluxo validado no mesmo repositório, e ainda assim passou. Uma
referência interna que se contradiz com o próprio material validado.

## 2. O que este documento não propõe

**Não propõe gate novo de CI.** A `AGENTS.md` é explícita:

> Não existe test suite, linter nem CI — e o build não prova comportamento.
> **Não invente um gate novo.**

Um gate que verificasse "esta constante tem origem versionada" seria
inventar um gate. E seria inútil: ele passaria, porque a origem
*existe* — ela apenas não está no repositório.

## 3. `MV_ClickBySpec`: clique cego por coordenada

Este item não é uma origem morta. É o mecanismo que **converte** uma
constante errada em ação errada sem erro, e por isso aparece em três dos
outros documentos.

`scripts/mv_session.ahk:760-781`

```ahk
MV_ClickBySpec(winTitle, classNN, x, y) {
    if (classNN = "" || classNN = "CLASSNN" || x = "" || y = "")
        return false

    ; Igual ao teste 12: localizar controle por ClassNN + ponto Client com tolerância 20.
    if MV_ClickControlAt(winTitle, classNN, x, y, 20)
        return true

    if !WinExist(winTitle)
        return false

    try {
        WinActivate winTitle
        if !MV_Poll(() => WinActive(winTitle), 3)
            return false
        CoordMode("Mouse", "Client")
        Click(x, y, 1)
        return true
    } catch {
        return false
    }
}
```

A intenção é razoável: degradar para coordenada quando o `ClassNN` não
resolve, porque o ponto Client veio do mesmo Window Spy e provavelmente
aponta para o lugar certo. O efeito é o oposto da segurança: **a
degradação é indistinguível do sucesso.**

O contrato real da função é: "ou clico o controle, ou clico no ponto, ou
falo que falhei". O contratável: "ou clico o controle, ou clico no ponto, e
nunca falho". Um chamador não consegue distinguir `true` por controle de
`true` por coordenada, e a função **não loga qual dos dois aconteceu**.

Onde isso já pesa:

- `scripts/fechar_xml.ahk:551` e `:764` — `MV_XML_FORM_BTN_VOLTAR`, cujo `ClassNN`
  é `Button7` e cuja tela, na única captura disponível, tem quatro botões e
  nenhum "Voltar" (ver
  [doc 02, seção 6](02-fechar-xml-divergencia-do-validado.md#6-capturas-em-images-fora-de-escopo)).
  O clique cego cai em `(731, 470)`.
- `scripts/protocolar.ahk:287`, `:382`, `:392` — `PR_FFCV_BTN_GERAR_ARQUIVO`
  (`TBitBtn2`).
- `scripts/fechar_xml.ahk:520`, `:541` — botão Faturamento e botão Salvar da
  tela XML.

> `FX_BTN_ABRIR_DATAS` (`Button6`, "5 - Entregar Rem.") aparecia nesta lista e
> **não existe mais**: foi removido junto com o hop por Manutenção de Remessa
> (`scripts/fechar_xml.ahk:37-39`).

Em todos esses, um `ClassNN` que deixa de casar **não produz erro**. Produz um
clique no ponto, e o fluxo segue como se tivesse clicado no botão.

### 3.1 Por que não é para mexer agora

Dois motivos, e o segundo é o que manda.

**Primeiro:** o fallback não é o defeito. O defeito é a constante errada, que
é assunto de [doc 02](02-fechar-xml-divergencia-do-validado.md). Remover o
fallback agora transforma um clique errado silencioso em erro explícito — o que
é bom, mas expõe a constante errada que hoje está produzindo resultado
aparentemente correto, e isso pode ser lido como regressão do fluxo que
funciona.

**Segundo, e mais importante:** `remessa_protocolo.ahk` **rodou contra o
MV2000i** usando `MV_ClickBySpec` em vários pontos, incluindo o
`FFCV_BTN_ABRIR_DATAS`. O fallback pode ter sido justamente o que fez esses
pontos funcionarem numa estação onde o `ClassNN` não casava. Desligá-lo sem
observar o MV é trocar comportamento validado por otimismo.

### 3.2 O que dá para fazer sem risco

A correção que não muda comportamento: **a função passa a dizer qual caminho
usou.** `MV_ClickBySpec` ganha um `Notify` no ramo do clique por coordenada,
com `classNN` e `x`, `y` no texto. Nenhum fluxo muda de comportamento; apenas
o log passa a distinguir "cliquei o controle" de "cliquei no ponto".

Isso transforma a próxima ocorrência de constante errada em um problema
diagnosticável em vez de um mistério, e é a mesma lição do
[doc 04](04-remessa-protocolo-ctrl-q-nao-sai.md#33-o-fluxo-validado-faz-as-duas-coisas-que-esta-não-faz):
**um log que não distingue sucesso de fallback não é evidência.**

Separar o comportamento (manter o fallback) do relato (logar o fallback) é o
menor caminho que entrega o benefício sem tocar no que foi validado.

## 4. Correção proposta

### 4.1 Origem versionada, no caminho que a `AGENTS.md` já indica

A `AGENTS.md`, na regra 7, dá a ordem de'importance e a primeira opção é
promover para a seção "Falha silenciosa" do próprio `AGENTS.md`. Isso vale
para o que é armadilha com falha sem erro visível — que é o caso deste
repositório. Concretamente, três Promotion candidatos já estão
identificados por esta análise:

1. **`PR_JanelaVisivel` mascara o bit errado** — bit de estilo verificado em
   código, sem captura, e o erro mata o fluxo inteiro de forma opaca.
2. **Verificação por estabilidade não prova transição** — vale para
   `MV_WaitOracleSettled` e para o fechamento por `^q`. É a armadilha que
   produziu o log enganoso do operador.
3. **`MV_ClickBySpec` degrada sem dizer** — clique cego como sucesso.

Os três são exatamente o tipo de conteúdo que a seção "Falha silenciosa"
existe para, e nenhum dos três está lá hoje.

### 4.2 Registro versionado de constantes

Para o restante — as coordenadas e os `ClassNN` de cada tela — a proposta é um
registro versionado, com a origem real ao lado do valor:

- **`docs/CONSTANTES.md`** como registro legível e diffável, ou
- origem **inlineada** no `.ahk`, substituindo `; Spy em Fluxos\protocolar.ahk L269`
  por `; Spy em Praxis_TO-DO/Protocolar/images/Salvar Como/image6.png —
  Button1 = "&1- Executar", Button2 = "&Sair"`.

O inline tem uma vantagem que importa aqui: ele **coloca a evidência ao lado
do valor**, e uma captura do Window Spy vale mais que um número de linha de um
arquivo que não existe. Onde a captura não está versionada, oinline sozinho não
basta, e aí o registro versionado é o caminho.

**Não decidir entre as duas opções agora.** A escolha depende de algo que
ainda não foi verificado: se as capturas do operador podem ser versionadas
(hoje estão em `Praxis_TO-DO/`, fora do Git por decisão de higiene). Se puderem,
o inline resolve. Se não puderem, é registro versionado com a origem
descrita em texto, e aí a fragilidade que resta é da evidência, não do
registro.

### 4.3 Corrigir as citações que mentem

Independente da escolha acima, há correções de baixo custo e sem risco:

- `scripts/mv_session.ahk:61` e `:81-86` — trocar "Fonte versionada" por uma
  referência que não finja ser versionada. Hoy a terceira linha do bloco já
  diz a verdade (`Fluxos/, que é gitignored e não existe neste checkout`); a
  segunda linha é que contradiz.
- ~~`scripts/protocolar.ahk:11-12` e `scripts/fechar_xml.ahk:16`~~ — **feito.** A
  referência a spec inexistente já diz isso explicitamente, no mesmo estilo da
  terceira linha de `mv_session.ahk`: *"Spec previsto: .agents\workflows\…md —
  NÃO EXISTE no repositório (.gitignore:16)"*.

Um comentário de origem que aponta para o nada é pior do que nenhum
comentário: dá a aparência de rastreabilidade que não existe.

## 5. Validação

### 5.1 Sem o MV2000i — possível, e aqui cabe

Nada neste documento exige automação. A validação é de consistência do
repositório.

- **Contagem das citações**, que deve cair a cada correção:

  ```powershell
  Select-String -Path scripts\*.ahk,main.ahk,lib\FFCV_ErrorTemplates.ahk -Pattern '\.agents|Fluxos'
  ```

  Hoje: 34. O alvo é zero, ou um número residual explicitamente justificado.

- **Nenhuma constante nova sem origem verificável.** Verificação estática de
  que todo bloco de constante com `; Spy em` aponta para caminho que existe no
  repositório ou para uma captura versionada.

- **Build + `--integrity-check`**, para confirmar que nenhuma edição de
  comentário quebrou include ou sintaxe:

  ```powershell
  powershell -ExecutionPolicy Bypass -File .\tools\build-praxis.ps1 -Version 9.9.9-test -SkipInstaller
  $p = Start-Process -FilePath ".\dist\Praxis-9.9.9-test\stage\Praxis.exe" `
       -ArgumentList '--integrity-check' -Wait -PassThru; $p.ExitCode
  ```

- **Diff da `MV_ClickBySpec` com o `Notify`**: conferir nos logs de uma
  execução em dev que o ramo do clique por coordenada aparece com `classNN` e
  coordenadas, e que nenhum fluxo mudou de resultado.

### 5.2 Exige o MV2000i real

Nada obrigatório para o texto das correções de origem.

Para a **seção 3.2** (logar o fallback sem mudar comportamento), a validação é
que uma execução completa de cada um dos três fluxos produza **resultado
idêntico** ao de antes da mudança. Se algum resultado mudar, o fallback estava
sendo usado de verdade naquele ponto — o que é informação valiosa e precisa ser
tratada como bug, não como ajuste de log.

## 6. PENDENTE

- **As capturas do operador podem ser versionadas?** Hoje `Praxis_TO-DO/` e
  `Praxis_TO-DO.zip` estão fora do Git por decisão de higiene do `AGENTS.md`
  (regra 8). Versioná-las resolve a maior parte deste documento, mas é uma
  decisão do operador, porque involves copyrighted screen do sistema do
  hospital. **Não assumir.**
- **Existe o `spec 03` em algum lugar?** Se sim, a origem dele passa a ser
  versionada e as sete divergências do [doc 02](02-fechar-xml-divergencia-do-validado.md)
  ganham contexto. Se não, as divergências ficam sem justificativa
  permanente e alguém vai ter que reconstruí-la a partir deobservation no MV.
- **O `LEARNINGS.md` local contém algo que deveria ter subido?** A `AGENTS.md`
  regra 7 manda promover learnings de armadilha para a seção "Falha
  silenciosa". Não foi lido nesta análise e pode conter item equivalente ao que
  a seção 4.1 propõe. **Verificar antes de escrever**, para não duplicar.
