; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Include mv_session.ahk
#Include ..\lib\FFCV_ErrorTemplates.ahk

; Configuração conservadora para computadores rápidos e lentos.
; Não usar prioridade alta: o Oracle Forms precisa reagir aos eventos de teclado/mouse.
ListLines(false)
SetKeyDelay(10, 10)
SetMouseDelay(-1)
SetDefaultMouseSpeed(0)
SetControlDelay(-1)

; ════════════════════════════════════════════════════════════════
;  REMESSA POR PROTOCOLO
; ════════════════════════════════════════════════════════════════

; ── Janelas ───────────────────────────────────────────────────
WIN_MOVDOC_BAIXA       := MV_WIN_MOVDOC_BAIXA
WIN_MOVDOC_POPUP       := "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
; O popup "Informações da Conta" é embarcado na janela FFCV: o título não muda.
; Detectá-lo por controle sentinela dentro de MV_WIN_FFCV_ANY, não por WinTitle próprio.
WIN_FFCV_DATAS         := MV_WIN_FFCV_DATAS
WIN_FFCV_DATAS_OK      := MV_WIN_MSG_USER
WIN_CAPA_REMESSA       := MV_WIN_CAPA_REMESSA
WIN_XML                := MV_WIN_XML_TISS
WIN_XML_PATH_FORM      := MV_WIN_XML_PATH_FORM
WIN_XML_POPUP_SIMNAO   := MV_WIN_MSG_USER

; ── Regiões MOV DOC em coordenadas Client ─────────────────────
; Não usar EditN como contrato: Oracle Forms renumera Edit1/Edit2/Edit15 conforme estado.
; A grid MOV DOC não expõe texto confiável via ControlGetText: usar clique físico,
; Home, Shift+End e Ctrl+C com validação semântica.
MOVDOC_PROTOCOLO_X := 21
MOVDOC_PROTOCOLO_Y := 106
MOVDOC_CONTA_X     := 252
MOVDOC_CONVENIO_X  := 491
MOVDOC_GRID_ROWS_Y := [222, 245, 268, 291]

; Confirmado previamente para primeira linha, mas manter validável por teste.
MOVDOC_CHECK_RECEBIDO_CLASS  := "Button1"
MOVDOC_CHECK_RECEBIDO_X      := 718
MOVDOC_CHECK_RECEBIDO_Y      := 359

; Coluna "Devolvido" da grid: um checkbox POR LINHA, dentro da área rolável.
; O ClassNN de cada linha é FIXO — confirmado pelo Window Spy do operador nas 4
; capturas do TO-DO, uma por linha. O Forms numera de baixo para cima, e a
; numeração não muda com o estado da grade:
;
;   linha 1 -> Button5   (client 679, y 224)
;   linha 2 -> Button4   (client 679, y 247)
;   linha 3 -> Button3   (client 679, y 270)
;   linha 4 -> Button2   (client 679, y 293)
;
; O índice é a posição na linha MOVDOC_GRID_ROWS_Y (222/245/268/291); o Spy
; mede +2 px em relação a ela porque reporta o topo do controle.
; A coluna "Recebido" fica em x 718, a 39 px — a busca por ClassNN exato já
; desambigua, e a tolerância abaixo é pequena de propósito para não alcançar
; a coluna vizinha.
; Capturas não versionadas (fora do Git por higiene): conferir com Window Spy
; antes de mexer neste bloco.
; docs/analise-causa-raiz/05-remensa-protocolo-coluna-devolvido.md
MOVDOC_CHECK_DEVOLVIDO_CLASSES := ["Button5", "Button4", "Button3", "Button2"]
MOVDOC_CHECK_DEVOLVIDO_X := 679
MOVDOC_CHECK_DEVOLVIDO_TOL := 12

; ── Controles FFCV ────────────────────────────────────────────
; Manutenção de Remessa usa teclado/atalhos de propósito.
; Os campos de remessa são Oracle Forms com EditN variável conforme quantidade de
; remessas do convênio e estado da tela. Preferir o fluxo validado no mini macro 03:
; F7/F8 para consulta, F6/F10 para nova remessa e Tab apenas onde foi testado.
FFCV_BTN_HABILITAR     := "CLASSNN"  ; preferir F7; não mapear campo variável sem nova validação
FFCV_CAMPO_CONVENIO    := "CLASSNN"  ; fluxo atual usa F7 + digitação por foco do Oracle Forms
FFCV_AREA_REMESSAS     := "CLASSNN"  ; fluxo atual usa Tab x3 validado no mini macro 03
FFCV_BTN_BUSCAR_REM    := "CLASSNN"  ; preferir F8; não mapear campo variável sem nova validação
FFCV_CAMPO_NUM_REM     := "CLASSNN"  ; EditN variável; manter teclado no fluxo atual
FFCV_BTN_CONFIRMAR_REM := "CLASSNN"  ; preferir F8; não mapear campo variável sem nova validação
FFCV_BTN_NOVA_REM      := "CLASSNN"  ; preferir F6; não mapear campo variável sem nova validação
FFCV_CAMPO_DATA_REM    := "CLASSNN"  ; EditN variável; manter teclado no fluxo atual
FFCV_CAMPO_TIPO        := "CLASSNN"  ; EditN variável; manter teclado no fluxo atual
FFCV_BTN_SALVAR_REM    := "CLASSNN"  ; preferir F10; não mapear campo variável sem nova validação
FFCV_BTN_ADICIONAR     := "Button10" ; 1 - Inserir Conta
FFCV_BTN_ABRIR_DATAS   := "Button6"  ; 5 - Entregar Rem.
FFCV_BTN_IMPRIMIR      := "Button7"  ; Relatório/Imprimir atendimentos
FFCV_BTN_IMPRIMIR_X    := 567
FFCV_BTN_IMPRIMIR_Y    := 458

; ── Controles popup de envio de contas ────────────────────────
; Validado por captura do usuário: "Informações da Conta" não abre WinTitle próprio;
; o sentinela é o painel desenhado ui60Drawn W323 dentro da janela principal FFCV.
FFCV_POPUP_CONTA_SENTINEL_CLASS := "ui60Drawn W323"
FFCV_POPUP_CONTA_SENTINEL_X     := 432
FFCV_POPUP_CONTA_SENTINEL_Y     := 109
POPUP_DROPDOWN_1   := "ComboBox2"
POPUP_DROPDOWN_1_X := 84
POPUP_DROPDOWN_1_Y := 143
POPUP_DROPDOWN_2   := "ComboBox1"
POPUP_DROPDOWN_2_X := 190
POPUP_DROPDOWN_2_Y := 143
POPUP_CAMPO_CONTA  := "Edit2"
POPUP_CAMPO_CONTA_X := 298
POPUP_CAMPO_CONTA_Y := 143
POPUP_BTN_OK       := "Button1"  ; modal de aviso/erro usa o primeiro Button1

; ── Controles tela de datas / XML ─────────────────────────────
; Constantes promovidas para o contrato compartilhado em mv_session.ahk
; (prefixo MV_DATAS_* e MV_XML_*), junto com o atalho MV_SAIR_TELA_ATALHO.
; As referências abaixo usam o prefixo MV_ direto.

; ── Fragmentos/classificação de erros no popup de envio ───────
; Modais Oracle Forms não expõem a mensagem pelo Window Spy/WinGetText de forma confiável.
; A classificação confiável vem do OCR local do Windows na área client do modal.
ERR_JA_DIGITADA        := "já digitada"
ERR_CONVENIO_DIFERENTE := "convênio diferente"
ERR_CONTA_ABERTA       := "conta aberta"
ERR_CONTA_JA_EM_REMESSA := "já em remessa"
ERR_TIPO_DIFERENTE     := "tipo diferente"

; ── Entrada por teclado/campo Oracle Forms ─────────────────────
; Timing canônico vive em mv_session.ahk (prefixo MV_). Aliases locais mantêm
; a leitura curta das referências deste arquivo.
RP_FIELD_FOCUS_SETTLE_MS := MV_FIELD_FOCUS_SETTLE_MS
RP_FIELD_CLEAR_SETTLE_MS := MV_FIELD_CLEAR_SETTLE_MS
RP_KEY_SETTLE_MS         := MV_KEY_SETTLE_MS

; ── Performance FFCV Inserir Conta ─────────────────────────────
; Contrato do macro 11: manter popup aberto, reagir ao modal e liberar próxima conta por estado.
FFCV_CONTA_FOCUS_SETTLE_MS      := RP_FIELD_FOCUS_SETTLE_MS
FFCV_CONTA_CLEAR_SETTLE_MS      := RP_FIELD_CLEAR_SETTLE_MS
FFCV_CONTA_READY_MIN_MS         := 180
FFCV_CONTA_FIELD_EMPTY_MIN_MS   := 100
FFCV_CONTA_STABLE_MS            := 100
FFCV_CONTA_SUBMIT_TIMEOUT_MS    := 650

; ── Esperas da fase de fechamento/XML ─────────────────────────
; Esta fase dispara processamentos pesados no Oracle Forms. Evitar avançar apenas
; porque o clique foi aceito; aguardar janela/modal/cursor estabilizarem.
RP_FINAL_STABLE_MS             := MV_FINAL_STABLE_MS
RP_FINAL_ACTION_TIMEOUT_MS     := MV_FINAL_ACTION_TIMEOUT_MS
RP_XML_QUERY_MIN_WAIT_MS       := MV_XML_QUERY_MIN_WAIT_MS

RunRemessaProtocolo(params) {
    global gRunning

    protocolos   := ParseProtocolos(params["protocolos"])
    tipoConta    := params["tipo_conta"]
    dataEntrega  := params["data_entrega"]
    dataVenc     := params["data_vencimento"]
    numRemessa   := Trim(params["num_remessa"])
    temDatas     := (dataEntrega != "" && dataVenc != "")

    if (protocolos.Length = 0)
        return RP_Abort("Informe ao menos um protocolo.")

    linhasMovDoc := []
    erros        := []
    avisos       := []
    convenioNum  := ""
    timings      := []
    totalStart   := A_TickCount
    stageStart   := A_TickCount

    Notify("Garantindo MOV DOC...")
    if !MV_EnsureMovDoc()
        return RP_Abort("Não foi possível acessar o MOV DOC.")

    if !RP_AbrirTelaBaixaMovDoc()
        return RP_Abort("Não consegui abrir a tela Baixa de Documentos no MOV DOC.")
    RP_RecordTiming(timings, "Abrir MOV DOC e tela Baixa", stageStart)

    Progress(5)

    stageStart := A_TickCount
    for idx, protocolo in protocolos {
        protocolStart := A_TickCount
        Notify("Processando protocolo " protocolo " (" idx "/" protocolos.Length ")")
        result := ProcessarProtocolo(protocolo)

        if !result["ok"] {
            ; "Todas as contas do protocolo X estão devolvidas" é exatamente o
            ; caso que o operador precisa ver WHICH contas. A lista ia para
            ; `avisos` e era perdida: o abort carrega só result["erro"] e o
            ; relatório final nunca chega a rodar. A lista entra na própria
            ; mensagem de abort.
            for _, d in result["devolvidas"]
                avisos.Push(d)
            if (avisos.Length > 0)
                return RP_Abort(result["erro"] "`nContas devolvidas:`n" RP_FormatarAvisos(avisos))
            return RP_Abort(result["erro"])
        }

        for _, linha in result["linhas"]
            linhasMovDoc.Push(linha)

        for _, d in result["devolvidas"]
            avisos.Push(d)

        Notify("⏱ MOV DOC protocolo " protocolo ": " MV_FormatDuration(A_TickCount - protocolStart) " | " result["linhas"].Length " linha(s)"
            (result["devolvidas"].Length > 0 ? " | " result["devolvidas"].Length " devolvida(s) não enviada(s)" : ""))
        Progress(5 + (idx / protocolos.Length) * 40)
    }
    RP_RecordTiming(timings, "MOV DOC consultar, coletar e baixar", stageStart, protocolos.Length " protocolo(s), " linhasMovDoc.Length " linha(s)")

    convenioNum := RP_ConvenioMajoritario(linhasMovDoc)
    if (convenioNum = "") {
        if (avisos.Length > 0)
            return RP_Abort("Convênio não identificado: " avisos.Length
                " conta(s) do MOV DOC estão marcadas como devolvidas e nenhuma outra foi coletada. Avisos:`n"
                RP_FormatarAvisos(avisos))
        return RP_Abort("Convênio não identificado no MOV DOC.")
    }

    protocolContas := RP_FiltrarContasPorConvenio(linhasMovDoc, convenioNum, erros)
    totalContasFFCV := ContarContas(protocolContas)

    ; Contas coletadas no MOV DOC: fechar a tela de baixa antes de passar ao FFCV.
    ; Precisa vir antes de MV_EnsureFFCV, que ativa o FFCV e tornaria o Ctrl+Q ambíguo
    ; entre as duas janelas.
    ;
    ; Usa MV_WIN_MOVDOC_ANY (a raiz) e não MV_WIN_MOVDOC_BAIXA: o nome da tela de
    ; baixa aparece ENTRE COLCHETES no título da raiz MDI, e com
    ; SetTitleMatchMode 2 o WinExist resolve para a raiz — o Ctrl+Q é processado
    ; pela child, então ativar a raiz não a fecha. É o mesmo motivo pelo qual a
    ; saída do FFCV (MV_WIN_FFCV_ANY) funciona. MV_WIN_MOVDOC_BAIXA continua
    ; correto para espera e clique na tela, e por isso não foi alterado.
    ; docs/analise-causa-raiz/04-remessa-protocolo-ctrl-q-nao-sai.md
    MV_FecharUltimaTela(MV_WIN_MOVDOC_ANY, "MOV DOC (tela de baixa)")

    stageStart := A_TickCount
    Notify("Garantindo FFCV...")
    if !MV_EnsureFFCV()
        return RP_Abort("Não foi possível acessar o FFCV.")

    if !RP_AbrirManutencaoRemessaFFCV()
        return RP_Abort("Não consegui abrir Manutenção de Remessa no FFCV.")
    RP_RecordTiming(timings, "Abrir FFCV e Manutenção de Remessa", stageStart)

    Progress(50)

    stageStart := A_TickCount
    if !CarregarConvenioFFCV(convenioNum)
        return RP_Abort("Não consegui carregar o convênio " convenioNum " no FFCV.")

    PosicionarAreaRemessas()

    if (numRemessa != "") {
        if !SelecionarRemessaExistente(numRemessa)
            return RP_Abort("Remessa " numRemessa " não encontrada.")
    } else {
        if !CriarNovaRemessa(tipoConta)
            return RP_Abort("Erro ao criar nova remessa.")
    }
    RP_RecordTiming(timings, "Carregar convênio e posicionar remessa", stageStart, "convênio " convenioNum)

    Progress(60)
    stageStart := A_TickCount
    if !InserirContasNaRemessa(protocolContas, tipoConta, erros)
        return false
    RP_RecordTiming(timings, "Inserir contas FFCV", stageStart, totalContasFFCV " conta(s)")

    Progress(87)

    if temDatas {
        stageStart := A_TickCount
        Notify("Preenchendo datas...")
        result := FinalizarComDatas(dataEntrega, dataVenc)
        if !result["ok"]
            return RP_Abort(result["erro"])
        RP_RecordTiming(timings, "Fechar remessa e preencher datas", stageStart, "remessa " result["remessa"])
        Progress(94)
        stageStart := A_TickCount
        Notify("Gerando XML...")
        if !GerarXML(result["remessa"])
            return false
        RP_RecordTiming(timings, "Gerar XML", stageStart)
    } else {
        stageStart := A_TickCount
        FinalizarSemDatas()
        RP_RecordTiming(timings, "Finalização sem datas", stageStart)
    }

    Progress(100)
    RP_RecordTiming(timings, "Total do fluxo", totalStart, protocolos.Length " protocolo(s), " totalContasFFCV " conta(s)")
    timingReport := RP_FormatTimingReport(timings)
    gRunning := false

    MV_FecharUltimaTela(MV_WIN_FFCV_ANY, "FFCV")

    ; Avisos e pendências são seções separadas e de cores diferentes: uma conta
    ; devolvida é um AVISO (o MV decidiu isso, não é falha), enquanto pendência de
    ; convênio/setor é ERRO. O operador precisa da distinção para saber se precisa
    ; intervir.
    relatorio := "Remessa concluída com sucesso!`n`n" timingReport

    if (avisos.Length > 0)
        relatorio .= "`nAVISOS (" avisos.Length ") — contas devolvidas, não enviadas à remessa`n"
        relatorio .= "PROTOCOLO | CONTA | AVISO`n"
        for _, a in avisos
            relatorio .= "  [[aviso]]" a["protocolo"] " | " a["conta"] " | " a["descricao"] "[[/aviso]]`n"

    if (erros.Length > 0) {
        relatorio .= "`nPENDÊNCIAS (" erros.Length ")`n"
        relatorio .= "PROTOCOLO | CONTA | ERRO`n"
        for _, e in erros
            relatorio .= "  [[red]]" e["protocolo"] " | " e["conta"] " | " e["descricao"] "[[/red]]`n"
    }

    if (avisos.Length = 0 && erros.Length = 0)
        relatorio := "Remessa concluída com sucesso!`n`n" timingReport

    Done(relatorio)
}

; Formata a lista de avisos para uma mensagem de abort (texto puro, sem tag).
RP_FormatarAvisos(avisos) {
    texto := ""
    for _, a in avisos
        texto .= "  " a["conta"] " — " a["descricao"] "`n"
    return texto
}


; ════════════════════════════════════════════════════════════════
;  FASE MOV DOC
; ════════════════════════════════════════════════════════════════

RP_AbrirTelaBaixaMovDoc() {
    ; Sempre abre uma nova instância da tela funcional. Não reutilizar Baixa já aberta.
    MV_ActivateModule(MV_WIN_MOVDOC_ANY)
    if !MV_WaitWindowStable(MV_WIN_MOVDOC_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
        return false

    ; Atalho validado no macro 02: Manutenção → Protocolação → Baixa.
    Send "{Alt down}mpb{Alt up}"

    if !MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA), MV_TIMEOUT_LOAD)
        return false

    return MV_WaitWindowStable(WIN_MOVDOC_BAIXA, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD)
}

ProcessarProtocolo(protocolo) {
    WinActivate WIN_MOVDOC_BAIXA
    if !RP_SetProtocoloMovDocByClick(protocolo)
        return Map("ok", false, "erro", "Não consegui focar/preencher o campo Protocolo.", "devolvidas", [])

    Sleep MV_DELAY_INPUT
    Send "{F8}"
    if !RP_WaitMovDocFirstGridLineReady(protocolo, &primeiraLinhaValida)
        return Map("ok", false, "erro", "A primeira linha da grid não ficou legível após F8 para o protocolo " protocolo ".", "devolvidas", [])

    ; As devolvidas vão no resultado, e não em `erros`: erros é do módulo
    ; RunRemessaProtocolo e não chega aqui. O chamador (:172) as mescla em
    ; `erros` — mesmo array, mesmo formato de três chaves.
    devolvidas := []
    linhas := RP_ColetarLinhasMovDoc(protocolo, primeiraLinhaValida, devolvidas)
    if (linhas.Length = 0) {
        if (devolvidas.Length > 0)
            return Map("ok", false, "erro", "Todas as contas do protocolo " protocolo
                " estão marcadas como devolvidas no MOV DOC.", "devolvidas", devolvidas)
        return Map("ok", false, "erro", "Nenhuma conta/convênio foi coletado para o protocolo " protocolo ".", "devolvidas", devolvidas)
    }

    if !RP_FinalizarBaixaProtocolo()
        return Map("ok", false, "erro", "Falha ao salvar/baixar o protocolo " protocolo ".", "devolvidas", devolvidas)

    return Map("ok", true, "linhas", linhas, "devolvidas", devolvidas)
}

RP_SetProtocoloMovDocByClick(protocolo) {
    if !WinExist(WIN_MOVDOC_BAIXA)
        return false

    WinActivate WIN_MOVDOC_BAIXA
    if !MV_Poll(() => WinActive(WIN_MOVDOC_BAIXA), 2)
        return false

    CoordMode("Mouse", "Client")
    Click(MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, 1)
    Sleep RP_KEY_SETTLE_MS
    SendText protocolo
    Sleep RP_KEY_SETTLE_MS
    return true
}

RP_ColetarLinhasMovDoc(protocolo, primeiraLinha := "", avisos := []) {
    linhas := []
    vistos := Map()

    ; Lê o Devolvido das 4 linhas ANTES de copiar qualquer conta. A linha-semente
    ; é a 1ª linha e é empurrada por este bloco, fora do laço de cópia — se o
    ; Devolvido fosse conferido só lá dentro, a conta devolvida da linha 1
    ; entraria inteira na remessa.
    devolvidos := RP_LerDevolvidosVisiveis()

    if (primeiraLinha is Map) {
        keyInicial := primeiraLinha["protocolo"] "|" primeiraLinha["conta"] "|" primeiraLinha["convenio"]
        vistos[keyInicial] := true
        if RP_LinhaDevolvida(devolvidos, 1) {
            avisos.Push(Map("protocolo", protocolo, "conta", primeiraLinha["conta"],
                "descricao", "Conta devolvida"))
            Notify("Conta " primeiraLinha["conta"] " devolvida — não segue para a remessa.")
        } else {
            linhas.Push(primeiraLinha)
        }
    }

    RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos, avisos)

    maxIteracoes := 100
    semNovasConsecutivas := 0

    Loop maxIteracoes {
        result := RP_AvancarGridMovDocQuatroLinhas()
        added := RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos, avisos)

        ; Popup de último registro é o sinal mais confiável: parar imediatamente.
        if result["popup"]
            break

        ; Oracle Forms pode atrasar atualização da grid; exigir dois blocos vazios seguidos
        ; evita parar cedo por uma leitura repetida/transitória.
        if (added = 0) {
            semNovasConsecutivas++
            if (semNovasConsecutivas >= 2)
                break
        } else {
            semNovasConsecutivas := 0
        }
    }

    return linhas
}

RP_AvancarGridMovDocQuatroLinhas() {
    CoordMode("Mouse", "Client")
    ultimoY := MOVDOC_GRID_ROWS_Y[MOVDOC_GRID_ROWS_Y.Length]
    Click(MOVDOC_CONTA_X + 15, ultimoY + 8, 1)
    Sleep RP_KEY_SETTLE_MS

    Loop MOVDOC_GRID_ROWS_Y.Length {
        if RP_MovDocPopupWindowVisible() {
            RP_DismissMovDocPopup()
            return Map("popup", true)
        }

        Send "{Down}"
        Sleep RP_KEY_SETTLE_MS
    }

    if RP_MovDocPopupWindowVisible() {
        RP_DismissMovDocPopup()
        return Map("popup", true)
    }

    primeiroY := MOVDOC_GRID_ROWS_Y[1]
    Click(MOVDOC_CONTA_X + 15, primeiroY + 8, 1)
    Sleep RP_KEY_SETTLE_MS
    return Map("popup", false)
}

RP_ColetarLinhasVisiveisMovDoc(protocolo, linhas, vistos, avisos := []) {
    added := 0

    ; Primeiro os 4 checkboxes, depois qualquer leitura de conta/convênio.
    devolvidos := RP_LerDevolvidosVisiveis()

    for i, rowY in MOVDOC_GRID_ROWS_Y {
        ; Linha devolvida: o número da conta é lido só para o relatório final
        ; (é o que o operador precisa para conferir), e a linha não entra em
        ; `linhas` — que é a origem de RP_ConvenioMajoritario, de
        ; RP_FiltrarContasPorConvenio e de tudo que vai para o FFCV.
        if RP_LinhaDevolvida(devolvidos, i) {
            contaDev := RP_ReadMovDocGridField(MOVDOC_CONTA_X, rowY, "conta")
            if (contaDev != "" && contaDev != protocolo) {
                ; Marca em `vistos` para a mesma conta devolvida vista em outra
                ; página da grid não gerar o aviso duas vezes. A chave é menor que
                ; a da linha normal de propósito: aqui não se lê o convênio, e
                ; `protocolo|conta` nunca colide com `protocolo|conta|convênio`.
                chave := protocolo "|" contaDev
                if !vistos.Has(chave) {
                    vistos[chave] := true
                    avisos.Push(Map("protocolo", protocolo, "conta", contaDev,
                        "descricao", "Conta devolvida"))
                    Notify("Conta " contaDev " devolvida — não segue para a remessa.")
                }
            } else {
                Notify("Aviso: linha " i " marcada como devolvida, mas não consegui ler a conta dela.")
            }
            continue
        }

        conta := RP_ReadMovDocGridField(MOVDOC_CONTA_X, rowY, "conta")
        convenio := RP_ReadMovDocGridField(MOVDOC_CONVENIO_X, rowY, "convenio")

        if (conta = protocolo || convenio = protocolo || conta = "" || convenio = "")
            continue

        if (conta = convenio)
            conta := RP_ReadMovDocGridField(MOVDOC_CONTA_X, rowY, "conta")

        if (conta = "" || convenio = "")
            continue

        key := protocolo "|" conta "|" convenio
        if vistos.Has(key)
            continue

        vistos[key] := true
        linhas.Push(Map("protocolo", protocolo, "conta", conta, "convenio", convenio))
        added++
    }

    return added
}

RP_ConvenioMajoritario(linhas) {
    counts := Map()
    ordem := []

    for _, linha in linhas {
        convenio := linha["convenio"]
        if !counts.Has(convenio) {
            counts[convenio] := 0
            ordem.Push(convenio)
        }
        counts[convenio] += 1
    }

    escolhido := ""
    maior := 0
    for _, convenio in ordem {
        if (counts[convenio] > maior) {
            maior := counts[convenio]
            escolhido := convenio
        }
    }
    return escolhido
}

RP_FiltrarContasPorConvenio(linhas, convenioEscolhido, erros) {
    protocolContas := Map()

    for _, linha in linhas {
        protocolo := linha["protocolo"]
        conta := linha["conta"]
        convenio := linha["convenio"]

        if (convenio != convenioEscolhido) {
            erros.Push(Map("protocolo", protocolo, "conta", conta, "descricao", "Convênio diferente: " convenio))
            continue
        }

        if !protocolContas.Has(protocolo)
            protocolContas[protocolo] := []
        protocolContas[protocolo].Push(Map("conta", conta, "convenio", convenio))
    }

    return protocolContas
}

RP_MovDocPopupVisible() {
    return WinExist(WIN_MOVDOC_POPUP)
}

RP_MovDocPopupWindowVisible() {
    return WinExist(WIN_MOVDOC_POPUP)
}

RP_DismissMovDocPopup() {
    try {
        if WinExist(WIN_MOVDOC_POPUP) {
            WinActivate WIN_MOVDOC_POPUP
            Sleep RP_KEY_SETTLE_MS
            if !MV_ClickFirstControl(WIN_MOVDOC_POPUP, MV_MODAL_OK_CLASS)
                Send "{Enter}"
            return MV_Poll(() => !WinExist(WIN_MOVDOC_POPUP), 3)
        }
    }
    return false
}

RP_FinalizarBaixaProtocolo() {
    ; Checkbox Recebido: estado vem do controle Button1.
    ; Regra validada pelo usuário: 0 → click simples; 1 → double click.
    checked := MV_ControlCheckedAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)

    if (checked = 0 || checked = "") {
        if !MV_ClickControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)
            return false
    } else if (checked = 1) {
        if !MV_DoubleClickControlAt(WIN_MOVDOC_BAIXA, MOVDOC_CHECK_RECEBIDO_CLASS, MOVDOC_CHECK_RECEBIDO_X, MOVDOC_CHECK_RECEBIDO_Y)
            return false
    } else {
        return false
    }

    Sleep RP_KEY_SETTLE_MS

    ; Fluxo validado: checkbox → F10 → clicar campo Protocolo → F7.
    ; Não há popup de confirmação aqui; o próximo F8 valida a consulta pela grid legível.
    Send "{F10}"
    Sleep RP_KEY_SETTLE_MS

    if !RP_FocusProtocoloMovDocByClick()
        return false

    Sleep RP_KEY_SETTLE_MS
    Send "{F7}"
    Sleep RP_KEY_SETTLE_MS
    return true
}

RP_FocusProtocoloMovDocByClick() {
    if !WinExist(WIN_MOVDOC_BAIXA)
        return false

    WinActivate WIN_MOVDOC_BAIXA
    if !MV_Poll(() => WinActive(WIN_MOVDOC_BAIXA), 2)
        return false

    CoordMode("Mouse", "Client")
    Click(MOVDOC_PROTOCOLO_X + 40, MOVDOC_PROTOCOLO_Y + 10, 1)
    return true
}

RP_WaitMovDocFirstGridLineReady(protocolo, &primeiraLinhaValida) {
    startedAt := A_TickCount
    deadline := startedAt + 12000

    Loop {
        conta := RP_ReadMovDocGridField(MOVDOC_CONTA_X, MOVDOC_GRID_ROWS_Y[1], "conta", 150, 300)
        convenio := RP_ReadMovDocGridField(MOVDOC_CONVENIO_X, MOVDOC_GRID_ROWS_Y[1], "convenio", 150, 300)

        if (conta != "" && convenio != "" && conta != protocolo && convenio != protocolo) {
            Notify("MOV DOC: primeira linha legível após F8 em " (A_TickCount - startedAt) "ms.")
            primeiraLinhaValida := Map("protocolo", protocolo, "conta", conta, "convenio", convenio)
            return true
        }

        if (A_TickCount >= deadline)
            return false

        Sleep 100
    }
}

RP_ReadMovDocGridField(x, y, campo := "", fastTimeoutMs := 150, fallbackTimeoutMs := 300) {
    if !WinExist(WIN_MOVDOC_BAIXA)
        return ""

    WinActivate WIN_MOVDOC_BAIXA
    if !MV_Poll(() => WinActive(WIN_MOVDOC_BAIXA), 2)
        return ""
    CoordMode("Mouse", "Client")

    Click(x + 15, y + 8, 1)
    Sleep RP_KEY_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}")

    valor := RP_CopySelectedText(fastTimeoutMs)
    if RP_GridValueValid(valor, campo)
        return valor

    valor := RP_CopySelectedText(fallbackTimeoutMs)
    if RP_GridValueValid(valor, campo)
        return valor

    return ""
}

RP_CopySelectedText(timeoutMs := 500) {
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(timeoutMs / 1000)
        return ""
    return Trim(A_Clipboard)
}

RP_GridValueValid(valor, campo := "") {
    valor := Trim(valor)
    if (valor = "")
        return false
    if !RegExMatch(valor, "^\d+$")
        return false
    if (campo = "convenio" && StrLen(valor) >= 4)
        return false
    if (campo = "conta" && StrLen(valor) < 5)
        return false
    return true
}

RP_WaitLoadingAfterF8() {
    ; Mantida para compatibilidade; o fluxo principal usa RP_WaitMovDocFirstGridLineReady.
    return MV_Poll(() => WinExist(WIN_MOVDOC_BAIXA), MV_TIMEOUT_LOAD)
}

RP_WaitLoadingAfterSave() {
    ; Mantida para compatibilidade. O fluxo validado não espera popup após F10;
    ; prepara nova consulta com clique no protocolo + F7.
    return WinExist(WIN_MOVDOC_BAIXA)
}

; ════════════════════════════════════════════════════════════════
;  FASE FFCV
; ════════════════════════════════════════════════════════════════

RP_AbrirManutencaoRemessaFFCV() {
    ; Sempre abre um novo Manutenção de Remessa via atalho, mesmo que já exista um aberto.
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    if !MV_WaitWindowStable(MV_WIN_FFCV_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
        return false

    ; Atalho validado no macro 03: Lançamentos → Manutenção de Remessa.
    Send "{Alt down}lm{Alt up}{Enter}"

    if !MV_Poll(() => WinExist(MV_WIN_FFCV_REMESSA), MV_TIMEOUT_LOAD)
        return false

    return MV_WaitWindowStable(MV_WIN_FFCV_REMESSA, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD)
}

CarregarConvenioFFCV(convenioNum) {
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    Send "{F7}"
    Sleep RP_KEY_SETTLE_MS
    SendText convenioNum
    Sleep RP_KEY_SETTLE_MS
    Send "{F8}"
    return RP_WaitFFCVLoad()
}

PosicionarAreaRemessas() {
    Send "{Tab 3}"
    Sleep RP_KEY_SETTLE_MS
}

SelecionarRemessaExistente(numRemessa) {
    Send "{F7}"
    Sleep RP_KEY_SETTLE_MS
    SendText numRemessa
    Sleep RP_KEY_SETTLE_MS
    Send "{F8}"
    return RP_WaitFFCVLoad()
}

CriarNovaRemessa(tipoConta) {
    Send "{F6}"
    Sleep RP_KEY_SETTLE_MS

    hoje := FormatTime(, "dd/MM/yyyy")
    SendText hoje
    Sleep RP_KEY_SETTLE_MS
    Send "{Tab 3}"
    Sleep RP_KEY_SETTLE_MS
    SendText RP_TipoContaCodigo(tipoConta)
    Sleep RP_KEY_SETTLE_MS
    Send "{F10}"
    return RP_WaitFFCVLoad()
}

RP_TipoContaCodigo(tipoConta) {
    switch tipoConta {
        case "Emergência": return "1"
        case "Internamento": return "2"
        case "Ambulatório": return "3"
        default: return ""
    }
}

InserirContasNaRemessa(protocolContas, tipoConta, erros) {
    totalContas := ContarContas(protocolContas)
    contaIdx := 0
    okCount := 0
    erroCount := 0
    blockerCount := 0

    if !RP_AbrirConfigurarPopupContas(tipoConta)
        return false

    for protocolo, contas in protocolContas {
        for _, contaObj in contas {
            contaIdx++
            numConta := contaObj["conta"]
            Notify("Enviando conta " numConta " [prot. " protocolo "]")

            outcome := EnviarConta(numConta)
            if (outcome["status"] = "modal") {
                ; RP_WaitContaSubmitOutcome já classificou o modal. Não repetir classificação aqui.
                erroConta := outcome["erro"]

                ; Regra validada: conta já digitada é continuável; fecha só o modal Forms e segue no mesmo popup.
                if (erroConta["tipo"] != "conta_ja_digitada") {
                    erros.Push(Map("protocolo", protocolo, "conta", numConta, "descricao", erroConta["descricao"]))
                    erroCount++
                } else {
                    okCount++
                }

                dismissResult := RP_DismissActiveModal()
                if !dismissResult["ok"] {
                    blockerCount++
                    return RP_Abort("Modal de erro apareceu após a conta " numConta ", mas não consegui fechar o popup de erro.")
                }

                if !MV_Poll(() => RP_FFCVContaPopupVisible(), MV_TIMEOUT_ACOE) {
                    blockerCount++
                    return RP_Abort("Modal foi fechado, mas o popup de conta não voltou/estabilizou após a conta " numConta ".")
                }
            } else if (outcome["status"] = "ready") {
                okCount++
                ; Popup permanece aberto para a próxima conta.
            } else {
                blockerCount++
                return RP_Abort("Estado incerto após enviar conta " numConta ": " outcome["erro"])
            }

            Progress(60 + (contaIdx / totalContas) * 25)
        }
    }

    Notify("Resumo inserção FFCV: ok=" okCount " erro/modal=" erroCount " bloqueio=" blockerCount " total=" totalContas)

    if !RP_CloseContaPopupAndWait(5000)
        return RP_Abort("Lote de contas terminou, mas não consegui fechar o popup de conta com Alt+2.")

    return true
}

RP_AbrirConfigurarPopupContas(tipoConta) {
    if !RP_EnsureFFCVActive()
        return RP_Abort("FFCV não ficou ativa antes de clicar em Inserir Conta.")

    if !MV_ClickBySpec(MV_WIN_FFCV_ANY, FFCV_BTN_ADICIONAR, 24, 458)
        return RP_Abort("Não consegui clicar em Inserir Conta no FFCV.")

    popupReady := RP_WaitContaPopupReady(5000)
    if !popupReady["ok"]
        return RP_Abort(popupReady["erro"])
    Notify("Popup Informações da Conta detectado em " popupReady["elapsed"] "ms.")

    if MV_ActiveModalTitle() != "" && !RP_FFCVContaPopupVisible() {
        if !MV_PollMs(() => MV_ActiveModalTitle() = "" || RP_FFCVContaPopupVisible(), 1200)
            return RP_Abort("Modal apareceu antes do popup de conta e não foi resolvido: " RP_SafeWinGetText(MV_ActiveModalTitle()))
    }

    if !RP_EnsureFFCVActive()
        return RP_Abort("FFCV não ficou ativa antes dos atalhos do popup de conta.")

    stable := RP_WaitContaPopupStable(300)
    if !stable["ok"]
        return RP_Abort(stable["erro"])

    if !ConfigurarDropdownsPopup(tipoConta)
        return RP_Abort("Não consegui configurar o popup de conta por atalhos.")

    Notify("Popup de conta configurado e mantido aberto para o lote.")
    return true
}

RP_WaitContaPopupAfterOpen(timeoutSecs := 5) {
    ready := RP_WaitContaPopupReady(timeoutSecs * 1000)
    return ready["ok"]
}

RP_FFCVContaPopupVisible() {
    sentinel := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "ui60Drawn", FFCV_POPUP_CONTA_SENTINEL_X, FFCV_POPUP_CONTA_SENTINEL_Y, 35)
    if !sentinel
        return false

    campoConta := MV_FindControlByClientPoint(MV_WIN_FFCV_ANY, POPUP_CAMPO_CONTA, POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 35)
    if !campoConta
        campoConta := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "Edit", POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 50)

    if !campoConta
        campoConta := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "ComboBox", POPUP_DROPDOWN_1_X, POPUP_DROPDOWN_1_Y, 40)

    if !campoConta
        campoConta := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "ComboBox", POPUP_DROPDOWN_2_X, POPUP_DROPDOWN_2_Y, 40)

    return campoConta != 0
}

RP_EnsureFFCVActive(timeoutSecs := 3) {
    if !WinExist(MV_WIN_FFCV_ANY)
        return false
    WinActivate MV_WIN_FFCV_ANY
    return MV_Poll(() => WinActive(MV_WIN_FFCV_ANY), timeoutSecs)
}

RP_WaitContaPopupReady(timeoutMs) {
    startedAt := A_TickCount
    Loop {
        if RP_FFCVContaPopupVisible()
            return Map("ok", true, "modal", false, "elapsed", A_TickCount - startedAt, "erro", "")

        if MV_ActiveModalTitle() != "" {
            if MV_PollMs(() => MV_ActiveModalTitle() = "" || RP_FFCVContaPopupVisible(), Min(800, timeoutMs))
                continue
            return Map("ok", true, "modal", true, "elapsed", A_TickCount - startedAt, "erro", "")
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "modal", false, "elapsed", A_TickCount - startedAt, "erro", "Popup Informações da Conta não apareceu após Inserir Conta em " timeoutMs "ms. Verifique sentinela ui60Drawn no ponto Client " FFCV_POPUP_CONTA_SENTINEL_X "," FFCV_POPUP_CONTA_SENTINEL_Y " e campo da conta em " POPUP_CAMPO_CONTA_X "," POPUP_CAMPO_CONTA_Y ".")

        Sleep 20
    }
}

RP_WaitContaPopupStable(stableMs := 300, timeoutMs := 1200) {
    startedAt := A_TickCount
    stableSince := 0
    Loop {
        if RP_FFCVContaPopupVisible() {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= stableMs)
                return Map("ok", true, "erro", "")
        } else {
            stableSince := 0
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "erro", "Popup de conta não estabilizou por " stableMs "ms dentro de " timeoutMs "ms.")

        Sleep 20
    }
}

RP_WaitReadyForNextAccount(timeoutMs := 1000) {
    startedAt := A_TickCount

    Loop {
        if MV_ActiveModalTitle() != "" {
            result := RP_DismissActiveModal()
            if !result["ok"]
                return false
        }

        if RP_FFCVContaPopupVisible()
            return true

        if (A_TickCount - startedAt >= timeoutMs)
            return false

        Sleep 20
    }
}

RP_CloseContaPopupAndWait(timeoutMs := 5000) {
    ; Regra: manter o popup aberto durante o lote e fechar com Alt+2 somente ao final.
    if !RP_FFCVContaPopupVisible()
        return true

    if !RP_EnsureFFCVActive()
        return false

    Send "!2"
    Sleep RP_KEY_SETTLE_MS
    Send "{Enter}"

    startedAt := A_TickCount
    Loop {
        if (!RP_FFCVContaPopupVisible() && (MV_ActiveModalTitle() = "")) {
            Sleep FFCV_CONTA_STABLE_MS
            return true
        }
        if (A_TickCount - startedAt >= timeoutMs)
            return false
        Sleep 20
    }
}

RP_FindControlByClassPrefixAtPoint(winTitle, classPrefix, targetX, targetY, tolerance := 35) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    bestHwnd := 0
    bestDist := 999999

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue

        if (SubStr(ctrlClass, 1, StrLen(classPrefix)) != classPrefix)
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

; Estado do checkbox "Devolvido" de uma linha da grid do MOV DOC.
; O ClassNN é FIXO por posição de linha (MOVDOC_CHECK_DEVOLVIDO_CLASSES), então
; a busca é por igualdade exata via MV_FindControlByClientPoint — sem prefixo e
; sem heurística de proximidade. A coordenada serve só para confirmar que o
; controle encontrado é o da linha certa e não a mesma coluna de outra linha.
; Retorna "" quando não encontra ou não consegue ler — distinto de 0 (não
; marcado); o chamador trata os três estados.
RP_CheckGridDevolvido(indiceLinha) {
    if (indiceLinha < 1 || indiceLinha > MOVDOC_GRID_ROWS_Y.Length)
        return ""

    hwnd := MV_FindControlByClientPoint(
        WIN_MOVDOC_BAIXA,
        MOVDOC_CHECK_DEVOLVIDO_CLASSES[indiceLinha],
        MOVDOC_CHECK_DEVOLVIDO_X,
        MOVDOC_GRID_ROWS_Y[indiceLinha],
        MOVDOC_CHECK_DEVOLVIDO_TOL)
    if !hwnd
        return ""
    try return ControlGetChecked(hwnd)
    catch
        return ""
}

; Lê o Devolvido das 4 LINHAS VISÍVEIS de uma vez, antes de qualquer leitura de
; conta/convênio. Ler tudo primeiro é o que garante que nenhuma linha escape da
; checagem: a linha-semente (1ª linha) é empurrada em outro ponto do fluxo e
; passaria por cima de uma checagem feita só dentro do laço de cópia.
; Devolve um Map indiceLinha(1..4) -> 0/1.
RP_LerDevolvidosVisiveis() {
    estado := Map()
    for i, _ in MOVDOC_GRID_ROWS_Y
        estado[i] := RP_CheckGridDevolvido(i)
    return estado
}

; Verdadeiro quando a linha está marcada como devolvida. Um checkbox ilegível
; ("") NÃO conta como devolvida: tratar como devolvida descartaria uma conta
; válida, e o operador perderia faturamento. O ilegível vira aviso no log.
RP_LinhaDevolvida(estado, indiceLinha) {
    v := estado[indiceLinha]
    if (v = "")
        Notify("Aviso: não consegui ler o checkbox Devolvido da linha " indiceLinha
            ". Seguindo como NÃO devolvida — conferir a conta depois.")
    return (v = 1)
}

ConfigurarDropdownsPopup(tipoConta) {
    ; Fonte de verdade: macro 11.
    ; Popup aberto uma única vez; Tab x3 → dropdown 1 → Down x2 → sequência do tipo → campo conta.
    if !RP_EnsureFFCVActive()
        return false

    if (tipoConta = "Internamento") {
        Send "{Tab 3}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Down 2}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Tab}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Tab 2}"
        Sleep RP_KEY_SETTLE_MS
    } else if (tipoConta = "Emergência" || tipoConta = "Ambulatório") {
        Send "{Tab 3}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Down 2}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Tab 2}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Up 2}"
        Sleep RP_KEY_SETTLE_MS
        Send "{Tab}"
        Sleep RP_KEY_SETTLE_MS
    } else {
        return false
    }

    return true
}

EnviarConta(numConta) {
    envio := RP_LimparCampoContaEnviar(numConta)
    if !envio["ok"]
        return envio

    outcome := RP_WaitContaSubmitOutcome(FFCV_CONTA_SUBMIT_TIMEOUT_MS, numConta)
    if (outcome["status"] = "modal")
        return outcome

    if !RP_WaitReadyForNextAccount(FFCV_CONTA_SUBMIT_TIMEOUT_MS)
        return Map("status", "blocker", "erro", "Não consegui estabilizar o popup de conta após inserir " numConta ".", "texto", "", "report", "❌ Falha ao aguardar popup ou modal após a conta " numConta ".`n")

    return outcome
}

RP_LimparCampoContaEnviar(numConta) {
    if !RP_FFCVContaPopupVisible()
        return Map("ok", false, "erro", "Popup de conta não está visível antes de limpar/enviar a conta " numConta ".", "texto", "", "report", "❌ Popup de conta não está visível antes de limpar/enviar a conta " numConta ".`n")
    if !RP_EnsureFFCVActive()
        return Map("ok", false, "erro", "FFCV não ficou ativa antes de limpar/enviar a conta " numConta ".", "texto", "", "report", "❌ FFCV não ficou ativa antes de limpar/enviar a conta " numConta ".`n")

    CoordMode("Mouse", "Client")
    Click(POPUP_CAMPO_CONTA_X + 15, POPUP_CAMPO_CONTA_Y + 8, 1)
    Sleep RP_FIELD_FOCUS_SETTLE_MS
    Send("{Home}{Shift down}{End}{Shift up}{Backspace}")
    Sleep RP_FIELD_CLEAR_SETTLE_MS
    SendText numConta
    Send "{Enter}"
    return Map("ok", true, "erro", "", "texto", "", "report", "✅ Campo da conta clicado, limpo, conta digitada e Enter enviado: " numConta "`n")
}

RP_GetContaFieldText() {
    hwnd := RP_FindControlByClassPrefixAtPoint(MV_WIN_FFCV_ANY, "Edit", POPUP_CAMPO_CONTA_X, POPUP_CAMPO_CONTA_Y, 35)
    if !hwnd
        return ""
    try return Trim(ControlGetText(hwnd))
    catch
        return ""
}

RP_WaitContaSubmitOutcome(timeoutMs, submittedConta := "") {
    startTick := A_TickCount
    deadline := startTick + timeoutMs
    stableSince := 0
    emptySince := 0

    Loop {
        popup := RP_ActiveContaErrorModalTitle()
        if (popup != "") {
            erro := ClassificarErroContaModal()
            return Map("status", "modal", "erro", erro, "texto", "", "report", "ℹ️ Modal Forms detectado após Enter: " erro["descricao"] " [" erro["fonte"] "]`n")
        }

        fieldText := RP_GetContaFieldText()
        if (submittedConta != "" && fieldText != submittedConta && fieldText = "") {
            if (emptySince = 0)
                emptySince := A_TickCount
            if (A_TickCount - emptySince >= FFCV_CONTA_FIELD_EMPTY_MIN_MS)
                return Map("status", "ready", "erro", "", "texto", "", "report", "✅ Campo esvaziou após " Round((A_TickCount - startTick) / 1000, 2) "s; liberado para próxima conta.`n")
        } else {
            emptySince := 0
        }

        if RP_FFCVContaPopupVisible() {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - startTick >= FFCV_CONTA_READY_MIN_MS && A_TickCount - stableSince >= FFCV_CONTA_STABLE_MS)
                return Map("status", "ready", "erro", "", "texto", "", "report", "✅ Nenhum modal após " Round((A_TickCount - startTick) / 1000, 2) "s; popup está estável para próxima conta.`n")
        } else {
            stableSince := 0
        }

        if (A_TickCount > deadline) {
            if (stableSince != 0 && A_TickCount - stableSince >= FFCV_CONTA_STABLE_MS)
                return Map("status", "ready", "erro", "", "texto", "", "report", "✅ Nenhum modal após " Round((A_TickCount - startTick) / 1000, 2) "s; popup está estável para próxima conta.`n")
            return Map("status", "timeout", "erro", "Timeout aguardando modal ou popup estável após Enter.", "texto", "", "report", "❌ Timeout aguardando modal ou popup estável após Enter.`n")
        }

        Sleep 15
    }
}

RP_WaitErrorModalAfterConta(timeoutSecs) {
    deadline := A_TickCount + timeoutSecs * 1000
    Loop {
        popup := MV_ActiveModalTitle()
        if (popup != "")
            return popup
        if (A_TickCount > deadline)
            return ""
        Sleep MV_POLL_MS
    }
}

RP_ActiveContaErrorModalTitle() {
    return WinExist("Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE")
        ? "Forms ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"
        : ""
}

RP_DismissActiveModal() {
    popup := MV_ActiveModalTitle()
    if (popup = "")
        return Map("ok", true, "report", "")

    try {
        WinActivate popup
        Sleep RP_KEY_SETTLE_MS

        if !MV_Poll(() => RP_FirstControlByClass(popup, MV_MODAL_OK_CLASS) != 0, 5)
            return Map("ok", false, "report", "❌ Modal existe, mas o botão OK não ficou disponível em tempo.")

        if !MV_ClickFirstControl(popup, MV_MODAL_OK_CLASS)
            return Map("ok", false, "report", "❌ Não consegui clicar OK do modal.")

        if !MV_Poll(() => !WinExist(popup), MV_TIMEOUT_ACOE)
            return Map("ok", false, "report", "❌ Cliquei OK, mas o modal não fechou em tempo.")

        Sleep FFCV_CONTA_STABLE_MS
        return Map("ok", true, "report", "✅ OK do modal clicado e janela fechada/estabilizada.`n")
    }
    return Map("ok", false, "report", "❌ Exceção ao tentar fechar o modal.")
}

RP_FirstControlByClass(winTitle, classNN) {
    try hwnds := WinGetControlsHwnd(winTitle)
    catch
        return 0

    for hwnd in hwnds {
        try ctrlClass := ControlGetClassNN(hwnd)
        catch
            continue
        if (ctrlClass = classNN)
            return hwnd
    }
    return 0
}

RP_SafeWinGetText(winTitle) {
    try text := WinGetText(winTitle)
    catch as e
        return "<erro WinGetText: " e.Message ">"

    text := Trim(text)
    if (text = "" || text = "&OK" || text = "&Sim`r`n&Não" || text = "&Não`r`n&Sim")
        return text "`n<observação: Oracle Forms pode desenhar a mensagem em ui60Drawn; WinGetText pode expor só botões.>"
    return text
}

ClassificarErroContaModal() {
    popup := RP_ActiveContaErrorModalTitle()
    if (popup != "")
        return FFCV_ClassifyErrorModal(popup)

    return Map("tipo", "erro_desconhecido", "descricao", "Erro modal não classificado", "fonte", "sem modal Forms", "texto", "", "img", "")
}

RP_ErrorTemplateVisible(imagePath, variation := 35) {
    popup := MV_ActiveModalTitle()
    return FFCV_ErrorTemplateVisible(imagePath, popup, variation)
}

ClassificarErro(textoPopup) {
    global ERR_CONVENIO_DIFERENTE, ERR_CONTA_ABERTA, ERR_CONTA_JA_EM_REMESSA, ERR_TIPO_DIFERENTE

    lower := StrLower(textoPopup)
    if InStr(lower, StrLower(ERR_CONVENIO_DIFERENTE))
        return "Conta de outro convênio"
    if InStr(lower, StrLower(ERR_CONTA_ABERTA))
        return "Conta aberta"
    if InStr(lower, StrLower(ERR_CONTA_JA_EM_REMESSA))
        return "Conta já em remessa"
    if InStr(lower, StrLower(ERR_TIPO_DIFERENTE))
        return "Conta de tipo diferente"

    texto := Trim(textoPopup)
    if (texto = "" || texto = "&OK" || InStr(texto, "<observação: Oracle Forms"))
        return "Erro ao inserir conta: modal Forms sem texto acessível"

    return texto
}

RP_WaitFFCVLoad() {
    ; Não há popup de confirmação no FFCV nesses passos. Esta função é só um micro-settle
    ; para o Oracle Forms consumir F8/F10; a validação real acontece na próxima ação observável
    ; (popup de conta, tela de datas, XML gerado etc.).
    Sleep RP_KEY_SETTLE_MS
    return WinExist(MV_WIN_FFCV_ANY)
}

RP_WaitAnyModalOrDelay(timeoutSecs) {
    return MV_Poll(() => WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), timeoutSecs)
}

; ════════════════════════════════════════════════════════════════
;  FASE FINALIZAÇÃO / XML
; ════════════════════════════════════════════════════════════════

FinalizarSemDatas() {
    ImprimirRelatorioAtendimentos()
}

ImprimirRelatorioAtendimentos() {
    if !RP_EnsureFFCVActive() {
        Notify("Erro: FFCV não ficou ativa antes de imprimir relatório de atendimentos.")
        return false
    }

    if !MV_ClickControlAt(MV_WIN_FFCV_ANY, FFCV_BTN_IMPRIMIR, FFCV_BTN_IMPRIMIR_X, FFCV_BTN_IMPRIMIR_Y) {
        Notify("Erro: não consegui clicar em Relatório Atendimentos.")
        return false
    }

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD) {
        Notify("Erro: janela Relatório de Atendimentos da Remessa não apareceu.")
        return false
    }

    WinActivate WIN_CAPA_REMESSA
    Sleep RP_KEY_SETTLE_MS
    Send "{Enter}"
    MV_Poll(() => !WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
    Notify("Relatório de atendimentos confirmado para impressão.")
    return true
}

FinalizarComDatas(dataEntrega, dataVenc) {
    if !RP_EnsureFFCVActive()
        return Map("ok", false, "erro", "FFCV não ficou ativa antes de abrir a tela de fechar remessa/datas.")

    startedAt := A_TickCount
    ; Mesmo contrato do teste 12: botão por ClassNN + ponto Client validado.
    if !MV_ClickBySpec(MV_WIN_FFCV_ANY, FFCV_BTN_ABRIR_DATAS, 464, 458)
        return Map("ok", false, "erro", "Não consegui clicar em Entregar Remessa.")

    if !MV_Poll(() => WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de fechar remessa/datas não abriu.")
    Notify("Tela de datas detectada em " (A_TickCount - startedAt) "ms.")

    datas := RP_PreencherDatasEntregaPorTeclado(dataEntrega, dataVenc)
    if !datas["ok"]
        return Map("ok", false, "erro", datas["erro"])
    numRemessa := datas["remessa"]

    checkedFecharContas := MV_ControlCheckedAt(WIN_FFCV_DATAS, MV_DATAS_CHECKBOX, MV_DATAS_CHECKBOX_X, MV_DATAS_CHECKBOX_Y, 20)
    if (checkedFecharContas = 0) {
        if !MV_ClickBySpec(WIN_FFCV_DATAS, MV_DATAS_CHECKBOX, MV_DATAS_CHECKBOX_X, MV_DATAS_CHECKBOX_Y)
            return Map("ok", false, "erro", "Não consegui marcar 'Fechar contas sem imprimir faturas'.")
    } else if (checkedFecharContas = "") {
        return Map("ok", false, "erro", "Não consegui ler o estado de 'Fechar contas sem imprimir faturas'.")
    }
    Sleep MV_DELAY_INPUT

    if !MV_ClickBySpec(WIN_FFCV_DATAS, MV_DATAS_BTN_CONFIRMAR, MV_DATAS_BTN_CONFIRMAR_X, MV_DATAS_BTN_CONFIRMAR_Y)
        return Map("ok", false, "erro", "Não consegui confirmar a entrega da remessa.")

    if !RP_WaitAnyModalOrDelay(MV_TIMEOUT_ACOE)
        return Map("ok", false, "erro", "Popup de confirmação não apareceu.")
    if !RP_ClickNaoModal()
        return Map("ok", false, "erro", "Não consegui clicar Não no popup de confirmação.")
    if !MV_WaitModalGone(RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Popup de confirmação foi acionado, mas não fechou/estabilizou em tempo.")

    if !MV_Poll(() => WinExist(WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
        return Map("ok", false, "erro", "Tela de impressão não apareceu.")
    if !MV_EnsureWindowActive(WIN_CAPA_REMESSA)
        return Map("ok", false, "erro", "Tela de impressão apareceu, mas não ficou ativa para confirmar.")
    if !MV_WaitOracleSettled(WIN_CAPA_REMESSA, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Tela de impressão apareceu, mas não estabilizou antes do Enter.")

    Send "{Enter}"
    if !MV_WaitWindowGone(WIN_CAPA_REMESSA, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Enter enviado na tela de impressão, mas ela não fechou em tempo.")

    if !MV_WaitOracleSettled(WIN_FFCV_DATAS, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "Após a impressão, a tela de Entrega de Remessas não estabilizou para sair.")

    if !RP_SairTelaEntrega()
        return Map("ok", false, "erro", "Ctrl+Q não fechou a tela de Entrega de Remessas. Sem essa saída o fluxo não consegue chegar ao XML.")
    if !MV_WaitOracleSettled(MV_WIN_FFCV_ANY, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return Map("ok", false, "erro", "FFCV não estabilizou após sair da tela Entrega de Remessas.")

    return Map("ok", true, "remessa", Trim(numRemessa))
}

RP_SairTelaEntrega() {
    if !MV_EnsureWindowActive(WIN_FFCV_DATAS) {
        Notify("Não consegui ativar a tela Entrega de Remessas para enviar o atalho de saída.")
        return false
    }

    Send MV_SAIR_TELA_ATALHO
    return MV_Poll(() => !WinExist(WIN_FFCV_DATAS), MV_TIMEOUT_ACOE)
}

RP_PreencherDatasEntregaPorTeclado(dataEntrega, dataVenc) {
    if !MV_EnsureWindowActive(WIN_FFCV_DATAS)
        return Map("ok", false, "erro", "Tela de datas não ficou ativa para preencher entrega/vencimento.", "remessa", "")

    ; Contrato validado no teste 12:
    ; ancorar foco em Data de Entrega, Shift+Tab seleciona Remessa, Tab volta
    ; para Data de Entrega, Enter avança para Data Prevista. Não usar Ctrl+A.
    CoordMode("Mouse", "Client")
    Click(MV_DATAS_CAMPO_ENTREGA_X + 15, MV_DATAS_CAMPO_ENTREGA_Y + 8, 1)
    Sleep RP_KEY_SETTLE_MS

    Send("+{Tab}")
    Sleep RP_KEY_SETTLE_MS
    numRemessa := RP_CopyFocusedNumericText(600)
    if (numRemessa = "")
        return Map("ok", false, "erro", "Não consegui copiar o número da remessa via Shift+Tab na tela de datas.", "remessa", "")

    Send("{Tab}")
    Sleep RP_KEY_SETTLE_MS
    SendText MV_NormalizarDataBr(dataEntrega)
    Sleep RP_KEY_SETTLE_MS
    Send("{Enter}")
    Sleep RP_KEY_SETTLE_MS
    SendText MV_NormalizarDataBr(dataVenc)
    Sleep RP_KEY_SETTLE_MS

    ; Conferência de ida e volta, como no Fechar&XML: se o FFCV recusar o
    ; formato, o log precisa dizer qual campo divergiu.
    Notify("Conferência de datas na tela — entrega: "
        MV_CompararDataTela(WIN_FFCV_DATAS, MV_DATAS_CAMPO_ENTREGA_X, MV_DATAS_CAMPO_ENTREGA_Y, dataEntrega)
        "; vencimento: "
        MV_CompararDataTela(WIN_FFCV_DATAS, MV_DATAS_CAMPO_VENCIMENTO_X, MV_DATAS_CAMPO_VENCIMENTO_Y, dataVenc))

    Notify("Datas enviadas por teclado. Remessa " numRemessa ", entrega " MV_NormalizarDataBr(dataEntrega) ", vencimento " MV_NormalizarDataBr(dataVenc) ".")

    return Map("ok", true, "erro", "", "remessa", numRemessa)
}

GerarXML(numRemessa) {
    global gWorkDir

    if !RP_AbrirTelaTISS()
        return RP_Abort("Erro: tela XML/TISS não abriu.")

    if !MV_SetTextByClickNoClear(WIN_XML, MV_XML_CAMPO_REMESSA_X, MV_XML_CAMPO_REMESSA_Y, numRemessa)
        return RP_Abort("Não consegui preencher a remessa na tela XML/TISS.")
    Sleep RP_KEY_SETTLE_MS
    Send "{F8}"

    queryReady := RP_WaitXmlQueryReady(RP_FINAL_ACTION_TIMEOUT_MS)
    if !queryReady["ok"]
        return RP_Abort(queryReady["erro"])
    Notify("Consulta XML/TISS estabilizada em " queryReady["elapsed"] "ms.")

    if !MV_ClickBySpec(WIN_XML, MV_XML_BTN_FATURAMENTO, MV_XML_BTN_FATURAMENTO_X, MV_XML_BTN_FATURAMENTO_Y)
        return RP_Abort("Não consegui acionar o botão Faturamento na tela XML/TISS.")

    faturamento := RP_WaitXmlFormOrModal(MV_TIMEOUT_LOAD)
    if !faturamento["ok"]
        return RP_Abort(faturamento["erro"])

    xmlDir := gWorkDir "\XML"
    if !DirExist(xmlDir)
        DirCreate xmlDir

    xmlPath := xmlDir "\" numRemessa ".xml"

    if !MV_SetTextByClickAt(WIN_XML_PATH_FORM, MV_XML_FORM_CAMPO_PATH_X, MV_XML_FORM_CAMPO_PATH_Y, xmlPath)
        return RP_Abort("Não consegui preencher o campo de caminho do XML.")

    if !MV_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return RP_Abort("Tela de caminho do XML não estabilizou antes de salvar.")

    if !MV_ClickBySpec(WIN_XML_PATH_FORM, MV_XML_FORM_BTN_SALVAR, MV_XML_FORM_BTN_SALVAR_X, MV_XML_FORM_BTN_SALVAR_Y)
        return RP_Abort("Não consegui acionar o botão Salvar_XML.")

    if !RP_HandleXmlSaveModals()
        return false

    if !MV_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        return RP_Abort("Após salvar o XML, a tela não estabilizou para voltar.")

    if !MV_ClickBySpec(WIN_XML_PATH_FORM, MV_XML_FORM_BTN_VOLTAR, MV_XML_FORM_BTN_VOLTAR_X, MV_XML_FORM_BTN_VOLTAR_Y)
        return RP_Abort("Não consegui voltar da tela de XML gerado.")
    if !MV_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, RP_FINAL_ACTION_TIMEOUT_MS)
        Notify("Aviso: a tela de XML não confirmou estabilidade após Voltar; tentando sair mesmo assim.")

    RP_SairTelaAtual()
    return true
}

RP_AbrirTelaTISS() {
    ; Sempre abre uma nova instância da tela funcional. Não reutilizar TISS já aberta.
    if !RP_EnsureFFCVActive()
        return false

    startedAt := A_TickCount

    ; Atalho: Lançamentos → Monitoração de Faturamento - TISS.
    ; Confirmado contra o MV2000i pelo operador. Spy em Fluxos\Teste_corrigido.ahk L314.
    ; Constante canônica em mv_session.ahk: MV_TISS_ATALHO.
    Send MV_TISS_ATALHO

    ok := MV_Poll(() => WinExist(WIN_XML), MV_TIMEOUT_LOAD)
    if ok
        Notify("Tela XML/TISS detectada em " (A_TickCount - startedAt) "ms.")
    return ok
}

RP_CopyFocusedText() {
    A_Clipboard := ""
    Send "^c"
    MV_Poll(() => A_Clipboard != "", 3)
    return Trim(A_Clipboard)
}

RP_CopyFocusedNumericText(timeoutMs := 600) {
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(timeoutMs / 1000)
        return ""

    value := Trim(A_Clipboard)
    if RegExMatch(value, "\d+", &m)
        return m[0]
    return ""
}

RP_WaitXmlQueryReady(timeoutMs := 30000) {
    startedAt := A_TickCount
    stableSince := 0

    Loop {
        modal := MV_ActiveModalTitle()
        if (modal != "")
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "Modal apareceu após consultar a remessa no XML/TISS: " RP_SafeWinGetText(modal))

        minWaitDone := (A_TickCount - startedAt >= RP_XML_QUERY_MIN_WAIT_MS)
        if (minWaitDone
            && MV_ControlAtReady(WIN_XML, MV_XML_BTN_FATURAMENTO, MV_XML_BTN_FATURAMENTO_X, MV_XML_BTN_FATURAMENTO_Y, 20)
            && A_Cursor != "Wait" && A_Cursor != "AppStarting") {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= RP_FINAL_STABLE_MS)
                return Map("ok", true, "elapsed", A_TickCount - startedAt, "erro", "")
        } else {
            stableSince := 0
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "Consulta da remessa no XML/TISS não estabilizou em " timeoutMs "ms.")

        Sleep MV_POLL_MS
    }
}

RP_WaitXmlFormOrModal(timeoutSecs := 20) {
    startedAt := A_TickCount
    deadline := startedAt + timeoutSecs * 1000

    Loop {
        if WinExist(WIN_XML_PATH_FORM)
            return Map("ok", true, "erro", "")

        popup := MV_ActiveModalTitle()
        if (popup != "") {
            if MV_ClickModalButtonByText(popup, "&OK") {
                ; Modal pós-1 Faturamento é continuável. Não depender do texto desenhado.
                MV_Poll(() => !WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), MV_TIMEOUT_ACOE)
            } else {
                return Map("ok", false, "erro", "Modal após 1 Faturamento apareceu, mas não encontrei botão &OK acessível.")
            }
        }

        if (A_TickCount >= deadline)
            return Map("ok", false, "erro", "Tela de XML gerado não apareceu após tratar possíveis modais em " timeoutSecs "s.")

        Sleep MV_POLL_MS
    }
}

RP_HandleXmlSaveModals() {
    Loop 5 {
        if !MV_Poll(() => WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), 2) {
            if (A_Index = 1)
                Notify("Nenhum modal apareceu imediatamente após salvar XML; aguardando estabilização da tela.")
            if MV_WaitOracleSettled(WIN_XML_PATH_FORM, RP_FINAL_STABLE_MS, 5000)
                return true
            continue
        }

        popup := MV_ActiveModalTitle()

        ; Modal de sobrescrita: tem Sim e Não. Regra atual: não sobrescrever.
        if MV_ModalHasButton(popup, "&Sim") && MV_ModalHasButton(popup, "&Não") {
            if MV_ClickModalButtonByText(popup, "&Não")
                Notify("Modal com Sim/Não respondido com Não.")
            else
                return RP_Abort("Modal com Sim/Não apareceu, mas não consegui clicar Não.")
        } else if MV_ModalHasButton(popup, "&OK") {
            if MV_ClickModalButtonByText(popup, "&OK")
                Notify("Modal informativo do XML fechado com OK.")
            else
                return RP_Abort("Modal com OK apareceu, mas não consegui clicar OK.")
        } else {
            return RP_Abort("Modal do XML apareceu, mas não encontrei botão seguro (&Não ou &OK).")
        }

        if !MV_Poll(() => !WinExist("ahk_class ui60Modal_W32 ahk_exe ifrun60.EXE"), MV_TIMEOUT_ACOE)
            return RP_Abort("Modal do XML foi acionado, mas não fechou em tempo.")
    }
    return RP_Abort("XML não estabilizou após salvar e tratar modais.")
}

RP_ClickNaoModal() {
    if WinExist(WIN_XML_POPUP_SIMNAO)
        return MV_ClickFirstControl(WIN_XML_POPUP_SIMNAO, MV_XML_BTN_NAO)
    popup := MV_ActiveModalTitle()
    if (popup != "")
        return MV_ClickFirstControl(popup, MV_XML_BTN_NAO)
    return false
}

RP_SairTelaAtual() {
    Send MV_SAIR_TELA_ATALHO
    Sleep MV_DELAY_INPUT
    return true
}

RP_SetControlText(winTitle, classNN, value, label) {
    if (classNN = "" || classNN = "CLASSNN")
        return RP_Abort("Falta mapear " label ".")
    try {
        ControlSetText value, classNN, winTitle
        Sleep MV_DELAY_INPUT
        return true
    } catch as e {
        return RP_Abort("Falha ao preencher " label ": " e.Message)
    }
}

ParseProtocolos(str) {
    result := []
    for _, p in StrSplit(str, ",") {
        p := Trim(p)
        if (p != "")
            result.Push(p)
    }
    return result
}

ContarContas(protocolContas) {
    total := 0
    for _, contas in protocolContas
        total += contas.Length
    return total
}

RP_RecordTiming(timings, label, startedAt, extra := "") {
    elapsedMs := A_TickCount - startedAt
    timings.Push(Map("label", label, "ms", elapsedMs, "extra", extra))
    Notify("⏱ " label ": " MV_FormatDuration(elapsedMs) (extra != "" ? " | " extra : ""))
    return elapsedMs
}

RP_FormatTimingReport(timings) {
    report := "⏱ Tempos da execução:`n"
    for _, item in timings {
        extra := item["extra"] != "" ? " | " item["extra"] : ""
        report .= "  - " item["label"] ": " MV_FormatDuration(item["ms"]) extra "`n"
    }
    return report
}

RP_Abort(msg) => MV_Abort(msg)

Notify(msg) => SendToUI(Map("type", "log", "message", msg))
Progress(v) {
    static lastProgress := ""
    normalized := Max(0, Min(100, Round(v)))
    if (lastProgress != "" && normalized = lastProgress)
        return
    lastProgress := normalized
    SendToUI(Map("type", "progress", "value", normalized))
}
Done(msg)    => SendToUI(Map("type", "done", "message", msg))
