#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; MV TEXT SCANNER - Win32 + UI Automation (UIA-v2)
;
; Requisitos:
;   - AutoHotkey v2
;   - UIA-v2 da Descolada
;
; Estrutura recomendada:
;   MV_Text_Scanner_Win32_UIA.ahk
;   Lib\UIA.ahk
;
; Teclas:
;   F8  = escanear janela ativa (Win32 + UIA)
;   F9  = escanear ponto sob o mouse (Win32 + UIA)
;   F10 = listar todas as janelas (Win32)
;   F11 = escanear somente UIA da janela ativa
;   F12 = monitorar novas janelas por 5 segundos
;   Esc = sair
;
; Observação:
;   Este scanner NÃO usa OCR. A intenção é descobrir o que o MV
;   realmente expõe como texto antes de partir para OCR.
; ============================================================

#Include %A_ScriptDir%\Lib\UIA.ahk

SetTitleMatchMode(2)

F8::ScanActiveWindow()
F9::ScanPointUnderMouse()
F10::ScanAllWindows()
F11::ScanActiveUIA()
F12::MonitorNewWindows(5000)
Esc::ExitApp()


; ============================================================
; F8 - JANELA ATIVA: WIN32 + UIA
; ============================================================

ScanActiveWindow() {
    hwnd := WinExist("A")

    if !hwnd {
        MsgBox("Nenhuma janela ativa encontrada.")
        return
    }

    result := "MV TEXT SCANNER - JANELA ATIVA`n"
    result .= "Data/Hora: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
    result .= "`n"
    result .= WindowHeader(hwnd)
    result .= "`n"
    result .= ScanWindowWin32(hwnd)
    result .= "`n"
    result .= ScanWindowUIA(hwnd, 10)

    ShowResult(result)
}


; ============================================================
; F9 - ELEMENTO SOB O MOUSE
; ============================================================

ScanPointUnderMouse() {
    MouseGetPos(&mx, &my, &winHwnd, &control)

    result := "MV TEXT SCANNER - PONTO SOB O MOUSE`n"
    result .= "Data/Hora: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
    result .= "Mouse: X=" mx " Y=" my "`n"
    result .= "`n"

    if winHwnd {
        result .= "JANELA WIN32 SOB O MOUSE`n"
        result .= WindowHeader(winHwnd)
        result .= "Controle retornado pelo MouseGetPos: " (control ?? "[nenhum]") "`n"
        result .= "`n"

        result .= "--- Win32 do ponto/janela ---`n"
        try {
            pointText := WinGetText("ahk_id " winHwnd)
            result .= pointText ? pointText "`n" : "[WinGetText vazio]`n"
        } catch Error as e {
            result .= "[WinGetText erro] " e.Message "`n"
        }
    } else {
        result .= "Nenhuma janela Win32 encontrada nesse ponto.`n"
    }

    result .= "`n--- UIA.ElementFromPoint() ---`n"

    try {
        el := UIA.ElementFromPoint(mx, my, , 0)
        result .= DescribeUIAElement(el, true)
        result .= "`n"

        result .= "UIA.Dump() do elemento:`n"
        try result .= el.Dump(" | ", 2) "`n"
        catch Error as e
            result .= "[Dump erro] " e.Message "`n"

        result .= "`n--- UIA TextPattern / texto ---`n"
        result .= ReadUIAText(el)
    } catch Error as e {
        result .= "[ElementFromPoint erro] " e.Message "`n"
    }

    result .= "`n--- UIA.SmallestElementFromPoint() ---`n"

    try {
        smallest := UIA.SmallestElementFromPoint(mx, my)
        result .= DescribeUIAElement(smallest, true)
        result .= "`n"
        result .= ReadUIAText(smallest)
    } catch Error as e {
        result .= "[SmallestElementFromPoint erro] " e.Message "`n"
    }

    ShowResult(result)
}


; ============================================================
; F10 - TODAS AS JANELAS (WIN32)
; ============================================================

ScanAllWindows() {
    windows := WinGetList()

    result := "MV TEXT SCANNER - TODAS AS JANELAS`n"
    result .= "Data/Hora: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n"
    result .= "Janelas encontradas: " windows.Length "`n`n"

    for index, hwnd in windows {
        result .= "====================================================`n"
        result .= "JANELA #" index "`n"
        result .= WindowHeader(hwnd)

        try {
            text := WinGetText("ahk_id " hwnd)
            result .= "WinGetText:`n"
            result .= text ? text "`n" : "[VAZIO]`n"
        } catch Error as e {
            result .= "WinGetText: [ERRO] " e.Message "`n"
        }

        result .= "`n"
    }

    ShowResult(result)
}


; ============================================================
; F11 - SOMENTE UIA DA JANELA ATIVA
; ============================================================

ScanActiveUIA() {
    hwnd := WinExist("A")

    if !hwnd {
        MsgBox("Nenhuma janela ativa encontrada.")
        return
    }

    result := "MV TEXT SCANNER - UIA DA JANELA ATIVA`n"
    result .= "Data/Hora: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n`n"
    result .= WindowHeader(hwnd)
    result .= "`n"
    result .= ScanWindowUIA(hwnd, 12)

    ShowResult(result)
}


; ============================================================
; F12 - MONITORAR NOVAS JANELAS
; Útil para popup de erro que aparece e desaparece rapidamente.
; ============================================================

MonitorNewWindows(durationMs := 5000) {
    known := Map()
    start := A_TickCount
    result := "MV TEXT SCANNER - MONITOR DE NOVAS JANELAS`n"
    result .= "Duração: " durationMs " ms`n"
    result .= "`n"

    for hwnd in WinGetList()
        known[hwnd] := true

    while (A_TickCount - start < durationMs) {
        for hwnd in WinGetList() {
            if known.Has(hwnd)
                continue

            known[hwnd] := true

            result .= "====================================================`n"
            result .= "NOVA JANELA DETECTADA`n"
            result .= "Momento: " FormatTime(, "HH:mm:ss") " +" Mod(A_TickCount, 1000) " ms`n"
            result .= WindowHeader(hwnd)

            try {
                text := WinGetText("ahk_id " hwnd)
                result .= "WinGetText:`n"
                result .= text ? text "`n" : "[VAZIO]`n"
            } catch Error as e {
                result .= "WinGetText: [ERRO] " e.Message "`n"
            }

            result .= "`n--- UIA da nova janela ---`n"
            result .= ScanWindowUIA(hwnd, 8)
            result .= "`n"
        }

        Sleep(30)
    }

    if !InStr(result, "NOVA JANELA DETECTADA")
        result .= "Nenhuma nova janela foi detectada no período.`n"

    ShowResult(result)
}


; ============================================================
; WIN32 - CABEÇALHO DA JANELA
; ============================================================

WindowHeader(hwnd) {
    try title := WinGetTitle("ahk_id " hwnd)
    catch
        title := "?"

    try class := WinGetClass("ahk_id " hwnd)
    catch
        class := "?"

    try process := WinGetProcessName("ahk_id " hwnd)
    catch
        process := "?"

    try pid := WinGetPID("ahk_id " hwnd)
    catch
        pid := "?"

    return "Título   : [" title "]`n"
        . "Classe   : [" class "]`n"
        . "Processo : [" process "]`n"
        . "PID      : [" pid "]`n"
        . "HWND     : " Format("0x{:X}", hwnd) "`n"
}


; ============================================================
; WIN32 - CONTROLES + TEXTO
; ============================================================

ScanWindowWin32(hwnd) {
    result := "====================================================`n"
    result .= "WIN32 / AHK`n"
    result .= "====================================================`n"

    ; --------------------------------------------------------
    ; WinGetText
    ; --------------------------------------------------------

    result .= "--- Método 1: WinGetText() ---`n"

    try {
        windowText := WinGetText("ahk_id " hwnd)
        result .= windowText ? windowText "`n" : "[NENHUM TEXTO]`n"
    } catch Error as e {
        result .= "[ERRO] " e.Message "`n"
    }

    result .= "`n"

    ; --------------------------------------------------------
    ; WinGetControls / ControlGetText / ControlGetChoice
    ; --------------------------------------------------------

    try controls := WinGetControls("ahk_id " hwnd)
    catch Error as e {
        result .= "WinGetControls: [ERRO] " e.Message "`n"
        return result
    }

    result .= "--- Método 2: controles Win32 ---`n"
    result .= "Controles encontrados: " controls.Length "`n`n"

    for index, control in controls {
        result .= "[Controle #" index "]`n"
        result .= "Control NN : " control "`n"

        try {
            cHwnd := ControlGetHwnd(control, "ahk_id " hwnd)
            result .= "HWND       : " Format("0x{:X}", cHwnd) "`n"
        } catch {
            cHwnd := 0
            result .= "HWND       : [não obtido]`n"
        }

        try cClass := ControlGetClassNN(control, "ahk_id " hwnd)
        catch
            cClass := "?"
        result .= "Classe     : " cClass "`n"

        try {
            cText := ""
            cText := ControlGetText(control, "ahk_id " hwnd)
            result .= "Texto      : " (cText != "" ? "[" cText "]" : "[VAZIO]") "`n"
        } catch Error as e {
            result .= "Texto      : [ERRO] " e.Message "`n"
        }

        try {
            choice := ControlGetChoice(control, "ahk_id " hwnd)
            result .= "Choice     : " (choice != "" ? "[" choice "]" : "[VAZIO]") "`n"
        } catch {
            result .= "Choice     : [não suportado/erro]`n"
        }

        try {
            ControlGetPos(&x, &y, &w, &h, control, "ahk_id " hwnd)
            result .= "Posição    : X=" x " Y=" y " W=" w " H=" h "`n"
        } catch {
            result .= "Posição    : [não obtida]`n"
        }

        if cHwnd {
            try {
                hwndText := ControlGetText("ahk_id " cHwnd)
                if hwndText != cText
                    result .= "Texto HWND : [" hwndText "]`n"
            } catch {
                ; Não suportado para alguns controles.
            }
        }

        result .= "`n"
    }

    return result
}


; ============================================================
; UIA - JANELA INTEIRA
; ============================================================

ScanWindowUIA(hwnd, maxDepth := 10) {
    result := "====================================================`n"
    result .= "UI AUTOMATION / UIA-v2`n"
    result .= "====================================================`n"

    result .= "--- ElementFromHandle() ---`n"

    try {
        ; 0 no terceiro argumento evita tentativa de ativação de
        ; acessibilidade específica de Chromium, que não interessa ao MV.
        root := UIA.ElementFromHandle(hwnd, , 0)
        result .= DescribeUIAElement(root, false)
    } catch Error as e {
        return result "[ElementFromHandle ERRO] " e.Message "`n"
    }

    result .= "`n--- Texto diretamente no elemento raiz/padrões ---`n"
    result .= ReadUIAText(root)

    result .= "`n--- DumpAll() UIA ---`n"
    result .= "Profundidade máxima: " maxDepth "`n"

    try {
        dump := root.DumpAll(" | ", maxDepth)
        result .= dump ? dump "`n" : "[DumpAll vazio]`n"
    } catch Error as e {
        result .= "[DumpAll ERRO] " e.Message "`n"
    }

    result .= "`n--- Elementos de texto encontrados via UIA ---`n"
    result .= ScanUIATextElements(root)

    return result
}


; ============================================================
; UIA - ELEMENTOS DE TEXTO
; ============================================================

ScanUIATextElements(root) {
    result := ""
    seen := Map()
    total := 0

    ; Tipos que podem carregar texto diretamente ou apresentar texto
    ; por Value/TextPattern.
    types := [UIA.Type.Text, UIA.Type.Edit, UIA.Type.Document]

    for typeId in types {
        try elements := root.FindElements({Type:typeId}, UIA.TreeScope.Descendants)
        catch {
            continue
        }

        for element in elements {
            ; RuntimeId é uma boa forma de evitar duplicação entre buscas.
            key := ""
            try key := RuntimeIdKey(element.RuntimeId)
            catch {
                key := ""
                    . element.CachedType "|"
                    . SafeUIAValue(element, "CachedName") "|"
                    . SafeUIAValue(element, "CachedValue")
            }

            if seen.Has(key)
                continue

            seen[key] := true
            total++

            result .= "----------------------------------------------------`n"
            result .= "Elemento de texto #" total "`n"
            result .= DescribeUIAElement(element, true)
            result .= ReadUIAText(element)
            result .= "`n"
        }
    }

    if !total
        result .= "Nenhum elemento Text/Edit/Document localizado por UIA.`n"

    return result
}


; ============================================================
; UIA - DESCRIÇÃO DO ELEMENTO
; ============================================================

DescribeUIAElement(element, includeCurrent := true) {
    result := ""

    try {
        typeId := element.CachedType
        typeName := UIA.Type[typeId]
    } catch {
        try {
            typeId := element.Type
            typeName := UIA.Type[typeId]
        } catch {
            typeId := "?"
            typeName := "?"
        }
    }

    result .= "Type          : " typeId " (" typeName ")`n"
    result .= "Name          : " UIAGet(element, "Name", "[VAZIO]") "`n"
    result .= "Value         : " UIAGet(element, "Value", "[VAZIO]") "`n"
    result .= "AutomationId  : " UIAGet(element, "AutomationId", "[VAZIO]") "`n"
    result .= "ClassName     : " UIAGet(element, "ClassName", "[VAZIO]") "`n"
    result .= "FrameworkId   : " UIAGet(element, "FrameworkId", "[VAZIO]") "`n"
    result .= "IsOffscreen   : " UIAGet(element, "IsOffscreen", "?") "`n"
    result .= "ControlElement: " UIAGet(element, "IsControlElement", "?") "`n"
    result .= "ContentElement: " UIAGet(element, "IsContentElement", "?") "`n"
    result .= "TextPattern?  : " UIAGet(element, "IsTextPatternAvailable", "?") "`n"
    result .= "LegacyIA?     : " UIAGet(element, "IsLegacyIAccessiblePatternAvailable", "?") "`n"

    try {
        br := element.BoundingRectangle
        result .= "Rect          : X=" br.l " Y=" br.t
            . " W=" (br.r - br.l) " H=" (br.b - br.t) "`n"
    } catch {
        try {
            br := element.CachedBoundingRectangle
            result .= "Rect(cache)   : X=" br.l " Y=" br.t
                . " W=" (br.r - br.l) " H=" (br.b - br.t) "`n"
        } catch {
            result .= "Rect          : [não obtido]`n"
        }
    }

    try {
        nativeHwnd := element.NativeWindowHandle
        result .= "Native HWND   : " (nativeHwnd ? Format("0x{:X}", nativeHwnd) : "0") "`n"
    } catch {
        try {
            nativeHwnd := element.CachedNativeWindowHandle
            result .= "Native HWND(c): " (nativeHwnd ? Format("0x{:X}", nativeHwnd) : "0") "`n"
        } catch {
            result .= "Native HWND   : [não obtido]`n"
        }
    }

    if includeCurrent {
        result .= "CurrentName   : " UIAGetCurrent(element, "Name", "[erro/vazio]") "`n"
        result .= "CurrentValue  : " UIAGetCurrent(element, "Value", "[erro/vazio]") "`n"
    }

    return result
}


; ============================================================
; UIA - VÁRIAS FONTES DE TEXTO
; ============================================================

ReadUIAText(element) {
    result := ""

    result .= "Name            : " UIAGetCurrent(element, "Name", "[VAZIO]") "`n"
    result .= "Value           : " UIAGetCurrent(element, "Value", "[VAZIO]") "`n"
    result .= "Legacy Name     : " UIAGetCurrent(element, "LegacyIAccessibleName", "[VAZIO]") "`n"
    result .= "Legacy Value    : " UIAGetCurrent(element, "LegacyIAccessibleValue", "[VAZIO]") "`n"

    ; TextPattern é a camada mais importante para testar texto
    ; renderizado/exposto pela acessibilidade.
    try {
        pattern := element.TextPattern
        range := pattern.DocumentRange
        text := range.GetText(4096)
        result .= "TextPattern     : " (text != "" ? "[" text "]" : "[VAZIO]") "`n"
    } catch Error as e {
        result .= "TextPattern     : [não disponível]"
        result .= " (" e.Message ")`n"
    }

    ; LegacyIAccessible também pode expor texto que Value/Name não mostram.
    try {
        legacy := element.LegacyIAccessiblePattern
        result .= "Legacy Pattern  : disponível`n"
        result .= "  Name          : " SafePatternProperty(legacy, "Name") "`n"
        result .= "  Value         : " SafePatternProperty(legacy, "Value") "`n"
        result .= "  Description   : " SafePatternProperty(legacy, "Description") "`n"
        result .= "  Role          : " SafePatternProperty(legacy, "Role") "`n"
        result .= "  State         : " SafePatternProperty(legacy, "State") "`n"
    } catch {
        result .= "Legacy Pattern  : [não disponível]`n"
    }

    return result
}


; ============================================================
; HELPERS UIA
; ============================================================

UIAGet(element, property, defaultValue := "") {
    try {
        value := element.%property%
        return value != "" ? value : defaultValue
    } catch {
        return defaultValue
    }
}

UIAGetCurrent(element, property, defaultValue := "") {
    try {
        value := element.%"Current" property%
        return value != "" ? value : defaultValue
    } catch {
        try {
            value := element.%property%
            return value != "" ? value : defaultValue
        } catch {
            return defaultValue
        }
    }
}

SafeUIAValue(element, property) {
    try {
        return String(element.%property%)
    } catch {
        return ""
    }
}

SafePatternProperty(pattern, property) {
    try {
        value := pattern.%property%
        return value != "" ? String(value) : "[VAZIO]"
    } catch {
        return "[não disponível]"
    }
}

RuntimeIdKey(runtimeId) {
    out := ""

    if !IsObject(runtimeId)
        return String(runtimeId)

    for value in runtimeId
        out .= value ":"

    return out
}


; ============================================================
; GUI DE RESULTADO
; ============================================================

ShowResult(text) {
    g := Gui("+Resize", "MV Text Scanner - Win32 + UIA")
    g.SetFont("s10", "Consolas")

    edit := g.AddEdit(
        "x10 y10 w1180 h720 +Multi +ReadOnly +HScroll +VScroll",
        text
    )

    copyButton := g.AddButton(
        "x10 y740 w120 h32",
        "Copiar"
    )

    copyButton.OnEvent(
        "Click",
        (*) => A_Clipboard := text
    )

    saveButton := g.AddButton(
        "x140 y740 w120 h32",
        "Salvar"
    )

    saveButton.OnEvent(
        "Click",
        (*) => SaveResult(text)
    )

    closeButton := g.AddButton(
        "x270 y740 w120 h32",
        "Fechar"
    )

    closeButton.OnEvent(
        "Click",
        (*) => g.Destroy()
    )

    g.OnEvent("Close", (*) => g.Destroy())

    g.Show("w1200 h790")
}


; ============================================================
; SALVAR RESULTADO
; ============================================================

SaveResult(text) {
    path := A_ScriptDir "\scanner_resultado_"
        . FormatTime(, "yyyyMMdd_HHmmss") ".txt"

    try {
        FileAppend(text, path, "UTF-8")
        MsgBox("Resultado salvo em:`n`n" path, "MV Text Scanner")
    } catch Error as e {
        MsgBox("Falha ao salvar:`n`n" e.Message, "MV Text Scanner")
    }
}
