#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("Pixel", "Client")
CoordMode("Mouse", "Client")

; ===== CONFIG =====
AREA := {x1: 430, y1: 280, x2: 650, y2: 315}   ; cola aqui saída do AreaPicker
STEP := 5
TEST_KEY := "{F8}"     ; "" = você age manualmente; senão Send dessa tecla
TIMEOUT := 5000
STABLE_MS := 300
POLL_MS := 30
; ==================

ScreenSignature(x1, y1, x2, y2, step := 10) {
    sig := ""
    y := y1
    while y <= y2 {
        x := x1
        while x <= x2 {
            sig .= PixelGetColor(x, y) "|"
            x += step
        }
        y += step
    }
    return sig
}

WaitForChange(oldSig, x1, y1, x2, y2, step := 10, timeout := 5000, poll := 30) {
    startedAt := A_TickCount
    while (A_TickCount - startedAt) < timeout {
        if ScreenSignature(x1, y1, x2, y2, step) != oldSig
            return true
        Sleep(poll)   ; só frequência de checagem
    }
    return false
}

WaitForStable(x1, y1, x2, y2, step := 10, stableMs := 300, timeout := 5000, poll := 30) {
    startedAt := A_TickCount
    prev := ScreenSignature(x1, y1, x2, y2, step)
    since := A_TickCount
    while (A_TickCount - startedAt) < timeout {
        Sleep(poll)
        cur := ScreenSignature(x1, y1, x2, y2, step)
        if cur != prev {
            prev := cur
            since := A_TickCount
        } else if A_TickCount - since >= stableMs
            return true
    }
    return false
}

; F3 = teste completo: captura ANTES -> ação -> espera mudar -> espera estabilizar
F3:: {
    t0 := A_TickCount
    old := ScreenSignature(AREA.x1, AREA.y1, AREA.x2, AREA.y2, STEP)  ; antes da ação

    if TEST_KEY != ""
        Send(TEST_KEY)
    else
        ToolTip("Assinatura capturada. Faça a ação agora...")

    if !WaitForChange(old, AREA.x1, AREA.y1, AREA.x2, AREA.y2, STEP, TIMEOUT, POLL_MS) {
        ToolTip("FALHOU: área não mudou (" (A_TickCount - t0) " ms)")
        SetTimer(() => ToolTip(), -4000)
        return
    }
    tChange := A_TickCount - t0

    ok := WaitForStable(AREA.x1, AREA.y1, AREA.x2, AREA.y2, STEP, STABLE_MS, TIMEOUT, POLL_MS)
    tTotal := A_TickCount - t0

    ToolTip((ok ? "OK" : "NÃO estabilizou") "`n"
          . "Mudou em: " tChange " ms`n"
          . "Total: " tTotal " ms")
    SetTimer(() => ToolTip(), -5000)
}

; F4 = só estabilidade (sem ação)
F4:: {
    t0 := A_TickCount
    ok := WaitForStable(AREA.x1, AREA.y1, AREA.x2, AREA.y2, STEP, STABLE_MS, TIMEOUT, POLL_MS)
    ToolTip((ok ? "Estável" : "Timeout") " em " (A_TickCount - t0) " ms")
    SetTimer(() => ToolTip(), -4000)
}

; F5 = mostra custo de uma leitura da assinatura
F5:: {
    t0 := A_TickCount
    s := ScreenSignature(AREA.x1, AREA.y1, AREA.x2, AREA.y2, STEP)
    ToolTip("1 leitura: " (A_TickCount - t0) " ms`nPixels: " StrSplit(s, "|").Length - 1)
    SetTimer(() => ToolTip(), -4000)
}