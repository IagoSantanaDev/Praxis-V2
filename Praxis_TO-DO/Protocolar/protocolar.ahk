#Requires AutoHotkey v2.0
#SingleInstance Force
#Include %A_LineFile%\..\lib\globals\mv\ParseUtils.ahk

; ==========================================================
; MV2000i - Protocolação / Envio de Contas
; AHK v2
; Versão: 2026-06-22.20-ocr-server-persistente
; ==========================================================
; Observações importantes:
; - Pensado para Windows Server/rede hospitalar sem privilégio de administrador.
;   O .ahk deve ficar em pasta gravável pelo usuário, pois cria planilhas e log.
; - O script usa ClassNN quando a tela fornece controles reais.
;   Em campos desenhados do Oracle Forms/MV, usa teclado e algumas coordenadas
;   client baseadas nas imagens enviadas.
; - OCR: usa Windows.Media.Ocr via PowerShell para ler mensagens desenhadas.
;   Se o OCR do Windows estiver indisponível, o script vai parar e avisar.
; ==========================================================

SetTitleMatchMode 2
SetWinDelay 100
SetControlDelay -1
SetKeyDelay 35, 35
SendMode "Input"
CoordMode "Mouse", "Screen"

class Delay {
    ; Ajuste todos os tempos aqui.
    static AfterHotkey := 100      ; pausa obrigatória depois de Send/hotkey
    static AfterClick := 100       ; pausa obrigatória depois de clique
    static Tiny := 100
    static CopyStep := 100
    static Fast := 100
    static ActivateRestore := 100
    static ActivateActive := 100
    static Poll := 100
    static FilePoll := 100
    static MenuStep := 100
    static Short := 100
    static Close := 100
    static LongClose := 100
    static Medium := 100
    static Save := 100
    static Form := 100
    static Query := 100
    static Report := 100

    ; Otimização do envio de contas.
    ; Mantém 100 ms após hotkeys/cliques, mas reduz esperas extras por conta.
    static AccountPaste := 100          ; pausa após Ctrl+V da conta
    static AccountAfterEnter := 100     ; pausa mínima após Enter da conta
    static AccountPopupTimeout := 300   ; quanto tempo esperar por popup de erro após cada conta
    static PopupTextMethodLog := false   ; true = loga se leu popup por WinGetText/OCR
    static ProgressLogEvery := 25       ; loga progresso a cada N contas para não travar a GUI

    ; Fechamento por Ctrl+Q. Mantém o padrão de 100 ms para teclas/cliques,
    ; mas aguarda a tela estabilizar antes de Enter/próximo registro.
    static CtrlQReadyTimeout := 8000    ; tempo máximo esperando a tela estabilizar após Ctrl+Q
    static CtrlQStableMs := 500         ; quanto tempo a mesma tela precisa ficar estável
    static AfterCtrlQEnter := 100       ; pausa depois do Enter de confirmação do Ctrl+Q
}

global DEFAULT_SETOR_ATUAL := "34"
global DEFAULT_SETOR_ENVIO := "356"
global PLANILHAS_DIR := A_ScriptDir "\planilhas"
global CSV_ENVIO := PLANILHAS_DIR "\Envio.CSV"
global CSV_SAVE_NAME := PLANILHAS_DIR "\Envio"
global CSV_ENVIO_ALT := PLANILHAS_DIR "\Envio.CSV.CSV"
global LOG_PATH := A_ScriptDir "\mv_protocolo_envio.log"
global DEDUPLICAR_CONTAS := true

; OCR do Windows: usa pt-BR. Usa escala rápida por padrão e escala maior só como fallback.
global OCR_LANGUAGE := "pt-BR"
global OCR_SCALE := 2
global OCR_SCALE_RETRY := 3
global SETOR_OCR_CORRECTION_WITH_CONFIG := true

; Para acelerar o envio, o script não escreve uma linha de log para cada conta aceita.
; Popups/erros continuam sendo registrados sempre.
global LOG_CADA_CONTA := false
global STATUS_MAX_CHARS := 12000
global gEnvioHwnd := 0

; OCR persistente: elimina a sobrecarga de iniciar um processo PS a cada chamada.
; O servidor PS carrega o engine uma vez e fica em loop aguardando requisições.
global gOcrServerReady    := false
global gOcrServerPid      := 0
global gOcrServerReqFile  := A_Temp "\mv2000i_ocr_srv_req.txt"
global gOcrServerSigFile  := A_Temp "\mv2000i_ocr_srv_sig.txt"
global gOcrServerRespFile := A_Temp "\mv2000i_ocr_srv_resp.txt"
global gOcrServerKillFile := A_Temp "\mv2000i_ocr_srv_kill.txt"
global gOcrServerInitFile := A_Temp "\mv2000i_ocr_srv_init.txt"
global gOcrServerPs1      := A_Temp "\mv2000i_ocr_server_v1.ps1"
global OCR_SERVER_TIMEOUT_MS := 8000
global OCR_SERVER_POLL_MS    := 25

global gGui
global gEdtRemessas
global gDdlTipo
global gEdtSetorAtual
global gEdtSetorEnvio
global gChkImprimirSalvarEnvio
global gTxtStatus
global gBtnStart

OnExit((*) => StopOcrServer())

DirCreate PLANILHAS_DIR
BuildGui()
return

; Hotkeys de emergência
F3::Pause -1
Esc::ExitApp

BuildGui() {
    global gGui, gEdtRemessas, gDdlTipo, gEdtSetorAtual, gEdtSetorEnvio, gChkImprimirSalvarEnvio, gTxtStatus, gBtnStart

    gGui := Gui("+AlwaysOnTop", "MV2000i - Protocolo / Envio de Contas")
    gGui.SetFont("s9", "Segoe UI")

    gGui.AddText("xm ym", "Remessas")
    gEdtRemessas := gGui.AddEdit("xm y+4 w520 r3", "")

    gGui.AddText("xm y+10", "Tipo")
    gDdlTipo := gGui.AddDropDownList("xm y+4 w180 Choose1", ["Ambulatorial", "Hospitalar"])

    gGui.AddText("x+20 yp-24", "Setor Atual")
    gEdtSetorAtual := gGui.AddEdit("x+20 y+4 w90", DEFAULT_SETOR_ATUAL)

    gGui.AddText("x+20 yp-24", "Setor Envio")
    gEdtSetorEnvio := gGui.AddEdit("x+20 y+4 w90", DEFAULT_SETOR_ENVIO)

    gChkImprimirSalvarEnvio := gGui.AddCheckBox("xm y+16 Checked", "Imprimir/salvar envio")

    gBtnStart := gGui.AddButton("xm y+12 w130 Default", "Iniciar")
    gBtnStart.OnEvent("Click", StartAutomation)

    gGui.AddText("xm y+14", "Status")
    gTxtStatus := gGui.AddEdit("xm y+4 w600 r12 ReadOnly -Wrap", "")

    gGui.AddText("xm y+8 cRed", "F3 pausa/continua. Esc encerra.")
    gGui.Show()
}

StartAutomation(*) {
    global gEdtRemessas, gDdlTipo, gEdtSetorAtual, gEdtSetorEnvio, gChkImprimirSalvarEnvio, gBtnStart

    remessas := Trim(gEdtRemessas.Value)
    tipo := Trim(gDdlTipo.Text)
    setorAtual := Trim(gEdtSetorAtual.Value)
    setorEnvio := Trim(gEdtSetorEnvio.Value)
    imprimirSalvarEnvio := !!gChkImprimirSalvarEnvio.Value

    if (remessas = "") {
        MsgBox "Informe as remessas.", "Validação", "Icon!"
        return
    }

    if (setorAtual = "")
        setorAtual := DEFAULT_SETOR_ATUAL
    if (setorEnvio = "")
        setorEnvio := DEFAULT_SETOR_ENVIO

    cfg := {
        Remessas: remessas,
        Tipo: tipo,
        SetorAtual: setorAtual,
        SetorEnvio: setorEnvio,
        ImprimirSalvarEnvio: imprimirSalvarEnvio
    }

    gBtnStart.Enabled := false
    try {
        LogLine("========== INÍCIO ==========")
        LogLine("Remessas: " cfg.Remessas)
        LogLine("Tipo: " cfg.Tipo " | Setor Atual: " cfg.SetorAtual " | Setor Envio: " cfg.SetorEnvio)
        LogLine("Imprimir/salvar envio: " (cfg.ImprimirSalvarEnvio ? "Sim" : "Não"))


        LogLine("OCR: iniciando servidor persistente...")
        EnsureOcrServer()

        csvGerado := RunFFCV(cfg)

        contas := ExtractContasFromCsv(csvGerado)
        if (contas.Length = 0)
            throw Error("Nenhuma conta encontrada abaixo da coluna CD_REG_AMB no arquivo: " csvGerado)

        LogLine("Contas extraídas: " contas.Length)
        finalizouEnvio := RunMovDoc(cfg, contas)

        LogLine("========== FIM ==========")
        if (finalizouEnvio) {
            MsgBox "Processo finalizado.`nContas processadas: " contas.Length, "MV2000i", "Iconi"
        } else {
            MsgBox "Última conta enviada e registro em branco excluído.`nImprimir/salvar envio estava desativado, então o script parou antes do Alt+1.`nContas processadas: " contas.Length, "MV2000i", "Iconi"
        }
    } catch as e {
        LogLine("ERRO: " e.Message)
        MsgBox "O script parou com erro:`n`n" e.Message "`n`nVeja o log em:`n" LOG_PATH, "Erro", "Iconx"
    } finally {
        gBtnStart.Enabled := true
    }
}

; ==========================================================
; FFCV
; ==========================================================

RunFFCV(cfg) {
    global CSV_ENVIO, CSV_SAVE_NAME, CSV_ENVIO_ALT

    LogLine("Abrindo/ativando FFCV...")
    LogLine("FFCV: arquivo esperado=" CSV_ENVIO " | nome enviado ao Salvar como=" CSV_SAVE_NAME)
    for oldCsv in [CSV_ENVIO, CSV_ENVIO_ALT, CSV_SAVE_NAME] {
        if FileExist(oldCsv) {
            try FileDelete oldCsv
        }
    }

    ffcv := WaitWindow(["Faturamento"], "ifrun60.EXE", "", 10)
    ActivateWindow(ffcv)

    LogLine("FFCV: Alt+E, Enter 2x")
    SendKeys("!e")
    Sleep Delay.Short
    SendKeys("{Enter 2}")

    rel := WaitWindow(["Relatórios Personalizado"], "ifrun60.EXE", "ui60Modal_W32", 30)
    ActivateWindow(rel)

    LogLine("FFCV: selecionando relatório com Down 121x")
    Sleep Delay.Short
    SendKeys("{Down 121}")
    Sleep Delay.FilePoll
    SendKeys("!1")

    ; O popup de Remessa do FFCV pode ficar com título/classe inconsistentes no Windows Server.
    ; Por isso ele é localizado pelos controles reais do popup, não só por ahk_class/ahk_exe.
    remWin := WaitFfcvRemessaWindow(60)
    ActivateWindow(remWin)

    LogLine("FFCV: informando remessas")
    SetFfcvRemessaText(remWin, cfg.Remessas)
    Sleep Delay.Poll

    LogLine("FFCV: Gerar Arquivo")
    ClickControlOrClientFallback("TBitBtn2", remWin, 548, 91)
    Sleep Delay.Short

    saveWin := WaitSaveAsWindow(45)
    ActivateWindow(saveWin)

    LogLine("FFCV: salvando CSV. Campo receberá: " CSV_SAVE_NAME)
    SetSaveAsFileName(saveWin, CSV_SAVE_NAME)
    Sleep Delay.Poll
    ClickSaveAsButton(saveWin)
    Sleep Delay.Save
    info := WaitWindow(["Information"], "EXECUTASQL.exe", "TMessageForm", 60)
    ActivateWindow(info)
    LogLine("FFCV: arquivo gerado com sucesso")
    ClickControlOrSendEnter("TButton1", info)
    Sleep Delay.LongClose

    ; Fecha popup "Relatórios Personalizado", botão Sair.
    if WinExist("ahk_id " rel) {
        ActivateWindow(rel)
        ClickControlOrSendEnter("Button1", rel)
        Sleep Delay.Close
    }

    csvGerado := WaitForAnyFile([CSV_ENVIO, CSV_ENVIO_ALT], 30)
    LogLine("FFCV: CSV localizado para leitura: " csvGerado)
    return csvGerado
}



; ==========================================================
; MOVDOC
; ==========================================================

RunMovDoc(cfg, contas) {
    global LOG_CADA_CONTA

    LogLine("Abrindo/ativando MovDoc...")
    OpenEnvioScreen(cfg.SetorAtual, cfg.SetorEnvio, cfg.Tipo)

    total := contas.Length
    for index, conta in contas {
        EnsureEnvioScreen(cfg)

        if (LOG_CADA_CONTA || index = 1 || index = total || Mod(index, Delay.ProgressLogEvery) = 0)
            LogLine("Conta " index "/" total ": " conta)

        ; Todas as contas, inclusive a última, são enviadas com Enter.
        ; Depois da última, o fluxo decide se continua para Alt+1 ou se apenas exclui o registro em branco.
        ProcessConta(cfg, conta)
    }

    if (cfg.ImprimirSalvarEnvio) {
        FinalizarProtocoloMovDoc()
        return true
    }

    FinalizarSemImprimirSalvarEnvio()
    return false
}

OpenEnvioScreen(setorAtual, setorEnvio, tipo) {
    global gEnvioHwnd

    mov := WaitWindow(["Movimentação de Documentos"], "ifrun60.EXE", "", 15)
    ActivateWindow(mov)

    LogLine("MovDoc: Alt+M, P, E")
    SendMenuPath("mpe")

    envWin := WaitWindow(["Protocolação de Envio de Documentos"], "ifrun60.EXE", "", 30)
    ActivateWindow(envWin)
    gEnvioHwnd := envWin

    SetupEnvioScreen(setorAtual, setorEnvio, tipo)
    return envWin
}

SetupEnvioScreen(setorAtual, setorEnvio, tipo) {
    global gEnvioHwnd

    envWin := WaitWindow(["Protocolação de Envio de Documentos"], "ifrun60.EXE", "", 10)
    ActivateWindow(envWin)
    gEnvioHwnd := envWin

    LogLine("Envio: Setor Atual=" setorAtual " | Setor Envio=" setorEnvio)
    SendTextSafe(setorAtual)
    SendKeys("{Enter}")
    Sleep Delay.Poll
    SendTextSafe(setorEnvio)
    Sleep Delay.Poll

    ; Button2 conforme Window Spy da tela de envio.
    ClickControlOrThrow("Button2", envWin)
    Sleep Delay.FilePoll

    SendKeys("{Tab 2}")
    Sleep Delay.Poll

    if (StrLower(tipo) = "hospitalar") {
        LogLine("Envio: aplicando ajuste Hospitalar")
        SendKeys("+{Tab 2}")
        Sleep Delay.AfterHotkey
        SendKeys("{Up 2}")
        Sleep Delay.AfterHotkey
        SendKeys("+{Tab 2}")
        Sleep Delay.AfterHotkey
    }
}

EnsureEnvioScreen(cfg) {
    global gEnvioHwnd

    ; Caminho rápido: evita WinActivate + sleeps a cada conta aceita.
    if (gEnvioHwnd && WinExist("ahk_id " gEnvioHwnd)) {
        try title := WinGetTitle("ahk_id " gEnvioHwnd)
        catch
            title := ""

        if InStr(title, "Protocolação de Envio de Documentos") {
            if !WinActive("ahk_id " gEnvioHwnd)
                ActivateWindow(gEnvioHwnd)
            return gEnvioHwnd
        }
    }

    envWin := FindWindow(["Protocolação de Envio de Documentos"], "ifrun60.EXE", "")
    if (envWin) {
        gEnvioHwnd := envWin
        if !WinActive("ahk_id " envWin)
            ActivateWindow(envWin)
        return envWin
    }

    ; Se o fluxo de baixa voltou para o menu/tela principal, reabre o envio
    ; com a configuração original.
    LogLine("Tela de envio não está ativa. Reabrindo Protocolação de Envio...")
    return OpenEnvioScreen(cfg.SetorAtual, cfg.SetorEnvio, cfg.Tipo)
}

ProcessConta(cfg, conta) {
    ; Fluxo rápido para contas: evita sleeps duplicados e o timeout antigo de 1200 ms.
    ; Se algum popup de erro passar batido em uma estação lenta, aumente
    ; Delay.AccountPopupTimeout no início do arquivo.
    SendContaFast(conta)
    SendKeys("{Enter}")
    Sleep Delay.AccountAfterEnter

    popup := FindMvUserMessage(Delay.AccountPopupTimeout)
    if (!popup) {
        ; Conta aceita sem popup.
        return
    }

    HandleAccountPopup(cfg, conta, popup)
}

FinalizarSemImprimirSalvarEnvio() {
    LogLine("Imprimir/salvar envio desativado: clicando no botão Excluir do registro em branco e parando antes do Alt+1.")

    envWin := WaitWindow(["Protocolação de Envio de Documentos"], "ifrun60.EXE", "", 20)
    ActivateWindow(envWin)

    ; A última conta já foi enviada com Enter pelo ProcessConta().
    ; Remove o registro em branco criado pelo Enter, mas não chama Alt+1.
    ClickControlOrThrow("ui60Viewcore_W3211", envWin)
    Sleep Delay.Close

    LogLine("Imprimir/salvar envio desativado: Alt+1 não foi enviado.")
}

HandleAccountPopup(cfg, conta, popup) {
    ActivateWindow(popup)
    msg := NormalizeText(ReadMvMessage(popup))
    LogLine("Popup para conta " conta ": " msg)

    protocolo := ExtractPendingProtocol(msg)
    if (protocolo != "") {
        LogLine("Documento pendente reconhecido. Protocolo extraído: " protocolo)
        CloseMvPopup(popup)
        BaixarProtocolo(protocolo)
        return
    }

    setorRecebido := ExtractSetorRecebido(msg, cfg)
    if (setorRecebido != "") {
        LogLine("Setor recebido extraído: " setorRecebido)
        CloseMvPopup(popup)
        CorrigirSetorDaContaEBaixar(cfg, conta, setorRecebido)
        return
    }

    ; Mensagem não reconhecida: evita seguir fazendo operação errada.
    throw Error("Popup não reconhecido para a conta " conta ". Texto lido: " msg)
}

BaixarProtocolo(protocolo) {
    if (protocolo = "")
        throw Error("BaixarProtocolo recebeu protocolo vazio.")

    LogLine("Baixa: protocolo " protocolo)

    mov := WaitWindow(["Movimentação de Documentos"], "ifrun60.EXE", "", 15)
    ActivateWindow(mov)

    SendMenuPath("mpb")
    baixa := WaitWindow(["Protocolação de Baixa de Documentos"], "ifrun60.EXE", "", 30)
    ActivateWindow(baixa)

    SendTextSafe(protocolo)
    Sleep Delay.Poll
    SendKeys("{F8}")
    Sleep Delay.Query

    ; Button1 da tela de baixa, conforme Window Spy da imagem 14.
    ClickControlOrThrow("Button1", baixa)

    Sleep Delay.Poll
    SendKeys("{F10}")
    Sleep Delay.Form
    CloseByCtrlQEnterAndWait("baixa de protocolo")
}

CorrigirSetorDaContaEBaixar(cfg, conta, setorRecebido) {
    LogLine("Correção por setor diferente. Conta=" conta " | Setor recebido=" setorRecebido)

    ; Inverte conforme fluxo solicitado:
    ; envia setor recebido como Setor Atual e o Setor Atual configurado como Setor Envio.
    OpenEnvioScreen(setorRecebido, cfg.SetorAtual, cfg.Tipo)

    SendTextSafe(conta)
    Sleep Delay.ActivateActive
    SendKeys("!1")

    relPrint := WaitWindow(["Relatório de Registro de Envio"], "ifrun60.EXE", "ui60Modal_W32", 30)
    ActivateWindow(relPrint)

    ; Nesta etapa o fluxo pediu Button1 da imagem 16, que é Sair.
    ClickControlOrSendEnter("Button1", relPrint)
    Sleep Delay.LongClose

    envWin := WaitWindow(["Protocolação de Envio de Documentos"], "ifrun60.EXE", "", 15)
    ActivateWindow(envWin)

    ; Campo Protocolo: usar coordenada client, não ClassNN.
    ; Baseado na imagem 17, campo em torno de Client x 21..94 / y 106..124.
    ClickClient(envWin, 60, 115)
    Sleep Delay.AfterHotkey

    protocoloNovo := CopyFocusedField()
    protocoloNovo := RegExReplace(protocoloNovo, "\D")
    if (protocoloNovo = "")
        throw Error("Não foi possível copiar o protocolo novo da conta " conta ".")

    LogLine("Protocolo novo copiado: " protocoloNovo)

    CloseByCtrlQAndWait("envio temporário da correção de setor")

    BaixarProtocolo(protocoloNovo)
}

FinalizarProtocoloMovDoc() {
    LogLine("Finalizando protocolo de envio...")

    envWin := WaitWindow(["Protocolação de Envio de Documentos"], "ifrun60.EXE", "", 20)
    ActivateWindow(envWin)

    ; Fluxo correto da última conta:
    ; ela já foi enviada e confirmada com Enter pelo ProcessConta().
    ; Agora remove o registro em branco criado pelo Enter e segue para Alt+1.
    LogLine("Finalização: clicando no botão Excluir do registro em branco e indo para Alt+1.")
    ClickControlOrThrow("ui60Viewcore_W3211", envWin)
    Sleep Delay.Close

    SendKeys("!1")
    relPrint := WaitWindow(["Relatório de Registro de Envio"], "ifrun60.EXE", "ui60Modal_W32", 30)
    ActivateWindow(relPrint)

    CloseBackgroundReportsIfAny()

    ; Nesta etapa final o fluxo pediu Button2 da imagem 15, que é Imprimir.
    ClickControlOrThrow("Button2", relPrint)
    Sleep Delay.Report

    CloseBackgroundReportsIfAny()

    mov := WaitWindow(["Movimentação de Documentos"], "ifrun60.EXE", "", 15)
    ActivateWindow(mov)
    CloseByCtrlQAndWait("finalização do MovDoc")

    LogLine("Protocolo finalizado.")
}

; ==========================================================
; CSV
; ==========================================================

ExtractContasFromCsv(path) {
    global DEDUPLICAR_CONTAS

    if !FileExist(path)
        throw Error("CSV não encontrado: " path)

    txt := FileRead(path, "UTF-8")
    txt := StrReplace(txt, "`r", "")
    lines := StrSplit(txt, "`n")

    if (lines.Length < 2)
        throw Error("CSV sem linhas suficientes: " path)

    header := SplitSemicolonCsvLine(lines[1])
    idx := 0
    for i, col in header {
        if (Trim(col) = "CD_REG_AMB") {
            idx := i
            break
        }
    }

    if (idx = 0)
        throw Error("Coluna CD_REG_AMB não encontrada no CSV: " path)

    contas := []
    seen := Map()

    for i, line in lines {
        if (i = 1)
            continue
        line := Trim(line)
        if (line = "")
            continue

        cols := SplitSemicolonCsvLine(line)
        if (cols.Length < idx)
            continue

        conta := Trim(cols[idx])
        conta := RegExReplace(conta, "\D")
        if (conta = "")
            continue

        if (DEDUPLICAR_CONTAS) {
            if seen.Has(conta)
                continue
            seen[conta] := true
        }

        contas.Push(conta)
    }

    return contas
}

SplitSemicolonCsvLine(line) {
    return MV_SplitSemicolonCsvLine(line)
}

; ==========================================================
; Janelas / Controles / Teclado
; ==========================================================

WaitWindow(titleParts, exe := "", className := "", timeoutSec := 20) {
    start := A_TickCount
    while ((A_TickCount - start) < timeoutSec * 1000) {
        hwnd := FindWindow(titleParts, exe, className)
        if (hwnd)
            return hwnd
        Sleep Delay.Poll
    }

    joined := ""
    for part in titleParts
        joined .= (joined = "" ? "" : " | ") part

    throw Error("Janela não encontrada: " joined " | exe=" exe " | class=" className)
}

WaitWindowBySpec(winSpec, timeoutSec := 20) {
    start := A_TickCount
    while ((A_TickCount - start) < timeoutSec * 1000) {
        hwnd := WinExist(winSpec)
        if (hwnd && IsWindowVisible(hwnd))
            return hwnd
        Sleep Delay.Poll
    }
    throw Error("Janela não encontrada: " winSpec)
}

WaitFfcvRemessaWindow(timeoutSec := 60) {
    ; O popup de remessa fica embarcado/instável no FFCV em algumas estações.
    ; Busca tolerante sem biblioteca externa e sem admin.
    start := A_TickCount
    while ((A_TickCount - start) < timeoutSec * 1000) {
        ; 1) Janela ativa. Quando o Alt+1 abre o popup, normalmente ele vira a janela ativa.
        try {
            active := WinGetID("A")
            if IsFfcvRemessaWindow(active) {
                LogLine("FFCV Remessa detectado por janela ativa | " WindowInfo(active))
                return active
            }
        } catch {
        }

        ; 2) Busca direta pelo par classe/processo visto no Window Spy.
        try {
            hwnd := WinExist("ahk_class TFPrincipal ahk_exe EXECUTASQL.exe")
            if (hwnd && IsFfcvRemessaWindow(hwnd)) {
                LogLine("FFCV Remessa detectado por WinExist TFPrincipal + EXECUTASQL.exe | " WindowInfo(hwnd))
                return hwnd
            }
        } catch {
        }

        ; 3) Busca por todas as TFPrincipal do EXECUTASQL, sem depender de texto/control list.
        hwnd := FindSmallExcutasqlTfPrincipal()
        if (hwnd) {
            LogLine("FFCV Remessa detectado por scan TFPrincipal pequeno do EXECUTASQL | " WindowInfo(hwnd))
            return hwnd
        }

        ; 3.1) Fallback ainda mais aberto: qualquer janela pequena do EXECUTASQL.
        hwnd := FindSmallExcutasqlAnyClass()
        if (hwnd) {
            LogLine("FFCV Remessa detectado por scan janela pequena do EXECUTASQL | " WindowInfo(hwnd))
            return hwnd
        }

        ; 4) Busca antiga por controles/texto, quando o Windows entrega os controles corretamente.
        hwnd := FindWindowByControls("EXECUTASQL.exe", ["TEdit1"], ["TBitBtn2"], "Gerar Arquivo")
        if (hwnd) {
            LogLine("FFCV Remessa detectado por controles TEdit1/TBitBtn2/texto | " WindowInfo(hwnd))
            return hwnd
        }

        hwnd := FindWindowByText("EXECUTASQL.exe", "Gerar Arquivo", "TFPrincipal")
        if (hwnd) {
            LogLine("FFCV Remessa detectado por texto Gerar Arquivo | " WindowInfo(hwnd))
            return hwnd
        }

        Sleep Delay.Poll
    }

    throw Error("Popup de Remessa/Gerar Arquivo não encontrado. A versão limpa tenta janela ativa, TFPrincipal/EXECUTASQL, janela pequena e controles/texto.")
}


IsFfcvRemessaWindow(hwnd) {
    if (!hwnd)
        return false

    try proc := StrLower(WinGetProcessName("ahk_id " hwnd))
    catch
        proc := ""

    try cls := WinGetClass("ahk_id " hwnd)
    catch
        cls := ""

    try title := WinGetTitle("ahk_id " hwnd)
    catch
        title := ""

    try {
        WinGetPos &x, &y, &w, &h, "ahk_id " hwnd
    } catch {
        w := 0, h := 0
    }

    ; Caso principal visto no Window Spy: TFPrincipal + EXECUTASQL.exe + popup 615x141.
    if (proc = "executasql.exe" && cls = "TFPrincipal" && w >= 450 && w <= 900 && h >= 90 && h <= 260)
        return true

    ; Se os controles aparecerem para AHK, também aceita.
    if (proc = "executasql.exe" && ControlExists("TBitBtn2", hwnd))
        return true

    try wtext := WinGetText("ahk_id " hwnd)
    catch
        wtext := ""

    if (proc = "executasql.exe" && InStr(wtext, "Gerar Arquivo"))
        return true

    ; Em alguns casos o título herdado fica errado, mas o pid/classe/tamanho denunciam o popup.
    if (cls = "TFPrincipal" && w >= 450 && w <= 900 && h >= 90 && h <= 260 && (InStr(title, "Relatório") || title = ""))
        return true

    return false
}


FindWindowByText(exe := "", requiredText := "", className := "") {
    spec := ""
    if (exe != "")
        spec .= "ahk_exe " exe
    if (className != "")
        spec .= (spec = "" ? "" : " ") "ahk_class " className

    try list := WinGetList(spec)
    catch {
        list := WinGetList()
    }

    for hwnd in list {
        if !IsWindowVisible(hwnd)
            continue

        if (exe != "") {
            try proc := StrLower(WinGetProcessName("ahk_id " hwnd))
            catch
                continue
            if (proc != StrLower(exe))
                continue
        }

        try wtext := WinGetText("ahk_id " hwnd)
        catch
            wtext := ""

        if (requiredText = "" || InStr(wtext, requiredText))
            return hwnd
    }

    return 0
}

FindWindowByControls(exe := "", requiredControls := "", optionalControls := "", requiredText := "") {
    spec := ""
    if (exe != "")
        spec := "ahk_exe " exe

    try {
        if (spec = "")
            list := WinGetList()
        else
            list := WinGetList(spec)
    } catch {
        list := WinGetList()
    }

    for hwnd in list {
        if !IsWindowVisible(hwnd)
            continue

        if IsObject(requiredControls) {
            hasAll := true
            for ctrl in requiredControls {
                if !ControlExists(ctrl, hwnd) {
                    hasAll := false
                    break
                }
            }
            if !hasAll
                continue
        }

        if IsObject(optionalControls) && optionalControls.Length > 0 {
            hasAnyOptional := false
            for ctrl in optionalControls {
                if ControlExists(ctrl, hwnd) {
                    hasAnyOptional := true
                    break
                }
            }

            if (!hasAnyOptional && requiredText != "") {
                try wtext := WinGetText("ahk_id " hwnd)
                catch
                    wtext := ""
                if InStr(wtext, requiredText)
                    hasAnyOptional := true
            }

            if !hasAnyOptional
                continue
        } else if (requiredText != "") {
            try wtext := WinGetText("ahk_id " hwnd)
            catch
                wtext := ""
            if !InStr(wtext, requiredText)
                continue
        }

        return hwnd
    }

    return 0
}

ControlExists(control, hwnd) {
    try {
        ch := ControlGetHwnd(control, "ahk_id " hwnd)
        if (ch != 0)
            return true
    } catch {
        ; Continua para WinGetControls, que em algumas telas do MV/EXECUTASQL funciona melhor.
    }

    try {
        controls := WinGetControls("ahk_id " hwnd)
        for c in controls {
            if (c = control)
                return true
        }
    } catch {
    }

    return false
}

FindWindow(titleParts, exe := "", className := "") {
    spec := ""
    if (exe != "")
        spec .= "ahk_exe " exe
    if (className != "")
        spec .= (spec = "" ? "" : " ") "ahk_class " className

    try list := WinGetList(spec)
    catch {
        list := WinGetList()
    }

    for hwnd in list {
        if !IsWindowVisible(hwnd)
            continue

        title := ""
        try title := WinGetTitle("ahk_id " hwnd)
        catch
            continue

        ok := true
        for part in titleParts {
            if !InStr(title, part) {
                ok := false
                break
            }
        }

        if ok
            return hwnd
    }

    return 0
}

IsWindowVisible(hwnd) {
    try {
        style := WinGetStyle("ahk_id " hwnd)
        return (style & 0x10000000) != 0
    } catch {
        return false
    }
}


WindowInfo(hwnd) {
    try title := WinGetTitle("ahk_id " hwnd)
    catch
        title := ""
    try cls := WinGetClass("ahk_id " hwnd)
    catch
        cls := ""
    try proc := WinGetProcessName("ahk_id " hwnd)
    catch
        proc := ""
    try WinGetPos &x, &y, &w, &h, "ahk_id " hwnd
    catch {
        x := 0, y := 0, w := 0, h := 0
    }
    return "hwnd=" hwnd " | exe=" proc " | class=" cls " | title=" title " | pos=" x "," y "," w "," h
}

FindSmallExcutasqlTfPrincipal() {
    ; Busca relaxada para o popup de remessa quando WinGetText/WinGetControls não enxergam os filhos.
    try list := WinGetList("ahk_class TFPrincipal")
    catch {
        return 0
    }

    best := 0
    for hwnd in list {
        try proc := StrLower(WinGetProcessName("ahk_id " hwnd))
        catch
            proc := ""

        if (proc != "executasql.exe")
            continue

        try {
            WinGetPos &x, &y, &w, &h, "ahk_id " hwnd
        } catch {
            continue
        }

        ; Popup visto nas imagens: 615x141. Mantém margem para DPI/tema.
        if (w >= 450 && w <= 900 && h >= 90 && h <= 260) {
            best := hwnd
            break
        }
    }
    return best
}

FindSmallExcutasqlAnyClass() {
    try list := WinGetList("ahk_exe EXECUTASQL.exe")
    catch {
        return 0
    }

    for hwnd in list {
        try WinGetPos &x, &y, &w, &h, "ahk_id " hwnd
        catch
            continue

        ; Popup pequeno de Remessa, independente da classe que o Windows entregar.
        if (w >= 450 && w <= 900 && h >= 90 && h <= 260)
            return hwnd
    }
    return 0
}


WaitSaveAsWindow(timeoutSec := 45) {
    start := A_TickCount
    while ((A_TickCount - start) < timeoutSec * 1000) {
        try {
            active := WinGetID("A")
            if IsSaveAsWindow(active) {
                LogLine("Salvar como detectado por janela ativa | " WindowInfo(active))
                return active
            }
        } catch {
        }

        try {
            hwnd := WinExist("Salvar como ahk_exe EXECUTASQL.exe")
            if (hwnd && IsSaveAsWindow(hwnd)) {
                LogLine("Salvar como detectado por WinExist título + EXECUTASQL.exe | " WindowInfo(hwnd))
                return hwnd
            }
        } catch {
        }

        hwnd := FindSaveAsByScan()
        if (hwnd) {
            LogLine("Salvar como detectado por scan EXECUTASQL/#32770/controles | " WindowInfo(hwnd))
            return hwnd
        }

        hwnd := FindWindowByControls("EXECUTASQL.exe", ["Edit1"], ["Button2", "Button3"], "Salvar em:")
        if (hwnd && IsSaveAsWindow(hwnd)) {
            LogLine("Salvar como detectado por controles Edit1 + Button2/Button3 | " WindowInfo(hwnd))
            return hwnd
        }

        Sleep Delay.Poll
    }

    throw Error("Janela Salvar como não encontrada. A versão limpa tenta janela ativa, WinExist, varredura por #32770/controles e texto.")
}

IsSaveAsWindow(hwnd) {
    if (!hwnd)
        return false

    try proc := StrLower(WinGetProcessName("ahk_id " hwnd))
    catch
        proc := ""
    try cls := WinGetClass("ahk_id " hwnd)
    catch
        cls := ""
    try title := WinGetTitle("ahk_id " hwnd)
    catch
        title := ""
    try WinGetPos &x, &y, &w, &h, "ahk_id " hwnd
    catch {
        w := 0, h := 0
    }
    try wtext := WinGetText("ahk_id " hwnd)
    catch
        wtext := ""

    if (proc != "executasql.exe")
        return false

    if (cls = "#32770" && InStr(title, "Salvar"))
        return true

    if (cls = "#32770" && ControlExists("Edit1", hwnd) && (ControlExists("Button2", hwnd) || ControlExists("Button3", hwnd)))
        return true

    if (cls = "#32770" && (InStr(wtext, "Salvar em") || InStr(wtext, "Nome") || InStr(wtext, "Text files")))
        return true

    ; Fallback por tamanho típico do diálogo Salvar como clássico.
    if (w >= 500 && w <= 950 && h >= 330 && h <= 750 && (InStr(title, "Salvar") || ControlExists("Edit1", hwnd)))
        return true

    return false
}

FindSaveAsByScan() {
    try list := WinGetList("ahk_exe EXECUTASQL.exe")
    catch {
        return 0
    }

    for hwnd in list {
        if !IsWindowVisible(hwnd)
            continue
        if IsSaveAsWindow(hwnd)
            return hwnd
    }
    return 0
}

JoinArray(arr, sep := ",") {
    out := ""
    for item in arr
        out .= (out = "" ? "" : sep) item
    return out
}

ActivateWindow(hwnd) {
    try WinRestore "ahk_id " hwnd
    Sleep Delay.Fast
    WinActivate "ahk_id " hwnd
    try WinWaitActive "ahk_id " hwnd, , 3
    Sleep Delay.ActivateActive
}

SendKeys(keys, waitMs := "") {
    Send keys
    if (waitMs = "")
        Sleep Delay.AfterHotkey
    else
        Sleep waitMs
}

ClickMouse(waitMs := "") {
    Click
    if (waitMs = "")
        Sleep Delay.AfterClick
    else
        Sleep waitMs
}

SendMenuPath(path) {
    ; Ex.: "mpe" = Alt+M, P, E
    if (StrLen(path) < 1)
        return

    first := SubStr(path, 1, 1)
    rest := SubStr(path, 2)

    SendKeys("!" first)
    Sleep Delay.MenuStep

    Loop Parse rest {
        SendKeys(A_LoopField)
        Sleep Delay.MenuStep
    }
}

CloseByCtrlQAndWait(context := "") {
    ; Fecha a tela atual e aguarda a tela resultante estabilizar.
    ; Isso evita começar o próximo envio enquanto o Oracle Forms/MV ainda está carregando.
    LogLine("Ctrl+Q: fechando janela" (context != "" ? " (" context ")" : ""))
    SendKeys("^q")
    WaitCurrentScreenStableAfterCtrlQ(context)
}

CloseByCtrlQEnterAndWait(context := "") {
    ; Fluxos como a baixa usam Ctrl+Q e depois Enter.
    ; Antes do Enter, aguarda a tela/diálogo atual aparecer e ficar estável.
    ; Depois do Enter, aguarda novamente para não enviar a próxima conta pela metade.
    CloseByCtrlQAndWait(context " antes do Enter")
    LogLine("Ctrl+Q: tela detectada; enviando Enter" (context != "" ? " (" context ")" : ""))
    SendKeys("{Enter}")
    Sleep Delay.AfterCtrlQEnter
    WaitCurrentScreenStableAfterCtrlQ(context " depois do Enter")
    WaitMovDocOrEnvioReadyAfterClose(context)
}

WaitCurrentScreenStableAfterCtrlQ(context := "") {
    start := A_TickCount
    lastSignature := ""
    stableSince := 0

    while ((A_TickCount - start) < Delay.CtrlQReadyTimeout) {
        try hwnd := WinGetID("A")
        catch {
            Sleep Delay.Poll
            continue
        }

        if (!hwnd) {
            Sleep Delay.Poll
            continue
        }

        signature := ActiveScreenSignature(hwnd)
        if (signature = "") {
            Sleep Delay.Poll
            continue
        }

        if (signature != lastSignature) {
            lastSignature := signature
            stableSince := A_TickCount
            Sleep Delay.Poll
            continue
        }

        if ((A_TickCount - stableSince) >= Delay.CtrlQStableMs) {
            LogLine("Ctrl+Q: tela atual estável" (context != "" ? " (" context ")" : "") " | " WindowInfo(hwnd))
            return hwnd
        }

        Sleep Delay.Poll
    }

    try hwnd := WinGetID("A")
    catch
        hwnd := 0

    if (hwnd)
        LogLine("Ctrl+Q: tempo limite aguardando estabilidade; seguindo com tela ativa | " WindowInfo(hwnd))
    else
        LogLine("Ctrl+Q: tempo limite aguardando estabilidade; nenhuma tela ativa detectada")

    return hwnd
}

WaitMovDocOrEnvioReadyAfterClose(context := "") {
    global gEnvioHwnd

    start := A_TickCount
    while ((A_TickCount - start) < Delay.CtrlQReadyTimeout) {
        envWin := FindWindow(["Protocolação de Envio de Documentos"], "ifrun60.EXE", "")
        if (envWin) {
            gEnvioHwnd := envWin
            if !WinActive("ahk_id " envWin)
                ActivateWindow(envWin)
            WaitCurrentScreenStableAfterCtrlQ(context " tela de envio pronta")
            LogLine("Ctrl+Q: tela de envio pronta para continuar" (context != "" ? " (" context ")" : ""))
            return envWin
        }

        movWin := FindWindow(["Movimentação de Documentos"], "ifrun60.EXE", "")
        if (movWin) {
            if !WinActive("ahk_id " movWin)
                ActivateWindow(movWin)
            WaitCurrentScreenStableAfterCtrlQ(context " tela MovDoc pronta")
            LogLine("Ctrl+Q: MovDoc estável após fechamento" (context != "" ? " (" context ")" : ""))
            return movWin
        }

        Sleep Delay.Poll
    }

    throw Error("Após Ctrl+Q, a tela do MovDoc/Envio não estabilizou no tempo esperado" (context != "" ? ": " context : "."))
}

ActiveScreenSignature(hwnd) {
    try title := WinGetTitle("ahk_id " hwnd)
    catch
        title := ""
    try cls := WinGetClass("ahk_id " hwnd)
    catch
        cls := ""
    try proc := WinGetProcessName("ahk_id " hwnd)
    catch
        proc := ""
    return hwnd "|" proc "|" cls "|" title
}

SendContaFast(conta) {
    ; Mais rápido que SendTextSafe porque a conta é enviada centenas de vezes.
    ; Mantém o mínimo obrigatório de 100 ms depois do Ctrl+V.
    oldClip := ClipboardAll()
    A_Clipboard := ""
    A_Clipboard := conta
    if !ClipWait(1) {
        A_Clipboard := oldClip
        throw Error("Falha ao preparar clipboard da conta " conta ".")
    }

    Send "^v"
    Sleep Delay.AccountPaste
    A_Clipboard := oldClip
}

SendTextSafe(text) {
    ; Para Oracle Forms, colar costuma ser mais estável que digitar número por número.
    PasteText(text)
    Sleep Delay.Fast
}

PasteText(text) {
    oldClip := ClipboardAll()
    A_Clipboard := ""
    A_Clipboard := text
    if !ClipWait(1) {
        A_Clipboard := oldClip
        throw Error("Falha ao preparar clipboard.")
    }
    SendKeys("^v")
    Sleep Delay.ActivateActive
    A_Clipboard := oldClip
}


SetSaveAsFileName(hwnd, path) {
    LogLine("Salvar como: tentando Edit1 via ControlSetText")
    try {
        ControlFocus "Edit1", "ahk_id " hwnd
        Sleep Delay.Fast
        ControlSetText "", "Edit1", "ahk_id " hwnd
        Sleep Delay.Tiny
        ControlSetText path, "Edit1", "ahk_id " hwnd
        Sleep Delay.AfterHotkey
        try {
            val := ControlGetText("Edit1", "ahk_id " hwnd)
            if (Trim(val) = Trim(path)) {
                LogLine("Salvar como: nome preenchido via Edit1/ControlSetText e validado")
                return true
            }
            LogLine("Salvar como: ControlSetText executou, mas validação retornou '" val "'. Tentando fallback.")
        } catch {
            LogLine("Salvar como: nome preenchido via Edit1/ControlSetText sem validação possível")
            return true
        }
    } catch as e {
        LogLine("Salvar como: Edit1/ControlSetText falhou: " e.Message)
    }

    LogLine("Salvar como: fallback ControlFocus/Edit1 + clipboard")
    ActivateWindow(hwnd)
    try ControlFocus "Edit1", "ahk_id " hwnd
    catch {
    }
    Sleep Delay.Fast
    SendKeys("^a")
    PasteText(path)
    return true
}

ClickSaveAsButton(hwnd) {
    if ClickControl("Button2", hwnd) {
        LogLine("Salvar como: clique em Button2/Salvar via ControlClick")
        return true
    }

    ; Fallback por coordenada client do botão Salvar visto no Window Spy: x≈564 y≈354.
    LogLine("Salvar como: fallback por coordenada client do botão Salvar")
    ClickClient(hwnd, 564, 354)
    return true
}

SetControlTextOrPaste(control, hwnd, text) {
    try {
        ControlFocus control, "ahk_id " hwnd
        Sleep Delay.Fast
        ControlSetText "", control, "ahk_id " hwnd
        Sleep Delay.Tiny
        ControlSetText text, control, "ahk_id " hwnd
        Sleep Delay.AfterHotkey
        return
    } catch {
        ActivateWindow(hwnd)
        try ControlFocus control, "ahk_id " hwnd
        catch {
            ; controle indisponível: segue com foco da janela e cola via teclado
        }
        Sleep Delay.Fast
        SendKeys("^a")
        Sleep Delay.Tiny
        PasteText(text)
    }
}

ClickControl(control, hwnd) {
    try {
        ControlClick control, "ahk_id " hwnd,,,, "NA"
        Sleep Delay.AfterClick
        return true
    } catch {
        return false
    }
}

ClickControlOrThrow(control, hwnd) {
    if !ClickControl(control, hwnd)
        throw Error("Não foi possível clicar no controle " control " da janela: " WinGetTitle("ahk_id " hwnd))
}

ClickControlOrClientFallback(control, hwnd, fallbackClientX, fallbackClientY) {
    if ClickControl(control, hwnd) {
        LogLine("Clique: " control " via ControlClick")
        return true
    }

    ; Fallback por coordenada client dentro do próprio popup.
    ; No popup de Remessa, o botão Gerar Arquivo fica por volta de x=548 y=91 no client.
    LogLine("Clique: fallback por coordenada client x=" fallbackClientX " y=" fallbackClientY "")
    ClickClient(hwnd, fallbackClientX, fallbackClientY)
    return true
}


SetFfcvRemessaText(hwnd, text) {
    ; Primeiro tenta pelo controle real. Se o EXECUTASQL/MV ignorar ControlSetText,
    ; cai para foco/click + clipboard.
    LogLine("Remessa: tentando TEdit1 via ControlSetText")
    try {
        ControlFocus "TEdit1", "ahk_id " hwnd
        Sleep Delay.Fast
        ControlSetText "", "TEdit1", "ahk_id " hwnd
        Sleep Delay.Tiny
        ControlSetText text, "TEdit1", "ahk_id " hwnd
        Sleep Delay.AfterHotkey

        ; Em algumas telas o ControlSetText não dá erro, mas também não escreve.
        try {
            val := ControlGetText("TEdit1", "ahk_id " hwnd)
            if (Trim(val) = Trim(text)) {
                LogLine("Remessa: preenchida por TEdit1/ControlSetText e validada")
                return true
            }
            LogLine("Remessa: ControlSetText executou, mas validação retornou '" val "'. Tentando fallback.")
        } catch {
            ; Se não der para validar, aceita e segue.
            LogLine("Remessa: preenchida por TEdit1/ControlSetText sem validação possível")
            return true
        }
    } catch as e {
        LogLine("Remessa: TEdit1/ControlSetText falhou: " e.Message)
    }

    LogLine("Remessa: usando fallback click client + clipboard")
    ActivateWindow(hwnd)
    try ControlFocus "TEdit1", "ahk_id " hwnd
    catch {
    }
    Sleep Delay.Fast

    ; Coordenada client do campo REMESSA vista no Window Spy: x≈85 y≈10.
    ; Clica um pouco dentro do campo para garantir foco.
    ClickClient(hwnd, 110, 14)
    SendKeys("^a")
    PasteText(text)
    return true
}


ClickControlOrSendEnter(control, hwnd) {
    if !ClickControl(control, hwnd) {
        ActivateWindow(hwnd)
        SendKeys("{Enter}")
        Sleep Delay.Poll
    }
}

ClickClient(hwnd, x, y) {
    WinGetPos &wx, &wy, &ww, &wh, "ahk_id " hwnd
    ; Converte ponto client para screen.
    pt := Buffer(8, 0)
    NumPut("Int", x, pt, 0)
    NumPut("Int", y, pt, 4)
    DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", pt)
    sx := NumGet(pt, 0, "Int")
    sy := NumGet(pt, 4, "Int")

    ActivateWindow(hwnd)
    MouseMove sx, sy, 0
    ClickMouse()
}

CopyFocusedField() {
    oldClip := ClipboardAll()
    A_Clipboard := ""
    SendKeys("{Home}")
    Sleep Delay.CopyStep
    SendKeys("+{End}")
    Sleep Delay.CopyStep
    SendKeys("^c")
    if !ClipWait(1) {
        A_Clipboard := oldClip
        throw Error("Falha ao copiar texto do campo focado.")
    }

    val := Trim(A_Clipboard)
    A_Clipboard := oldClip
    return val
}

WaitForFile(path, timeoutSec := 20) {
    start := A_TickCount
    while ((A_TickCount - start) < timeoutSec * 1000) {
        if FileExist(path)
            return true
        Sleep Delay.FilePoll
    }
    throw Error("Arquivo não foi criado no tempo esperado: " path)
}


WaitForAnyFile(paths, timeoutSec := 20) {
    start := A_TickCount
    while ((A_TickCount - start) < timeoutSec * 1000) {
        for path in paths {
            if FileExist(path)
                return path
        }
        Sleep Delay.FilePoll
    }

    joined := ""
    for path in paths
        joined .= (joined = "" ? "" : " | ") path
    throw Error("Arquivo não foi criado no tempo esperado. Procurado: " joined)
}

; ==========================================================
; Popups e OCR
; ==========================================================

FindMvUserMessage(timeoutMs := 1200) {
    start := A_TickCount
    while ((A_TickCount - start) <= timeoutMs) {
        try list := WinGetList("Mensagem ao Usuário do MV 2000 ahk_exe ifrun60.EXE")
        catch {
            list := []
        }

        for hwnd in list {
            if IsWindowVisible(hwnd)
                return hwnd
        }
        Sleep Delay.Poll
    }
    return 0
}

CloseMvPopup(hwnd) {
    ActivateWindow(hwnd)
    if !ClickControl("Button1", hwnd) {
        SendKeys("{Enter}")
        Sleep Delay.Poll
    }
    Sleep Delay.Close
}

ReadMvMessage(hwnd) {
    global OCR_SCALE, OCR_SCALE_RETRY

    ; Ordem rápida:
    ; 1) WinGetText, quando o MV expõe o texto;
    ; 2) OCR como fallback, recortando só a área da mensagem.
    text := ""
    try text := WinGetText("ahk_id " hwnd)
    catch
        text := ""

    if IsUsefulPopupText(text) {
        MaybeLogPopupTextMethod("WinGetText")
        return text
    }

    ; OCR rápido: escala 2 e script PowerShell cacheado.
    ; Se não conseguir texto útil, tenta uma segunda leitura com escala maior.
    ocr := OcrWindowText(hwnd, true, OCR_SCALE)
    if IsUsefulPopupText(ocr) {
        MaybeLogPopupTextMethod("OCR rápido")
        return ocr
    }

    if (OCR_SCALE_RETRY != OCR_SCALE) {
        ocrRetry := OcrWindowText(hwnd, true, OCR_SCALE_RETRY)
        if (Trim(ocrRetry) != "") {
            MaybeLogPopupTextMethod("OCR fallback escala " OCR_SCALE_RETRY)
            return ocrRetry
        }
    }

    if (Trim(ocr) = "")
        throw Error("OCR não retornou texto para o popup do MV.")

    MaybeLogPopupTextMethod("OCR rápido sem validação")
    return ocr
}

IsUsefulPopupText(text) {
    normalized := NormalizeOcrForMatch(text)
    if (InStr(normalized, "atenc") || InStr(normalized, "protoc") || InStr(normalized, "setor") || InStr(normalized, "pendente") || InStr(normalized, "diferente"))
        return true
    return false
}

MaybeLogPopupTextMethod(method) {
    try {
        if (Delay.PopupTextMethodLog)
            LogLine("Popup: texto lido via " method)
    }
}

NormalizeText(text) {
    text := StrReplace(text, "`r", " ")
    text := StrReplace(text, "`n", " ")
    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

; OCR do MV pode trocar letras/números em mensagens desenhadas.
; Exemplo real: "documenta", "recebimenta", "Protocola n.0".
; Estas funções fazem leitura tolerante sem depender do texto perfeito.
ExtractPendingProtocol(msg) {
    loose := NormalizeOcrForMatch(msg)

    ; Só trata como pendência se houver sinal claro de mensagem de documento pendente.
    if (!InStr(loose, "pendente"))
        return ""

    if !(InStr(loose, "devolu") || InStr(loose, "receb") || InStr(loose, "document"))
        return ""

    ; Aceita Protocolo/Protocola/Protocol0 e variações OCR de "n.º", "n.0", "nº".
    if (RegExMatch(loose, "protoc[a-z0-9]*\s*(?:n|n\.|n0|no|numero|num)?\s*[\.:º°o0]*\s*(\d{4,})", &m))
        return m[1]

    ; Fallback seguro: em mensagem pendente, pega número longo depois da palavra protoc*.
    pos := RegExMatch(loose, "protoc[a-z0-9]*", &p)
    if (pos) {
        after := SubStr(loose, pos)
        if (RegExMatch(after, "(\d{4,})", &m))
            return m[1]
    }

    return ""
}

ExtractSetorRecebido(msg, cfg := 0) {
    loose := NormalizeOcrForMatch(msg)

    ; Só entra no fluxo de setor quando a mensagem tem a estrutura do erro de setor.
    ; Aceita OCR trocando "conta" por "canta" e variações pequenas.
    ; Isso evita confundir "recebimento" da mensagem de documento pendente com "setor recebido".
    hasConta := InStr(loose, "conta") || InStr(loose, "canta") || InStr(loose, "cont4")
    if !(InStr(loose, "setor") && InStr(loose, "diferente") && hasConta)
        return ""

    candidato := ""

    ; Prioridade absoluta: número logo depois de "Setor recebido".
    ; Exemplo real correto: "O Setor no 34 está diferente do Setor recebido: 356 para conta: 13023847".
    ; O OCR pode ler 356 como 336; a função abaixo aplica uma correção controlada quando isso
    ; conflita por apenas 1 dígito com o Setor Envio configurado.
    if (RegExMatch(loose, "setor\s*(?:recebido|recebida|recebid0|receb1do|receb|receh|recen|reced)[a-z0-9]*\s*[:;.,\-]?\s*(\d{1,4})", &m))
        candidato := m[1]

    ; Fallback: recorta a parte depois de "setor receb..." e antes de "conta".
    if (candidato = "") {
        pos := RegExMatch(loose, "setor\s*(?:receb|receh|recen|reced)[a-z0-9]*", &mSetor)
        if (!pos)
            pos := RegExMatch(loose, "receb[a-z0-9]*", &mSetor)

        if (pos) {
            trecho := SubStr(loose, pos)
            contaPos := InStr(trecho, "conta")
            if (!contaPos)
                contaPos := InStr(trecho, "canta")
            if (contaPos)
                trecho := SubStr(trecho, 1, contaPos - 1)

            ; Setor é curto. Conta geralmente tem 7/8+ dígitos, então limite 1..4 reduz falso positivo.
            if (RegExMatch(trecho, "\b(\d{1,4})\b", &m))
                candidato := m[1]
        }
    }

    ; Fallback controlado para OCR muito distorcido:
    ; pega os números curtos entre "diferente" e "conta/canta" e usa o último.
    ; Ex.: "setor no 34 esta diferente do setor recebido 356 para canta 13023847" -> 356.
    if (candidato = "") {
        ini := InStr(loose, "diferente")
        fim := InStr(loose, "conta")
        if (!fim)
            fim := InStr(loose, "canta")
        if (ini && fim && fim > ini) {
            trecho := SubStr(loose, ini, fim - ini)
            nums := []
            posNum := 1
            while (posNum := RegExMatch(trecho, "\b\d{1,4}\b", &m, posNum)) {
                nums.Push(m[0])
                posNum += StrLen(m[0])
            }
            if (nums.Length > 0)
                candidato := nums[nums.Length]
        }
    }

    if (candidato = "")
        return ""

    return CorrigirSetorRecebidoPorContexto(candidato, cfg, loose)
}

CorrigirSetorRecebidoPorContexto(candidato, cfg, loose) {
    global SETOR_OCR_CORRECTION_WITH_CONFIG

    candidato := RegExReplace(candidato, "\D")
    if (candidato = "")
        return ""

    if (!SETOR_OCR_CORRECTION_WITH_CONFIG || !IsObject(cfg))
        return candidato

    esperado := RegExReplace(cfg.SetorEnvio, "\D")
    setorAtual := RegExReplace(cfg.SetorAtual, "\D")

    if (esperado = "" || candidato = esperado)
        return candidato

    ; Correção conservadora para o caso real do OCR ler 356 como 336:
    ; - o candidato e o Setor Envio têm o mesmo tamanho;
    ; - diferem por apenas 1 dígito;
    ; - o texto do popup contém a estrutura do erro de setor;
    ; - o texto também menciona o Setor Atual configurado antes do trecho "diferente".
    ; Assim evita corrigir qualquer número solto da mensagem.
    if (StrLen(candidato) = StrLen(esperado) && DigitDistance(candidato, esperado) = 1) {
        antesDiferente := loose
        posDif := InStr(loose, "diferente")
        if (posDif)
            antesDiferente := SubStr(loose, 1, posDif - 1)

        if ((setorAtual = "" || RegExMatch(antesDiferente, "\b" setorAtual "\b")) && InStr(loose, "setor") && InStr(loose, "receb")) {
            LogLine("Setor recebido corrigido por contexto/OCR: lido=" candidato " | usando Setor Envio configurado=" esperado)
            return esperado
        }
    }

    return candidato
}

DigitDistance(a, b) {
    if (StrLen(a) != StrLen(b))
        return 999

    dist := 0
    Loop StrLen(a) {
        if (SubStr(a, A_Index, 1) != SubStr(b, A_Index, 1))
            dist++
    }
    return dist
}

NormalizeOcrForMatch(text) {
    text := StrLower(NormalizeText(text))
    text := RemovePortugueseAccents(text)

    ; Normalizações comuns do OCR nos popups do MV.
    text := StrReplace(text, "n.º", "n")
    text := StrReplace(text, "n°", "n")
    text := StrReplace(text, "nº", "n")
    text := StrReplace(text, "n.0", "n")
    text := StrReplace(text, "n.o", "n")
    text := StrReplace(text, "n 0", "n")
    text := StrReplace(text, "protocol0", "protocolo")
    text := StrReplace(text, "protoco1o", "protocolo")

    ; Normalizações para erro de setor. O OCR do MV às vezes lê "conta" como "canta".
    ; Mantemos também a checagem em ExtractSetorRecebido, mas normalizar ajuda no recorte.
    text := RegExReplace(text, "\bcanta\b", "conta")
    text := RegExReplace(text, "\bcont4\b", "conta")
    text := RegExReplace(text, "\bconla\b", "conta")

    text := RegExReplace(text, "\s+", " ")
    return Trim(text)
}

RemovePortugueseAccents(text) {
    replacements := Map(
        "á", "a", "à", "a", "ã", "a", "â", "a", "ä", "a",
        "é", "e", "è", "e", "ê", "e", "ë", "e",
        "í", "i", "ì", "i", "î", "i", "ï", "i",
        "ó", "o", "ò", "o", "õ", "o", "ô", "o", "ö", "o",
        "ú", "u", "ù", "u", "û", "u", "ü", "u",
        "ç", "c"
    )

    for from, to in replacements
        text := StrReplace(text, from, to)

    return text
}

; ==========================================================
; OCR SERVER PERSISTENTE
; ==========================================================

EnsureOcrServer() {
    global gOcrServerReady, gOcrServerPid, gOcrServerPs1
    global gOcrServerReqFile, gOcrServerSigFile, gOcrServerRespFile
    global gOcrServerKillFile, gOcrServerInitFile
    global OCR_SERVER_TIMEOUT_MS, OCR_SERVER_POLL_MS, OCR_LANGUAGE

    ; Servidor já está rodando e vivo.
    if (gOcrServerReady && gOcrServerPid && ProcessExist(gOcrServerPid))
        return true

    LogLine("OCR: iniciando servidor persistente de OCR...")
    gOcrServerReady := false

    ; Limpa arquivos de sessão anterior.
    for f in [gOcrServerReqFile, gOcrServerSigFile, gOcrServerRespFile, gOcrServerKillFile, gOcrServerInitFile]
        try FileDelete f

    EnsureOcrServerPs1()

    cmd := Format('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{1}" -ReqFile "{2}" -SigFile "{3}" -RespFile "{4}" -KillFile "{5}" -InitFile "{6}" -Lang "{7}"',
        gOcrServerPs1, gOcrServerReqFile, gOcrServerSigFile, gOcrServerRespFile, gOcrServerKillFile, gOcrServerInitFile, OCR_LANGUAGE)

    Run cmd, , "Hide", &pid
    gOcrServerPid := pid

    ; Aguarda sinal de pronto (arquivo init criado pelo PS).
    start := A_TickCount
    while ((A_TickCount - start) < OCR_SERVER_TIMEOUT_MS) {
        if FileExist(gOcrServerInitFile) {
            try FileDelete gOcrServerInitFile
            gOcrServerReady := true
            LogLine("OCR: servidor pronto (pid=" gOcrServerPid ")")
            return true
        }
        if !ProcessExist(gOcrServerPid)
            throw Error("Servidor OCR encerrou inesperadamente durante a inicialização.")
        Sleep OCR_SERVER_POLL_MS
    }

    throw Error("Servidor OCR não ficou pronto no tempo esperado (" OCR_SERVER_TIMEOUT_MS "ms).")
}

StopOcrServer() {
    global gOcrServerPid, gOcrServerReady, gOcrServerKillFile, gOcrServerRespFile

    gOcrServerReady := false
    if (!gOcrServerPid)
        return

    ; Sinaliza encerramento gracioso.
    try FileAppend "kill", gOcrServerKillFile
    Sleep 300
    try ProcessClose gOcrServerPid
    gOcrServerPid := 0

    ; Remove resposta pendente se houver.
    try FileDelete gOcrServerRespFile
}

OcrViaServer(x, y, w, h, scale) {
    global gOcrServerPid, gOcrServerReady
    global gOcrServerReqFile, gOcrServerSigFile, gOcrServerRespFile
    global OCR_SERVER_TIMEOUT_MS, OCR_SERVER_POLL_MS

    if (!gOcrServerReady)
        throw Error("Servidor OCR não está pronto.")
    if (!ProcessExist(gOcrServerPid)) {
        gOcrServerReady := false
        throw Error("Processo do servidor OCR não existe mais.")
    }

    ; Garante que não há resposta antiga.
    try FileDelete gOcrServerRespFile

    ; Escreve parâmetros e sinaliza o servidor.
    reqContent := x "`n" y "`n" w "`n" h "`n" scale
    FileAppend reqContent, gOcrServerReqFile, "UTF-8"
    FileAppend "1", gOcrServerSigFile

    ; Aguarda resposta.
    start := A_TickCount
    while ((A_TickCount - start) < OCR_SERVER_TIMEOUT_MS) {
        if FileExist(gOcrServerRespFile) {
            text := FileRead(gOcrServerRespFile, "UTF-8")
            try FileDelete gOcrServerRespFile
            if (SubStr(text, 1, 9) = "OCR_ERRO:")
                throw Error("Servidor OCR reportou erro: " text)
            return text
        }
        if !ProcessExist(gOcrServerPid) {
            gOcrServerReady := false
            throw Error("Servidor OCR encerrou durante o reconhecimento.")
        }
        Sleep OCR_SERVER_POLL_MS
    }

    throw Error("Servidor OCR não respondeu em " OCR_SERVER_TIMEOUT_MS "ms.")
}

OcrViaPowerShell(x, y, w, h, ocrScale) {
    ; Método legado: lança um processo PS para cada chamada. Mais lento.
    ; Usado como fallback quando o servidor persistente não está disponível.
    global OCR_LANGUAGE

    ps1 := EnsureOcrPowerShellScript()
    outFile := A_Temp "\mv_ocr_" A_TickCount ".txt"
    cmd := Format("powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"{1}`" -X {2} -Y {3} -W {4} -H {5} -Out `"{6}`" -Lang `"{7}`" -Scale {8}",
        ps1, x, y, w, h, outFile, OCR_LANGUAGE, ocrScale)
    exitCode := RunWait(cmd, , "Hide")
    if (exitCode != 0)
        throw Error("PowerShell OCR (legado) falhou. Código: " exitCode)
    if !FileExist(outFile)
        throw Error("PowerShell OCR (legado) não gerou arquivo de texto.")
    text := FileRead(outFile, "UTF-8")
    try FileDelete outFile
    return text
}

EnsureOcrServerPs1() {
    global gOcrServerPs1

    ; Sempre regenera para garantir que está na versão correta.
    try FileDelete gOcrServerPs1

    psLines := []
    psLines.Push("param(")
    psLines.Push("    [string]`$ReqFile,")
    psLines.Push("    [string]`$SigFile,")
    psLines.Push("    [string]`$RespFile,")
    psLines.Push("    [string]`$KillFile,")
    psLines.Push("    [string]`$InitFile,")
    psLines.Push("    [string]`$Lang = 'pt-BR',")
    psLines.Push("    [int]`$PollMs = 25")
    psLines.Push(")")
    psLines.Push("")
    psLines.Push("`$ErrorActionPreference = 'Stop'")
    psLines.Push("if (`$PollMs -lt 5) { `$PollMs = 5 }")
    psLines.Push("")
    psLines.Push("Add-Type -AssemblyName System.Drawing")
    psLines.Push("Add-Type -AssemblyName System.Runtime.WindowsRuntime")
    psLines.Push("")
    psLines.Push("[Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Graphics.Imaging.BitmapAlphaMode, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("")
    psLines.Push("`$script:asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() |")
    psLines.Push("    Where-Object {")
    psLines.Push("        `$_.Name -eq 'AsTask' -and")
    psLines.Push("        `$_.IsGenericMethodDefinition -and")
    psLines.Push("        `$_.GetParameters().Count -eq 1")
    psLines.Push("    } |")
    psLines.Push("    Select-Object -First 1")
    psLines.Push("")
    psLines.Push("function Await(`$Operation, [Type]`$ResultType) {")
    psLines.Push("    `$asTask = `$script:asTaskGeneric.MakeGenericMethod(`$ResultType)")
    psLines.Push("    `$task = `$asTask.Invoke(`$null, @(`$Operation))")
    psLines.Push("    `$task.Wait() | Out-Null")
    psLines.Push("    return `$task.Result")
    psLines.Push("}")
    psLines.Push("")
    psLines.Push("# Inicializa o engine OCR UMA VEZ e reutiliza em todas as chamadas.")
    psLines.Push("`$engine = `$null")
    psLines.Push("try {")
    psLines.Push("    `$language = New-Object Windows.Globalization.Language `$Lang")
    psLines.Push("    `$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage(`$language)")
    psLines.Push("} catch { `$engine = `$null }")
    psLines.Push("if (`$null -eq `$engine) {")
    psLines.Push("    `$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()")
    psLines.Push("}")
    psLines.Push("if (`$null -eq `$engine) {")
    psLines.Push("    'OCR_ERRO: engine indisponivel' | Out-File -FilePath `$RespFile -Encoding utf8")
    psLines.Push("    exit 1")
    psLines.Push("}")
    psLines.Push("")
    psLines.Push("`$pngFile = `$RespFile + '.tmp.png'")
    psLines.Push("")
    psLines.Push("function DoOcr([int]`$X, [int]`$Y, [int]`$W, [int]`$H, [int]`$Scale) {")
    psLines.Push("    `$bmp = New-Object System.Drawing.Bitmap `$W, `$H")
    psLines.Push("    `$g = [System.Drawing.Graphics]::FromImage(`$bmp)")
    psLines.Push("    `$g.CopyFromScreen(`$X, `$Y, 0, 0, (New-Object System.Drawing.Size `$W, `$H))")
    psLines.Push("    `$g.Dispose()")
    psLines.Push("    if (`$Scale -gt 1) {")
    psLines.Push("        `$sw = [Math]::Max(1, `$W * `$Scale)")
    psLines.Push("        `$sh = [Math]::Max(1, `$H * `$Scale)")
    psLines.Push("        `$scaled = New-Object System.Drawing.Bitmap `$sw, `$sh")
    psLines.Push("        `$sg = [System.Drawing.Graphics]::FromImage(`$scaled)")
    psLines.Push("        `$sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor")
    psLines.Push("        `$sg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighSpeed")
    psLines.Push("        `$sg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighSpeed")
    psLines.Push("        `$sg.DrawImage(`$bmp, 0, 0, `$sw, `$sh)")
    psLines.Push("        `$sg.Dispose()")
    psLines.Push("        `$bmp.Dispose()")
    psLines.Push("        `$bmp = `$scaled")
    psLines.Push("    }")
    psLines.Push("    `$bmp.Save(`$pngFile, [System.Drawing.Imaging.ImageFormat]::Png)")
    psLines.Push("    `$bmp.Dispose()")
    psLines.Push("    `$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync(`$pngFile)) ([Windows.Storage.StorageFile])")
    psLines.Push("    `$stream = Await (`$file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])")
    psLines.Push("    `$decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync(`$stream)) ([Windows.Graphics.Imaging.BitmapDecoder])")
    psLines.Push("    `$bitmap = Await (`$decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])")
    psLines.Push("    `$stream.Dispose()")
    psLines.Push("    if (`$bitmap.BitmapPixelFormat -ne [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8) {")
    psLines.Push("        `$bitmap = [Windows.Graphics.Imaging.SoftwareBitmap]::Convert(")
    psLines.Push("            `$bitmap,")
    psLines.Push("            [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,")
    psLines.Push("            [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied")
    psLines.Push("        )")
    psLines.Push("    }")
    psLines.Push("    `$result = Await (`$engine.RecognizeAsync(`$bitmap)) ([Windows.Media.Ocr.OcrResult])")
    psLines.Push("    try { Remove-Item `$pngFile -Force -ErrorAction SilentlyContinue } catch {}")
    psLines.Push("    return `$result.Text")
    psLines.Push("}")
    psLines.Push("")
    psLines.Push("# Sinaliza ao AHK que o servidor está pronto.")
    psLines.Push("'READY' | Out-File -FilePath `$InitFile -Encoding ASCII -NoNewline")
    psLines.Push("")
    psLines.Push("# Loop principal: aguarda requisições.")
    psLines.Push("while (`$true) {")
    psLines.Push("    if (Test-Path `$KillFile) { break }")
    psLines.Push("    if (Test-Path `$SigFile) {")
    psLines.Push("        try { Remove-Item `$SigFile -Force } catch {}")
    psLines.Push("        try {")
    psLines.Push("            `$lines = [System.IO.File]::ReadAllLines(`$ReqFile, [System.Text.Encoding]::UTF8)")
    psLines.Push("            `$X = [int]`$lines[0]; `$Y = [int]`$lines[1]")
    psLines.Push("            `$W = [int]`$lines[2]; `$H = [int]`$lines[3]")
    psLines.Push("            `$Scale = [int]`$lines[4]")
    psLines.Push("            try { Remove-Item `$ReqFile -Force } catch {}")
    psLines.Push("            `$text = DoOcr `$X `$Y `$W `$H `$Scale")
    psLines.Push("            [System.IO.File]::WriteAllText(`$RespFile, `$text, [System.Text.Encoding]::UTF8)")
    psLines.Push("        } catch {")
    psLines.Push("            [System.IO.File]::WriteAllText(`$RespFile, ('OCR_ERRO: ' + `$_), [System.Text.Encoding]::UTF8)")
    psLines.Push("        }")
    psLines.Push("    }")
    psLines.Push("    Start-Sleep -Milliseconds `$PollMs")
    psLines.Push("}")
    psLines.Push("")
    psLines.Push("try { Remove-Item `$pngFile -Force -ErrorAction SilentlyContinue } catch {}")

    psCode := ""
    for line in psLines
        psCode .= line "`r`n"

    FileAppend psCode, gOcrServerPs1, "UTF-8"
}

OcrWindowText(hwnd, cropMessageArea := true, scaleOverride := "") {
    global OCR_SCALE, OCR_SCALE_RETRY, OCR_LANGUAGE
    global gOcrServerReady

    ocrScale := (scaleOverride = "" ? OCR_SCALE : scaleOverride)

    WinGetPos &x, &y, &w, &h, "ahk_id " hwnd

    if (cropMessageArea) {
        x := x + 4
        y := y + 24
        w := Max(w - 8, 160)
        h := Max(h - 64, 55)
    }

    ; Tenta o servidor persistente primeiro (muito mais rápido: engine já carregado).
    if (gOcrServerReady) {
        try {
            text := OcrViaServer(x, y, w, h, ocrScale)
            return text
        } catch as e {
            LogLine("OCR: servidor falhou (" e.Message "); tentando reiniciar...")
            ; Tenta reiniciar o servidor e fazer uma segunda tentativa.
            try {
                EnsureOcrServer()
                text := OcrViaServer(x, y, w, h, ocrScale)
                return text
            } catch as e2 {
                LogLine("OCR: servidor não pôde ser reiniciado (" e2.Message "); usando PS avulso como fallback.")
            }
        }
    }

    ; Fallback: PS avulso (método original, mais lento).
    ocr := OcrViaPowerShell(x, y, w, h, ocrScale)
    if (Trim(ocr) != "")
        return ocr

    if (OCR_SCALE_RETRY != ocrScale) {
        ocrRetry := OcrViaPowerShell(x, y, w, h, OCR_SCALE_RETRY)
        if (Trim(ocrRetry) != "")
            return ocrRetry
    }

    return ocr
}

EnsureOcrPowerShellScript() {
    ; Nome versionado para não reaproveitar o .ps1 antigo do Temp.
    ps1 := A_Temp "\mv2000i_ocr_window_v14_fast_ptbr_scale.ps1"
    if FileExist(ps1)
        return ps1

    ; AHK v2 não aceita este PowerShell como string multilinha simples em todos os builds.
    ; Por isso o .ps1 é montado linha a linha.
    psLines := []
    psLines.Push("param(")
    psLines.Push("    [int]$X,")
    psLines.Push("    [int]$Y,")
    psLines.Push("    [int]$W,")
    psLines.Push("    [int]$H,")
    psLines.Push("    [string]$Out,")
    psLines.Push("    [string]$Lang = 'pt-BR',")
    psLines.Push("    [int]$Scale = 3")
    psLines.Push(")")
    psLines.Push("")
    psLines.Push("$ErrorActionPreference = 'Stop'")
    psLines.Push("if ($Scale -lt 1) { $Scale = 1 }")
    psLines.Push("if ($Scale -gt 4) { $Scale = 4 }")
    psLines.Push("")
    psLines.Push("Add-Type -AssemblyName System.Drawing")
    psLines.Push("$png = [System.IO.Path]::ChangeExtension($Out, '.png')")
    psLines.Push("")
    psLines.Push("$bmp = New-Object System.Drawing.Bitmap $W, $H")
    psLines.Push("$g = [System.Drawing.Graphics]::FromImage($bmp)")
    psLines.Push("$g.CopyFromScreen($X, $Y, 0, 0, (New-Object System.Drawing.Size $W, $H))")
    psLines.Push("$g.Dispose()")
    psLines.Push("")
    psLines.Push("if ($Scale -gt 1) {")
    psLines.Push("    $scaledW = [Math]::Max(1, $W * $Scale)")
    psLines.Push("    $scaledH = [Math]::Max(1, $H * $Scale)")
    psLines.Push("    $scaled = New-Object System.Drawing.Bitmap $scaledW, $scaledH")
    psLines.Push("    $sg = [System.Drawing.Graphics]::FromImage($scaled)")
    psLines.Push("    $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor")
    psLines.Push("    $sg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighSpeed")
    psLines.Push("    $sg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighSpeed")
    psLines.Push("    $sg.DrawImage($bmp, 0, 0, $scaledW, $scaledH)")
    psLines.Push("    $sg.Dispose()")
    psLines.Push("    $bmp.Dispose()")
    psLines.Push("    $scaled.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)")
    psLines.Push("    $scaled.Dispose()")
    psLines.Push("} else {")
    psLines.Push("    $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)")
    psLines.Push("    $bmp.Dispose()")
    psLines.Push("}")
    psLines.Push("")
    psLines.Push("Add-Type -AssemblyName System.Runtime.WindowsRuntime")
    psLines.Push("")
    psLines.Push("[Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Graphics.Imaging.BitmapAlphaMode, Windows.Graphics.Imaging, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("[Windows.Globalization.Language, Windows.Globalization, ContentType=WindowsRuntime] | Out-Null")
    psLines.Push("")
    psLines.Push("$script:asTaskGeneric = [System.WindowsRuntimeSystemExtensions].GetMethods() |")
    psLines.Push("    Where-Object {")
    psLines.Push("        $_.Name -eq 'AsTask' -and")
    psLines.Push("        $_.IsGenericMethodDefinition -and")
    psLines.Push("        $_.GetParameters().Count -eq 1")
    psLines.Push("    } |")
    psLines.Push("    Select-Object -First 1")
    psLines.Push("")
    psLines.Push("function Await($Operation, [Type]$ResultType) {")
    psLines.Push("    $asTask = $script:asTaskGeneric.MakeGenericMethod($ResultType)")
    psLines.Push("    $task = $asTask.Invoke($null, @($Operation))")
    psLines.Push("    $task.Wait() | Out-Null")
    psLines.Push("    return $task.Result")
    psLines.Push("}")
    psLines.Push("")
    psLines.Push("$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($png)) ([Windows.Storage.StorageFile])")
    psLines.Push("$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])")
    psLines.Push("$decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])")
    psLines.Push("$bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])")
    psLines.Push("")
    psLines.Push("if ($bitmap.BitmapPixelFormat -ne [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8) {")
    psLines.Push("    $bitmap = [Windows.Graphics.Imaging.SoftwareBitmap]::Convert(")
    psLines.Push("        $bitmap,")
    psLines.Push("        [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,")
    psLines.Push("        [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied")
    psLines.Push("    )")
    psLines.Push("}")
    psLines.Push("")
    psLines.Push("$engine = $null")
    psLines.Push("try {")
    psLines.Push("    $language = New-Object Windows.Globalization.Language $Lang")
    psLines.Push("    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)")
    psLines.Push("} catch {")
    psLines.Push("    $engine = $null")
    psLines.Push("}")
    psLines.Push("")
    psLines.Push("if ($null -eq $engine) {")
    psLines.Push("    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()")
    psLines.Push("}")
    psLines.Push("if ($null -eq $engine) {")
    psLines.Push("    throw 'Windows.Media.Ocr indisponível ou idioma OCR não instalado. Tentado: ' + $Lang")
    psLines.Push("}")
    psLines.Push("")
    psLines.Push("$result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])")
    psLines.Push("$result.Text | Out-File -FilePath $Out -Encoding utf8")
    psLines.Push("")
    psLines.Push("try { Remove-Item -Path $png -Force -ErrorAction SilentlyContinue } catch {}")

    psCode := ""
    for line in psLines
        psCode .= line "`r`n"

    FileAppend psCode, ps1, "UTF-8"
    return ps1
}

CloseBackgroundReportsIfAny() {
    ; Janela: "Operação de Fundo dos Relatórios"
    Loop 20 {
        found := false
        try list := WinGetList("Operação de Fundo dos Relatórios")
        catch {
            list := []
        }

        for hwnd in list {
            if IsWindowVisible(hwnd) {
                found := true
                LogLine("Fechando Operação de Fundo dos Relatórios...")
                try WinClose "ahk_id " hwnd
                Sleep Delay.LongClose
            }
        }

        if !found
            return

        Sleep Delay.Short
    }

    ; Se ainda existir, força erro para não avançar com janela aberta.
    if WinExist("Operação de Fundo dos Relatórios")
        throw Error("A janela Operação de Fundo dos Relatórios não fechou.")
}

; ==========================================================
; Log
; ==========================================================

LogLine(msg) {
    global gTxtStatus, LOG_PATH, STATUS_MAX_CHARS

    stamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    line := stamp " - " msg

    try FileAppend line "`r`n", LOG_PATH, "UTF-8"

    try {
        current := gTxtStatus.Value
        nextText := (current = "" ? line : current "`r`n" line)
        if (StrLen(nextText) > STATUS_MAX_CHARS)
            nextText := "... log anterior ocultado na tela; arquivo completo continua em disco ...`r`n" SubStr(nextText, StrLen(nextText) - STATUS_MAX_CHARS + 1)
        gTxtStatus.Value := nextText
        SendMessage 0x115, 7, 0, gTxtStatus.Hwnd ; scroll para baixo
    }
}
