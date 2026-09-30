# Praxis

Automação de processos de faturamento hospitalar no sistema **MV2000i (Gestão Hospitalar)**. Desenvolvido em AutoHotkey v2 com interface gráfica WebView2 (HTML/CSS/JS).

> Hospital: São Rafael · Desenvolvedor: Iago Santana

---

## Tecnologias

| Componente | Tecnologia |
|---|---|
| Shell da janela | AutoHotkey v2 (`Gui`) |
| Interface UI | WebView2 (Chromium) + HTML/CSS/JS puro |
| Comunicação JS↔AHK | `PostWebMessageAsJson` / `window.chrome.webview.postMessage` |
| Automação do MV | AutoHotkey v2 — Send, ControlClick, OCR local + Clipboard |
| Configuração | `config.ini` (IniRead/IniWrite) |

**Dependências para desenvolvimento:**
- AutoHotkey v2 → [autohotkey.com](https://autohotkey.com)
- Ahk2Exe → instalado junto ao AutoHotkey ou pelo instalador oficial
- Inno Setup 6 → necessário para gerar instalador
- WebView2 Runtime → necessário para executar a interface WebView2

Para detalhes de build, assinatura, artefatos e validação, consulte [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md).

---

## Estrutura de Arquivos

```
Praxis/
├── main.ahk                   # Entry point: GUI, registro de scripts, dispatcher, integridade
├── config.ini                 # Configuração local (gitignored; criado pelo instalador)
├── AGENTS.md                  # Regras de projeto para agentes
├── lib/
│   ├── WebView2.ahk           # Lib externa (thqby)
│   ├── JSON.ahk               # Lib externa (thqby)
│   ├── Promise.ahk            # Dependência da WebView2.ahk
│   ├── ComVar.ahk             # Dependência da WebView2.ahk
│   ├── FFCV_ErrorTemplates.ahk  # Classificação de modais de erro do FFCV por OCR
│   ├── FFCV_ErrorReferences.json  # Textos canônicos (gerado; ver tools/)
│   ├── 32bit/WebView2Loader.dll
│   └── 64bit/WebView2Loader.dll
├── scripts/
│   ├── mv_session.ahk         # Sessão MV, contrato de janela, polling
│   ├── remessa_protocolo.ahk  # Fluxo 01
│   ├── protocolar.ahk         # Fluxo 02
│   └── fechar_xml.ahk         # Fluxo 03
├── ui/
│   └── index.html             # Interface completa do app
├── tools/
│   ├── build-praxis.ps1       # Build, assinatura e empacotamento
│   ├── ocr-probe.ps1          # OCR de tela (runtime)
│   ├── build-ocr-error-references.ps1
│   ├── list-code-signing-certs.ps1
│   └── new-self-signed-code-signing-cert.ps1
├── docs/
│   ├── DISTRIBUTION.md        # Runbook de build, assinatura e entrega
│   ├── EULA.md
│   ├── NDA.md
│   ├── PRIVACY_LGPD.md
│   └── THIRD_PARTY_NOTICES.md
├── installer/
│   ├── Praxis.iss             # Script do Inno Setup
│   └── assets/                # Ícone e imagens do assistente
├── build/generated/           # Gerado a cada build (gitignored)
└── dist/                      # Artefatos de build (gitignored)
```

`#Include` no AutoHotkey é textual e transitivo: `main.ahk` inclui os três fluxos, e
`remessa_protocolo.ahk` inclui `mv_session.ahk` e `lib/FFCV_ErrorTemplates.ahk`.

---

## Scripts Disponíveis

Os três fluxos estão implementados. O status de validação contra o MV2000i real é diferente para
cada um — veja a tabela ao final desta seção.

### 1. Remessa por Protocolo (principal)
**Categoria:** Faturamento · **Validado no MV2000i**

Baixa protocolos no MOV DOC e cria/atualiza remessa no FFCV.

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| Protocolos | text | Sim |
| Tipo de Conta | select | Sim |
| Remessa Existente | text | Não |
| Data de Entrega | date | Não |
| Data de Vencimento | date | Não |

### 2. Protocolar
**Categoria:** Movimentação · **Implementado, não validado no MV2000i**

Movimenta contas de remessas para outro setor no MOV DOC.

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| Número das Remessas | text | Sim |
| Setor Atual | text | Sim |
| Setor de Envio | text | Sim |
| Tipo | select | Sim |
| Imprimir, Salvar e Enviar | select | Sim |

Com `Imprimir, Salvar e Enviar = Não`, o fluxo deixa o MOV DOC aberto para conferência em vez de
fechar a última tela.

### 3. Fechar e Gerar XML
**Categoria:** Faturamento · **Implementado, não validado no MV2000i**

Fecha as remessas informadas e gera o arquivo XML de cada uma em `<WorkDir>\XML\`.

| Parâmetro | Tipo | Obrigatório |
|---|---|---|
| Número das Remessas | text | Sim |
| Data de Entrega | date | Sim |
| Data de Vencimento | date | Sim |

### Status de validação

| Fluxo | Situação |
|---|---|
| 1 — Remessa por Protocolo | **Implementado e validado** contra o MV2000i real |
| 2 — Protocolar | Implementado e compilando; **nunca rodado** contra o MV2000i real |
| 3 — Fechar e Gerar XML | Implementado e compilando; **nunca rodado** contra o MV2000i real |

"Implementado" significa que o fluxo existe em código e compila. O build e o `--integrity-check`
comprovam sintaxe, includes e presença de recursos — **não** comprovam comportamento. Os fluxos 2 e
3 têm atalhos, coordenadas e lógica de popup que só serão confirmados na primeira execução real.

---

## Instalação (Desenvolvimento)

1. Copiar a pasta `Praxis/` para o computador
2. Criar `config.ini` com:
   ```ini
   [Paths]
   WorkDir=C:\Users\<usuario>\Documents\Praxis
   ```
   Sem `config.ini`, o app usa o padrão `%USERPROFILE%\Documents\Praxis`.
3. Criar a pasta `%USERPROFILE%\Documents\Praxis\XML\` (saída dos XMLs de remessa)
4. Abrir o `main.ahk` com o AutoHotkey v2, ou:
   ```powershell
   & "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" ".\main.ahk"
   ```

As libs de `lib/` já vêm versionadas no repositório — não é preciso baixá-las. Em desenvolvimento o
app lê `ui\index.html` direto do disco e pula a verificação de integridade.

---

## Instalação (Produção)

O pacote de produção é gerado pelo script de build e pelo instalador Inno Setup do projeto. Para testes controlados, o build também cria a pasta `dist\Praxis-<versão>\delivery\` com o instalador e os documentos legais, e a pasta `dist\Praxis-<versão>\distribution\` com a versão portátil para computadores que não aceitam instalador, sem expor `.ahk`, `.ps1`, `.html` ou `.json`.

Para gerar e validar builds, consulte [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md).

O instalador:
- instala em `%LOCALAPPDATA%\Programs\Praxis\` sem exigir privilégios elevados por padrão;
- cria `%USERPROFILE%\Documents\Praxis\` automaticamente;
- grava `WorkDir` no `config.ini`;
- cria atalhos no Menu Iniciar e, opcionalmente, na Área de Trabalho;
- instala os recursos de runtime necessários do Praxis;
- tenta instalar o Microsoft Edge WebView2 Runtime se ele não estiver presente.

---

## Interface

- **Janela:** 750×540px (redimensionável, mínimo 640×460)
- **App:** sidebar com módulos por categoria + formulário dinâmico + log + barra de progresso
- **Comunicação:** bidirecional AHK↔JS via WebView2

---

## Notas Técnicas — Oracle Forms 6i

O MV2000i roda sobre **Oracle Forms 6i (`ifrun60.EXE`)**.

### Funciona bem
- `WinExist`, `WinActivate`, `WinWaitActive`
- `ControlClick` com **ClassNN**
- `Send` (teclado: F7, F8, F10, Tab, Enter, setas)
- `WinGetText` em popups modais
- OCR local do Windows (`Windows.Media.Ocr`) na área client dos popups de erro

### Não confiável sozinho
- `ControlSetText`/`ControlGetText` para campos de texto do Forms
- Window Spy para identificar campos por ClassNN único (muitos campos compartilham `Edit2`, etc.)
- Coordenadas de tela (variam por monitor, resolução, escala)

### Estratégia para campos de texto
1. **Teclado** como caminho principal (SendText, Tab, Enter, F6/F7/F8/F10)
2. **HWND por ClassNN + coordenada Client** como fallback
3. **Clipboard** para leitura: double-click → `Ctrl+C`

---

## Padrões do Projeto

O contrato de janela do MV2000i é compartilhado por todos os fluxos e mora em
`scripts/mv_session.ahk` (prefixo `MV_`):

```autohotkey
MV_Poll(condFn, timeoutSecs)                 ; espera ativa, no lugar de Sleep fixo
MV_WaitOracleSettled(winTitle)               ; janela do Forms estável antes de interagir
MV_FindControlByClientPoint(winTitle, classNN, x, y)
MV_ClickBySpec(winTitle, classNN, x, y)      ; ClassNN + ponto Client
MV_SetTextByClickAt(winTitle, x, y, value)
MV_FecharUltimaTela(winTitle, rotulo)        ; saída obrigatória do fim de fluxo
```

Cada fluxo tem prefixo próprio (`RP_`, `PR_`, `FX_`) e não chama as funções dos outros. Para
convenções de automação, armadilhas conhecidas e o gate de validação, veja [`AGENTS.md`](AGENTS.md).
