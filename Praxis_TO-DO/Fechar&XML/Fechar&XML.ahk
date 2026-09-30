#Requires AutoHotkey v2.0
#WinActivateForce
SetTitleMatchMode(2)
SetControlDelay(-1)

global gGui := 0
global gRemessas := 0
global gPagamento := 0
global gVencimento := 0
global gFechar := 0
global gGerarXml := 0
global gStatus := 0
global gExecutando := false
global gCancelRequested := false

; --- IDENTIFICADORES DE JANELAS (Window Spy) ---
global gJanelaPrincipal := "MV2000i - Faturamento ahk_exe ifrun60.EXE"
global gJanelaRelatorio := "Relatório de Atendimentos da Remessa ahk_exe ifrun60.EXE"
global gJanelaProgresso := "Andamento do Relatório ahk_exe RWRBE60.EXE"
global gJanelaEntrega := "Cadastro: Faturas e Remessas ahk_exe ifrun60.EXE"
global gJanelaSucesso := "Sistema de Faturamento de Contas de Convênio ahk_exe ifrun60.EXE"
global gBotaoSucesso := "Button1"
global gJanelaFundo := "Operação de Fundo dos Relatórios ahk_exe RWRBE60.EXE"
global gJanelaTiss := "Monitoração de Faturamento - TISS ahk_exe ifrun60.EXE"
global gJanelaMsgUser := "Mensagem ao Usuário do MV 2000 ahk_exe ifrun60.EXE"
global gJanelaMenuBase := "MV2000i - Faturamento ahk_exe ifrun60.EXE"
global gTextoMenuBase := "Menu Principal - HOSPITAL SAO RAFAEL"
global gProcessoMv := "ifrun60.EXE"
global gProcessoRelatorio := "RWRBE60.EXE"

BuildGui()

BuildGui() {
    global gGui, gRemessas, gPagamento, gVencimento, gFechar, gGerarXml, gStatus

    gGui := Gui("+AlwaysOnTop", "Entrega de remessas")
    gGui.SetFont("s10", "Segoe UI")
    gGui.AddText("xm", "Números de remessa (separados por vírgula):")
    gRemessas := gGui.AddEdit("xm w420 r2")
    gRemessas.ToolTip := "Exemplo: 516837,516838,516839"

    gGui.AddText("xm y+12", "Data de pagamento:")
    gPagamento := gGui.AddEdit("x+8 w120")
    gPagamento.ToolTip := "Formato: dd/mm/aaaa"
    gGui.AddText("x+18", "Data de vencimento:")
    gVencimento := gGui.AddEdit("x+8 w120")
    gVencimento.ToolTip := "Formato: dd/mm/aaaa"

    gFechar := gGui.AddCheckBox("xm y+14", "Fechar remessa")
    gFechar.Value := 1
    gGerarXml := gGui.AddCheckBox("x+20", "Gerar XML")
    gGerarXml.Value := 1
    gFechar.OnEvent("Click", ToggleDates)

    gGui.AddButton("xm y+16 w140 Default", "Executar").OnEvent("Click", StartAutomation)
    gGui.AddButton("x+10 w140", "Sair").OnEvent("Click", (*) => ExitApp())
    gStatus := gGui.AddText("xm y+14 w420 r3", "Pronto.")
    gGui.OnEvent("Close", (*) => ExitApp())
    gGui.Show()
}

ToggleDates(*) {
    global gFechar, gPagamento, gVencimento
    enabled := gFechar.Value = 1
    gPagamento.Enabled := enabled
    gVencimento.Enabled := enabled
}

StartAutomation(*) {
    global gGui, gRemessas, gPagamento, gVencimento, gFechar, gGerarXml, gStatus, gExecutando, gCancelRequested

    if gExecutando
        return

    remessas := ParseRemessas(gRemessas.Value)
    if remessas.Length = 0 {
        SetStatus("Informe ao menos uma remessa.")
        return
    }
    if !gFechar.Value && !gGerarXml.Value {
        SetStatus("Marque Fechar remessa ou Gerar XML.")
        return
    }
    if gFechar.Value && (Trim(gPagamento.Value) = "" || Trim(gVencimento.Value) = "") {
        SetStatus("As duas datas são obrigatórias ao fechar a remessa.")
        return
    }

    gExecutando := true
    gCancelRequested := false
    SetStatus("Executando...")
    gGui.Hide()
    try {
        RunAutomation(remessas, Trim(gPagamento.Value), Trim(gVencimento.Value),
            gFechar.Value = 1, gGerarXml.Value = 1)
        SetStatus("Processo concluído.")
    } catch Error as err {
        if gCancelRequested
            SetStatus("Execução interrompida pelo usuário.")
        else {
            SetStatus("Erro: " err.Message)
            MsgBox(err.Message, "Automação do MV", 16)
        }
    } finally {
        gGui.Show()
        ToolTip()
    }
    gExecutando := false
}

ParseRemessas(value) {
    result := []
    for _, item in StrSplit(value, ",") {
        item := RegExReplace(item, "\s")
        if item != ""
            result.Push(item)
    }
    return result
}

RunAutomation(remessas, pagamento, vencimento, fechar, gerarXml) {
    if fechar
        ProcessDelivery(remessas, pagamento, vencimento)
    if gerarXml
        ProcessXml(remessas)
}

ProcessDelivery(remessas, pagamento, vencimento) {
    global gJanelaEntrega, gJanelaPrincipal
    mv := FindMvWindow()
    if !mv
        throw Error("O MV não está aberto.")

    WinActivate(gJanelaPrincipal)
    WaitActive(mv, 5)
    ; O botão de relatório só existe em algumas telas do MV. A navegação
    ; para entrega não pode depender dele.
    if AreControlsReady(mv, ["Button9"])
        PrintDeliveryReport(mv, "Impressão inicial em andamento...")
    Send("{Alt down}l{e}{Alt up}")
    entrega := WaitWindowReady(
        gJanelaEntrega,
        ["Edit1", "Button10"],
        20
    )
    WaitControlEnabled(entrega, "Button10", 10)

    total := remessas.Length
    for index, remessa in remessas {
        EnsureNotCancelled()
        WinActivate("ahk_id " entrega)
        WaitActive(entrega, 5)

        PasteFocused(remessa, true)
        Send("{Tab}")
        PasteFocused(pagamento, true)
        Send("{Tab}")
        PasteFocused(vencimento, true)
        WaitDelay(250)

        if !ControlGetChecked("Button3", "ahk_id " entrega)
            ControlClick("Button3", "ahk_id " entrega)
        WaitDelay(150)
        ControlClick("Button10", "ahk_id " entrega)
        HandleDeliveryMessage()
        WaitAndPrintDeliveryReport("Impressão da remessa " remessa " em andamento...")

        if index < total {
            CloseDeliveryIfOpen(entrega)
            mv := FindMvWindow()
            if !mv
                throw Error("O MV não foi encontrado ao reabrir a entrega.")
            WinActivate("ahk_id " mv)
            WaitActive(mv, 5)
            Send("{Alt down}l{e}{Alt up}")
            entrega := WaitWindowReady(
                gJanelaEntrega,
                ["Edit1", "Button10"],
                20
            )
            WaitControlEnabled(entrega, "Button10", 10)
        }
    }

    CloseDeliveryIfOpen(entrega)
}

CloseDeliveryIfOpen(hwnd) {
    global gJanelaEntrega
    if !WinExist("ahk_id " hwnd)
        return

    titulo := WinGetTitle("ahk_id " hwnd)
    if !InStr(titulo, "Cadastro: Faturas e Remessas")
        return

    WinActivate("ahk_id " hwnd)
    WaitActive(hwnd, 5)
    Send("^q")

    inicio := A_TickCount
    while (A_TickCount - inicio < 5000) {
        EnsureNotCancelled()
        if !WinExist("ahk_id " hwnd)
            return

        ; O MV pode reaproveitar o mesmo HWND ao voltar para a tela inicial.
        ; Nesse caso, a entrega já terminou mesmo que o HWND ainda exista.
        if FindMvWindow() = hwnd
            return
        atual := WinGetTitle("ahk_id " hwnd)
        if !InStr(atual, "Cadastro: Faturas e Remessas")
            return
        WaitDelay(100)
    }

    throw Error("A tela de entrega permaneceu aberta após o comando de saída.")
}

PrintDeliveryReport(mv, message) {
    global gJanelaRelatorio, gJanelaProgresso, gProcessoRelatorio
    WaitControlsReady(mv, ["Button9"], 10)
    ControlClick("Button9", "ahk_id " mv)
    relatorio := WaitWindowReady(gJanelaRelatorio, ["Button2"], 20)
    ControlClick("Button2", "ahk_id " relatorio)
    WaitImpressaoConcluir(gJanelaProgresso, gProcessoRelatorio, message)
}

WaitAndPrintDeliveryReport(message) {
    global gJanelaRelatorio, gJanelaProgresso, gProcessoRelatorio
    relatorio := WaitWindowReady(gJanelaRelatorio, ["Button2"], 20)
    ControlClick("Button2", "ahk_id " relatorio)
    WaitImpressaoConcluir(gJanelaProgresso, gProcessoRelatorio, message)
}

WaitImpressaoConcluir(janelaProgresso, processoRelatorio, mensagemTooltip, timeoutProcessoSeg := 20) {
    inicio := A_TickCount
    ToolTip(mensagemTooltip)
    while (A_TickCount - inicio < timeoutProcessoSeg * 1000) {
        EnsureNotCancelled()
        if WinExist(janelaProgresso)
            break
        WaitDelay(100)
    }

    if !WinExist(janelaProgresso) {
        ToolTip()
        throw Error("A janela de andamento da impressão não apareceu.")
    }

    while WinExist(janelaProgresso) {
        EnsureNotCancelled()
        WaitDelay(250)
    }

    ProcessWaitClose(processoRelatorio, timeoutProcessoSeg)
    ToolTip()
}

HandleDeliveryMessage() {
    global gJanelaSucesso, gBotaoSucesso, gProcessoMv
    inicio := A_TickCount
    while (A_TickCount - inicio < 15000) {
        hwnd := FindDeliveryMessageWindow()
        if hwnd {
            WinActivate("ahk_id " hwnd)
            WaitActive(hwnd, 3)
            texto := WinGetText("ahk_id " hwnd)
            if InStr(texto, "Erro") || InStr(texto, "Log de Erro")
                throw Error("O MV retornou erro ao fechar a remessa: " texto)

            ControlGetHwnd(gBotaoSucesso, "ahk_id " hwnd)
            ControlClick(gBotaoSucesso, "ahk_id " hwnd)
            return
        }
        WaitDelay(100)
    }
    throw Error("A mensagem de confirmação do fechamento não apareceu.")
}

FindDeliveryMessageWindow() {
    global gJanelaSucesso, gBotaoSucesso, gProcessoMv
    hwnd := WinExist(gJanelaSucesso)
    if hwnd {
        try {
            ControlGetHwnd(gBotaoSucesso, "ahk_id " hwnd)
            return hwnd
        }
    }

    ; Algumas execuções do MV alteram o título do popup. Nesse caso,
    ; identifica a janela pelo processo, Button1 e texto de mensagem.
    for _, candidate in WinGetList("ahk_exe " gProcessoMv) {
        try {
            ControlGetHwnd(gBotaoSucesso, "ahk_id " candidate)
            titulo := WinGetTitle("ahk_id " candidate)
            texto := WinGetText("ahk_id " candidate)
            if (InStr(titulo, "Sistema") || InStr(titulo, "Mensagem")) && texto != ""
                return candidate
        }
    }
    return 0
}

ProcessXml(remessas) {
    global gJanelaTiss
    mv := FindMvWindow()
    if !mv
        throw Error("A janela principal do MV não foi encontrada para o XML.")

    WinActivate("ahk_id " mv)
    WaitActive(mv, 5)
    ; Abre Monitoração de Faturamento - TISS.
    Send("{Alt down}lmm{Enter}{Alt up}")
    tiss := WaitWindowReady(
        gJanelaTiss,
        ["Button7"],
        20
    )
    WaitControlEnabled(tiss, "Button7", 10)

    total := remessas.Length
    for index, remessa in remessas {
        EnsureNotCancelled()
        WinActivate("ahk_id " tiss)
        WaitControlsReady(tiss, ["Button7"], 10)
        WaitControlEnabled(tiss, "Button7", 10)
        Send("{Tab 5}")
        PasteFocused(remessa, true)
        Send("{F8}")
        WaitXmlProcessingComplete(tiss)
        ControlClick("Button7", "ahk_id " tiss)

        if !WaitTelaXmlGerado(mv, 30000)
            throw Error("A tela de XML gerado não foi detectada para a remessa " remessa ".")

        SaveGeneratedXml(mv, remessa)
        WinActivate("ahk_id " tiss)
        WaitActive(tiss, 5)
        Send("{F7}")
        WaitActive(tiss, 5)
        WaitControlsReady(tiss, ["Button7"], 10)
        WaitControlEnabled(tiss, "Button7", 10)
    }
}

WaitXmlProcessingComplete(tiss, timeoutMs := 30000) {
    global gProcessoMv
    inicio := A_TickCount
    prontoDesde := 0
    ToolTip("Aguardando o monitoramento de XML destravar...")

    while (A_TickCount - inicio < timeoutMs) {
        if !WinExist("ahk_id " tiss) {
            ToolTip()
            throw Error("A tela de monitoramento de XML foi fechada durante o processamento.")
        }

        processando := false
        for _, hwnd in WinGetList("ahk_exe " gProcessoMv) {
            if hwnd = tiss
                continue
            titulo := WinGetTitle("ahk_id " hwnd)
            if InStr(titulo, "Andamento") || InStr(titulo, "Aguarde")
                processando := true
        }

        habilitado := false
        try habilitado := ControlGetEnabled("Button7", "ahk_id " tiss)

        if !processando && habilitado {
            if !prontoDesde
                prontoDesde := A_TickCount
            ; Exige estabilidade por dois ciclos, evitando clicar no instante
            ; em que o popup de processamento apenas começou a desaparecer.
            if (A_TickCount - prontoDesde >= 300) {
                ToolTip()
                return
            }
        } else {
            prontoDesde := 0
        }
        WaitDelay(100)
    }

    ToolTip()
    throw Error("O monitoramento de XML não destravou dentro do tempo esperado.")
}

SaveGeneratedXml(mv, remessa) {
    global gJanelaMsgUser
    caminho := "C:\Users\" A_UserName "\Documents\xml\" remessa ".xml"
    DirCreate("C:\Users\" A_UserName "\Documents\xml")
    WinActivate("ahk_id " mv)
    WaitActive(mv, 5)
    SendInput("{Tab}")
    PasteFocused(caminho)
    SendInput("{Tab}")
    SendInput("{Enter}")

    mensagem := gJanelaMsgUser
    inicio := A_TickCount
    popupEncontrado := false
    ultimoPopup := 0
    while (A_TickCount - inicio < 10000) {
        hwndMensagem := WinExist(mensagem)
        if hwndMensagem {
            popupEncontrado := true
            ultimoPopup := A_TickCount
            WinActivate("ahk_id " hwndMensagem)
            WaitActive(hwndMensagem, 5)
            SendInput("{Enter}")
            WaitClosed(hwndMensagem, 5)
            WaitDelay(350)
        }
        WaitDelay(100)
        if popupEncontrado && !WinExist(mensagem) && (A_TickCount - ultimoPopup >= 1500)
            break
    }

    if !popupEncontrado
        throw Error("O MV não exibiu confirmação ao salvar o XML da remessa " remessa ".")

    WinActivate("ahk_id " mv)
    WaitActive(mv, 5)
    SendInput("{Tab}")
    SendInput("{Enter}")
}

PasteFocused(text, selectAll := false) {
    expected := String(text)
    A_Clipboard := ""
    A_Clipboard := expected
    if !ClipWait(2, 0)
        throw Error("Não foi possível preparar a colagem.")
    if A_Clipboard != expected
        throw Error("O clipboard não contém exatamente o valor esperado: " expected)

    if selectAll
        SendInput("^a")
    EnsureNotCancelled()
    SendInput("^v")

    ; Confirma que o MV recebeu tempo suficiente para ler o clipboard.
    WaitDelay(700)
}

EnsureNotCancelled() {
    global gCancelRequested
    if gCancelRequested
        throw Error("Execução interrompida pelo usuário.")
}

WaitDelay(milliseconds) {
    elapsed := 0
    while elapsed < milliseconds {
        EnsureNotCancelled()
        slice := Min(50, milliseconds - elapsed)
        Sleep(slice)
        elapsed += slice
    }
    EnsureNotCancelled()
}

WaitActive(hwnd, timeoutSec := 5) {
    EnsureNotCancelled()
    inicio := A_TickCount
    while (A_TickCount - inicio < timeoutSec * 1000) {
        EnsureNotCancelled()
        if WinExist("ahk_id " hwnd) && WinActive("ahk_id " hwnd)
            return true
        WaitDelay(50)
    }
    throw Error("A janela não ficou ativa dentro do tempo esperado.")
}

WaitClosed(hwnd, timeoutSec := 5) {
    inicio := A_TickCount
    while (A_TickCount - inicio < timeoutSec * 1000) {
        EnsureNotCancelled()
        if !WinExist("ahk_id " hwnd)
            return true
        WaitDelay(50)
    }
    throw Error("A janela não fechou dentro do tempo esperado.")
}

FindMvWindow() {
    global gJanelaPrincipal, gProcessoMv
    principal := WinExist(gJanelaPrincipal)
    if principal
        return principal

    for _, hwnd in WinGetList("MV2000i - Faturamento") {
        if InStr(WinGetTitle("ahk_id " hwnd), "MV2000i - Faturamento")
            return hwnd
    }

    for _, hwnd in WinGetList("ahk_exe " gProcessoMv) {
        title := WinGetTitle("ahk_id " hwnd)
        if InStr(title, "MV2000i - Faturamento")
            return hwnd
    }
    return 0
}

WaitWindowReady(criteria, controls, timeoutSec := 15) {
    inicio := A_TickCount
    while (A_TickCount - inicio < timeoutSec * 1000) {
        EnsureNotCancelled()
        hwnd := WinExist(criteria)
        if hwnd {
            WinActivate("ahk_id " hwnd)
            WaitActive(hwnd, 5)
            if AreControlsReady(hwnd, controls)
                return hwnd
        }
        WaitDelay(100)
    }
    throw Error("A janela ou os controles não ficaram prontos: " criteria)
}

WaitControlsReady(hwnd, controls, timeoutSec := 10) {
    inicio := A_TickCount
    while (A_TickCount - inicio < timeoutSec * 1000) {
        EnsureNotCancelled()
        if !WinExist("ahk_id " hwnd)
            throw Error("A janela esperada foi fechada antes de carregar os controles.")

        if AreControlsReady(hwnd, controls)
            return true
        WaitDelay(100)
    }
    throw Error("Os controles da janela não ficaram prontos dentro do tempo esperado.")
}

AreControlsReady(hwnd, controls) {
    for _, control in controls {
        try {
            ControlGetHwnd(control, "ahk_id " hwnd)
        } catch {
            return false
        }
    }
    return true
}

WaitControlEnabled(hwnd, control, timeoutSec := 10) {
    inicio := A_TickCount
    while (A_TickCount - inicio < timeoutSec * 1000) {
        EnsureNotCancelled()
        if !WinExist("ahk_id " hwnd)
            throw Error("A janela esperada foi fechada antes de ficar pronta.")
        try {
            if ControlGetEnabled(control, "ahk_id " hwnd)
                return true
        }
        WaitDelay(100)
    }
    throw Error("O controle " control " não ficou habilitado dentro do tempo esperado.")
}

WaitTelaXmlGerado(mv, timeoutMs := 30000) {
    inicio := A_TickCount
    while (A_TickCount - inicio < timeoutMs) {
        try {
            texto := WinGetText("ahk_id " mv)
            if InStr(texto, "XML gerado") {
                ControlGetHwnd("Edit1", "ahk_id " mv)
                ControlGetHwnd("Button4", "ahk_id " mv)
                return true
            }
        }
        WaitDelay(150)
    }
    return false
}

SetStatus(text) {
    global gStatus
    if IsObject(gStatus)
        gStatus.Text := text
}

F3::StartAutomation()
^+p::StartAutomation()

$Esc:: {
    global gExecutando, gCancelRequested
    if gExecutando {
        gCancelRequested := true
        ToolTip("Execução interrompida. Pressione F3 para iniciar novamente.")
    }
}
