# Workflows — automação do MV2000i

Specs de referência dos fluxos de automação do MV2000i (Oracle Forms 6i) que o Praxis executa.

Cada workflow é a **fonte da verdade do procedimento**: o `.ahk` implementa o spec, e quando
divergem, o spec é que está errado ou o `.ahk` está fora de forma. Antes de alterar um fluxo,
leia o spec dele aqui.

| # | Workflow | Script | Status |
|---|----------|--------|--------|
| 01 | [Remessa por Protocolo](01-remessa-protocolo.md) | `scripts/remessa_protocolo.ahk` | **Implementado e validado no MV** |
| 02 | [Protocolar](02-protocolar.md) | `scripts/protocolar.ahk` | A implementar (stub) |
| 03 | [Fechar e Gerar XML](03-fechar-xml.md) | `scripts/fechar_xml.ahk` | A implementar (stub) |

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

Os specs usam prefixo `MV_` para o contrato de janela, mas **essa extração ainda não foi feita**.
Hoje o que existe em `scripts/remessa_protocolo.ahk` ainda é `RP_*` e o atalho do TISS está
embutido na função `RP_AbrirTelaTISS`, não em constante.

| Nome citado nos specs | Existe hoje | Onde |
|------------------------|--------------|------|
| `MV_TISS_ATALHO` | **não** — embutido em `RP_AbrirTelaTISS`, já com o valor confirmado | `scripts/remessa_protocolo.ahk` L1368 |
| `MV_ENTREGA_SAIR_ATALHO` | não — é `RP_ENTREGA_SAIR_ATALHO` | `scripts/remessa_protocolo.ahk` L107 |
| `MV_XML_BTN_SAIR_TALA` → `MV_XML_BTN_SAIR_TELA` | não — é `XML_BTN_SAIR_TELA` | `scripts/remessa_protocolo.ahk` L128 |
| `MV_WaitOracleSettled` | não — é `RP_WaitOracleSettled` | `scripts/remessa_protocolo.ahk` L1427 |
| `MV_EnsureWindowActive` | não — é `RP_EnsureWindowActive` | `scripts/remessa_protocolo.ahk` L1396 |
| `MV_Abort` | não — é `RP_Abort` | `scripts/remessa_protocolo.ahk` L1724 |

Grep por `MV_` em `scripts/` **não** encontra essas funções. Ao implementar a extração, promova
cada uma e atualize este quadro; até lá, os specs descrevem o destino, não o código.

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
