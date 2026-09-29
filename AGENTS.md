# AGENTS.md — Praxis (ponteiro)

Regras completas do projeto em **`.agents/AGENTS.md`**. Leia antes de qualquer trabalho.
Specs de automação do MV2000i em **`.agents/workflows/`** (índice em `.agents/workflows/README.md`).

Este arquivo existe porque o OpenCode V2 só carrega arquivos chamados `AGENTS.md` a partir da
raiz do workspace, e o array `instructions` do config não é resolvido na V2. Sem este ponteiro,
as regras abaixo seriam as únicas carregadas automaticamente.

## Regras de falha silenciosa — não ignorar

- **`#Include` é textual e transitivo.** `scripts/mv_session.ahk` já vem incluído via
  `scripts/remessa_protocolo.ahk`. **Não re-inclua** `mv_session.ahk` em `protocolar.ahk` ou
  `fechar_xml.ahk`: duplica todas as funções `MV_*` e o build quebra.
- **`gScripts` em `main.ahk` está duplicado em `devSim()` dentro de `ui/index.html`.** Alterar
  `id`, `label`, `tipo` ou `obrigatorio` de um parâmetro exige editar os dois lugares, senão a
  UI em modo dev mostra o formulário errado.
- **Automação do MV só está validada depois de rodar contra o MV2000i real.** Se você não rodou,
  diga isso explicitamente em vez de afirmar que funciona. `PENDENTE` significa `PENDENTE`.
- **Não "conserte" constante pendente por adivinhação de coordenada de tela.**

## Regras de automação (MV2000i / Oracle Forms 6i)

- Teclado primeiro. `Send`/`SendText` e atalhos (F6/F7/F8/F10, Alt+mnemonic) são o caminho validado.
- `EditN` não é contrato: o Forms renumera conforme estado da tela. Localize por ClassNN + ponto
  Client, ou por prefixo de classe (`ui60Drawn`).
- Coordenadas são **Client** e vieram de Window Spy/captura. Não introduza coordenadas de tela.
- Use `MV_Poll`/`MV_WaitOracleSettled` em vez de `Sleep` fixo quando esperar janela, modal ou
  cursor estabilizar.
- Ao criar constante nova, registre de qual tela/screenshot veio (padrão: linha `; Spy em ...`
  acima do bloco).
- `Fluxos/` é material de referência, não código, e é gitignored. Não copie `.ahk` de lá para o
  repositório.

## Commits

Conventional Commits em pt-BR, sem scope, linha única (`feat: ponto de mvp`, `fix: ...`).
