; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0

SetTitleMatchMode 2
DetectHiddenText true
SetControlDelay 0
SetWinDelay 0
SetKeyDelay 0, 0

; ════════════════════════════════════════════════════════════════
;  MV SESSION — módulo compartilhado
; ════════════════════════════════════════════════════════════════

; ── Executável, atalhos e janelas ─────────────────────────────
MV_PROJECT_ROOT   := RegExReplace(A_ScriptDir, "\\scripts$", "")
MV_SHORTCUT_DIR   := MV_PROJECT_ROOT "\atalhos"
MV_MOVDOC_LNK     := MV_SHORTCUT_DIR "\MOVDOC.lnk"
MV_FFCV_LNK       := MV_SHORTCUT_DIR "\FFCV.lnk"
MV_WIN_IDENTIFICACAO := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"

; Atenção: para detecção inicial, nunca exigir subtela exata.
; O usuário pode ter deixado MOV DOC/FFCV aberto em qualquer tela interna.
MV_WIN_MOVDOC_ANY := "Movimentação ahk_exe ifrun60.EXE"
; Detectar FFCV pelo executável e título principal para evitar dependência de subtela.
MV_WIN_FFCV_ANY   := "Faturamento ahk_exe ifrun60.EXE"

; Títulos específicos só devem ser usados depois de navegar para a tela esperada.
MV_WIN_MOVDOC_BAIXA := "Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"
MV_WIN_FFCV_REMESSA := "MV2000i - Faturamento ahk_exe ifrun60.EXE"
MV_WIN_FFCV         := MV_WIN_FFCV_ANY
MV_WIN_MOVDOC       := MV_WIN_MOVDOC_ANY

; ── Controles de popups conhecidos ────────────────────────────
MV_MODAL_OK_CLASS := "Button1"
; Título/tipo do modal do Oracle Forms usado para detectar popups abertos.
MV_FORMS_MODAL    := "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
; Janela de "Mensagem ao Usuário do MV 2000" (OK de confirmação, Sim/Não de sobrescrita).
MV_WIN_MSG_USER  := "Mensagem ao Usuário do MV 2000"

; ── Janelas do fluxo de remessa ───────────────────────────────
MV_WIN_FFCV_DATAS    := "Cadastro: Faturas e Remessas"
MV_WIN_CAPA_REMESSA  := "Relatório de Atendimentos da Remessa"
MV_WIN_XML_TISS      := "Monitoração de Faturamento - TISS"
MV_WIN_XML_PATH_FORM := "MV2000i - Faturamento - [WIN_PRINCIPAL]"
; Janela de progresso da impressão, no processo de relatórios (RWRBE60.EXE) —
; e NÃO no ifrun60.EXE. Fecha sozinha quando a impressão acaba.
MV_WIN_ANDAMENTO     := "Andamento do Relatório ahk_exe RWRBE60.EXE"

; ── Controles do relatório de atendimentos ─────────────────────
; Botão que abre o relatório a partir do menu do FFCV. NÃO existe em todas as
; telas — por isso FX_AbrirTelaEntrega checa a prontidão antes de clicar, como
; o fluxo validado (Fechar&XML.ahk:136-139, :222-223).
; Sem coordenada de propósito: o validado usa só ControlClick, e coordenada aqui
; viria de Window Spy que não existe versionado. MV_ClickFirstControl também
; não cai no clique cego por coordenada do MV_ClickBySpec.
MV_WIN_FFCV_BTN_RELATORIO := "Button9"
; Botão de impressão dentro da tela do relatório. Fonte: Fechar&XML.ahk:225.
MV_WIN_CAPA_REMESSA_BTN_IMPRIMIR := "Button2"

; ── Atalhos de teclado validados ──────────────────────────────
; Atalho: Lançamentos → Monitoração de Faturamento - TISS.
; Confirmado contra o MV2000i pelo operador. Spy em Fluxos/Teste_corrigido.ahk L314.
MV_TISS_ATALHO := "{Alt down}lmm{Enter}{Alt up}"
; Atalho: Lançamentos → Entrega de Remessas (Cadastro: Faturas e Remessas),
; direto do menu do FFCV. Confirmado pelo fluxo validado em
; Praxis_TO-DO/Fechar&XML/Fechar&XML.ahk:140 e :175, que usa exatamente este
; atalho para abrir e para reabrir a tela entre as remessas.
MV_ENTREGA_REMESSAS_ALTALHO := "{Alt down}l{Alt up}e"
; Saída de tela no MV2000i. Confirmado pelo operador: Ctrl+Q vale para TODAS as telas.
; No menu principal fecha o MV. Em AHK, "^q" É a notação de Ctrl+Q — não ajustar.
; {Esc} foi descartado: não sai da tela de Entrega de Remessas.
MV_SAIR_TELA_ATALHO := "^q"

; ── Controles tela de datas ───────────────────────────────────
; Tela "Cadastro: Faturas e Remessas". Coordenadas Client vindas de Window Spy.
; Capturas originais estão em Fluxos/, que é gitignored e não existe neste checkout;
; o spec que as trazia (.agents/workflows/01-remessa-protocolo.md) também não é
; versionado. As coordenadas abaixo vieram do Window Spy do operador e não são
; auditáveis em um clone novo — ao mexer aqui, exigir captura nova.
; docs/analise-causa-raiz/06-sistematico-origem-das-constantes.md
MV_DATAS_CAMPO_REMESSA    := "Edit5"
MV_DATAS_CAMPO_REMESSA_X  := 59
MV_DATAS_CAMPO_REMESSA_Y  := 101
MV_DATAS_CAMPO_ENTREGA    := "Edit1"
MV_DATAS_CAMPO_ENTREGA_X  := 146
MV_DATAS_CAMPO_ENTREGA_Y  := 101
MV_DATAS_CAMPO_VENCIMENTO := "Edit1"
MV_DATAS_CAMPO_VENCIMENTO_X := 244
MV_DATAS_CAMPO_VENCIMENTO_Y := 227
MV_DATAS_CHECKBOX         := "Button3"
MV_DATAS_CHECKBOX_X       := 541
MV_DATAS_CHECKBOX_Y       := 242
MV_DATAS_BTN_CONFIRMAR    := "Button10"
MV_DATAS_BTN_CONFIRMAR_X  := 30
MV_DATAS_BTN_CONFIRMAR_Y  := 426
MV_DATAS_BTN_VOLTAR       := "Button7"

; ── Controles tela XML ────────────────────────────────────────
; Tela "Monitoração de Faturamento - TISS". Coordenadas Client vindas de Window Spy.
; Mesma ressalva de proveniência do bloco de datas acima: sem captura versionada.
MV_XML_CAMPO_REMESSA   := "Edit1"
MV_XML_CAMPO_REMESSA_X := 272
MV_XML_CAMPO_REMESSA_Y := 89
MV_XML_BTN_BUSCAR      := ""        ; consulta continua por F8
MV_XML_BTN_FATURAMENTO := "Button7"  ; 1 Faturamento
MV_XML_BTN_FATURAMENTO_X := 12
MV_XML_BTN_FATURAMENTO_Y := 446
MV_XML_FORM_CAMPO_PATH   := "Edit1"
MV_XML_FORM_CAMPO_PATH_X := 267       ; Window Spy: client x dentro do Edit1 do caminho XML
MV_XML_FORM_CAMPO_PATH_Y := 467       ; Window Spy: client y dentro do Edit1 do caminho XML
MV_XML_FORM_BTN_SALVAR   := "Button4" ; Salvar_XML / Window Spy: Visualizar XML
MV_XML_FORM_BTN_SALVAR_X := 623       ; Window Spy: client x do Button4
MV_XML_FORM_BTN_SALVAR_Y := 471       ; Window Spy: client y do Button4
MV_XML_BTN_NAO           := "Button2"
MV_XML_FORM_BTN_VOLTAR   := "Button7" ; Voltar
MV_XML_FORM_BTN_VOLTAR_X := 731       ; Window Spy: client x do Button7
MV_XML_FORM_BTN_VOLTAR_Y := 470       ; Window Spy: client y do Button7

; ── Polling / estabilidade ────────────────────────────────────
MV_POLL_MS          := 100
MV_TIMEOUT_LOAD     := 100
MV_TIMEOUT_ACOE     := 100
MV_DELAY_INPUT      := 100
MV_MODULE_STABLE_MS := 600
MV_TARGET_STABLE_MS := 600

; ── Entrada por teclado/campo Oracle Forms ─────────────────────
; Padrão validado no macro 11: micro-settle suficiente para estabilidade sem sleeps longos.
MV_FIELD_FOCUS_SETTLE_MS := 100
MV_FIELD_CLEAR_SETTLE_MS := 100
MV_KEY_SETTLE_MS         := 100

; ── Formato de data dos campos do Oracle Forms ────────────────
; O FFCV exige dd/mm/aaaa e RECUSA yyyy-mm-dd (confirmado pelo operador).
; A UI entrega yyyy-mm-dd porque <input type="date"> segue a spec HTML,
; independente do locale exibido. A conversão acontece aqui, na fronteira
; com o MV, e não no JS — `gScripts` (main.ahk) e `devSim()` (ui/index.html)
; descrevem os mesmos scripts em duplicado, e normalizar no AHK cobre os dois
; caminhos com uma função. docs/analise-causa-raiz/03-fechar-xml-data-formato-americano.md
MV_DATA_FORMATO_FFCV := "dd/MM/yyyy"
MV_DATA_REGEX_ISO   := "^\d{4}-\d{2}-\d{2}$"

; ── Esperas da fase de fechamento/XML ─────────────────────────
; Esta fase dispara processamentos pesados no Oracle Forms. Evitar avançar apenas
; porque o clique foi aceito; aguardar janela/modal/cursor estabilizarem.
MV_FINAL_STABLE_MS             := 800
MV_FINAL_ACTION_TIMEOUT_MS     := 30000
MV_XML_QUERY_MIN_WAIT_MS       := 1200

; ════════════════════════════════════════════════════════════════
;  API PÚBLICA
; ════════════════════════════════════════════════════════════════

MV_EnsureMovDoc() {
    if WinExist(MV_WIN_MOVDOC_ANY) {
        MV_ActivateModule(MV_WIN_MOVDOC_ANY)
        if MV_WaitWindowStable(MV_WIN_MOVDOC_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
            return true
        ; se a janela de identificação aparecer, a automação não prossegue
    }

    if WinExist(MV_WIN_IDENTIFICACAO)
        return MV_AbortAuthenticationRequired("MOV DOC")

    ; Não abrir novo MOV DOC via atalho. Se não estiver aberto, abortar.
    return false
}

MV_EnsureFFCV() {
    if WinExist(MV_WIN_FFCV_ANY) {
        MV_ActivateModule(MV_WIN_FFCV_ANY)
        if MV_WaitWindowStable(MV_WIN_FFCV_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
            return true
        ; se a janela de identificação aparecer, a automação não prossegue
    }

    if WinExist(MV_WIN_IDENTIFICACAO)
        return MV_AbortAuthenticationRequired("FFCV")

    ; Não abrir novo FFCV via atalho. Se não estiver aberto, abortar.
    return false
}

MV_AbrirMovDoc() {
    ; Abertura por atalho está desabilitada neste fluxo.
    return false
}

MV_AbrirFFCV() {
    ; Abertura por atalho está desabilitada neste fluxo.
    return false
}

; ════════════════════════════════════════════════════════════════
;  AUTENTICAÇÃO AUTOMÁTICA DESABILITADA
; ════════════════════════════════════════════════════════════════

MV_AbortAuthenticationRequired(moduleName) {
    global gRunning
    gRunning := false

    message := "O Praxis não executa autenticação automática. Abra e autentique o " moduleName " manualmente no MV2000i antes de iniciar a automação."
    try SendToUI(Map("type", "error", "message", message))
    return false
}

; ════════════════════════════════════════════════════════════════
;  DETECÇÃO / CONTROLES
; ════════════════════════════════════════════════════════════════

MV_ModuleReady(moduleWin) {
    return MV_WinReady(moduleWin)
}

MV_ActivateModule(moduleWin) {
    if WinExist(moduleWin) {
        WinActivate moduleWin
        MV_Poll(() => WinActive(moduleWin), 3)
    }
}

MV_WinReady(title) {
    if !WinExist(title)
        return false
    return WinGetMinMax(title) != -1
}

MV_DoubleClickControlAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    ControlClick hwnd,,,, 2, "NA"
    return true
}

MV_ClickControlAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    ControlClick hwnd,,,,, "NA"
    return true
}

MV_ClickFirstControl(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN) {
            ControlClick hwnd,,,,, "NA"
            return true
        }
    }
    return false
}

MV_FocusControlAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    ControlFocus hwnd
    return true
}

MV_SetTextControlAt(winTitle, classNN, clientX, clientY, value, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    ControlFocus hwnd
    Sleep MV_DELAY_INPUT
    SendText value
    return true
}

MV_SetTextEditAtPoint(winTitle, clientX, clientY, value, tolerance := 14) {
    hwnd := MV_FindEditByClientPoint(winTitle, clientX, clientY, tolerance)
    if !hwnd
        return false

    WinActivate winTitle
    MV_Poll(() => WinActive(winTitle), 2)
    CoordMode("Mouse", "Client")
    Click(clientX + 15, clientY + 8, 1)
    Sleep 20
    Send "{Home}{Shift down}{End}{Shift up}{Backspace}"
    Sleep 20
    SendText value
    return true
}

MV_FocusEditAtPoint(winTitle, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindEditByClientPoint(winTitle, clientX, clientY, tolerance)
    if !hwnd
        return false

    WinActivate winTitle
    MV_Poll(() => WinActive(winTitle), 2)
    ControlFocus hwnd
    return true
}

MV_ReadEditAtPoint(winTitle, clientX, clientY, expectedPattern := "", tolerance := 14) {
    hwnd := MV_FindEditByClientPoint(winTitle, clientX, clientY, tolerance)
    if !hwnd
        return ""

    try text := Trim(ControlGetText(hwnd))
    catch
        return ""

    return MV_TextMatchesExpected(text, expectedPattern) ? text : ""
}

MV_TextMatchesExpected(text, expectedPattern := "") {
    if (text = "")
        return false
    if (expectedPattern = "")
        return true
    return RegExMatch(text, expectedPattern)
}

MV_FindEditByClientPoint(winTitle, targetX, targetY, tolerance := 14) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    bestHwnd := 0
    bestDist := 999999

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue

        if (SubStr(ctrlClass, 1, 4) != "Edit")
            continue

        try ControlGetPos &cx, &cy, &cw, &ch, hwnd
        catch
            continue

        if (targetX >= cx && targetX <= cx + cw && targetY >= cy && targetY <= cy + ch)
            return hwnd

        centerX := cx + (cw / 2)
        centerY := cy + (ch / 2)
        dist := Sqrt((targetX - centerX) ** 2 + (targetY - centerY) ** 2)
        if (dist < bestDist) {
            bestDist := dist
            bestHwnd := hwnd
        }
    }

    return (bestHwnd && bestDist <= tolerance) ? bestHwnd : 0
}

MV_ControlCheckedAt(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return ""

    try return ControlGetChecked(hwnd)
    catch
        return ""
}

MV_FindControlByClientPoint(winTitle, classNN, targetX, targetY, tolerance := 14) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    bestHwnd := 0
    bestDist := 999999

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue

        if (ctrlClass != classNN)
            continue

        try ControlGetPos &cx, &cy, &cw, &ch, hwnd
        catch
            continue

        if (targetX >= cx && targetX <= cx + cw && targetY >= cy && targetY <= cy + ch)
            return hwnd

        centerX := cx + (cw / 2)
        centerY := cy + (ch / 2)
        dist := Sqrt((targetX - centerX) ** 2 + (targetY - centerY) ** 2)
        if (dist < bestDist) {
            bestDist := dist
            bestHwnd := hwnd
        }
    }

    return (bestHwnd && bestDist <= tolerance) ? bestHwnd : 0
}

MV_Poll(condFn, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        if condFn()
            return true
        if A_TickCount > deadline
            return false
        Sleep MV_POLL_MS
    }
}

MV_WaitWindowStable(winTitle, stableMs := 600, timeoutSecs := 20) {
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        if WinExist(winTitle) {
            WinActivate winTitle
            try hwnds := WinGetControlsHwnd(winTitle)
            catch
                hwnds := []
            count := hwnds.Length

            if WinActive(winTitle) && count = lastCount {
                if (stableSince = 0)
                    stableSince := A_TickCount
                if (A_TickCount - stableSince >= stableMs)
                    return true
            } else {
                stableSince := 0
                lastCount := count
            }
        }

        if (A_TickCount - startedAt > timeoutSecs * 1000)
            return false

        Sleep MV_POLL_MS
    }
}

MV_WaitAnyWindow(titles, timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        for title in titles {
            if WinExist(title)
                return title
        }
        if A_TickCount > deadline
            return ""
        Sleep MV_POLL_MS
    }
}

; ════════════════════════════════════════════════════════════════
;  CONTRATO DE JANELA, MODAL E ENTRADA
; ════════════════════════════════════════════════════════════════

MV_PollMs(condFn, timeoutMs, intervalMs := 20) {
    startedAt := A_TickCount
    Loop {
        if condFn()
            return true

        if (A_TickCount - startedAt >= timeoutMs)
            return false

        Sleep intervalMs
    }
}

MV_FormatDuration(ms) {
    if (ms < 1000)
        return ms "ms"

    totalSecs := Round(ms / 1000, 1)
    if (totalSecs < 60)
        return totalSecs "s"

    mins := Floor(totalSecs / 60)
    secs := Round(Mod(totalSecs, 60), 1)
    return mins "min " secs "s"
}

MV_Abort(msg) {
    global gRunning
    SendToUI(Map("type", "error", "message", msg))
    gRunning := false
    return false
}

MV_ActiveModalTitle() {
    return WinExist(MV_FORMS_MODAL)
        ? MV_FORMS_MODAL
        : ""
}

MV_EnsureWindowActive(winTitle, timeoutSecs := 3) {
    if !WinExist(winTitle)
        return false
    WinActivate winTitle
    return MV_Poll(() => WinActive(winTitle), timeoutSecs)
}

MV_WaitModalGone(timeoutMs := 30000) {
    startedAt := A_TickCount
    Loop {
        if (MV_ActiveModalTitle() = "")
            return true
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

MV_WaitWindowGone(winTitle, timeoutMs := 30000) {
    startedAt := A_TickCount
    Loop {
        if !WinExist(winTitle) {
            Sleep MV_KEY_SETTLE_MS
            return true
        }
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep MV_POLL_MS
    }
}

; Fecha a tela corrente do MV com Ctrl+Q, ao fim de um fluxo.
; NÃO fecha se houver popup do MV aberto: a mensagem daquele popup é a informação que o
; operador precisa ler, e mandá-la embora destrói a única evidência do erro. Quem chama
; deve avisar o operador, não tentar contornar.
; NUNCA usar WinClose no Oracle Forms — perde o estado da aplicação.
MV_FecharUltimaTela(winTitle, rotulo) {
    if (MV_ActiveModalTitle() != "") {
        MV_LogSaidaTela(rotulo, "há um popup do MV aberto. Não foi fechada automaticamente —"
            " leia a mensagem na tela antes de rodar de novo.")
        return false
    }

    if !WinExist(winTitle) {
        MV_LogSaidaTela(rotulo, "a janela já não existe, nada a fechar.")
        return true
    }

    if !MV_EnsureWindowActive(winTitle, MV_TIMEOUT_ACOE) {
        MV_LogSaidaTela(rotulo, "a janela existe mas não ficou ativa para receber o atalho.")
        return false
    }

    ; Assinatura ANTES do atalho. O MV reaproveita o mesmo HWND ao trocar de
    ; tela, então a única prova de que a saída funcionou é a assinatura ter
    ; mudado — ou a janela ter sumido. Sem isto, uma tecla engolida produz uma
    ; tela "perfeitamente estável" e era reportada como sucesso.
    assinaturaAntes := MV_ScreenSignature(winTitle)
    MV_LogSaidaTela(rotulo, "assinatura antes: " assinaturaAntes)

    Send MV_SAIR_TELA_ATALHO

    if !MV_WaitTelaSaiu(winTitle, assinaturaAntes, MV_FINAL_STABLE_MS, MV_FINAL_ACTION_TIMEOUT_MS) {
        MV_LogSaidaTela(rotulo, MV_SAIR_TELA_ATALHO " enviado, mas a tela NÃO mudou"
            " (assinatura depois: " MV_ScreenSignature(winTitle) "). O atalho não teve efeito.")
        return false
    }

    MV_LogSaidaTela(rotulo, MV_SAIR_TELA_ATALHO " enviado e a tela mudou de verdade.")
    return true
}

; Identifica a tela ativa. O título entra porque é ele que muda quando o MV
; troca de tela no mesmo HWND; a contagem de controles, sozinha, não distingue
; "a tela mudou" de "nada aconteceu". Espelha o ActiveScreenSignature do fluxo
; validado. docs/analise-causa-raiz/04-remessa-protocolo-ctrl-q-nao-sai.md
MV_ScreenSignature(winTitle) {
    hwnd := WinExist(winTitle)
    if !hwnd
        return "(janela ausente)"

    try titulo := WinGetTitle("ahk_id " hwnd)
    catch
        titulo := ""
    try classe := WinGetClass("ahk_id " hwnd)
    catch
        classe := ""
    try hwnds := WinGetControlsHwnd("ahk_id " hwnd)
    catch
        hwnds := []

    return hwnd "|" classe "|" titulo "|" hwnds.Length
}

; Espera a tela realmente sair. Sucesso = a janela sumiu OU a assinatura mudou.
; Estabilidade com a assinatura intacta NÃO é sucesso: é justamente o estado em
; que a tecla foi engolida, e é por isso que ela não basta.
MV_WaitTelaSaiu(winTitle, assinaturaAntes, stableMs := 800, timeoutMs := 30000) {
    startedAt := A_TickCount

    Loop {
        if !WinExist(winTitle)
            return true

        if (MV_ScreenSignature(winTitle) != assinaturaAntes)
            return true

        if (A_TickCount - startedAt >= timeoutMs)
            return false

        Sleep MV_POLL_MS
    }
}

MV_LogSaidaTela(rotulo, detalhe) {
    try SendToUI(Map("type", "log", "message", "Saída de " rotulo ": " detalhe))
}

; O controle existe na janela? Equivalente ao AreControlsReady do fluxo
; validado (Fechar&XML.ahk:537-546), usado para não clicar num botão que não
; está presente na tela atual. Não clica: só responde se pode clicar.
MV_ControleExistePorClasse(winTitle, classNN) {
    if !WinExist(winTitle)
        return false
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN)
            return true
    }
    return false
}

MV_WaitOracleSettled(winTitle, stableMs := 800, timeoutMs := 30000) {
    startedAt := A_TickCount
    stableSince := 0
    lastCount := -1

    Loop {
        modalClear := (MV_ActiveModalTitle() = "")
        cursorReady := (A_Cursor != "Wait" && A_Cursor != "AppStarting")
        exists := WinExist(winTitle)
        count := -1

        if exists {
            try hwnds := WinGetControlsHwnd(winTitle)
            catch
                hwnds := []
            count := hwnds.Length
        }

        if (exists && modalClear && cursorReady && count = lastCount) {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= stableMs)
                return true
        } else {
            stableSince := 0
            lastCount := count
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return false

        Sleep MV_POLL_MS
    }
}

MV_ControlAtReady(winTitle, classNN, clientX, clientY, tolerance := 14) {
    hwnd := MV_FindControlByClientPoint(winTitle, classNN, clientX, clientY, tolerance)
    if !hwnd
        return false
    try return ControlGetEnabled(hwnd)
    catch
        return true
}

MV_SetTextByClickAt(winTitle, x, y, value) {
    if !MV_EnsureWindowActive(winTitle)
        return false

    CoordMode("Mouse", "Client")
    Click(x + 15, y + 8, 1)
    Sleep MV_FIELD_FOCUS_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}{Backspace}")
    Sleep MV_FIELD_CLEAR_SETTLE_MS
    SendText value
    Sleep MV_KEY_SETTLE_MS
    return true
}

MV_SetTextByClickNoClear(winTitle, x, y, value) {
    if !MV_EnsureWindowActive(winTitle)
        return false

    CoordMode("Mouse", "Client")
    Click(x + 15, y + 8, 1)
    Sleep MV_FIELD_FOCUS_SETTLE_MS
    SendText value
    Sleep MV_KEY_SETTLE_MS
    return true
}

MV_ClickModalButtonByText(winTitle, buttonText) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (SubStr(ctrlClass, 1, 6) != "Button")
            continue
        try text := ControlGetText(hwnd)
        catch
            continue
        if (text = buttonText) {
            ControlClick hwnd,,,,, "NA"
            return true
        }
    }
    return false
}

MV_ModalHasButton(winTitle, buttonText) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return false

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (SubStr(ctrlClass, 1, 6) != "Button")
            continue
        try text := ControlGetText(hwnd)
        catch
            continue
        if (text = buttonText)
            return true
    }
    return false
}

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

; ════════════════════════════════════════════════════════════════
;  DATA
; ════════════════════════════════════════════════════════════════

; Converte a data que chega da UI para o formato que o FFCV aceita.
; Aceita yyyy-mm-dd (o que <input type="date"> entrega) e repassa inalterado
; qualquer outro valor — inclusive dd/mm/aaaa, que pode vir de config.ini ou
; de outro chamador. Não valida: um valor irreconhecível precisa chegar ao FFCV
; para o operador ver a recusa dele, não para o macro adivinhar o que era.
MV_NormalizarDataBr(valor) {
    valor := Trim(valor)
    if !RegExMatch(valor, MV_DATA_REGEX_ISO, &m)
        return valor
    return FormatTime(RegExReplace(m[0], "\D") "000000", MV_DATA_FORMATO_FFCV)
}

; Lê de volta o texto de um campo de data já preenchido na tela do MV e compara
; com o valor que foi enviado. É o que impede um formato divergente de passar
; em silêncio: o operador vê a divergência no log, no momento do preenchimento.
; Não recebe classNN porque MV_ReadEditAtPoint já resolve por prefixo "Edit".
MV_CompararDataTela(winTitle, clientX, clientY, valorEnviado, tolerance := 14) {
    naTela := MV_ReadEditAtPoint(winTitle, clientX, clientY, "", tolerance)
    if (naTela = "")
        return "nao lida"
    if (MV_NormalizarDataBr(naTela) = MV_NormalizarDataBr(valorEnviado))
        return "ok"
    return "divergente: tela=" naTela " enviado=" valorEnviado
}
