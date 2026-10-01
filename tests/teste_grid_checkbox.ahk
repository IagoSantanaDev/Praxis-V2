; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Include lib\teste_lib.ahk

; ════════════════════════════════════════════════════════════════
;  LEITURA CRUA DOS CHECKBOXES DA GRID — MV2000i real
; ════════════════════════════════════════════════════════════════
;
;  Responde UMA pergunta: o que o AHK v2 devolve de cada checkbox
;  Button9..Button2 da tela de Protocolação de Baixa de Documentos.
;
;  Não pergunta, e não deduz, quais linhas têm conta. Essa correlação é
;  do operador, olhando a tela. O relatório entrega o que o AHK leu —
;  valor, tipo, visibilidade, posição — para a correlação ser feita na
;  tela, sem o script virar outra fonte de suposição.
;
;  Tudo aqui é LEITURA: ControlGetChecked, ControlGetVisible,
;  ControlGetEnabled, ControlGetText, ControlGetPos. Nenhum clique,
;  nenhuma tecla enviada ao MV, nenhum F8/F10. Pode rodar com o
;  operador na frente do console.
;
;  Uso:
;    1. No MOV DOC, abra a Protocolação de Baixa e consulte um protocolo
;       para a grid vir preenchida.
;    2. AutoHotkey64.exe teste_grid_checkbox.ahk
;    3. Clique na grid do MV, para a tela de baixa ficar com foco.
;    4. F3 — lê os 8 checkboxes e abre a janela com o resultado.
;       Pode repetir F3 quantas vezes quiser, em protocols diferentes.
;    5. F4 — sai.
;
;  Emergência: F4 sai; o botão "Fechar" da janela também.

; A grid só tem checkbox visível depois do F8 na tela de baixa. Se o script
; acordar antes disso, o relatório mostra ClassNN ausente — que é a resposta
; correta para "a grid não está desenhada", e não um erro do script.

F3::Grid_Analisar
F4::ExitApp

; ════════════════════════════════════════════════════════════════
;  JANELA DE FOCO → QUAL JANELA FOI LIDA
; ════════════════════════════════════════════════════════════════
;
;  WinExist("A") devolve a janela ativa, que na tela de baixa do MV é o
;  child MDI — o mesmo título que o fluxo validado usa para CLICAR
;  (TESTE_WIN_MOVDOC_BAIXA). Ler por "A" e não por título evita o
;  problema do título entre colchetes na raiz MDI, em que SetTitleMatchMode 2
;  resolve o child para a raiz e devolve hwnd cujo título já não casa.
;
;  Se a janela ativa for o relatório deste próprio script, não há o que ler:
;  o relatório informa isso e devolve, em vez de mostrar 8 linhas vazias sem
;  explicação. Fonte do contrato: mv_session.ahk L27 e L33.

Grid_ReportGui := ""

Grid_JanelaFoco() {
    return WinExist("A")
}

Grid_EraRelatorio(hwnd) {
    global Grid_ReportGui
    return IsObject(Grid_ReportGui) && Grid_ReportGui.Hwnd = hwnd
}

Grid_Titulo(hwnd) {
    try titulo := WinGetTitle("ahk_id " hwnd)
    catch
        titulo := "?"
    try classe := WinGetClass("ahk_id " hwnd)
    catch
        classe := "?"
    return classe " | " titulo
}

; ════════════════════════════════════════════════════════════════
;  COLETA
; ════════════════════════════════════════════════════════════════

Grid_Coletar(hwndFoco) {
    ; Uma entrada por (linha, coluna), como o fluxo validado monta:
    ; remessa_protocolo.ahk L442-L538. A diferença é que aqui nada é
    ; clicado e nenhuma linha é descartada — inclusive a que vier vazia,
    ; porque a pergunta é o que o AHK leu, não se a linha tem conta.
    achados := []

    ; Itera o array de linhas, como o fluxo validado faz em
    ; remessa_protocolo.ahk L482. Nada de "for i in 1..4": colado, o v2 lê
    ; 1..4 como o Float 1.4 e com espaço o ".." nem é range — erro em tempo de
    ; execução nos dois casos.
    for linha, yEsperado in TESTE_GRID_ROWS_Y {
        achados.Push(Map(
            "linha", linha,
            "coluna", "Devolvido",
            "classNN", TESTE_CHECK_DEVOLVIDO_CLASSES[linha],
            "controles", TESTE_InspecionarCheckbox(hwndFoco, TESTE_CHECK_DEVOLVIDO_CLASSES[linha]),
            "yEsperado", yEsperado
        ))
    }

    for linha, yEsperado in TESTE_GRID_ROWS_Y {
        achados.Push(Map(
            "linha", linha,
            "coluna", "Recebido",
            "classNN", TESTE_CHECK_RECEBIDO_CLASSES[linha],
            "controles", TESTE_InspecionarCheckbox(hwndFoco, TESTE_CHECK_RECEBIDO_CLASSES[linha]),
            "yEsperado", yEsperado
        ))
    }

    return achados
}

; O que o AHK v2 devolve para um checkbox:
;   0  -> Integer, desmarcado
;   1  -> Integer, marcado
;  -1  -> Integer, indeterminado (BS_3STATE). O fluxo validado REJEITA este
;         valor em RP_EstadoCheckboxValido (remessa_protocolo.ahk L1120) e trata
;         como erro fatal; aqui é só reportado.
;   "" -> ClassNN não existe na janela lida. Equivale a "não achei o controle",
;         e é diferente de 0.
; O texto do controle também entra: no Window Spy o checkbox de linha vazia é
; o que diferencia "desmarcado" de "linha sem conta" sem ler a conta.
Grid_Descrever(entrada) {
    controles := entrada["controles"]

    if (controles.Length = 0)
        return "ClassNN ausente nesta janela (distinto de 0 = desmarcado)"

    partes := []
    for reg in controles {
        texto := (reg["texto"] = "" ? "(vazio)" : reg["texto"])
        descricao := "valor=" reg["valor"] " (Tipo " reg["tipo"] ")"
        descricao .= ", visível=" reg["visivel"] ", habilitado=" reg["habilitado"]
        descricao .= ", pos=" reg["pos"] ", texto=" texto
        partes.Push(descricao)
    }

    return TESTE_Juntar(partes, " || ")
}

Grid_Contagem(achados) {
    presentes := 0
    marcados := 0
    for entrada in achados {
        for reg in entrada["controles"] {
            presentes += 1
            if (reg["valor"] = 1)
                marcados += 1
        }
    }
    return Map("presentes", presentes, "marcados", marcados, "esperados", achados.Length)
}

; ════════════════════════════════════════════════════════════════
;  RELATÓRIO
; ════════════════════════════════════════════════════════════════

Grid_Mostrar(achados, tituloLido) {
    global Grid_ReportGui

    ; F3 repetido não empilha relatório: o anterior é destruído antes do novo.
    if IsObject(Grid_ReportGui) {
        try Grid_ReportGui.Destroy()
    }

    contagem := Grid_Contagem(achados)
    cabecalho := "Leitura de " A_Now " | janela: " tituloLido
    cabecalho .= "`nClassNN presentes: " contagem["presentes"] " de " contagem["esperados"]
    cabecalho .= " | marcados (valor=1): " contagem["marcados"]
    cabecalho .= "`npos é x,y,w,h em coordenada CLIENT; o Y esperado é a linha da grid."

    corpo := ""
    for entrada in achados {
        corpo .= entrada["linha"] ". " entrada["coluna"] " (" entrada["classNN"] ")"
        corpo .= "  y esperado=" entrada["yEsperado"]
        corpo .= "  ->  " Grid_Descrever(entrada) "`r`n`r`n"
    }

    TESTE_Log("=== F3 em " A_Now " ===")
    TESTE_Log(cabecalho)
    TESTE_Log(corpo)

    ; Text para copiar e colar num relato. A janela só mostra; este é o
    ; entregável que o operador leva para o terminal.
    A_Clipboard := cabecalho "`r`n`r`n" corpo

    g := Gui("+E0x08000000", "Grid Button9..2 — " tituloLido)
    g.MarginX := 12
    g.MarginY := 12

    txt := g.Add("Text", , cabecalho)
    ; SetFont quer opção no formato do AHK: "s9" é tamanho 9. Bare "9" é
    ; recusado com "Invalid option" em tempo de execução.
    txt.SetFont("s9")

    edit := g.Add("Edit", "r22 w760 ReadOnly", corpo)
    edit.SetFont("s9", "Consolas")

    barra := g.Add("Text", "w760", "Colado na área de transferência. F3 de novo lê outra tela; F4 sai.")
    barra.SetFont("s9")

    btns := g.Add("Button", "w120", "Copiar de novo")
    btns.OnEvent("Click", (*) => A_Clipboard := cabecalho "`r`n`r`n" corpo)

    btnFechar := g.Add("Button", "w120", "Fechar")
    btnFechar.OnEvent("Click", (*) => ExitApp())

    g.OnEvent("Close", (*) => ExitApp())
    g.Show()

    Grid_ReportGui := g
}

; ════════════════════════════════════════════════════════════════
;  F3
; ════════════════════════════════════════════════════════════════

Grid_Analisar() {
    hwndFoco := Grid_JanelaFoco()

    ; O relatório tem foco. A tela de baixa não é a janela ativa, então ler
    ; agora devolveria 8 ClassNN ausentes sem explicar por quê. Dizer é melhor
    ; que mostrar resultado vazio.
    if Grid_EraRelatorio(hwndFoco) {
        MsgBox("A janela do relatório está em foco.`n"
            . "Clique na tela do MV2000i e aperte F3 de novo.`n`n"
            . "Este script lê a janela que estiver com o FOCO — ele não sabe "
            . "qual das linhas tem conta, e não adivinha qual é a tela de baixa.")
        return
    }

    if !hwndFoco {
        MsgBox("Nenhuma janela com foco para ler.")
        return
    }

    Grid_Mostrar(Grid_Coletar(hwndFoco), Grid_Titulo(hwndFoco))
}

; ════════════════════════════════════════════════════════════════
;  EXECUÇÃO
; ════════════════════════════════════════════════════════════════
;
;  Sem argumentos: este script não recebe protocolo. Digitar no MV é papel de
;  teste_baixa_cursor.ahk, e o operador consulta a grid à mão — que também
;  garante que ele sabe quais linhas têm conta ao comparar com o relatório.

TESTE_GuardPadroesProibidos(TESTE_ArquivosDoTeste())

TESTE_Log("=== teste_grid_checkbox: aguardando F3 (F4 sai) ===")
TESTE_Log("Abra a Protocolação de Baixa, consulte um protocolo, clique na grid e aperte F3.")

return