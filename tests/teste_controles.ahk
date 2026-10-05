; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; Praxis - Scanner de Controles Windows
; AHK v2
;
; F8 = escanear janela atualmente ativa
; F9 = escanear janela sob o mouse
; Esc = sair
; ============================================================

F8::ScanActiveWindow()
F9::ScanWindowUnderMouse()
Esc::ExitApp()


; ============================================================
; ESCANEAR JANELA ATIVA
; ============================================================

ScanActiveWindow() {
    hwnd := WinExist("A")

    if !hwnd {
        MsgBox("Nenhuma janela ativa encontrada.")
        return
    }

    ScanWindow(hwnd)
}


; ============================================================
; ESCANEAR JANELA SOB O MOUSE
; ============================================================

ScanWindowUnderMouse() {
    MouseGetPos(, , &hwnd)

    if !hwnd {
        MsgBox("Não foi possível identificar a janela.")
        return
    }

    ScanWindow(hwnd)
}


; ============================================================
; SCANNER PRINCIPAL
; ============================================================

ScanWindow(hwnd) {

    try {
        title := WinGetTitle("ahk_id " hwnd)
        process := WinGetProcessName("ahk_id " hwnd)
        class := WinGetClass("ahk_id " hwnd)

        result := ""
        result .= "============================================`n"
        result .= "JANELA`n"
        result .= "============================================`n"
        result .= "Título : " title "`n"
        result .= "Classe : " class "`n"
        result .= "HWND   : " Format("0x{:X}", hwnd) "`n"
        result .= "Processo: " process "`n"
        result .= "`n"

        ; ----------------------------------------------------
        ; Janela principal
        ; ----------------------------------------------------

        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)

            result .= "POSIÇÃO DA JANELA`n"
            result .= "X=" wx " Y=" wy
            result .= " W=" ww " H=" wh "`n`n"
        }

        ; ----------------------------------------------------
        ; Controles
        ; ----------------------------------------------------

        controls := WinGetControls("ahk_id " hwnd)

        result .= "============================================`n"
        result .= "CONTROLES ENCONTRADOS: " controls.Length "`n"
        result .= "============================================`n`n"

        for index, control in controls {

            try {
                cHwnd := ControlGetHwnd(control, "ahk_id " hwnd)
            } catch {
                cHwnd := 0
            }

            try {
                cClass := ControlGetClassNN(control, "ahk_id " hwnd)
            } catch {
                cClass := "?"
            }

            try {
                cText := ControlGetText(control, "ahk_id " hwnd)
            } catch {
                cText := ""
            }

            try {
                ControlGetPos(&cx, &cy, &cw, &ch, control, "ahk_id " hwnd)
            } catch {
                cx := cy := cw := ch := "?"
            }

            ; ------------------------------------------------
            ; ID do controle
            ; ------------------------------------------------

            controlId := ""

            try {
                controlId := ControlGetClassNN(control, "ahk_id " hwnd)
            } catch {
                controlId := ""
            }

            result .= "[" index "]`n"
            result .= "  Controle : " control "`n"
            result .= "  Classe   : " cClass "`n"
            result .= "  HWND     : " (cHwnd ? Format("0x{:X}", cHwnd) : "?") "`n"
            result .= "  Texto    : " cText "`n"
            result .= "  Posição  : X=" cx " Y=" cy "`n"
            result .= "  Tamanho  : W=" cw " H=" ch "`n"
            result .= "`n"
        }

        ShowResult(result)

    } catch Error as e {
        MsgBox(
            "Erro ao escanear janela:`n`n"
            e.Message
        )
    }
}


; ============================================================
; MOSTRAR RESULTADO
; ============================================================

ShowResult(text) {

    g := Gui("+Resize", "Praxis - Scanner de Controles")
    g.SetFont("s10", "Consolas")

    edit := g.AddEdit(
        "x10 y10 w1000 h650 +Multi +ReadOnly +HScroll +VScroll",
        text
    )

    g.AddButton(
        "x10 y670 w120 h30",
        "Copiar"
    ).OnEvent("Click", (*) => A_Clipboard := text)

    g.AddButton(
        "x140 y670 w120 h30",
        "Fechar"
    ).OnEvent("Click", (*) => g.Destroy())

    g.OnEvent("Close", (*) => g.Destroy())
    g.Show("w1020 h720")
}