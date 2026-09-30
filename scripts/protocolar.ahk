; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0

; ════════════════════════════════════════════════════════════════
;  PROTOCOLAR
; ════════════════════════════════════════════════════════════════
; Spec: .agents\workflows\02-protocolar.md
; Base: Fluxos\protocolar.ahk (2.200 l., 2026-06-22)
;
; Parâmetros da tela:
;   remessas              -> números das remessas separados por vírgula. Ex: 511458, 514015
;   setor_atual           -> setor onde as contas estão. Ex: 34
;   setor_envio           -> setor destino. Ex: 365
;   tipo                  -> Ambulatorial | Hospitalar. Muda a sequência de teclas do MOV DOC
;   imprimir_salvar_envio -> Sim | Não. Decide entre Alt+1+Imprimir ou só excluir o registro em branco
;
; ── Escopo (armadilhas desta casa) ───────────────────────────────
; NÃO declarar #Include aqui. `mv_session.ahk` e `lib\FFCV_ErrorTemplates.ahk`
; chegam a este arquivo por include TRANSITIVO (main.ahk → remessa_protocolo.ahk).
; Um #Include novo duplicaria todas as funções MV_* e quebraria o build.
;
; Os fluxos são autônomos: helper equivalente que só existe nos outros scripts é
; replicado aqui com prefixo PR_.
;
; Saída somente por Notify / Progress / Done e pelo abort PR_Abort.
; Nada de Gui, MsgBox, ToolTip ou hotkey.

; ════════════════════════════════════════════════════════════════
;  CONSTANTES
; ════════════════════════════════════════════════════════════════
; Base: Fluxos/protocolar.ahk L211-L276 (Fase FFCV) e L311-L541 (MOV DOC).
; As janelas do FFCV/Relatórios vivem no ifrun60.EXE; os popups de SQL no EXECUTASQL.exe.
; O exe entra no título de propósito: sem ele o WinExist casa na janela errada.

; ── Janelas ────────────────────────────────────────────────────
; Spy em Fluxos/protocolar.ahk L39-L47 (constantes do original)
PR_WIN_FFCV_RELATORIO  := "Relatórios Personalizado ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
PR_WIN_FFCV_REMESSASQL := "ahk_class TFPrincipal ahk_exe EXECUTASQL.exe"
PR_WIN_FFCV_INFO       := "Information ahk_exe EXECUTASQL.exe"
PR_WIN_FFCV_SALVAR     := "Salvar como ahk_exe EXECUTASQL.exe"
PR_WIN_MOVDOC_ENVIO   := "Protocolação de Envio de Documentos ahk_exe ifrun60.EXE"
PR_WIN_MOVREL_ENVIO   := "Relatório de Registro de Envio ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
PR_WIN_MV_MSG         := MV_WIN_MSG_USER  ; "Mensagem ao Usuário do MV 2000" (contrato compartilhado)
PR_EXE_MV             := "ifrun60.EXE"
PR_EXE_REPORTS        := "RWRBE60.EXE"
PR_EXE_SQL            := "EXECUTASQL.exe"

; ── Controles ──────────────────────────────────────────────────
; Spy em Fluxos/protocolar.ahk L249 (Gerar Arquivo / TBitBtn2 no client do popup SQL)
PR_FFCV_BTN_GERAR_ARQUIVO    := "TBitBtn2"
PR_FFCV_BTN_GERAR_ARQUIVO_X  := 548
PR_FFCV_BTN_GERAR_ARQUIVO_Y  := 91
; Spy em Fluxos/protocolar.ahk L263 (Information do EXECUTASQL)
PR_SQL_BTN_OK               := "TButton1"
; Spy em Fluxos/protocolar.ahk L343 (confirma setor atual/envio na tela de envio)
PR_ENVIO_BTN_CONFIRMAR      := "Button2"
; PREFIXO de classe, não ClassNN exato: o Forms renumera a viewcore.
; Spy em Fluxos/protocolar.ahk L415 e L521 (excluir registro em branco)
PR_ENVIO_BTN_EXCLUIR        := "ui60Viewcore_W3211"
; Campo Protocolo da tela de envio. Coordenada CLIENT.
; Spy em Fluxos/protocolar.ahk L496 (imagem 17, client x 21..94 / y 106..124)
PR_ENVIO_CAMPO_PROTOCOLO_X  := 60
PR_ENVIO_CAMPO_PROTOCOLO_Y  := 115
; Spy em Fluxos/protocolar.ahk L465 (Button1 da tela de baixa, imagem 14)
PR_BAIXA_BTN_RECEBIDO       := "Button1"
; Spy em Fluxos/protocolar.ahk L488 (Button1 do relatório de envio = Sair, imagem 16)
PR_MOVREL_BTN_SAIR          := "Button1"
; Spy em Fluxos/protocolar.ahk L531 (Button2 do relatório de envio = Imprimir, imagem 15)
PR_MOVREL_BTN_IMPRIMIR      := "Button2"
; Spy em Fluxos/protocolar.ahk L269 (Button1 = Sair do popup "Relatórios Personalizado")
PR_RELATORIO_BTN_SAIR       := "Button1"
; Campo de nome do arquivo no diálogo Salvar como (clássico do Windows)
PR_SALVAR_CAMPO_NOME        := "Edit1"
PR_SALVAR_BTN_CONFIRMAR     := "Button2"   ; botão Salvar do diálogo clássico
; Campo de remessas no popup do EXECUTASQL. Spy em Fluxos/protocolar.ahk L1368
PR_REMESSASQL_CAMPO_REMESSA := "TEdit1"
; Texto do botão/caption do popup, usado só como sinal de detecção (não para clicar).
PR_FFCV_GERAR_ARQUIVO_TEXTO  := "Gerar Arquivo"

; ── Teclado ────────────────────────────────────────────────────
PR_KEY_SETTLE_MS  := MV_KEY_SETTLE_MS
PR_DELAY_INPUT    := MV_DELAY_INPUT

; ── Esperas ────────────────────────────────────────────────────
; PENDENTE: `{Down 121}` é POSICIONAL e nunca foi validado contra o MV2000i real.
PR_RELATORIO_DOWN_N := 121
; Timeout CURTO de detecção do popup após o Enter da conta: conta aceita não abre popup.
; Base: Fluxos/protocolar.ahk L52 (Delay.AccountPopupTimeout)
PR_POPUP_CONTA_TIMEOUT_MS := 300
PR_POPUP_QUEDA_TIMEOUT_MS := 3000
PR_MODAL_TIMEOUT_SEG     := 30
PR_POPUP_REMESSA_TIMEOUT_SEG := 60
PR_SALVAR_TIMEOUT_SEG    := 45
PR_ARQUIVO_TIMEOUT_MS    := 30000
PR_MENU_STEP_MS          := 100
PR_FINAL_STABLE_MS       := MV_FINAL_STABLE_MS
PR_FINAL_TIMEOUT_MS      := MV_FINAL_ACTION_TIMEOUT_MS
PR_OCR_SCALE             := 2

; ── Configuração da execução ───────────────────────────────────
PR_TIPO_AMBULATORIAL := "ambulatorial"
PR_TIPO_HOSPITALAR   := "hospitalar"
PR_OCR_LANGUAGE      := "pt-BR"

; ════════════════════════════════════════════════════════════════
;  ENTRADA DO MÓDULO
; ════════════════════════════════════════════════════════════════

RunProtocolar(params) {
    global gRunning

    remessas := PR_ParseRemessas(params["remessas"])
    setorAtual := Trim(params["setor_atual"])
    setorEnvio := Trim(params["setor_envio"])
    tipo := StrLower(Trim(params["tipo"]))
    imprimir := (StrLower(Trim(params["imprimir_salvar_envio"])) = "sim")

    if (remessas.Length = 0)
        return PR_Abort("Informe o número das remessas. Ex: 511458, 514015")
    if (setorAtual = "")
        return PR_Abort("Informe o setor atual. Ex: 34")
    if (setorEnvio = "")
        return PR_Abort("Informe o setor de envio. Ex: 365")
    if (setorAtual = setorEnvio)
        return PR_Abort("O setor atual e o setor de envio devem ser diferentes.")
    if (tipo != PR_TIPO_AMBULATORIAL && tipo != PR_TIPO_HOSPITALAR)
        return PR_Abort("Tipo inválido. Use Ambulatorial ou Hospitalar.")

    cfg := Map(
        "remessas", JoinPR(remessas, ", "),
        "listaRemessas", remessas,
        "setorAtual", setorAtual,
        "setorEnvio", setorEnvio,
        "tipo", tipo,
        "imprimir", imprimir
    )

    Notify("Protocolar: " remessas.Length " remessa(s) do setor " setorAtual " para o setor " setorEnvio
        " | tipo " tipo " | imprimir/salvar " (imprimir ? "Sim" : "Não") ".")

    totalStart := A_TickCount

    try {
        ; ── Fase 1: FFCV gera a planilha de contas ──────────────
        csvPath := PR_Fase1GerarPlanilha(cfg)
        Progress(15)

        ; ── Fase 2: ler a planilha ──────────────────────────────
        contas := PR_Fase2LerPlanilha(csvPath)
        if (contas.Length = 0)
            return PR_Abort("Nenhuma conta encontrada na coluna CD_REG_AMB de: " csvPath)
        Notify("Contas extraídas: " contas.Length " (deduplicadas, coluna CD_REG_AMB).")
        Progress(25)

        ; ── Fase 3 e 4: enviar as contas e tratar os popups ─────
        resultado := PR_Fase3EnviarContas(cfg, contas)
        Progress(80)

        ; ── Fase 5: finalizar ───────────────────────────────────
        PR_Fase5Finalizar(cfg)
        Progress(100)
    } catch as e {
        PR_RecuperarTelas(cfg)
        return PR_Abort(e.Message)
    }

    ; Recuperação também roda no caminho feliz: devolve o MOV DOC a um estado previsível
    ; e fecha a última tela com Ctrl+Q.
    PR_RecuperarTelas(cfg)

    relatorio := "Protocolar concluído.`n`n"
    relatorio .= "Remessas: " cfg["remessas"] "`n"
    relatorio .= "Setor " cfg["setorAtual"] " → " cfg["setorEnvio"] " | tipo " tipo "`n"
    relatorio .= "Contas na planilha: " contas.Length "`n"
    relatorio .= "Contas enviadas sem popup: " resultado["aceitas"] "`n"
    relatorio .= "Documentos pendentes baixados: " resultado["pendentes"].Length "`n"
    relatorio .= "Setores divergentes corrigidos: " resultado["setores"].Length "`n"
    relatorio .= "Tempo total: " MV_FormatDuration(A_TickCount - totalStart) "`n`n"
    ; Aspas entre o texto e a variável para o AHK não ler "Down" como nome de variável.
    relatorio .= "PENDENTE: a posição do relatório no FFCV foi aberta por {Down }" PR_RELATORIO_DOWN_N
    relatorio .= " (posicional, sem validação). Se a ordenação do relatório mudar na estação, "
    relatorio .= "esta execução gera a planilha errada sem erro visível.`n"
    relatorio .= "NENHUMA etapa deste fluxo foi executada contra o MV2000i real."

    if (resultado["pendentes"].Length > 0) {
        relatorio .= "`nPROTOCOLOS BAIXADOS`n"
        for _, item in resultado["pendentes"]
            relatorio .= "  conta " item["conta"] " | protocolo " item["protocolo"] "`n"
    }
    if (resultado["setores"].Length > 0) {
        relatorio .= "`nSETORES CORRIGIDOS`n"
        for _, item in resultado["setores"]
            relatorio .= "  conta " item["conta"] " | recebido " item["setorRecebido"] " | novo protocolo " item["protocolo"] "`n"
    }
    if (resultado["erros"].Length > 0) {
        relatorio .= "`n[[red]]ERROS`n"
        for _, item in resultado["erros"]
            relatorio .= "  " item "`n"
    }

    gRunning := false
    Done(relatorio)
    return true
}

; ════════════════════════════════════════════════════════════════
;  FASE 1 — FFCV: GERAR A PLANILHA DE CONTAS
; ════════════════════════════════════════════════════════════════

PR_Fase1GerarPlanilha(cfg) {
    global gWorkDir

    if Trim(gWorkDir) = ""
        return PR_Erro("WorkDir não configurado. Verifique o config.ini (Paths/WorkDir).")

    if !MV_EnsureFFCV()
        return PR_Erro("Não foi possível acessar o FFCV. Abra e autentique o FFCV no MV2000i e tente de novo.")

    ; Idempotência: apagar os CSVs anteriores antes de gerar. Sem isso, uma execução
    ; que falhe no meio leria a planilha velha na vez seguinte.
    alvos := [PR_CsvPath(gWorkDir), PR_CsvPath(gWorkDir) ".CSV", PR_CsvAltPath(gWorkDir)]
    apagados := 0
    for caminho in alvos {
        if FileExist(caminho) {
            try {
                FileDelete caminho
                apagados++
            } catch as e {
                return PR_Erro("Não consegui apagar o CSV anterior " caminho ": " e.Message)
            }
        }
    }
    Notify("FFCV: " apagados " arquivo(s) de planilha anterior apagado(s) antes de gerar.")

    Notify("FFCV: abrindo a tela de relatórios (Alt+E, Enter 2).")
    Send "!e"
    Sleep PR_KEY_SETTLE_MS
    Send "{Enter 2}"
    Sleep PR_KEY_SETTLE_MS

    if !PR_EsperarJanela(PR_WIN_FFCV_RELATORIO, PR_MODAL_TIMEOUT_SEG)
        return PR_Erro("O popup 'Relatórios Personalizado' não apareceu após Alt+E.")

    ; PENDENTE: seleção POSICIONAL do relatório. 121 pressões de Down dependem da
    ; ordenação do relatório na estação do hospital. Se mudar lá, o FFCV gera a
    ; planilha errada sem nenhum erro visível. Não validado contra o MV2000i.
    Notify("FFCV: selecionando o relatório com {Down " PR_RELATORIO_DOWN_N "} — POSICIONAL, PENDENTE de validação.")
    Send "{Down " PR_RELATORIO_DOWN_N "}"
    Sleep PR_DELAY_INPUT
    Send "!1"

    ; O popup de remessa do FFCV é instável: o original tinha quatro fallbacks.
    ; Aqui ficam três, na mesma ordem de confiabilidade, e a última busca é por controle.
    popup := PR_EsperarPopupRemessa(PR_POPUP_REMESSA_TIMEOUT_SEG)
    if (popup = 0)
        return PR_Erro("O popup de Remessa/Gerar Arquivo do FFCV não apareceu em " PR_POPUP_REMESSA_TIMEOUT_SEG "s.")

    if !PR_PreencherRemessas(popup, cfg["remessas"])
        return PR_Erro("Não consegui informar as remessas no popup do FFCV.")

    Notify("FFCV: acionando 'Gerar Arquivo' (TBitBtn2).")
    if !MV_ClickBySpec("ahk_id " popup, PR_FFCV_BTN_GERAR_ARQUIVO, PR_FFCV_BTN_GERAR_ARQUIVO_X, PR_FFCV_BTN_GERAR_ARQUIVO_Y)
        return PR_Erro("Não consegui acionar 'Gerar Arquivo' no popup do FFCV.")

    ; ── Diálogo Salvar como ────────────────────────────────────
    salvar := PR_EsperarJanelaSaveAs(PR_SALVAR_TIMEOUT_SEG)
    if (salvar = 0)
        return PR_Erro("O diálogo 'Salvar como' do EXECUTASQL.exe não apareceu em " PR_SALVAR_TIMEOUT_SEG "s.")

    destino := PR_CsvPath(gWorkDir)
    Notify("FFCV: salvando a planilha em " destino ".")
    if !PR_PreencherNomeArquivo(salvar, destino)
        return PR_Erro("Não consegui informar o nome do arquivo no diálogo 'Salvar como'.")

    if !PR_ConfirmarSalvarComo(salvar)
        return PR_Erro("Não consegui confirmar o botão Salvar do diálogo 'Salvar como'.")

    ; ── Popup Information do EXECUTASQL.exe ────────────────────
    if !PR_EsperarJanela(PR_WIN_FFCV_INFO, PR_MODAL_TIMEOUT_SEG)
        Notify("Aviso: o popup 'Information' do EXECUTASQL.exe não apareceu; seguindo para conferir o arquivo.")
    else {
        Notify("FFCV: 'arquivo gerado com sucesso' confirmado.")
        if !PR_ClicarControle(PR_WIN_FFCV_INFO, PR_SQL_BTN_OK)
            Notify("Aviso: não consegui clicar em OK no popup 'Information' do EXECUTASQL.exe.")
    }

    ; ── Fechar o popup "Relatórios Personalizado" ──────────────
    if WinExist(PR_WIN_FFCV_RELATORIO) {
        Notify("FFCV: fechando o popup 'Relatórios Personalizado'.")
        PR_ClicarControle(PR_WIN_FFCV_RELATORIO, PR_RELATORIO_BTN_SAIR)
        PR_EsperarSumir(PR_WIN_FFCV_RELATORIO, PR_POPUP_QUEDA_TIMEOUT_MS)
    }

    ; ── O EXECUTASQL.exe às vezes confirma antes de terminar de escrever ──
    ; ── Por isso o arquivo no disco é o contrato, não o popup.        ──
    csvPath := PR_EsperarArquivo([PR_CsvPath(gWorkDir), PR_CsvAltPath(gWorkDir)], PR_ARQUIVO_TIMEOUT_MS)
    if (csvPath = "")
        return PR_Erro("O FFCV confirmou a geração, mas o arquivo de planilha não apareceu em "
            PR_ARQUIVO_TIMEOUT_MS "ms. Procurado: " PR_CsvPath(gWorkDir) " (ou " PR_CsvAltPath(gWorkDir) ").")

    Notify("FFCV: planilha gerada em " csvPath ".")
    return csvPath
}

PR_CsvPath(gWorkDir) => Trim(gWorkDir) "\Envio.csv"
PR_CsvAltPath(gWorkDir) => Trim(gWorkDir) "\Envio.csv.CSV"

PR_EsperarPopupRemessa(timeoutSec) {
    ; Cadeia de fallback do original (Fluxos/protocolar.ahk L660-690). O EXECUTASQL.exe é
    ; instável e muda título/classe conforme a estação, então cada estratégia vale:
    ;   1) Par classe/processo do Window Spy.
    ;   2) TFPrincipal do EXECUTASQL.exe visível (título inconsistente em algumas estações).
    ;   3) TFPrincipal do EXECUTASQL.exe com geometria de popup (450..900 x 90..260).
    ;   4) Qualquer janela do EXECUTASQL.exe que exponha o TBitBtn2 do "Gerar Arquivo".
    ;   5) Qualquer janela que exponha TEdit1 + TBitBtn2 + o texto "Gerar Arquivo".
    ;   6) Qualquer janela cujo texto contenha "Gerar Arquivo".
    ; PENDENTE: cadeia de detecção não validada contra o MV2000i real. É o ponto mais
    ; frágil do fluxo — se a estação abrir o popup com outra classe/texto, cai para 3..6.
    startedAt := A_TickCount
    Loop {
        if PR_Abortado()
            return 0

        try hwnd := WinExist(PR_WIN_FFCV_REMESSASQL)
        catch
            hwnd := 0
        if hwnd {
            try WinActivate("ahk_id " hwnd)
            return hwnd
        }

        try lista := WinGetList("ahk_exe " PR_EXE_SQL)
        catch
            lista := []

        for w in lista {
            if !PR_JanelaVisivel(w)
                continue
            if (WinGetClass("ahk_id " w) = "TFPrincipal") {
                try WinActivate("ahk_id " w)
                return w
            }
        }

        for w in lista {
            if !PR_JanelaVisivel(w)
                continue
            if PR_JanelaTemGeometriaDePopup(w) {
                try WinActivate("ahk_id " w)
                return w
            }
        }

        for w in lista {
            if !PR_JanelaVisivel(w)
                continue
            if PR_ControleExiste(w, PR_FFCV_BTN_GERAR_ARQUIVO) {
                try WinActivate("ahk_id " w)
                return w
            }
        }

        for w in lista {
            if !PR_JanelaVisivel(w)
                continue
            if PR_ControleExiste(w, PR_REMESSASQL_CAMPO_REMESSA)
                && PR_ControleExiste(w, PR_FFCV_BTN_GERAR_ARQUIVO)
                && InStr(PR_TextoJanela(w), PR_FFCV_GERAR_ARQUIVO_TEXTO) {
                try WinActivate("ahk_id " w)
                return w
            }
        }

        for w in lista {
            if !PR_JanelaVisivel(w)
                continue
            if InStr(PR_TextoJanela(w), PR_FFCV_GERAR_ARQUIVO_TEXTO) {
                try WinActivate("ahk_id " w)
                return w
            }
        }

        if (A_TickCount - startedAt >= timeoutSec * 1000)
            return 0
        Sleep MV_POLL_MS
    }
}

; Geometria do popup do "Gerar Arquivo" vista no Window Spy da estação.
; Base: Fluxos/protocolar.ahk L713 (IsFfcvRemessaWindow).
PR_JanelaTemGeometriaDePopup(hwnd) {
    try {
        WinGetPos &x, &y, &w, &h, "ahk_id " hwnd
    } catch {
        return false
    }
    return (w >= 450 && w <= 900 && h >= 90 && h <= 260)
}

PR_TextoJanela(hwnd) {
    try return WinGetText("ahk_id " hwnd)
    catch
        return ""
}

PR_PreencherRemessas(hwnd, remessas) {
    ; Primeiro o controle real. O EXECUTASQL.exe às vezes aceita ControlSetText sem
    ; escrever nada, então o valor é validado antes de aceitar.
    try {
        ControlFocus PR_REMESSASQL_CAMPO_REMESSA, "ahk_id " hwnd
        Sleep PR_KEY_SETTLE_MS
        ControlSetText "", PR_REMESSASQL_CAMPO_REMESSA, "ahk_id " hwnd
        Sleep PR_KEY_SETTLE_MS
        ControlSetText remessas, PR_REMESSASQL_CAMPO_REMESSA, "ahk_id " hwnd
        Sleep PR_KEY_SETTLE_MS
        try {
            if Trim(ControlGetText(PR_REMESSASQL_CAMPO_REMESSA, "ahk_id " hwnd)) = Trim(remessas)
                return true
        }
    }

    ; Fallback: foco de janela + digitação. Teclado primeiro.
    try WinActivate("ahk_id " hwnd)
    SendText remessas
    Sleep PR_KEY_SETTLE_MS
    return true
}

PR_EsperarJanelaSaveAs(timeoutSec) {
    startedAt := A_TickCount
    Loop {
        if PR_Abortado()
            return 0

        ; O diálogo clássico pertence ao EXECUTASQL.exe, não ao ifrun60.EXE.
        try lista := WinGetList("ahk_class #32770 ahk_exe " PR_EXE_SQL)
        catch
            lista := []

        for w in lista {
            if PR_JanelaVisivel(w)
                return w
        }

        if (A_TickCount - startedAt >= timeoutSec * 1000)
            return 0
        Sleep MV_POLL_MS
    }
}

PR_PreencherNomeArquivo(hwnd, caminho) {
    try {
        ControlFocus PR_SALVAR_CAMPO_NOME, "ahk_id " hwnd
        Sleep PR_KEY_SETTLE_MS
        ControlSetText "", PR_SALVAR_CAMPO_NOME, "ahk_id " hwnd
        Sleep PR_KEY_SETTLE_MS
        ControlSetText caminho, PR_SALVAR_CAMPO_NOME, "ahk_id " hwnd
        Sleep PR_KEY_SETTLE_MS
        try {
            if Trim(ControlGetText(PR_SALVAR_CAMPO_NOME, "ahk_id " hwnd)) = Trim(caminho)
                return true
        }
    }

    try WinActivate("ahk_id " hwnd)
    try ControlFocus PR_SALVAR_CAMPO_NOME, "ahk_id " hwnd
    Sleep PR_KEY_SETTLE_MS
    Send "^a"
    Sleep PR_KEY_SETTLE_MS
    SendText caminho
    Sleep PR_KEY_SETTLE_MS
    return true
}

PR_ConfirmarSalvarComo(hwnd) {
    if PR_ClicarControleHwnd(hwnd, PR_SALVAR_BTN_CONFIRMAR)
        return true
    ; Fallback por teclado: Alt+S é o mnemônico do "Salvar" do diálogo clássico.
    try WinActivate("ahk_id " hwnd)
    Sleep PR_KEY_SETTLE_MS
    Send "!s"
    Sleep PR_KEY_SETTLE_MS
    return true
}

; ════════════════════════════════════════════════════════════════
;  FASE 2 — LER A PLANILHA
; ════════════════════════════════════════════════════════════════

PR_Fase2LerPlanilha(csvPath) {
    contas := PR_ExtrairContasDoCsv(csvPath)
    if (contas.Length = 0)
        return []
    return PR_DeduplicarContas(contas)
}

PR_ExtrairContasDoCsv(path) {
    if !FileExist(path)
        return PR_Erro("Planilha não encontrada: " path)

    ; O EXECUTASQL.exe grava o CSV em ANSI/Windows-1252. FileRead sem charset entrega
    ; os bytes crus, o que basta: só interessam dígitos, que são iguais nos dois.
    raw := FileRead(path)
    if (SubStr(raw, 1, 1) = Chr(0xFEFF))
        raw := SubStr(raw, 2)   ; BOM UTF-8, quando houver

    texto := StrReplace(raw, "`r`n", "`n")
    texto := StrReplace(texto, "`r", "`n")
    linhas := StrSplit(texto, "`n")

    if (linhas.Length < 2)
        return PR_Erro("Planilha sem linhas suficientes: " path)

    ; A coluna de contas é buscada pelo NOME no cabeçalho, nunca por índice fixo:
    ; a ordem das colunas do relatório do FFCV não é contrato.
    cabecalho := PR_SplitCsvLine(linhas[1])
    indice := 0
    for i, coluna in cabecalho {
        if (StrUpper(Trim(coluna)) = "CD_REG_AMB") {
            indice := i
            break
        }
    }

    if (indice = 0)
        return PR_Erro("Coluna CD_REG_AMB não encontrada no cabeçalho de: " path)

    Notify("Planilha " path ": coluna CD_REG_AMB é a nº " indice " do cabeçalho.")

    contas := []
    for i, linha in linhas {
        if (i = 1)
            continue   ; cabeçalho
        linha := Trim(linha)
        if (linha = "")
            continue

        colunas := PR_SplitCsvLine(linha)
        if (colunas.Length < indice)
            continue   ; linha truncada

        conta := RegExReplace(Trim(colunas[indice]), "\D")
        if (conta = "")
            continue   ; valor não numérico

        contas.Push(conta)
    }

    return contas
}

PR_DeduplicarContas(contas) {
    vistas := Map()
    unicas := []
    for _, conta in contas {
        if vistas.Has(conta)
            continue
        vistas[conta] := true
        unicas.Push(conta)
    }
    if (unicas.Length != contas.Length)
        Notify("Dedupe de contas: " contas.Length " → " unicas.Length ".")
    return unicas
}

PR_SplitCsvLine(line, sep := ";") {
    ; Substitui MV_SplitSemicolonCsvLine, que vinha de lib\globals\mv\ParseUtils.ahk —
    ; arquivo que não existe neste repositório. O separador é `;` porque é o que o
    ; relatório do FFCV grava.
    return StrSplit(StrReplace(line, '"', ""), sep)
}

; ════════════════════════════════════════════════════════════════
;  FASE 3 — MOV DOC: ENVIAR AS CONTAS
; ════════════════════════════════════════════════════════════════

PR_Fase3EnviarContas(cfg, contas) {
    resultado := Map("aceitas", 0, "pendentes", [], "setores", [], "erros", [])

    if !MV_EnsureMovDoc()
        return PR_Erro("Não foi possível acessar o MOV DOC. Abra e autentique o MOV DOC no MV2000i e tente de novo.")

    ; Tela de envio aberta uma vez. As contas seguintes reaproveitam a mesma tela.
    if !PR_AbrirTelaEnvio(cfg["setorAtual"], cfg["setorEnvio"], cfg["tipo"])
        return PR_Erro("A tela 'Protocolação de Envio de Documentos' não abriu no MOV DOC.")

    total := contas.Length
    for indice, conta in contas {
        if PR_Abortado() {
            resultado["erros"].Push("Execução interrompida na conta " indice "/" total ".")
            break
        }

        ; Reaproveita a tela se ela ainda estiver aberta. A baixa de protocolo e a
        ; correção de setor devolvem o fluxo ao menu, então a tela precisa poder
        ; ser reaberta com a configuração original.
        if !PR_EnsureTelaEnvio(cfg["setorAtual"], cfg["setorEnvio"], cfg["tipo"]) {
            resultado["erros"].Push("Conta " conta ": a tela de envio não pôde ser reaberta.")
            break
        }

        Notify("Conta " indice "/" total ": " conta ".")
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
        if (classificacao["estado"] = "ok") {
            if (classificacao["tipo"] = "documento_pendente")
                resultado["pendentes"].Push(Map("conta", conta, "protocolo", classificacao["protocolo"]))
            else
                resultado["setores"].Push(Map("conta", conta, "setorRecebido", classificacao["setorRecebido"],
                    "protocolo", classificacao["protocolo"]))
        } else {
            ; Mensagem NÃO reconhecida aborta. Nunca seguir operando em popup que
            ; não se entendeu: a ação errada aqui mexe em setor e protocolo.
            ; O popup fica aberto de propósito — o texto é a evidência.
            resultado["erros"].Push("Conta " conta ": " classificacao["erro"])
            throw Error(classificacao["erro"])
        }

        Progress(25 + Round(55 * indice / total))
    }

    return resultado
}

PR_AbrirTelaEnvio(setorAtual, setorEnvio, tipo) {
    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_ANY, 5)
        return PR_Erro("Não consegui ativar a janela do MOV DOC para abrir a tela de envio.")

    ; Atalho do menu: Alt+M, P, E. Base: Fluxos/protocolar.ahk L318.
    Notify("MOV DOC: abrindo 'Protocolação de Envio de Documentos' (Alt+M, P, E).")
    PR_SendMenuPath("mpe")

    if !PR_EsperarJanela(PR_WIN_MOVDOC_ENVIO, PR_MODAL_TIMEOUT_SEG)
        return PR_Erro("A tela 'Protocolação de Envio de Documentos' não apareceu em " PR_MODAL_TIMEOUT_SEG "s.")

    if !PR_ConfigurarTelaEnvio(setorAtual, setorEnvio, tipo)
        return false

    return true
}

PR_EnsureTelaEnvio(setorAtual, setorEnvio, tipo) {
    ; Caminho rápido: a tela continua aberta entre duas contas.
    if WinExist(PR_WIN_MOVDOC_ENVIO) {
        MV_EnsureWindowActive(PR_WIN_MOVDOC_ENVIO, 3)
        return true
    }

    ; A baixa de protocolo (ou a correção de setor) devolveu o fluxo ao menu:
    ; reabre a tela com a configuração ORIGINAL.
    Notify("MOV DOC: a tela de envio não está mais aberta. Reabrindo com a configuração original.")
    return PR_AbrirTelaEnvio(setorAtual, setorEnvio, tipo)
}

PR_ConfigurarTelaEnvio(setorAtual, setorEnvio, tipo) {
    if !MV_EnsureWindowActive(PR_WIN_MOVDOC_ENVIO, 5)
        return PR_Erro("A tela de envio não ficou ativa para configurar os setores.")

    Notify("MOV DOC: envio configurado " setorAtual " → " setorEnvio " (" tipo ").")
    SendText setorAtual
    Sleep PR_KEY_SETTLE_MS
    Send "{Enter}"
    Sleep PR_KEY_SETTLE_MS
    SendText setorEnvio
    Sleep PR_KEY_SETTLE_MS

    if !PR_ClicarControle(PR_WIN_MOVDOC_ENVIO, PR_ENVIO_BTN_CONFIRMAR)
        return PR_Erro("Não consegui confirmar os setores na tela de envio (Button2).")

    Sleep PR_DELAY_INPUT
    Send "{Tab 2}"
    Sleep PR_KEY_SETTLE_MS

    ; Hospitalar muda a sequência de teclas da tela de envio.
    if (tipo = PR_TIPO_HOSPITALAR) {
        Notify("MOV DOC: aplicando o ajuste de teclas do tipo Hospitalar.")
        Send "+{Tab 2}"
        Sleep PR_KEY_SETTLE_MS
        Send "{Up 2}"
        Sleep PR_KEY_SETTLE_MS
        Send "+{Tab 2}"
        Sleep PR_KEY_SETTLE_MS
    }

    return true
}

PR_EnviarConta(conta) {
    SendText conta
    Sleep PR_KEY_SETTLE_MS
    Send "{Enter}"
    Sleep PR_KEY_SETTLE_MS
}

PR_EsperarPopupMv(timeoutMs) {
    ; Timeout CURTO: conta aceita não abre popup. Janela do ifrun60.EXE.
    startedAt := A_TickCount
    Loop {
        try lista := WinGetList(PR_WIN_MV_MSG " ahk_exe " PR_EXE_MV)
        catch
            lista := []

        for w in lista {
            if PR_JanelaVisivel(w)
                return w
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return 0
        Sleep 20
    }
}

; ════════════════════════════════════════════════════════════════
;  FASE 4 — TRATAR O POPUP DO MV
; ════════════════════════════════════════════════════════════════

PR_TratarPopup(cfg, conta, popup) {
    texto := PR_LerMensagemPopup(popup)
    Notify("Popup da conta " conta ": " PR_ResumirTexto(texto))

    ; Precedência: documento pendente ANTES de setor divergente. A ação é escolhida
    ; pelo CONTEÚDO do popup, nunca pela posição dele na tela.
    protocolo := PR_ExtrairProtocoloPendente(texto)
    if (protocolo != "") {
        Notify("Conta " conta ": documento pendente de recebimento. Protocolo " protocolo ".")
        if !PR_FecharPopupMv(popup)
            return PR_ClassifErro("Conta " conta ": reconheci documento pendente do protocolo " protocolo
                ", mas não consegui fechar o popup do MV.")
        if !PR_BaixarProtocolo(protocolo)
            return PR_ClassifErro("Conta " conta ": não consegui baixar o protocolo " protocolo ".")
        return Map("estado", "ok", "tipo", "documento_pendente", "protocolo", protocolo, "erro", "")
    }

    setorRecebido := PR_ExtrairSetorRecebido(texto, cfg)
    if (setorRecebido != "") {
        Notify("Conta " conta ": setor divergente. Setor recebido " setorRecebido ".")
        if !PR_FecharPopupMv(popup)
            return PR_ClassifErro("Conta " conta ": reconheci setor divergente (" setorRecebido
                "), mas não consegui fechar o popup do MV.")
        if !PR_CorrigirSetorDaContaEBaixar(cfg, conta, setorRecebido)
            return PR_ClassifErro("Conta " conta ": não consegui corrigir o setor " setorRecebido
                " nem baixar o protocolo novo.")
        return Map("estado", "ok", "tipo", "setor_divergente", "setorRecebido", setorRecebido,
            "protocolo", "", "erro", "")
    }

    return PR_ClassifErro("Conta " conta ": popup do MV não reconhecido. Texto lido: " PR_ResumirTexto(texto))
}

PR_ClassifErro(erro) => Map("estado", "erro", "tipo", "", "protocolo", "", "setorRecebido", "", "erro", erro)

PR_ResumirTexto(texto, limite := 240) =>
    (StrLen(texto) > limite ? SubStr(texto, 1, limite) "…" : texto)

PR_LerMensagemPopup(popup) {
    ; WinGetText/Window Spy NÃO expõem a mensagem desses modais: eles devolvem só
    ; "&OK". A leitura passa por OCR da área client da janela.
    region := FFCV_ResolveOcrRegion("ahk_id " popup)
    if !region["ok"]
        return ""

    ocr := FFCV_RunOcrProbe(PR_OcrArgs(region), PR_OCR_LANGUAGE)
    if !ocr.Get("ok", false) {
        Notify("OCR do popup do MV falhou: " ocr.Get("error", "erro não informado"))
        return ""
    }

    return Trim(ocr.Get("fullText", ""))
}

PR_OcrArgs(region) =>
    " -X " region["x"] " -Y " region["y"] " -Width " region["w"] " -Height " region["h"] " -Scale " PR_OCR_SCALE

PR_FecharPopupMv(popup) {
    try WinActivate("ahk_id " popup)

    ; Botão primeiro (Button1 do MV), Enter como plano B.
    if PR_ClicarControleHwnd(popup, MV_MODAL_OK_CLASS) {
        if PR_EsperarPopupSumir(popup, PR_POPUP_QUEDA_TIMEOUT_MS)
            return true
    }

    try {
        WinActivate("ahk_id " popup)
        Send "{Enter}"
    }
    return PR_EsperarPopupSumir(popup, PR_POPUP_QUEDA_TIMEOUT_MS)
}

PR_EsperarPopupSumir(popup, timeoutMs) {
    startedAt := A_TickCount
    Loop {
        if !WinExist("ahk_id " popup)
            return true
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        if PR_Abortado()
            return false
        Sleep MV_POLL_MS
    }
}

PR_BaixarProtocolo(protocolo) {
    if Trim(protocolo) = ""
        return PR_Erro("Baixa de protocolo chamada com protocolo vazio.")

    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_ANY, 5)
        return PR_Erro("Não consegui ativar o MOV DOC para baixar o protocolo " protocolo ".")

    ; Atalho validado contra o MV2000i pelo operador (README de workflows):
    ; Alt+M, P, B abre 'Protocolação de Baixa de Documentos'.
    Notify("MOV DOC: baixando o protocolo " protocolo " (Alt+M, P, B).")
    PR_SendMenuPath("mpb")

    if !PR_EsperarJanela(MV_WIN_MOVDOC_BAIXA, PR_MODAL_TIMEOUT_SEG)
        return PR_Erro("A tela 'Protocolação de Baixa de Documentos' não abriu para o protocolo " protocolo ".")

    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_BAIXA, 5)
        return PR_Erro("A tela de baixa não ficou ativa para o protocolo " protocolo ".")

    SendText protocolo
    Sleep PR_KEY_SETTLE_MS
    Send "{F8}"
    Sleep PR_DELAY_INPUT

    if !PR_ClicarControle(MV_WIN_MOVDOC_BAIXA, PR_BAIXA_BTN_RECEBIDO)
        return PR_Erro("Não consegui acionar 'Recebido' na tela de baixa do protocolo " protocolo ".")

    Sleep PR_DELAY_INPUT
    Send "{F10}"
    Sleep PR_DELAY_INPUT

    ; Ctrl+Q + Enter: fecha a tela de baixa e confirma. NUNCA usar WinClose no Forms.
    Send MV_SAIR_TELA_ATALHO
    if !PR_EsperarJanelaEstavel(MV_WIN_MOVDOC_ANY, PR_FINAL_STABLE_MS, PR_FINAL_TIMEOUT_MS)
        Notify("Aviso: o MOV DOC não estabilizou após o Ctrl+Q da baixa do protocolo " protocolo ".")
    Send "{Enter}"
    Sleep PR_DELAY_INPUT

    Notify("Protocolo " protocolo " baixado.")
    return true
}

PR_CorrigirSetorDaContaEBaixar(cfg, conta, setorRecebido) {
    ; Operação COMPENSATÓRIA: reabre a tela de envio INVERTENDO os setores
    ; (setor recebido como atual, setor atual configurado como envio) para forçar
    ; a emissão do registro, tira o número de protocolo novo e dá baixa nele.
    ; Base: Fluxos/protocolar.ahk L473-L509.
    Notify("Conta " conta ": corrigindo o setor com " setorRecebido " como atual e "
        cfg["setorAtual"] " como envio.")
    PR_FecharPendencias()

    if !PR_AbrirTelaEnvio(setorRecebido, cfg["setorAtual"], cfg["tipo"])
        return PR_Erro("Conta " conta ": não consegui reabrir a tela de envio para corrigir o setor "
            setorRecebido ".")

    if !MV_EnsureWindowActive(PR_WIN_MOVDOC_ENVIO, 5)
        return PR_Erro("Conta " conta ": a tela de envio não ficou ativa para a correção de setor.")

    SendText conta
    Sleep PR_KEY_SETTLE_MS
    Send "!1"

    if !PR_EsperarJanela(PR_WIN_MOVREL_ENVIO, PR_MODAL_TIMEOUT_SEG)
        return PR_Erro("Conta " conta ": o 'Relatório de Registro de Envio' não apareceu para a correção de setor.")

    ; Button1 = Sair. O registro fica emitido; o número de protocolo é lido na tela
    ; de envio, não no relatório.
    if !PR_ClicarControle(PR_WIN_MOVREL_ENVIO, PR_MOVREL_BTN_SAIR)
        Notify("Aviso: não consegui clicar em Sair no 'Relatório de Registro de Envio' da conta " conta ".")
    PR_EsperarSumir(PR_WIN_MOVREL_ENVIO, PR_POPUP_QUEDA_TIMEOUT_MS)

    if !PR_EsperarJanela(PR_WIN_MOVDOC_ENVIO, PR_MODAL_TIMEOUT_SEG)
        return PR_Erro("Conta " conta ": a tela de envio não voltou após a correção de setor.")

    ; Campo Protocolo: coordenada CLIENT do Forms desenhado, sem ClassNN estável.
    CoordMode("Mouse", "Client")
    try WinActivate(PR_WIN_MOVDOC_ENVIO)
    Sleep PR_KEY_SETTLE_MS
    Click(PR_ENVIO_CAMPO_PROTOCOLO_X, PR_ENVIO_CAMPO_PROTOCOLO_Y, 1)
    Sleep PR_KEY_SETTLE_MS

    protocoloNovo := RegExReplace(PR_CopyFocusedNumericText(1000), "\D")
    if (protocoloNovo = "")
        return PR_Erro("Conta " conta ": não consegui copiar o número de protocolo novo do registro emitido.")

    Notify("Conta " conta ": protocolo novo copiado do registro de envio: " protocoloNovo ".")

    ; Ctrl+Q para devolver o MOV DOC ao menu antes da baixa.
    Send MV_SAIR_TELA_ATALHO
    if !PR_EsperarJanelaEstavel(MV_WIN_MOVDOC_ANY, PR_FINAL_STABLE_MS, PR_FINAL_TIMEOUT_MS)
        Notify("Aviso: o MOV DOC não estabilizou após o Ctrl+Q da correção de setor da conta " conta ".")

    if !PR_BaixarProtocolo(protocoloNovo)
        return PR_Erro("Conta " conta ": não consegui baixar o protocolo novo " protocoloNovo ".")

    return true
}

PR_CopyFocusedNumericText(timeoutMs := 600) {
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(timeoutMs / 1000)
        return ""
    return Trim(A_Clipboard)
}

; ════════════════════════════════════════════════════════════════
;  FASE 5 — FINALIZAR
; ════════════════════════════════════════════════════════════════

PR_Fase5Finalizar(cfg) {
    if !PR_EsperarJanela(PR_WIN_MOVDOC_ENVIO, PR_MODAL_TIMEOUT_SEG) {
        Notify("Aviso: a tela de envio não está aberta na finalização; pulando a exclusão do registro em branco.")
        return true
    }

    if !MV_EnsureWindowActive(PR_WIN_MOVDOC_ENVIO, 5)
        return PR_Erro("A tela de envio não ficou ativa para excluir o registro em branco.")

    ; O registro em branco foi criado pelo {Enter} da ÚLTIMA conta. Excluir é o
    ; primeiro passo da finalização nos dois caminhos (imprimir ou não).
    Notify("MOV DOC: excluindo o registro em branco (prefixo " PR_ENVIO_BTN_EXCLUIR ").")
    if !PR_ClicarPorPrefixoClasse(PR_WIN_MOVDOC_ENVIO, PR_ENVIO_BTN_EXCLUIR)
        return PR_Erro("Não consegui localizar o botão de excluir do registro em branco (prefixo "
            PR_ENVIO_BTN_EXCLUIR "). A tela de envio pode ter ficado com o registro em branco aberto.")

    Sleep PR_DELAY_INPUT

    ; ── imprimir_salvar_envio = Não ────────────────────────────
    ; Parar AQUI, antes do Alt+1: o registro em branco já foi excluído e o MOV DOC
    ; fica aberto para o operador conferir.
    if !cfg["imprimir"] {
        Notify("Imprimir/salvar envio = Não: registro em branco excluído e Alt+1 NÃO enviado. MOV DOC permanece aberto.")
        return true
    }

    ; ── imprimir_salvar_envio = Sim ────────────────────────────
    Notify("MOV DOC: abrindo o 'Relatório de Registro de Envio' (Alt+1).")
    Send "!1"

    if !PR_EsperarJanela(PR_WIN_MOVREL_ENVIO, PR_MODAL_TIMEOUT_SEG)
        return PR_Erro("O 'Relatório de Registro de Envio' não apareceu para a impressão.")

    PR_FecharRelatoriosDeFundo()

    if !PR_ClicarControle(PR_WIN_MOVREL_ENVIO, PR_MOVREL_BTN_IMPRIMIR)
        return PR_Erro("Não consegui acionar 'Imprimir' no 'Relatório de Registro de Envio' (Button2).")

    Sleep PR_DELAY_INPUT
    PR_FecharRelatoriosDeFundo()

    if !MV_EnsureWindowActive(MV_WIN_MOVDOC_ANY, 5) {
        Notify("Aviso: não consegui ativar o MOV DOC para fechá-lo após a impressão.")
        return true
    }

    Send MV_SAIR_TELA_ATALHO
    if !PR_EsperarJanelaEstavel(MV_WIN_MOVDOC_ANY, PR_FINAL_STABLE_MS, PR_FINAL_TIMEOUT_MS)
        Notify("Aviso: o MOV DOC não estabilizou após o Ctrl+Q da tela de envio.")

    Notify("Relatório de registro de envio impresso e MOV DOC devolvido ao menu.")
    return true
}

PR_FecharRelatoriosDeFundo() {
    ; Janela: "Operação de Fundo dos Relatórios" (RWRBE60.EXE).
    ;_win_close_ é aceitável AQUI porque essa janela é do RWRBE60.EXE, não do Forms.
    ; NUNCA usar WinClose nas janelas do ifrun60.EXE: o Forms perde estado.
    Loop 20 {
        if PR_Abortado()
            return
        try lista := WinGetList("Operação de Fundo dos Relatórios")
        catch
            lista := []

        achou := false
        for w in lista {
            if PR_JanelaVisivel(w) {
                achou := true
                try WinClose("ahk_id " w)
                Sleep PR_DELAY_INPUT
            }
        }

        if !achou
            return
        Sleep PR_KEY_SETTLE_MS
    }

    Notify("Aviso: a janela 'Operação de Fundo dos Relatórios' não fechou sozinha.")
}

; ════════════════════════════════════════════════════════════════
;  CLASSIFICAÇÃO DO POPUP (lógica pura, testável sem o MV)
; ════════════════════════════════════════════════════════════════

PR_ExtrairProtocoloPendente(texto) {
    ; Exige os TRÊS sinais: "pendente" + ("devolu"|"receb"|"document")
    ; + número de 4+ dígitos depois de "protoc*". Qualquer um faltando, devolve "".
    ; Base: Fluxos/protocolar.ahk L1569-L1592
    fraco := PR_NormalizarOcr(texto)

    if !InStr(fraco, "pendente")
        return ""
    if !(InStr(fraco, "devolu") || InStr(fraco, "receb") || InStr(fraco, "document"))
        return ""

    ; Aceita Protocolo/Protocola/Protocol0 e as variações OCR de "n.º", "n.0", "nº".
    if RegExMatch(fraco, "protoc[a-z0-9]*\s*(?:n|n\.|n0|no|numero|num)?\s*[\.:º°o0]*\s*(\d{4,})", &m)
        return m[1]

    ; Fallback seguro: em mensagem de pendência, primeiro número longo após "protoc*".
    pos := RegExMatch(fraco, "protoc[a-z0-9]*")
    if pos {
        resto := SubStr(fraco, pos)
        if RegExMatch(resto, "(\d{4,})", &m)
            return m[1]
    }

    return ""
}

PR_ExtrairSetorRecebido(texto, cfg := "") {
    ; Exige "setor" + "diferente" + "conta" (o OCR lê "canta"/"cont4", já normalizado).
    ; Sem os três, devolve "": é o que separa o erro de setor do erro de documento.
    ; Base: Fluxos/protocolar.ahk L1594-L1658
    fraco := PR_NormalizarOcr(texto)

    if !(InStr(fraco, "setor") && InStr(fraco, "diferente") && InStr(fraco, "conta"))
        return ""

    candidato := ""

    ; Prioridade: número logo depois de "Setor recebido".
    if RegExMatch(fraco, "setor\s*(?:recebido|recebida|recebid0|receb1do|receb|receh|recen|reced)[a-z0-9]*\s*[:;.,\-]?\s*(\d{1,4})", &m)
        candidato := m[1]

    ; Fallback: trecho entre "setor receb..." e "conta".
    if (candidato = "") {
        pos := RegExMatch(fraco, "setor\s*(?:receb|receh|recen|reced)[a-z0-9]*")
        if !pos
            pos := RegExMatch(fraco, "receb[a-z0-9]*")

        if pos {
            trecho := SubStr(fraco, pos)
            contaPos := InStr(trecho, "conta")
            if contaPos
                trecho := SubStr(trecho, 1, contaPos - 1)

            ; Setor é curto (1..4 dígitos); conta costuma ter 7 ou 8. O limite corta falso positivo.
            if RegExMatch(trecho, "\b(\d{1,4})\b", &m)
                candidato := m[1]
        }
    }

    ; Fallback controlado para OCR muito distorcido: último número curto entre
    ; "diferente" e "conta".
    if (candidato = "") {
        ini := InStr(fraco, "diferente")
        fim := InStr(fraco, "conta")
        if (ini && fim && fim > ini) {
            trecho := SubStr(fraco, ini, fim - ini)
            numeros := []
            posNum := 1
            while (posNum := RegExMatch(trecho, "\b\d{1,4}\b", &m, posNum)) {
                numeros.Push(m[0])
                posNum += StrLen(m[0])
            }
            if (numeros.Length > 0)
                candidato := numeros[numeros.Length]
        }
    }

    if (candidato = "")
        return ""

    return PR_CorrigirSetorPorContexto(candidato, cfg, fraco)
}

PR_CorrigirSetorPorContexto(candidato, cfg, fraco) {
    ; Correção CONSERVADORA do caso real "356" lido como "336". Só aplica quando
    ; TODAS as condições batem — nunca em qualquer número solto da mensagem:
    ;   a) mesmo tamanho do setor_envio configurado;
    ;   b) difere em exatamente 1 dígito do setor_envio configurado;
    ;   c) a mensagem tem a estrutura do erro de setor (setor + receb*);
    ;   d) a mensagem menciona o setor_atual configurado ANTES da palavra "diferente".
    ; Base: Fluxos/protocolar.ahk L1660-L1695
    candidato := RegExReplace(candidato, "\D")
    if (candidato = "")
        return ""

    if !IsObject(cfg)
        return candidato

    esperado := RegExReplace(cfg["setorEnvio"], "\D")
    setorAtual := RegExReplace(cfg["setorAtual"], "\D")

    if (esperado = "" || candidato = esperado)
        return candidato

    if (StrLen(candidato) != StrLen(esperado) || PR_DistanciaDigitos(candidato, esperado) != 1)
        return candidato
    if !(InStr(fraco, "setor") && InStr(fraco, "receb"))
        return candidato

    posDif := InStr(fraco, "diferente")
    antesDiferente := posDif ? SubStr(fraco, 1, posDif - 1) : fraco
    if (setorAtual != "" && !RegExMatch(antesDiferente, "\b" setorAtual "\b"))
        return candidato

    Notify("Setor recebido corrigido por contexto/OCR: lido=" candidato
        " | usando o setor de envio configurado=" esperado ".")
    return esperado
}

PR_DistanciaDigitos(a, b) {
    if (StrLen(a) != StrLen(b))
        return 999
    dist := 0
    Loop StrLen(a) {
        if (SubStr(a, A_Index, 1) != SubStr(b, A_Index, 1))
            dist++
    }
    return dist
}

PR_NormalizarOcr(texto) {
    ; Minúsculo, sem acento, espaços colapsados e as trocas típicas do OCR nos
    ; popups do MV. Base: Fluxos/protocolar.ahk L1709-L1751
    texto := StrLower(StrReplace(StrReplace(texto, "`r", " "), "`n", " "))
    texto := PR_RemoverAcentos(texto)

    texto := StrReplace(texto, "n.º", "n")
    texto := StrReplace(texto, "n°", "n")
    texto := StrReplace(texto, "nº", "n")
    texto := StrReplace(texto, "n.0", "n")
    texto := StrReplace(texto, "n.o", "n")
    texto := StrReplace(texto, "n 0", "n")
    texto := StrReplace(texto, "protocol0", "protocolo")
    texto := StrReplace(texto, "protoco1o", "protocolo")
    texto := StrReplace(texto, "documenta ", "documento ")
    texto := StrReplace(texto, "recebimenta", "recebimento")

    ; "canta"/"cont4"/"conla" são leituras comuns de "conta" nesse popup.
    texto := RegExReplace(texto, "\bcanta\b", "conta")
    texto := RegExReplace(texto, "\bcont4\b", "conta")
    texto := RegExReplace(texto, "\bconla\b", "conta")

    return Trim(RegExReplace(texto, "\s+", " "))
}

PR_RemoverAcentos(texto) {
    trocas := Map(
        "á", "a", "à", "a", "â", "a", "ã", "a", "ä", "a",
        "é", "e", "ê", "e", "è", "e", "ë", "e",
        "í", "i", "ì", "i", "î", "i", "ï", "i",
        "ó", "o", "ò", "o", "ô", "o", "õ", "o", "ö", "o",
        "ú", "u", "ù", "u", "û", "u", "ü", "u",
        "ç", "c"
    )
    for de, para in trocas
        texto := StrReplace(texto, de, para)
    return texto
}

; ════════════════════════════════════════════════════════════════
;  CONTROLES, ESPERAS E RECUPERAÇÃO
; ════════════════════════════════════════════════════════════════

PR_Abortado() {
    global gRunning
    return !gRunning
}

PR_EsperarJanela(winTitle, timeoutSec) {
    startedAt := A_TickCount
    Loop {
        if WinExist(winTitle)
            return true
        ; gRunning é COOPERATIVO: checar dentro da espera faz o botão Parar
        ; agir durante a espera, e não só no próximo ponto de checagem.
        if (A_TickCount - startedAt >= timeoutSec * 1000)
            return false
        if PR_Abortado()
            return false
        Sleep MV_POLL_MS
    }
}

PR_EsperarSumir(winTitle, timeoutMs) {
    startedAt := A_TickCount
    Loop {
        if !WinExist(winTitle)
            return true
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        if PR_Abortado()
            return false
        Sleep MV_POLL_MS
    }
}

PR_EsperarJanelaEstavel(winTitle, stableMs, timeoutMs) {
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        if (WinExist(winTitle) && !PR_Abortado()) {
            try hwnds := WinGetControlsHwnd(winTitle)
            catch
                hwnds := []
            count := hwnds.Length

            if (WinActive(winTitle) && count = lastCount) {
                if (stableSince = 0)
                    stableSince := A_TickCount
                if (A_TickCount - stableSince >= stableMs)
                    return true
            } else {
                stableSince := 0
                lastCount := count
            }
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

PR_EsperarArquivo(caminhos, timeoutMs) {
    startedAt := A_TickCount
    Loop {
        for caminho in caminhos {
            if FileExist(caminho)
                return caminho
        }
        if (A_TickCount - startedAt >= timeoutMs)
            return ""
        if PR_Abortado()
            return ""
        Sleep MV_POLL_MS
    }
}

PR_SendMenuPath(caminho) {
    ; Reproduz o SendMenuPath do original: Alt + primeira letra, depois as demais
    ; uma a uma. "mpe" = Alt+M, P, E. "mpb" = Alt+M, P, B.
    ; Base: Fluxos/protocolar.ahk L1099-L1114
    if StrLen(caminho) < 1
        return

    Send "!" SubStr(caminho, 1, 1)
    Sleep PR_MENU_STEP_MS

    Loop Parse SubStr(caminho, 2) {
        Send A_LoopField
        Sleep PR_MENU_STEP_MS
    }
}

PR_ClicarControle(winTitle, classNN) {
    return MV_ClickFirstControl(winTitle, classNN)
}

PR_ClicarControleHwnd(hwnd, classNN) {
    if !hwnd
        return false
    try hwnds := WinGetControlsHwnd("ahk_id " hwnd)
    catch
        return false

    for c in hwnds {
        try ctrlClass := ControlGetClassNN(c)
        catch
            continue
        if (ctrlClass = classNN) {
            ControlClick c,,,,, "NA"
            return true
        }
    }
    return false
}

PR_ClicarPorPrefixoClasse(winTitle, classPrefix) {
    ; ENVIO_BTN_EXCLUIR é PREFIXO de classe (ui60Viewcore_W3211), não ClassNN exato:
    ; o Oracle Forms renumera a viewcore conforme o estado da tela.
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (SubStr(ctrlClass, 1, StrLen(classPrefix)) = classPrefix) {
            ControlClick hwnd,,,,, "NA"
            return true
        }
    }
    return false
}

PR_ControleExiste(hwnd, classNN) {
    if !hwnd
        return false
    try hwnds := WinGetControlsHwnd("ahk_id " hwnd)
    catch
        return false
    for c in hwnds {
        try ctrlClass := ControlGetClassNN(c)
        catch
            continue
        if (ctrlClass = classNN)
            return true
    }
    return false
}

PR_JanelaVisivel(hwnd) {
    if !hwnd
        return false
    try return WinGetStyle("ahk_id " hwnd) & 0x1000000   ; WS_VISIBLE
    catch
        return false
}

PR_FecharPendencias() {
    ; Limpa telas auxiliares SEM fechar o MV. Seguro para chamar no meio do fluxo.
    if WinExist(PR_WIN_MV_MSG) {
        ; O popup do MV NÃO é fechado às cegas: a classificação é o que decide
        ; a ação, e o operador precisa do texto na tela.
        Notify("Recuperação: há um popup do MV aberto. Ele NÃO foi fechado automaticamente —"
            " a mensagem precisa ser lida. Resolva na tela antes de rodar de novo.")
    }

    if WinExist(PR_WIN_MOVREL_ENVIO) {
        Notify("Recuperação: fechando o 'Relatório de Registro de Envio' pendente.")
        PR_ClicarControle(PR_WIN_MOVREL_ENVIO, PR_MOVREL_BTN_SAIR)
        PR_EsperarSumir(PR_WIN_MOVREL_ENVIO, PR_POPUP_QUEDA_TIMEOUT_MS)
    }

    PR_FecharRelatoriosDeFundo()
}

PR_RecuperarTelas(cfg) {
    ; Só no FIM do fluxo: devolve o MV a um estado previsível e fecha a última tela.
    ; No meio do fluxo use PR_FecharPendencias — fechar o MV ali quebraria a execução.
    ; NUNCA usar WinClose nas janelas do ifrun60.EXE.
    try {
        PR_FecharPendencias()

        ; imprimir/salvar = Não é a única exceção à saída obrigatória: o spec manda deixar o
        ; MOV DOC aberto para o operador conferir. Nos demais casos o fluxo fecha o MV.
        if !cfg["imprimir"] {
            Notify("Recuperação: imprimir/salvar = Não, o MOV DOC permanece aberto para conferência.")
            return
        }

        MV_FecharUltimaTela(MV_WIN_MOVDOC_ANY, "MOV DOC")
    } catch as e {
        Notify("Aviso na recuperação de telas: " e.Message)
    }
}

; ════════════════════════════════════════════════════════════════
;  UTILITÁRIOS DO MÓDULO
; ════════════════════════════════════════════════════════════════

PR_ParseRemessas(str) {
    resultado := []
    for _, item in StrSplit(str, ",") {
        remessa := Trim(item)
        if (remessa != "")
            resultado.Push(remessa)
    }
    return resultado
}

; Lança o erro. Usado como `return PR_Erro(...)` nas rotinas que devolvem valor:
; o throw sobe até o try/catch de RunProtocolar, que fecha a execução com PR_Abort.
PR_Erro(msg) {
    throw Error(msg)
}

JoinPR(itens, sep := ",") {
    saida := ""
    for item in itens
        saida .= (saida = "" ? "" : sep) item
    return saida
}

PR_Abort(msg) {
    ; Delega o erro ao contrato compartilhado e só então fecha o status da execução,
    ; como o stub fazia.
    resultado := MV_Abort(msg)
    SendToUI(Map("type", "status", "message", "Execução finalizada.", "running", false))
    return resultado
}
