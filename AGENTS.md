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
  `id`, `label`, `tipo`, `obrigatorio`, `opcoes` ou `default` de um parâmetro exige editar os dois
  lugares, senão a UI em modo dev mostra o formulário errado.
- **Os três fluxos existem em código; só um rodou no MV.** `remessa_protocolo.ahk` é o validado.
  `protocolar.ahk` (`PR_*`) e `fechar_xml.ahk` (`FX_*`) compilam mas **nunca rodaram contra o MV2000i**.
  Build e `--integrity-check` provam sintaxe, include e asset — não comportamento.
- **Os fluxos não se chamam.** `protocolar.ahk` não chama `RP_*` nem `FX_*`; `fechar_xml.ahk` não
  chama `RP_*` nem `PR_*`. Helper compartilhado novo sobe para `mv_session.ahk` com prefixo `MV_`.
- **Automação do MV só está validada depois de rodar contra o MV2000i real.** Se você não rodou,
  diga isso explicitamente em vez de afirmar que funciona. `PENDENTE` significa `PENDENTE`.
- **Sair de tela no MV é Ctrl+Q.** Confirmado pelo operador para **todas** as telas; no menu
  principal fecha o MV. Em AHK `^` é Ctrl, então `^q` **é** Ctrl+Q — não é valor suspeito. Uma
  constante só: `MV_SAIR_TELA_ATALHO`. `{Esc}` foi descartado. Não "conserte" por adivinhação.
- **Todo fim de fluxo fecha a última tela**, via `MV_FecharUltimaTela`. Duas exceções: popup do MV
  aberto (não fechar — o operador precisa ler a mensagem) e `imprimir_salvar_envio = Não` no
  protocolar (o spec manda deixar o MOV DOC aberto para conferência).
- **Recuperação de tela no meio do fluxo não fecha o MV.** No `protocolar`,
  `PR_FecharPendencias()` limpa telas auxiliares; `PR_RecuperarTelas(cfg)` fecha o MV e só pode ser
  chamada no fim. Fechar o MV no meio quebra a execução.
- **`{Down 121}` em `protocolar.ahk` é posicional** e depende da ordenação do relatório na estação
  do hospital. Se mudar lá, o fluxo gera a planilha errada sem erro visível.

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
