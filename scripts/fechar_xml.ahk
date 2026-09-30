; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0

; ════════════════════════════════════════════════════════════════
;  FECHAR E GERAR XML
; ════════════════════════════════════════════════════════════════
; Parâmetros da tela:
;   remessas         -> números das remessas separados por vírgula. Ex: 511458, 514015
;   data_entrega    -> data de entrega
;   data_vencimento -> data de vencimento
;
; Spec: .agents\workflows\03-fechar-xml.md
;
; ── Escopo (armadilhas desta casa) ───────────────────────────────
; NÃO declarar #Include aqui. `mv_session.ahk` e `lib\FFCV_ErrorTemplates.ahk`
; chegam a este arquivo por include TRANSITIVO (main.ahk → remessa_protocolo.ahk).
; Um #Include novo duplicaria todas as funções MV_* e quebraria o build.
;
; NÃO chamar funções RP_*. Os fluxos são autônomos: helper equivalente que só
; existe no remessa_protocolo.ahk é replicado aqui com prefixo FX_.
;
; Saída somente por Notify / Progress / Done e pelo abort FX_Abort.
; Nada de Gui, MsgBox, ToolTip ou hotkey.

; ── Constantes locais ───────────────────────────────────────────
; FFCV_BTN_ABRIR_DATAS vive no remessa_protocolo.ahk (prefixo RP_). Replicado aqui
; com o MESMO ClassNN e o MESMO ponto Client para manter os fluxos independentes.
; PENDENTE: não revalidado neste fluxo — só o workflow 01 rodou contra o MV2000i.
FX_BTN_ABRIR_DATAS   := "Button6"  ; 5 - Entregar Rem.
FX_BTN_ABRIR_DATAS_X := 464
FX_BTN_ABRIR_DATAS_Y := 458

; Espera máxima do modal de confirmação/recusa logo após confirmar a entrega.
FX_MODAL_CONFIRMACAO_TIMEOUT_SEG := 10

; ════════════════════════════════════════════════════════════════
;  ENTRADA DO MÓDULO
; ════════════════════════════════════════════════════════════════

RunFecharXML(params) {
    global gRunning

    remessas       := FX_ParseRemessas(params["remessas"])
    dataEntrega    := Trim(params["data_entrega"])
    dataVencimento := Trim(params["data_vencimento"])

    if (remessas.Length = 0)
        return FX_Abort("Informe o número das remessas. Ex: 511458, 514015")
    if (dataEntrega = "")
        return FX_Abort("Informe a data de entrega.")
    if (dataVencimento = "")
        return FX_Abort("Informe a data de vencimento.")

    Notify("Fechar e Gerar XML: " remessas.Length " remessa(s), entrega " dataEntrega ", vencimento " dataVencimento ".")

    if !MV_EnsureFFCV()
        return FX_Abort("Não foi possível acessar o FFCV. Abra e autentique o FFCV no MV2000i e tente de novo.")

    totalStart  := A_TickCount
    fechadas    := 0
    xmlPulados  := 0
    pendencias  := []

    for idx, remessa in remessas {
        stageStart := A_TickCount
        Notify("Remessa " remessa " (" idx "/" remessas.Length "): fechando...")

        resultado := FX_ProcessarRemessa(remessa, dataEntrega, dataVencimento)

        ; O finally do módulo sempre roda: devolve o FFCV ao menu para a próxima.
        FX_RecuperarTelas()

        if (resultado["estado"] = "fatal") {
            FX_LogResumo(fechadas, xmlPulados, pendencias, totalStart)
            return FX_Abort(resultado["erro"])
        }

        if (resultado["estado"] = "fechada") {
            fechadas++
            if (resultado["xml"] = "pulado")
                xmlPulados++
            else if (resultado["xml"] = "erro")
                pendencias.Push(Map("remessa", remessa, "motivo", resultado["erro"]))
        } else {
            pendencias.Push(Map("remessa", remessa, "motivo", resultado["erro"]))
        }

        Notify("⏱ Remessa " remessa ": " MV_FormatDuration(A_TickCount - stageStart) " | " resultado["estado"] " (XML: " resultado["xml"] ")")
        Progress(Round(100 * idx / remessas.Length))
    }

    Progress(100)

    ; Saída obrigatória do fluxo: fecha a última tela do FFCV. A recuperação por remessa
    ; acima devolve o FFCV ao menu entre iterações; aqui fecha-se o fluxo.
    MV_FecharUltimaTela(MV_WIN_FFCV_ANY, "FFCV")

    FX_LogResumo(fechadas, xmlPulados, pendencias, totalStart)

    relatorio := "Fechamento e XML concluídos.`n`n"
    relatorio .= "Remessas informadas: " remessas.Length "`n"
    relatorio .= "Fechadas: " fechadas "`n"
    relatorio .= "XML pulado (arquivo já existia): " xmlPulados "`n"
    relatorio .= "Com pendência: " pendencias.Length "`n"
    relatorio .= "Tempo total: " MV_FormatDuration(A_TickCount - totalStart) "`n"
    relatorio .= "`nDetecção de 'remessa já fechada' é PENDENTE: não existe referência OCR"
    relatorio .= " em lib\FFCV_ErrorReferences.json para esse texto. Hoje qualquer modal não"
    relatorio .= " reconhecido na confirmação do fechamento vira pendência e a lista continua —"
    relatorio .= " comportamento mais permissivo que o ideal."

    if (pendencias.Length > 0) {
        relatorio .= "`n`nPENDÊNCIAS`n"
        for _, item in pendencias
            relatorio .= "  [[red]]" item["remessa"] " | " item["motivo"] "[[/red]]`n"
    }

    gRunning := false
    Done(relatorio)
    return true
}

FX_ProcessarRemessa(remessa, dataEntrega, dataVencimento) {
    ; Fase 1 — abrir a tela de entrega a partir de uma instância nova da Manutenção de Remessa.
    if !FX_AbrirManutencaoRemessa()
        return FX_EstadoFatal("Não consegui abrir a Manutenção de Remessa no FFCV para a remessa " remessa ".")

    ; Fase 2 — fechar a remessa.
    if !FX_AbrirTelaEntrega()
        return FX_EstadoFatal("A tela de entrega da remessa " remessa " não abriu.")

    preenchimento := FX_PreencherDatasPorTeclado(remessa, dataEntrega, dataVencimento)
    if !preenchimento["ok"]
        return FX_EstadoFatal(preenchimento["erro"])

    fechamento := FX_ConfirmarFechamento(remessa)
    if (fechamento["estado"] = "fatal")
        return FX_EstadoFatal(fechamento["erro"])
    if (fechamento["estado"] = "recusada") {
        ; O MV recusou (remessa já fechada, regra do hospital, etc.). Pendência da remessa:
        ; a lista segue para a próxima em vez de abortar.
        Notify("Remessa " remessa " recusada pelo MV: " fechamento["erro"])
        return Map("estado", "pendencia", "xml", "", "erro", fechamento["erro"])
    }

    ; Fase 3 — gerar o XML.
    xml := FX_GerarXml(remessa)
    return Map("estado", "fechada", "xml", xml["estado"], "erro", xml["erro"])
}

FX_EstadoFatal(erro) => Map("estado", "fatal", "xml", "", "erro", erro)

; ════════════════════════════════════════════════════════════════
;  FASE 1 — ABRIR A TELA DE ENTREGA
; ════════════════════════════════════════════════════════════════

FX_AbrirManutencaoRemessa() {
    ; Sempre instância nova. O original imprimia "Relatório Atend." (Button9) antes de
    ; abrir a entrega; o spec 03 decidiu não incluir — o botão não existe em todas as telas.
    MV_ActivateModule(MV_WIN_FFCV_ANY)
    if !MV_WaitWindowStable(MV_WIN_FFCV_ANY, MV_MODULE_STABLE_MS, MV_TIMEOUT_LOAD)
        return false

    ; Atalho validado no macro 03: Lançamentos → Manutenção de Remessa.
    Send "{Alt down}lm{Alt up}{Enter}"

    if !MV_Poll(() => WinExist(MV_WIN_FFCV_REMESSA), MV_TIMEOUT_LOAD)
        return false

    return MV_WaitWindowStable(MV_WIN_FFCV_REMESSA, MV_TARGET_STABLE_MS, MV_TIMEOUT_LOAD)
}

FX_AbrirTelaEntrega() {
    if !MV_EnsureWindowActive(MV_WIN_FFCV_ANY)
        return false

    startedAt := A_TickCount
    if !MV_ClickBySpec(MV_WIN_FFCV_ANY, FX_BTN_ABRIR_DATAS, FX_BTN_ABRIR_DATAS_X, FX_BTN_ABRIR_DATAS_Y)
        return false

    if !MV_Poll(() => WinExist(MV_WIN_FFCV_DATAS), MV_TIMEOUT_LOAD)
        return false

    Notify("Tela de entrega de datas detectada em " (A_TickCount - startedAt) "ms.")
    return true
}

; ════════════════════════════════════════════════════════════════
;  FASE 2 — PREENCHER DATAS E FECHAR
; ════════════════════════════════════════════════════════════════

FX_PreencherDatasPorTeclado(remessaParam, dataEntrega, dataVencimento) {
    if !MV_EnsureWindowActive(MV_WIN_FFCV_DATAS)
        return Map("ok", false, "erro", "A tela de entrega de datas não ficou ativa para preencher as datas.", "remessaTela", "")

    ; Contrato validado no teste 12: ancorar o foco em Data de Entrega, Shift+Tab chega ao
    ; número da remessa, Tab volta para Data de Entrega.
    ; Digitar caractere a caractere nos campos de data é o que o Forms trata de
    ; forma inconsistente; a escrita é por colar, como no fluxo validado.
    CoordMode("Mouse", "Client")
    Click(MV_DATAS_CAMPO_ENTREGA_X + 15, MV_DATAS_CAMPO_ENTREGA_Y + 8, 1)
    Sleep MV_KEY_SETTLE_MS

    Send("+{Tab}")
    Sleep MV_KEY_SETTLE_MS
    remessaTela := FX_CopyFocusedNumericText(600)

    ; A remessa vem do PARÂMETRO. O valor da tela serve só para conferência/log:
    ; se divergir, o operador precisa saber antes de conferir o FFCV manualmente.
    if (remessaTela != "") {
        if (remessaTela = remessaParam)
            Notify("Conferência: a tela de datas mostra a remessa " remessaTela ".")
        else
            Notify("Atenção: parâmetro " remessaParam " x tela de datas " remessaTela ". Seguindo com o parâmetro.")
    } else {
        Notify("Atenção: não consegui ler o número da remessa na tela de datas. Seguindo com o parâmetro " remessaParam ".")
    }

    ; Navegação e escrita por Tab + colar, como o fluxo validado
    ; (Fechar&XML.ahk:154-158). O Enter entre os campos de data foi removido:
    ; o validado não o usa, e no Oracle Forms ele commitava o campo e podia
    ; disparar a validação antes do segundo campo estar preenchido.
    ; Colar em vez de digitar porque o Forms trata digitação longa de forma
    ; inconsistente nos campos de data.
    Send("{Tab}")
    Sleep MV_KEY_SETTLE_MS
    FX_ColarNoFoco(MV_NormalizarDataBr(dataEntrega))
    Send("{Tab}")
    Sleep MV_KEY_SETTLE_MS
    FX_ColarNoFoco(MV_NormalizarDataBr(dataVencimento))

    ; Conferência de ida e volta: a tela é lida depois do preenchimento para
    ; confirmar que o FFCV recebeu dd/mm/aaaa. Sem isto, um formato divergente
    ; só apareceria como recusa do MV, sem dizer qual campo falhou.
    Notify("Conferência de datas na tela — entrega: "
        MV_CompararDataTela(MV_WIN_FFCV_DATAS, MV_DATAS_CAMPO_ENTREGA_X, MV_DATAS_CAMPO_ENTREGA_Y, dataEntrega)
        "; vencimento: "
        MV_CompararDataTela(MV_WIN_FFCV_DATAS, MV_DATAS_CAMPO_VENCIMENTO_X, MV_DATAS_CAMPO_VENCIMENTO_Y, dataVencimento))

    Notify("Datas enviadas por teclado: entrega " MV_NormalizarDataBr(dataEntrega) ", vencimento " MV_NormalizarDataBr(dataVencimento) ".")
    return Map("ok", true, "erro", "", "remessaTela", remessaTela)
}

; Cola o texto no campo com foco, verificando antes que o clipboard ficou
; exato. Sem essa verificação, uma falha de clipboard vira um campo em branco
; que o FFCV aceita sem reclamar. Espelha o PasteFocused do fluxo validado
; (Fechar&XML.ahk:430-446), sem restauração de cursor: aqui o chamador já
; garante a janela ativa.
FX_ColarNoFoco(texto) {
    anterior := ClipboardAll()
    A_Clipboard := texto
    if !ClipWait(1) {
        A_Clipboard := anterior
        return false
    }
    Send "^a"
    Sleep MV_KEY_SETTLE_MS
    Send "^v"
    Sleep MV_KEY_SETTLE_MS
    A_Clipboard := anterior
    return true
}

FX_CopyFocusedNumericText(timeoutMs := 600) {
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(timeoutMs / 1000)
        return ""

    value := Trim(A_Clipboard)
    if RegExMatch(value, "\d+", &m)
        return m[0]
    return ""
}

FX_ConfirmarFechamento(remessa) {
    ; Checkbox "Fechar contas sem imprimir faturas": estado vem do controle Button3.
    checked := MV_ControlCheckedAt(MV_WIN_FFCV_DATAS, MV_DATAS_CHECKBOX, MV_DATAS_CHECKBOX_X, MV_DATAS_CHECKBOX_Y, 20)
    if (checked = 0) {
        if !MV_ClickBySpec(MV_WIN_FFCV_DATAS, MV_DATAS_CHECKBOX, MV_DATAS_CHECKBOX_X, MV_DATAS_CHECKBOX_Y)
            return FX_EstadoFechamentoFatal("Não consegui marcar 'Fechar contas sem imprimir faturas' na remessa " remessa ".")
    } else if (checked = "") {
        return FX_EstadoFechamentoFatal("Não consegui ler o estado de 'Fechar contas sem imprimir faturas' na remessa " remessa ".")
    }
    Sleep MV_DELAY_INPUT

    if !MV_ClickBySpec(MV_WIN_FFCV_DATAS, MV_DATAS_BTN_CONFIRMAR, MV_DATAS_BTN_CONFIRMAR_X, MV_DATAS_BTN_CONFIRMAR_Y)
        return FX_EstadoFechamentoFatal("Não consegui confirmar a entrega da remessa " remessa ".")

    if !FX_EsperarQualquerModal(FX_MODAL_CONFIRMACAO_TIMEOUT_SEG)
        return FX_EstadoFechamentoFatal("Nenhum modal apareceu após confirmar a entrega da remessa " remessa ".")

    if FX_ResponderNaoModal() {
        ; Caminho validado: modal de confirmação → Não (não imprimir as faturas).
        if !FX_EsperarModalFechar(MV_FINAL_ACTION_TIMEOUT_MS)
            return FX_EstadoFechamentoFatal("Respondi Não no modal de confirmação da remessa " remessa ", mas o modal não fechou em tempo.")

        if !MV_Poll(() => WinExist(MV_WIN_CAPA_REMESSA), MV_TIMEOUT_LOAD)
            return FX_EstadoFechamentoFatal("A tela de impressão da remessa " remessa " não apareceu.")
        if !MV_EnsureWindowActive(MV_WIN_CAPA_REMESSA)
            return FX_EstadoFechamentoFatal("A tela de impressão da remessa " remessa " apareceu, mas não ficou ativa para confirmar.")
        if !MV_WaitOracleSettled(MV_WIN_CAPA_REMESSA, MV_FINAL_STABLE_MS, MV_FINAL_ACTION_TIMEOUT_MS)
            return FX_EstadoFechamentoFatal("A tela de impressão da remessa " remessa " não estabilizou antes do Enter.")

        Send "{Enter}"
        if !MV_WaitWindowGone(MV_WIN_CAPA_REMESSA, MV_FINAL_ACTION_TIMEOUT_MS)
            return FX_EstadoFechamentoFatal("Enviei Enter na tela de impressão da remessa " remessa ", mas ela não fechou em tempo.")

        if !MV_WaitOracleSettled(MV_WIN_FFCV_DATAS, MV_FINAL_STABLE_MS, MV_FINAL_ACTION_TIMEOUT_MS)
            return FX_EstadoFechamentoFatal("Após a impressão, a tela de entrega da remessa " remessa " não estabilizou para sair.")

        if !FX_SairTelaEntrega()
            return FX_EstadoFechamentoFatal("A tela de entrega da remessa " remessa " não fechou com o atalho " MV_SAIR_TELA_ATALHO ". Nenhum WinClose é forçado porque o Oracle Forms perde estado.")

        if !MV_WaitOracleSettled(MV_WIN_FFCV_ANY, MV_FINAL_STABLE_MS, MV_FINAL_ACTION_TIMEOUT_MS)
            return FX_EstadoFechamentoFatal("O FFCV não estabilizou depois de sair da tela de entrega da remessa " remessa ".")

        return Map("estado", "fechada", "erro", "")
    }

    ; Não é o modal de confirmação: o MV recusou o fechamento.
    ; PENDENTE: lib\FFCV_ErrorReferences.json não tem referência para "remessa já fechada",
    ; então FFCV_ClassifyErrorModal devolve "erro_desconhecido" para esse texto. O caso é
    ; tratado como pendência da remessa atual e a lista continua.
    recusa := FX_ClassificarRecusa(remessa)
    if !FX_DescartarModalSeguro()
        return FX_EstadoFechamentoFatal("O MV recusou fechar a remessa " remessa " (" recusa "), e não consegui fechar o modal com segurança.")

    return Map("estado", "recusada", "erro", "MV recusou o fechamento (" recusa "). Modal descartado; a lista segue para a próxima remessa.")
}

FX_EstadoFechamentoFatal(erro) => Map("estado", "fatal", "erro", erro)

FX_ResponderNaoModal() {
    ; Confirmação do FFCV: "Mensagem ao Usuário do MV 2000" com Botão1=Sim / Botão2=Não.
    ; MV_XML_BTN_NAO é o "Button2" compartilhado do contrato de janela (nome legado).
    if WinExist(MV_WIN_MSG_USER)
        return MV_ClickFirstControl(MV_WIN_MSG_USER, MV_XML_BTN_NAO)

    popup := MV_ActiveModalTitle()
    if (popup != "")
        return MV_ClickFirstControl(popup, MV_XML_BTN_NAO)

    return false
}

FX_ClassificarRecusa(remessa) {
    popup := FX_ModalAtivo()
    if (popup = "")
        return "modal sem título reconhecível"

    classificacao := FFCV_ClassifyErrorModal(popup)
    tipo  := classificacao.Get("tipo", "erro_desconhecido")
    texto := Trim(classificacao.Get("texto", ""))
    fonte := classificacao.Get("fonte", "")

    ; Registro o texto bruto do OCR: sem ele não há como criar a referência que falta
    ; em lib\FFCV_ErrorReferences.json quando o MV for capturado com o modal aberto.
    detalhes := "tipo OCR=" tipo
    if (fonte != "")
        detalhes .= " | " fonte
    if (texto != "")
        detalhes .= " | OCR: " (StrLen(texto) > 240 ? SubStr(texto, 1, 240) "…" : texto)
    else
        detalhes .= " | OCR não leu texto"

    Notify("Remessa " remessa ": modal do FFCV -> " detalhes)
    return detalhes
}

FX_SairTelaEntrega() {
    if !MV_EnsureWindowActive(MV_WIN_FFCV_DATAS) {
        Notify("Não consegui ativar a tela de entrega para enviar o atalho de saída.")
        return false
    }

    Send MV_SAIR_TELA_ATALHO
    return MV_Poll(() => !WinExist(MV_WIN_FFCV_DATAS), MV_TIMEOUT_ACOE)
}

; ════════════════════════════════════════════════════════════════
;  FASE 3 — GERAR O XML
; ════════════════════════════════════════════════════════════════

FX_GerarXml(remessa) {
    global gWorkDir

    if (Trim(gWorkDir) = "")
        return Map("estado", "erro", "erro", "WorkDir não configurado. Verifique o config.ini (Paths/WorkDir).")

    xmlDir  := Trim(gWorkDir) "\XML"
    xmlPath := xmlDir "\" remessa ".xml"

    ; Idempotência: nunca sobrescrever. Checar antes evita o processamento pesado do relatório.
    if FileExist(xmlPath) {
        Notify("XML já existe, não sobrescrito: " xmlPath)
        return Map("estado", "pulado", "erro", "")
    }

    if !FX_AbrirTelaTiss()
        return Map("estado", "erro", "erro", "A tela de XML/TISS não abriu para a remessa " remessa ".")

    ; Preenchimento por teclado, como o fluxo validado (Fechar&XML.ahk:328):
    ; {Tab 5} chega ao campo da remessa e o texto é colado. O MV_ClickBySpec
    ; por coordenada ficava aqui, e é o que produz clique cego quando o
    ; ClassNN não casa (docs/analise-causa-raiz/06).
    if !MV_EnsureWindowActive(MV_WIN_XML_TISS)
        return Map("estado", "erro", "erro", "A tela de XML/TISS não ficou ativa para a remessa " remessa ".")
    Send "{Tab 5}"
    Sleep MV_KEY_SETTLE_MS
    if !FX_ColarNoFoco(remessa)
        return Map("estado", "erro", "erro", "Não consegui colar a remessa " remessa " na tela XML/TISS.")
    Send "{F8}"

    consulta := FX_EsperarConsultaXmlPronta(MV_FINAL_ACTION_TIMEOUT_MS)
    if !consulta["ok"]
        return Map("estado", "erro", "erro", consulta["erro"])
    Notify("Consulta XML/TISS da remessa " remessa " estabilizada em " consulta["elapsed"] "ms.")

    if !MV_ClickBySpec(MV_WIN_XML_TISS, MV_XML_BTN_FATURAMENTO, MV_XML_BTN_FATURAMENTO_X, MV_XML_BTN_FATURAMENTO_Y)
        return Map("estado", "erro", "erro", "Não consegui acionar o botão Faturamento na tela XML/TISS da remessa " remessa ".")

    formulario := FX_EsperarFormularioXmlOuModal(MV_TIMEOUT_LOAD)
    if !formulario["ok"]
        return Map("estado", "erro", "erro", formulario["erro"])

    if !DirExist(xmlDir)
        DirCreate xmlDir

    ; Caminho do XML por teclado, como o validado (Fechar&XML.ahk:396-399):
    ; Tab para o campo, cola, Tab e Enter.
    if !MV_EnsureWindowActive(MV_WIN_XML_PATH_FORM)
        return Map("estado", "erro", "erro", "A tela de caminho do XML não ficou ativa para a remessa " remessa ".")
    Send "{Tab}"
    Sleep MV_KEY_SETTLE_MS
    if !FX_ColarNoFoco(xmlPath)
        return Map("estado", "erro", "erro", "Não consegui colar o caminho do XML da remessa " remessa ".")
    if !MV_WaitOracleSettled(MV_WIN_XML_PATH_FORM, MV_FINAL_STABLE_MS, MV_FINAL_ACTION_TIMEOUT_MS)
        return Map("estado", "erro", "erro", "A tela de caminho do XML da remessa " remessa " não estabilizou antes de salvar.")

    if !MV_ClickBySpec(MV_WIN_XML_PATH_FORM, MV_XML_FORM_BTN_SALVAR, MV_XML_FORM_BTN_SALVAR_X, MV_XML_FORM_BTN_SALVAR_Y)
        return Map("estado", "erro", "erro", "Não consegui acionar o botão Salvar_XML da remessa " remessa ".")

    modais := FX_TratarModaisXmlSalvo()
    if !modais["ok"]
        return Map("estado", "erro", "erro", modais["erro"])

    if !MV_WaitOracleSettled(MV_WIN_XML_PATH_FORM, MV_FINAL_STABLE_MS, MV_FINAL_ACTION_TIMEOUT_MS)
        return Map("estado", "erro", "erro", "Após salvar o XML da remessa " remessa ", a tela não estabilizou para voltar.")

    if !MV_ClickBySpec(MV_WIN_XML_PATH_FORM, MV_XML_FORM_BTN_VOLTAR, MV_XML_FORM_BTN_VOLTAR_X, MV_XML_FORM_BTN_VOLTAR_Y)
        return Map("estado", "erro", "erro", "Não consegui voltar da tela de XML da remessa " remessa ".")

    if !MV_WaitOracleSettled(MV_WIN_XML_PATH_FORM, MV_FINAL_STABLE_MS, MV_FINAL_ACTION_TIMEOUT_MS)
        Notify("Aviso: a tela de XML da remessa " remessa " não confirmou estabilidade após Voltar; saindo mesmo assim.")

    Send MV_SAIR_TELA_ATALHO
    Sleep MV_DELAY_INPUT

    if !FileExist(xmlPath)
        return Map("estado", "erro", "erro", "O MV não criou o arquivo " xmlPath ". Confira o relatório do TISS.")

    Notify("XML gerado: " xmlPath)
    return Map("estado", "gerado", "erro", "")
}

FX_AbrirTelaTiss() {
    if !MV_EnsureWindowActive(MV_WIN_FFCV_ANY)
        return false

    startedAt := A_TickCount
    ; Atalho confirmado pelo operador. Constante canônica em mv_session.ahk.
    Send MV_TISS_ATALHO

    ok := MV_Poll(() => WinExist(MV_WIN_XML_TISS), MV_TIMEOUT_LOAD)
    if ok
        Notify("Tela XML/TISS detectada em " (A_TickCount - startedAt) "ms.")
    return ok
}

FX_EsperarConsultaXmlPronta(timeoutMs := 30000) {
    startedAt := A_TickCount
    stableSince := 0

    Loop {
        if (FX_ModalAtivo() != "")
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "Modal apareceu depois de consultar a remessa no XML/TISS: " FX_TextoModalSeguro())

        minWaitOk := (A_TickCount - startedAt >= MV_XML_QUERY_MIN_WAIT_MS)
        if (minWaitOk
            && MV_ControlAtReady(MV_WIN_XML_TISS, MV_XML_BTN_FATURAMENTO, MV_XML_BTN_FATURAMENTO_X, MV_XML_BTN_FATURAMENTO_Y, 20)
            && A_Cursor != "Wait" && A_Cursor != "AppStarting") {
            if (stableSince = 0)
                stableSince := A_TickCount
            if (A_TickCount - stableSince >= MV_FINAL_STABLE_MS)
                return Map("ok", true, "elapsed", A_TickCount - startedAt, "erro", "")
        } else {
            stableSince := 0
        }

        if (A_TickCount - startedAt >= timeoutMs)
            return Map("ok", false, "elapsed", A_TickCount - startedAt, "erro", "A consulta da remessa no XML/TISS não estabilizou em " timeoutMs "ms.")

        Sleep MV_POLL_MS
    }
}

FX_EsperarFormularioXmlOuModal(timeoutSecs := 20) {
    startedAt := A_TickCount
    deadline := startedAt + timeoutSecs * 1000

    Loop {
        if WinExist(MV_WIN_XML_PATH_FORM)
            return Map("ok", true, "erro", "")

        popup := FX_ModalAtivo()
        if (popup != "") {
            ; Modal pós-1 Faturamento é continuável. Não depender do texto desenhado.
            if MV_ClickModalButtonByText(popup, "&OK")
                MV_PollMs(() => FX_ModalAtivo() = "", MV_TIMEOUT_ACOE * 1000)
            else
                return Map("ok", false, "erro", "Modal após 1 Faturamento apareceu, mas não encontrei botão &OK acessível.")
        }

        if (A_TickCount >= deadline)
            return Map("ok", false, "erro", "A tela de caminho do XML não apareceu após tratar possíveis modais em " timeoutSecs "s.")

        Sleep MV_POLL_MS
    }
}

FX_TratarModaisXmlSalvo() {
    ; O fluxo validado exige que o popup de confirmação do MV APAREÇA
    ; (Fechar&XML.ahk:405-422) e lança erro se não aparecer. Sem essa exigência,
    ; "nenhum modal apareceu" era aceito como sucesso — e aí nada distingue
    ; "o MV confirmou" de "o MV não respondeu", que é o mesmo defeito de
    ; verificação do doc 04. `confirmou` só é verdadeiro depois de um popup
    ; tratado com OK, nunca por ausência de popup.
    confirmou := false

    Loop 5 {
        if !MV_PollMs(() => FX_ModalAtivo() != "", 2000) {
            if confirmou
                return Map("ok", true, "erro", "")
            if MV_WaitOracleSettled(MV_WIN_XML_PATH_FORM, MV_FINAL_STABLE_MS, 5000)
                return Map("ok", false,
                    "erro", "O MV não exibiu confirmação ao salvar o XML. O arquivo pode não ter sido gravado.")
            continue
        }

        popup := FX_ModalAtivo()

        ; Modal de sobrescrita: tem Sim e Não. Política do módulo: nunca sobrescrever.
        if (MV_ModalHasButton(popup, "&Sim") && MV_ModalHasButton(popup, "&Não")) {
            if !MV_ClickModalButtonByText(popup, "&Não")
                return Map("ok", false, "erro", "Modal com Sim/Não apareceu, mas não consegui clicar Não.")
            Notify("Modal com Sim/Não respondido com Não (política: não sobrescrever XML).")
        } else if (MV_ClickModalButtonByText(popup, "&OK") || MV_ClickFirstControl(popup, MV_MODAL_OK_CLASS)) {
            Notify("Modal informativo do XML fechado com OK.")
            confirmou := true
        } else {
            return Map("ok", false, "erro", "Modal do XML apareceu, mas não encontrei botão seguro (&Não ou &OK).")
        }

        if !FX_EsperarModalFechar(MV_TIMEOUT_ACOE * 1000)
            return Map("ok", false, "erro", "O modal do XML foi acionado, mas não fechou em tempo.")
    }

    return Map("ok", false, "erro", "O XML não estabilizou após salvar e tratar os modais.")
}

; ════════════════════════════════════════════════════════════════
;  MODAIS, RECUPERAÇÃO E SAÍDA
; ════════════════════════════════════════════════════════════════

FX_ModalAtivo() {
    if WinExist(MV_FORMS_MODAL)
        return MV_FORMS_MODAL
    if WinExist(MV_WIN_MSG_USER)
        return MV_WIN_MSG_USER
    return ""
}

FX_EsperarQualquerModal(timeoutSecs) {
    return MV_PollMs(() => FX_ModalAtivo() != "", timeoutSecs * 1000)
}

FX_EsperarModalFechar(timeoutMs := 30000) {
    return MV_PollMs(() => FX_ModalAtivo() = "", timeoutMs)
}

FX_DescartarModalSeguro() {
    if (FX_ModalAtivo() = "")
        return true

    ; Ordem: rótulo explícito do botão e, em último caso, o primeiro botão do modal.
    ; Nenhuma coordenada é inventada aqui — se não houver botão visível, o fluxo aborta
    ; para o operador resolver na tela em vez de clicar no escuro.
    acoes := [["rotulo", "&OK"], ["rotulo", "&Não"], ["primeiro", MV_MODAL_OK_CLASS]]

    for _, acao in acoes {
        popup := FX_ModalAtivo()
        if (popup = "")
            return true

        clicou := (acao[1] = "rotulo")
            ? MV_ClickModalButtonByText(popup, acao[2])
            : MV_ClickFirstControl(popup, acao[2])

        if clicou && FX_EsperarModalFechar(MV_TIMEOUT_ACOE * 1000)
            return true
    }

    return false
}

FX_TextoModalSeguro() {
    popup := FX_ModalAtivo()
    if (popup = "")
        return "(sem modal)"

    ; WinGetText/Window Spy normalmente expõem só os botões desses modais. A mensagem real
    ; vem do OCR; este texto serve apenas como diagnóstico rápido.
    try texto := Trim(WinGetText(popup))
    catch as e
        texto := "<erro WinGetText: " e.Message ">"

    if (texto = "" || texto = "&OK" || InStr(texto, "&Sim") || InStr(texto, "&Não"))
        return texto " (observação: o Oracle Forms desenha a mensagem em ui60Drawn; use FFCV_ClassifyErrorModal para ler o texto)"

    return texto
}

FX_RecuperarTelas() {
    ; Executado ao fim de cada remessa, inclusive em caso de erro: devolve o FFCV ao menu
    ; para a próxima execução começar de um estado limpo.
    ; NUNCA usar WinClose no Oracle Forms — perde o estado da aplicação.
    try {
        if (FX_ModalAtivo() != "") {
            if FX_DescartarModalSeguro()
                Notify("Recuperação: modal pendente foi fechado.")
            else
                Notify("Recuperação: há um modal aberto e não encontrei botão seguro para fechá-lo. Resolva na tela.")
        }

        if WinExist(MV_WIN_XML_PATH_FORM) {
            Notify("Recuperação: voltando da tela de caminho do XML.")
            MV_ClickBySpec(MV_WIN_XML_PATH_FORM, MV_XML_FORM_BTN_VOLTAR, MV_XML_FORM_BTN_VOLTAR_X, MV_XML_FORM_BTN_VOLTAR_Y)
            Sleep MV_DELAY_INPUT
        }

        if WinExist(MV_WIN_XML_TISS) {
            Notify("Recuperação: saída da tela XML/TISS por " MV_SAIR_TELA_ATALHO ".")
            Send MV_SAIR_TELA_ATALHO
            Sleep MV_DELAY_INPUT
        }

        if WinExist(MV_WIN_FFCV_DATAS) {
            ; Fase 4 do spec: reabrir a tela de entrega a cada iteração exige voltar ao menu.
            ; O MV reaproveita o mesmo HWND ao voltar ao menu, então "a janela sumiu" não é
            ; prova isolada: exigir também a estabilidade do FFCV.
            if MV_EnsureWindowActive(MV_WIN_FFCV_DATAS) {
                Notify("Recuperação: saída da tela de entrega por " MV_SAIR_TELA_ATALHO ".")
                Send MV_SAIR_TELA_ATALHO
                MV_Poll(() => !WinExist(MV_WIN_FFCV_DATAS), MV_TIMEOUT_ACOE)
            } else {
                Notify("Recuperação: a tela de entrega da remessa pode ter ficado aberta.")
            }
        }

        MV_WaitOracleSettled(MV_WIN_FFCV_ANY, MV_FINAL_STABLE_MS, MV_FINAL_ACTION_TIMEOUT_MS)
    } catch as e {
        Notify("Aviso na recuperação de telas: " e.Message)
    }
}

; ════════════════════════════════════════════════════════════════
;  UTILITÁRIOS DO MÓDULO
; ════════════════════════════════════════════════════════════════

FX_ParseRemessas(str) {
    resultado := []
    for _, item in StrSplit(str, ",") {
        remessa := Trim(item)
        if (remessa != "")
            resultado.Push(remessa)
    }
    return resultado
}

FX_LogResumo(fechadas, xmlPulados, pendencias, totalStart) {
    Notify("Resumo: fechadas=" fechadas " | XML pulado=" xmlPulados " | pendências=" pendencias.Length " | total=" MV_FormatDuration(A_TickCount - totalStart))
}

FX_Abort(msg) {
    ; Delega o erro ao contrato compartilhado e só então fecha o status da execução,
    ; como o stub fazia.
    result := MV_Abort(msg)
    SendToUI(Map("type", "status", "message", "Execução finalizada.", "running", false))
    return result
}
