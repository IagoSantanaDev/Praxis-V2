#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode("Mouse", "Client")
CoordMode("ToolTip", "Screen")

; F2 = marca canto (1º: sup-esq, 2º: inf-dir). Esc = cancela.
; Sem clique -> não dispara nada no MV.

global p1 := 0, picking := false

F2:: {
    global p1, picking
    MouseGetPos(&x, &y)

    if !picking {
        p1 := {x: x, y: y}
        picking := true
        SetTimer(LiveTip, 30)
        return
    }

    SetTimer(LiveTip, 0)
    picking := false
    x1 := Min(p1.x, x), y1 := Min(p1.y, y)
    x2 := Max(p1.x, x), y2 := Max(p1.y, y)

    txt := x1 ", " y1 ", " x2 ", " y2
    A_Clipboard := txt
    ToolTip("Copiado: " txt "`nLargura=" (x2 - x1) "  Altura=" (y2 - y1))
    SetTimer(() => ToolTip(), -5000)
}

#HotIf picking
Esc:: {
    global picking
    SetTimer(LiveTip, 0)
    picking := false
    ToolTip()
}
#HotIf

LiveTip() {
    global p1
    MouseGetPos(&x, &y)
    ToolTip("Canto 1: " p1.x ", " p1.y "`n"
          . "Atual:   " x ", " y "`n"
          . "L=" Abs(x - p1.x) "  A=" Abs(y - p1.y) "`n"
          . "F2 = fixar | Esc = cancelar")
}