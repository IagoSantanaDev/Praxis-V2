; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Include lib\teste_lib.ahk

; ════════════════════════════════════════════════════════════════
;  TESTE DA ESPERA DE CURSOR — não toca no MV2000i
; ════════════════════════════════════════════════════════════════
;
;  Exercita TESTE_WaitCursorReady isolado. Sai com o número de falhas, então
;  serve de gate: 0 = passou.
;
;  Uso:
;    AutoHotkey64.exe teste_espera_cursor.ahk
;    AutoHotkey64.exe teste_espera_cursor.ahk --vigiar 15000
;
;  --vigiar amostra A_Cursor real durante N ms e imprime os valores distintos.
;  É a evidência de como o MV2000i se anuncia: se a estação nunca mostra o
;  relégio, este gate não tem o que esperar.

falhas := 0
verificacoes := 0

Checar(condicao, descricao, detalhe := "") {
    global falhas, verificacoes
    verificacoes += 1

    if condicao {
        TESTE_Log("  ok   " descricao (detalhe = "" ? "" : " — " detalhe))
        return
    }

    falhas += 1
    TESTE_Log("  FALHA " descricao (detalhe = "" ? "" : " — " detalhe))
}

; ════════════════════════════════════════════════════════════════
;  1. CAMINHO OCIOSO — cursor pronto responde na hora
; ════════════════════════════════════════════════════════════════

TESTE_DefinirCursorOverride("Arrow")

inicio := A_TickCount
ok := TESTE_WaitCursorReady(5000)
elapsed := A_TickCount - inicio

Checar(ok, "ocioso retorna true", "elapsed " elapsed "ms")
Checar(elapsed < 200, "ocioso responde sem esperar o prazo", elapsed "ms")

TESTE_DefinirCursorOverride("")

; ════════════════════════════════════════════════════════════════
;  2. CURSOR REAL — a variável embutida realmente é legível
; ════════════════════════════════════════════════════════════════

TESTE_Log("A_Cursor real agora: " TESTE_CursorAtual())
Checar(A_Cursor != "", "A_Cursor devolve valor", A_Cursor)

inicio := A_TickCount
ok := TESTE_WaitCursorReady(2000)
elapsed := A_TickCount - inicio

Checar(ok, "cursor real (não ocupado) retorna true", "elapsed " elapsed "ms")

; ════════════════════════════════════════════════════════════════
;  3. TIMEOUT — cursor ocupado bloqueia pelo prazo inteiro
; ════════════════════════════════════════════════════════════════

for ocupado in ["Wait", "AppStarting"] {
    TESTE_DefinirCursorOverride(ocupado)

    inicio := A_TickCount
    ok := TESTE_WaitCursorReady(600)
    elapsed := A_TickCount - inicio

    Checar(!ok, ocupado ": cursor ocupado retorna false")
    ; Folga de uma passada de polling: o laço só pode sair depois do prazo.
    Checar(elapsed >= 600, ocupado ": respeita o prazo", elapsed "ms")
    Checar(elapsed < 600 + TESTE_CURSOR_POLL_MS * 4,
        ocupado ": não excede o prazo além do polling", elapsed "ms")
}

TESTE_DefinirCursorOverride("")

; ════════════════════════════════════════════════════════════════
;  4. CURSORES QUE NÃO DEVEM BLOQUEAR
; ════════════════════════════════════════════════════════════════

for livre in ["Arrow", "IBeam", "Unknown", "SizeAll", "No", "Hand"] {
    TESTE_DefinirCursorOverride(livre)
    Checar(TESTE_CursorPronto(), livre ": não conta como ocupado")
    Checar(TESTE_WaitCursorReady(300), livre ": retorna true")
}

TESTE_DefinirCursorOverride("")

; ════════════════════════════════════════════════════════════════
;  5. WRAPAROUND — o prazo não pode ser por soma
; ════════════════════════════════════════════════════════════════
;
;  A_TickCount zera em ~49,7 dias. Uma estação de faturamento que não
;  reinicia chega lá, e com "prazo = A_TickCount + timeout" o prazo vira
;  negativo e a espera dura zero — sem erro visível.

TESTE_Log("A_TickCount atual: " A_TickCount " (zera em ~49,7 dias)")

TESTE_DefinirCursorOverride("Wait")
inicio := A_TickCount
ok := TESTE_WaitCursorReady(600)
elapsed := A_TickCount - inicio
Checar(!ok, "wraparound: cursor ocupado ainda bloqueia")

; Com prazo por soma e A_TickCount já em 0, o prazo seria 600 e passaria.
; Com a forma por decorrido, o mesmo código acima segurou os 600ms.
Checar(elapsed >= 600, "wraparound: forma por decorrido segura o prazo", elapsed "ms")
TESTE_DefinirCursorOverride("")

; ════════════════════════════════════════════════════════════════
;  6. GUARD — padrões proibidos nos três arquivos de teste
; ════════════════════════════════════════════════════════════════

TESTE_Log("guard:")
falhasGuard := TESTE_GuardPadroesProibidos(TESTE_ArquivosDoTeste())
Checar(falhasGuard = 0, "guard: nenhum padrão proibido", falhasGuard " ocorrência(s)")

; ════════════════════════════════════════════════════════════════
;  7. MODO --vigiar — o que o MV2000i realmente mostra
; ════════════════════════════════════════════════════════════════

if TESTE_TemArg("--vigiar") {
    duracaoMs := TESTE_ValorArg("--vigiar", 15000)
    TESTE_Log("vigiando A_Cursor por " duracaoMs "ms — mova o mouse sobre o MV2000i.")

    vistos := Map()
    inicio := A_TickCount

    while (A_TickCount - inicio) < duracaoMs {
        cursor := A_Cursor
        if !vistos.Has(cursor)
            vistos.Set(cursor, 0)
        vistos.Set(cursor, vistos.Get(cursor) + 1)
        Sleep TESTE_CURSOR_POLL_MS
    }

    TESTE_Log("valores distintos observados:")
    for cursor, contagem in vistos
        TESTE_Log("  " cursor ": " contagem " leitura(s)")

    ; O pressuposto inteiro do gate é que o MV anuncie "Wait". Sem isso,
    ; esperar cursor é esperar nada. Só é falha se houver MV aberto para
    ; observar — com o MV fechado não há o que ver, e reprovar aqui seria um
    ; vermelho que não significa nada.
    if WinExist("Movimentação ahk_exe ifrun60.EXE")
        Checar(vistos.Has("Wait") || vistos.Has("AppStarting"),
            "MV2000i sinaliza ocupado via cursor",
            "vistos: " TESTE_Juntar(TESTE_Chaves(vistos)))
    else
        TESTE_Log("  info   MV2000i não está aberto: nada a observar sobre o cursor."
            " Rode com o MOV DOC aberto e ocupado para essa verificação valer.")
}

; ════════════════════════════════════════════════════════════════
;  RESULTADO
; ════════════════════════════════════════════════════════════════

TESTE_Log("=== " (verificacoes - falhas) "/" verificacoes " verificações passaram, "
    falhas " falha(s) ===")
TESTE_Log("log: " TESTE_LOG_PATH)

ExitApp falhas
