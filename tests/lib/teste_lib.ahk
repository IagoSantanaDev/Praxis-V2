; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0

; ════════════════════════════════════════════════════════════════
;  TESTE LIB — primitivas compartilhadas pelos scripts de teste
; ════════════════════════════════════════════════════════════════
;
;  estes testes são INDEPENDENTES do app: não dão #Include em
;  scripts\mv_session.ahk. Motivos concretos, não preferência:
;    1. MV_Abort chama SendToUI sem try — sem host WebView isso estoura
;       "Call to nonexistent function" e mascara o resultado real do MV;
;    2. mv_session.ahk aplica SetTitleMatchMode 2 e SetKeyDelay 0,0 no
;       include, que é estado global de que o timing dos mnemônicos depende;
;    3.Independência faz uma falha do teste apontar para o teste.
;  A consistência vem de copiar contrato, nomes e proveniência de lá.
;
;  Fonte do contrato: scripts\mv_session.ahk e scripts\protocolar.ahk.

SetTitleMatchMode 2
DetectHiddenText true
SetWinDelay 0
SetKeyDelay 10, 10
SetMouseDelay -1
SetDefaultMouseSpeed 0
SetControlDelay -1

; ── Janelas do MV2000i ─────────────────────────────────────────
; Cópia literal do contrato de scripts\mv_session.ahk.
; Com SetTitleMatchMode 2, um título dentro de colchetes na raiz MDI casa
; na raiz e o hwnd devolvido não contém mais o texto procurado. Por isso
; TESTE_WIN_MOVDOC_ANY (fora dos colchetes) é o título de SAÍDA, e
; TESTE_WIN_MOVDOC_BAIXA (dentro dos colchetes) é o título de ESPERA e CLIQUE.
TESTE_WIN_MOVDOC_ANY   := "Movimentação ahk_exe ifrun60.EXE"
TESTE_WIN_MOVDOC_BAIXA := "Protocolação de Baixa de Documentos ahk_exe ifrun60.EXE"
TESTE_WIN_IDENT        := "Identificação ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
TESTE_FORMS_MODAL      := "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
; Spy em mv_session.ahk L42 (janela de "Mensagem ao Usuário do MV 2000")
TESTE_WIN_MSG_USER     := "Mensagem ao Usuário do MV 2000"

; ── Teclado ────────────────────────────────────────────────────
; Saída de tela no MV2000i: Ctrl+Q vale para TODAS as telas. Em AHK "^q" É
; Ctrl+Q — não ajustar. {Esc} foi descartado. Fonte: mv_session.ahk L75-L78.
TESTE_SAIR_TELA := "^q"
; O fluxo validado acrescenta {Enter} depois do ^q na baixa; o Praxis NÃO
; acrescenta, por decisão do operador (AGENTS.md, "Falha silenciosa").
; Fica visível e virável aqui de propósito — não "corrigir" por adivinhação.
TESTE_ENTER_APOS_CTRLQ := false
; Alt+M, P, B abre a Protocolação de Baixa. Fonte: protocolar.ahk L877.
TESTE_MENU_BAIXA := "mpb"
TESTE_MENU_STEP_MS := 100

; ── Controles ──────────────────────────────────────────────────
; Botão "Recebido" da tela de baixa.
; Spy em Praxis_TO-DO/Protocolar/protocolar.ahk L465 (imagem 14). A imagem
; NÃO é versionada (.gitignore:41) — a proveniência é herdada, não verificada.
TESTE_BAIXA_BTN := "Button1"

; ── Polling ────────────────────────────────────────────────────
TESTE_POLL_MS := 100
; O cursor troca antes do layout da tela; 100ms (MV_POLL_MS) seria lento
; demais para um gate de 7 passos por protocolo.
TESTE_CURSOR_POLL_MS := 50
TESTE_CURSOR_TIMEOUT_MS := 10000
TESTE_TIMEOUT_SAIDA_MS := 30000

; ── Log ────────────────────────────────────────────────────────
; A_ScriptName já vem com ".ahk" no v2, daí o nome um pouco redundante.
TESTE_LOG_PATH := A_ScriptDir "\" A_ScriptName ".log"

TESTE_Log(msg) {
    linha := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") " | " msg
    try FileAppend linha "`r`n", TESTE_LOG_PATH, "UTF-8"
    try FileAppend linha "`n"
}

; ════════════════════════════════════════════════════════════════
;  ESPERA DE CURSOR — a primitiva sob teste
; ════════════════════════════════════════════════════════════════

TESTE_CURSOR_OCUPADOS := ["Wait", "AppStarting"]

; Vazio = ler o cursor real do sistema. Preenchido = simular, para testar o
; laço sem depender do SO. Só o teste unitário escreve; via setter.
;
; Declaração global SEM a palavra "global" no topo: verificado no AHK v2.0.26 que
; "global X := ..." no topo não produz a mesma variável que o "global X" dentro de
; uma função — o setter escrevia e a leitura via função voltava vazia. Atribuição
; simples no topo é o que cria a global de verdade.
TESTE_CursorOverride := ""

TESTE_DefinirCursorOverride(cursor) {
    global TESTE_CursorOverride
    TESTE_CursorOverride := cursor
}

; Cursor de mão (apontando e agarrando) é classificado como "Unknown" pelo AHK.
; Ele NÃO está na lista de ocupados — correto: não indica app ocupado.
; Função normal, e não "=>": arrow function tem escopo local e não enxerga global.
TESTE_CursorAtual() {
    global TESTE_CursorOverride
    return (TESTE_CursorOverride != "" ? TESTE_CursorOverride : A_Cursor)
}

; Testado no AutoHotkey64 2.0.26: Array.Has é por ÍNDICE e Array.Contains não
; existe. ["Wait"].Has("Wait") devolve 0. Usar Has aqui deixaria o gate de cursor
; permanentemente "pronto", sem erro visível — a mesma classe de falha do
; wraparound de A_TickCount. Por isso a busca é explícita.
TESTE_Contem(lista, valor) {
    for item in lista {
        if (item = valor)
            return true
    }
    return false
}

TESTE_CursorPronto() {
    return !TESTE_Contem(TESTE_CURSOR_OCUPADOS, TESTE_CursorAtual())
}

; A API do AHK v2 é a variável embutida A_Cursor. Não existe função de cursor
; no v2 — a única função de mouse é a de posição. Ler o índice de funções do
; v2 e a tabela de strings do binário instalado confirmam: zero ocorrências.
;
; Prazo por SUBTRAÇÃO DE DECORRIDO, nunca por soma com prazo final: A_TickCount
; zera depois de ~49,7 dias e uma estação que não reinicia atinge isso. Com
; "A_TickCount + timeout" o prazo vira negativo e a espera passa a durar zero —
; falha silenciosa, sem erro visível. Todo o resto do repo já usa a forma
; por decorrido (mv_session.ahk L413, L647).
TESTE_WaitCursorReady(timeoutMs := 10000) {
    startedAt := A_TickCount

    while (A_TickCount - startedAt) < timeoutMs {
        if TESTE_CursorPronto()
            return true
        Sleep TESTE_CURSOR_POLL_MS
    }

    ; Última checagem: o Sleep final pode ter sido o instante em que o app
    ; liberou. Sem ela, um TIMEOUT aqui é relato falso.
    return TESTE_CursorPronto()
}

; Wrapper com rastro: o log é o entregável real deste teste.
TESTE_EsperarCursor(rotulo, timeoutMs := TESTE_CURSOR_TIMEOUT_MS) {
    cursorAntes := TESTE_CursorAtual()
    startedAt := A_TickCount
    ok := TESTE_WaitCursorReady(timeoutMs)
    TESTE_Log(rotulo ": " (ok ? "ok" : "TIMEOUT") " em " (A_TickCount - startedAt)
        "ms (cursor=" cursorAntes ")")
    return ok
}

; ════════════════════════════════════════════════════════════════
;  JANELA / POLLING — espelha scripts\mv_session.ahk
; ════════════════════════════════════════════════════════════════

TESTE_Poll(condFn, timeoutSecs) {
    startedAt := A_TickCount

    while (A_TickCount - startedAt) < timeoutSecs * 1000 {
        if condFn()
            return true
        Sleep TESTE_POLL_MS
    }

    return condFn()
}

TESTE_AtivarJanela(winTitle, timeoutSecs := 5) {
    if !WinExist(winTitle)
        return false
    WinActivate winTitle
    return TESTE_Poll(() => WinActive(winTitle), timeoutSecs)
}

TESTE_EsperarJanela(winTitle, timeoutSecs) {
    startedAt := A_TickCount

    while (A_TickCount - startedAt) < timeoutSecs * 1000 {
        if WinExist(winTitle)
            return true
        Sleep TESTE_POLL_MS
    }

    return false
}

; Assinatura inclui o título porque é ele que muda quando o MV troca de tela no
; MESMO HWND. Contagem de controles sozinha não distingue "trocou" de "não
; aconteceu" — foi assim que tecla engolida virou tela "perfeitamente estável".
; Fonte: mv_session.ahk L582-L602.
TESTE_ScreenSignature(winTitle) {
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

; Sucesso = janela sumiu OU assinatura mudou. Estabilidade com a assinatura
; intacta NÃO é sucesso — é o estado em que a tecla foi engolida.
; Fonte: mv_session.ahk L604-L622.
TESTE_EsperarTelaMudou(winTitle, assinaturaAntes, timeoutMs := 30000) {
    startedAt := A_TickCount

    while (A_TickCount - startedAt) < timeoutMs {
        if !WinExist(winTitle)
            return true
        if (TESTE_ScreenSignature(winTitle) != assinaturaAntes)
            return true
        Sleep TESTE_POLL_MS
    }

    return false
}

TESTE_PopupAberto() {
    return (WinExist(TESTE_FORMS_MODAL) || WinExist(TESTE_WIN_MSG_USER)) ? true : false
}

; Clique pelo ClassNN exato, sem coordenada e SEM o fallback por coordenada de
; MV_ClickBySpec — que devolve true tanto se clicou no controle quanto se clicou
; no ponto errado. Fontes: mv_session.ahk L250-L265 e L760-L781.
TESTE_ClicarPrimeiroControle(winTitle, classNN) {
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

; Alt+primeira letra, depois as demais uma a uma. Fonte: protocolar.ahk L1317.
TESTE_SendMenuPath(caminho) {
    if StrLen(caminho) < 1
        return

    Send "!" SubStr(caminho, 1, 1)
    Sleep TESTE_MENU_STEP_MS

    Loop Parse SubStr(caminho, 2) {
        Send A_LoopField
        Sleep TESTE_MENU_STEP_MS
    }
}

; ════════════════════════════════════════════════════════════════
;  ARGUMENTOS / SAÍDA
; ════════════════════════════════════════════════════════════════

; Fonte: protocolar.ahk L1446 (PR_ParseRemessas).
TESTE_ParseLista(itens, sep := ",") {
    resultado := []
    for item in itens {
        for parte in StrSplit(item, sep) {
            valor := Trim(parte)
            if (valor != "")
                resultado.Push(valor)
        }
    }
    return resultado
}

TESTE_Erro(msg) {
    throw Error(msg)
}

; Array não tem Join no v2 e Map não tem Keys/Values — só enumeração por for.
TESTE_Juntar(itens, sep := ", ") {
    saida := ""
    for item in itens
        saida .= (saida = "" ? "" : sep) item
    return saida
}

; InStr do v2 exige String no haystack e rejeita Array, então procure à mão.
TESTE_TemArg(flag) {
    for arg in A_Args {
        if (arg = flag)
            return true
    }
    return false
}

; Valor numérico que acompanha a flag, ou padrão.
TESTE_ValorArg(flag, padrao := 0) {
    for i, arg in A_Args {
        if (arg = flag && i < A_Args.Length && IsNumber(A_Args[i + 1]))
            return A_Args[i + 1]
    }
    return padrao
}

; Enumera as chaves de um Map. Existe porque v2 não expõe Keys.
TESTE_Chaves(mapa) {
    chaves := []
    for chave, valor in mapa
        chaves.Push(chave)
    return chaves
}

; ════════════════════════════════════════════════════════════════
;  GUARD — padrões que já custaram tempo aqui, verificados a cada run
; ════════════════════════════════════════════════════════════════

; Montados por concatenação de propósito: escritos literais aqui, o guard
; acusaria o próprio arquivo que os define.
TESTE_PADRAO_DEADLINE := "A_TickCount " "+"
TESTE_PADRAO_CURSOR := "MouseGet" "Cursor"

; Remove comentários antes de casar o padrão. Sem isto o guard acusa o próprio
; texto que explica por que o padrão é proibido — o que tornaria o guard
; decorativo. Varre respeitando aspas porque ";" também aparece em string.
TESTE_SemComentarios(texto) {
    saida := ""
    dentroDeAspas := false
    i := 1
    total := StrLen(texto)

    while (i <= total) {
        caractere := SubStr(texto, i, 1)

        if (caractere = '"')
            dentroDeAspas := !dentroDeAspas
        else if (caractere = ";" && !dentroDeAspas) {
            while (i <= total && SubStr(texto, i, 1) != "`n")
                i += 1
            continue
        }

        saida .= caractere
        i += 1
    }

    return saida
}

TESTE_GuardPadroesProibidos(arquivos) {
    proibidos := [
        { texto: TESTE_PADRAO_DEADLINE,
          motivo: "prazo por soma quebra no wraparound de 49,7 dias do A_TickCount" },
        { texto: TESTE_PADRAO_CURSOR,
          motivo: "função de cursor não existe no AHK v2 — usar a variável A_Cursor" },
    ]

    falhas := 0

    for arquivo in arquivos {
        if !FileExist(arquivo)
            continue

        try bruto := FileRead(arquivo, "UTF-8")
        catch as err {
            TESTE_Log("guard: não consegui ler " arquivo ": " err.Message)
            falhas += 1
            continue
        }

        conteudo := TESTE_SemComentarios(bruto)

        for proibido in proibidos {
            if InStr(conteudo, proibido.texto) {
                TESTE_Log("guard: " arquivo " usa padrão proibido — " proibido.motivo)
                falhas += 1
            }
        }
    }

    if (falhas = 0)
        TESTE_Log("guard: ok, nenhum padrão proibido.")

    return falhas
}

TESTE_ArquivosDoTeste() {
    return [
        A_ScriptDir "\lib\teste_lib.ahk",
        A_ScriptDir "\teste_espera_cursor.ahk",
        A_ScriptDir "\teste_baixa_cursor.ahk",
    ]
}
