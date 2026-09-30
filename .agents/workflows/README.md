# Workflows — automação do MV2000i

Specs de referência dos fluxos de automação do MV2000i (Oracle Forms 6i) que o Praxis executa.

Cada workflow é a **fonte da verdade do procedimento**: o `.ahk` implementa o spec, e quando
divergem, o spec é que está errado ou o `.ahk` está fora de forma. Antes de alterar um fluxo,
leia o spec dele aqui.

| # | Workflow | Script | Status |
|---|----------|--------|--------|
| 01 | [Remessa por Protocolo](01-remessa-protocolo.md) | `scripts/remessa_protocolo.ahk` | **Implementado e validado no MV** |
| 02 | [Protocolar](02-protocolar.md) | `scripts/protocolar.ahk` | **Implementado, não validado no MV** |
| 03 | [Fechar e Gerar XML](03-fechar-xml.md) | `scripts/fechar_xml.ahk` | **Implementado, não validado no MV** |

"Implementado" significa que o fluxo existe em código e compila. **Nenhum dos dois rodou contra o
MV2000i real** — atalhos de menu, `{Down 121}` e coordenadas continuam não validados. O único gate
automatizado é o build + `--integrity-check`, que não prova comportamento.

## Material de referência

Os `.ahk` originais que serviram de base vivem em `Fluxos/`, que é **gitignored** e não existe em
todo checkout. São citados aqui por caminho e linha, mas não são copiados para o repositório.

| Arquivo | Origem |
|---------|--------|
| `Fluxos/protocolar.ahk` (2.200 l.) | base do workflow 02. Versão mais recente (2026-06-22, OCR persistente) |
| `Fluxos/Protocolar_recuperado.ahk` (1.780 l.) | versão **anterior** do 02. Divergência conhecida em `CorrigirSetorDaContaEBaixar`; quando divergir, o `protocolar.ahk` manda |
| `Fluxos/Teste_corrigido.ahk` (594 l.) | base do workflow 03, multi-remessa |
| `Fluxos/OLD.ahk` (309 l.) | versão de **1** remessa do workflow 03. Superada pelo `Teste_corrigido.ahk` |
| `Fluxos/ffcv/*.CSV` | amostras reais do relatório que o workflow 02 consome |
| `Fluxos/ffcv/*.png`, `Fluxos/Envio/*.png` | capturas de tela de referência |

## Template dos specs

Todo workflow novo segue esta estrutura. Não invente seções novas.

```markdown
# NN — Nome do fluxo

Script: `scripts/<arquivo>.ahk`   |   Registro: `gScripts` id `<id>`

## Objetivo
## Entrada            — params da tela, com tipo e obrigatoriedade
## Pré-condições      — o que o operador precisa ter pronto antes de rodar
## Constantes        — ClassNN + ponto Client, sempre com a linha `; Spy em ...`
## Fases              — numeradas; cada passo diz teclado OU controle, nunca "porcoords" solto
## Idempotência e recuperação
## Critérios de sucesso
## Pendências         — só `PENDENTE`, nunca preenchido por adivinhação
## Não validado       — o que NÃO foi rodado contra o MV2000i real
```

## Estado atual vs. estado descrito

A extração para o prefixo `MV_` **foi feita**. O contrato de janela compartilhado está em
`scripts/mv_session.ahk`, incluído por `scripts/remessa_protocolo.ahk`. Os specs citam `MV_*` e o
código agora corresponde.

| Nome citado nos specs | Onde está |
|------------------------|----------|
| `MV_TISS_ATALHO` | `scripts/mv_session.ahk` — constante, com o valor confirmado pelo operador |
| `MV_SAIR_TELA_ATALHO` | `scripts/mv_session.ahk` — `^q` (Ctrl+Q), confirmado. Substituiu as duas constantes antigas |
| `MV_FecharUltimaTela` | `scripts/mv_session.ahk` — saída obrigatória do fim do fluxo |
| `MV_WaitOracleSettled`, `MV_EnsureWindowActive`, `MV_ClickBySpec`, `MV_SetTextByClickAt` | `scripts/mv_session.ahk` |
| `MV_Abort` | `scripts/mv_session.ahk` — `RP_Abort` virou wrapper de uma linha |

Os fluxos 02 e 03 **não** podem chamar funções `RP_` nem `FX_` um do outro: cada um tem helpers
próprios com prefixo próprio (`PR_` e `FX_`), porque `#Include` é textual e de escopo global.

### Atalhos já confirmados contra o MV2000i

Estes **não** são mais pendência — o operador confirmou em execução real:

| Atalho | Abre | Nota |
|--------|------|------|
| `{Alt down}mpb{Alt up}` | MOV DOC → Protocolação de Baixa | usado pela Fase 1 |
| `{Alt down}lm{Alt up}{Enter}` | FFCV → Manutenção de Remessa | usado pela Fase 2 |
| `{Alt down}lmm{Enter}{Alt up}` | FFCV → Monitoração de Faturamento TISS | **confirmado pelo operador e já aplicado** em `RP_AbrirTelaTISS` |

## Regras que valem para todo spec

- **Teclado primeiro.** `Send`/`SendText` e atalhos (F6/F7/F8/F10, Alt+mnemonic) são o caminho
  validado. `ControlClick` só com ClassNN + ponto Client.
- **Coordenada é sempre Client.** Nunca coordenada de tela.
- **`EditN` não é contrato.** O Forms renumera conforme o estado da tela.
- **Toda constante nova registra a origem**: linha `; Spy em Fluxos/<arquivo> L<n>` ou
  `; Spy em <captura>.png` imediatamente acima do bloco.
- **`PENDENTE` é literal.** Se o atalho ou a coordenada não foi descoberta, deixa `PENDENTE` com o
  motivo. Preencher por adivinhação é pior que deixar pendente, porque o erro fica silencioso.
- **Nenhuma etapa depende de modal já aberto.** Os modais do Oracle Forms não expõem a mensagem
  pelo Window Spy de forma confiável; a leitura de erro passa por OCR
  (`lib/FFCV_ErrorTemplates.ahk` + `tools/ocr-probe.ps1`).
