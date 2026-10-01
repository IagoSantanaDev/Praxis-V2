; Praxis — software proprietário
; Copyright (c) 2026 Iago Santana Lima. Todos os direitos reservados.
; Licença: proprietária. Consulte LICENSE, COPYRIGHT e NOTICE.md na raiz do repositório.
; Uso, cópia, modificação, redistribuição ou engenharia reversa somente com autorização expressa.

#Requires AutoHotkey v2.0
#Include lib\teste_lib.ahk

; ════════════════════════════════════════════════════════════════
;  BAIXA COM GATE DE CURSOR — automação real no MV2000i
; ════════════════════════════════════════════════════════════════
;
;  Entra no MOV DOC e, para cada protocolo, repete:
;    ativar -> Alt+M,P,B -> digitar -> F8 -> Button1 -> F10 -> Ctrl+Q
;  esperando o cursor normalizar depois de CADA passo.
;
;  Uso:
;    AutoHotkey64.exe teste_baixa_cursor.ahk 12345,67890
;    AutoHotkey64.exe teste_baixa_cursor.ahk 12345 --dry-run
;
;  Pré-requisito: MOV DOC já aberto e autenticado. Este script não abre e não
;  autentica o MV2000i.
;
;  Este é o gargalo do teste: esperar cursor é NECESSÁRIO, mas não suficiente.
;  A_Cursor é global do sistema — o relógio do MV só aparece com o ponteiro
;  sobre a região ocupada. Se o mouse estiver em outro lugar, A_Cursor devolve
;  "Arrow" com o app ainda processando, e a tecla seguinte vai para o vazio.
;  Por isso toda espera também checa popup, e a saída exige a assinatura de tela
;  mudada — não "ficou estável".
;
;  Emergência: F3 pausa, Esc sai.

F3::Pause -1
Esc::ExitApp

; ════════════════════════════════════════════════════════════════
;  PASSOS
; ════════════════════════════════════════════════════════════════

; Ler a mensagem de um popup do MV exige OCR, que é o plumbing do FFCV e não o
; que este teste mede. Então popup aqui é sinal de PARADA, não de tratamento.
TESTE_PararSePopup(protocolo, etapa) {
    if !TESTE_PopupAberto()
        return

    TESTE_Log("POPUP do MV aberto após " etapa " do protocolo " protocolo
        ". Lote interrompido — a mensagem está na tela, leia antes de rodar de novo.")
    TESTE_Erro("popup do MV aberto após " etapa)
}

TESTE_BaixarProtocolo(protocolo, dryRun) {
    ; ── 1. ativar MOV DOC ──
    if !TESTE_AtivarJanela(TESTE_WIN_MOVDOC_ANY, 5)
        TESTE_Erro("MOV DOC não ficou ativo para o protocolo " protocolo ".")
    TESTE_EsperarCursor("1 ativar MOV DOC")
    TESTE_PararSePopup(protocolo, "1 ativar MOV DOC")

    ; ── 2. navegar para a baixa ──
    TESTE_SendMenuPath(TESTE_MENU_BAIXA)
    TESTE_EsperarCursor("2 " TESTE_MENU_BAIXA " (menu da baixa)")
    TESTE_PararSePopup(protocolo, "2 menu da baixa")

    ; ── 3. tela de baixa aberta e ativa ──
    if !TESTE_EsperarJanela(TESTE_WIN_MOVDOC_BAIXA, 30)
        TESTE_Erro("a tela 'Protocolação de Baixa de Documentos' não abriu para o protocolo "
            protocolo ".")
    if !TESTE_AtivarJanela(TESTE_WIN_MOVDOC_BAIXA, 5)
        TESTE_Erro("a tela de baixa não ficou ativa para o protocolo " protocolo ".")
    TESTE_EsperarCursor("3 abrir tela de baixa")

    if dryRun {
        TESTE_Log("--dry-run: navegação até a baixa concluída. Nada digitado.")
        return
    }

    ; ── 4. digitar o protocolo ──
    ; A tela chega com o foco já no campo — os dois fluxos existentes assumem
    ; isso e nenhum clica antes de digitar. PENDENTE: confirmar no MV real.
    SendText protocolo
    TESTE_EsperarCursor("4 digitar protocolo")
    TESTE_PararSePopup(protocolo, "4 digitar protocolo")

    ; ── 5. F8 ──
    Send "{F8}"
    TESTE_EsperarCursor("5 F8")
    TESTE_PararSePopup(protocolo, "5 F8")

    ; ── 6. Button1 ──
    ; Sem coordenada e sem o fallback por coordenada de MV_ClickBySpec, que
    ; devolve true tanto se clicou no controle quanto se clicou no ponto errado.
    if !TESTE_ClicarPrimeiroControle(TESTE_WIN_MOVDOC_BAIXA, TESTE_BAIXA_BTN)
        TESTE_Erro("não achei " TESTE_BAIXA_BTN " na tela de baixa do protocolo " protocolo ".")
    TESTE_EsperarCursor("6 clicar " TESTE_BAIXA_BTN)
    TESTE_PararSePopup(protocolo, "6 clicar " TESTE_BAIXA_BTN)

    ; ── 7. F10 ──
    Send "{F10}"
    TESTE_EsperarCursor("7 F10")
    TESTE_PararSePopup(protocolo, "7 F10")

    ; ── 8. sair da tela ──
    ; Assinatura pela raiz MDI (fora dos colchetes), que é o título que casa
    ; para SAÍDA. Estabilidade não prova transição: exigimos a mudança.
    assinaturaAntes := TESTE_ScreenSignature(TESTE_WIN_MOVDOC_ANY)
    Send TESTE_SAIR_TELA
    TESTE_EsperarCursor("8 " TESTE_SAIR_TELA)

    if !TESTE_EsperarTelaMudou(TESTE_WIN_MOVDOC_ANY, assinaturaAntes, TESTE_TIMEOUT_SAIDA_MS) {
        TESTE_Erro(TESTE_SAIR_TELA " enviado, mas a tela NÃO mudou (assinatura depois: "
            TESTE_ScreenSignature(TESTE_WIN_MOVDOC_ANY) "). O atalho não teve efeito.")
    }

    if TESTE_ENTER_APOS_CTRLQ {
        Send "{Enter}"
        TESTE_EsperarCursor("8b Enter de confirmação")
    }

    TESTE_Log("protocolo " protocolo " baixado.")
}

; ════════════════════════════════════════════════════════════════
;  EXECUÇÃO
; ════════════════════════════════════════════════════════════════

TESTE_Rodar() {
    TESTE_GuardPadroesProibidos(TESTE_ArquivosDoTeste())

    dryRun := TESTE_TemArg("--dry-run")

    ; Só os argumentos que não são flag viram lista de protocolos.
    entradas := []
    for arg in A_Args {
        if InStr(arg, "--") = 1
            continue
        entradas.Push(arg)
    }

    protocolos := TESTE_ParseLista(entradas)

    if (protocolos.Length = 0)
        TESTE_Erro("informe os protocolos separados por vírgula. Ex: 12345,67890")

    ; Digits-only: evita digitar lixo no campo do MV.
    for protocolo in protocolos {
        if !RegExMatch(protocolo, "^\d+$")
            TESTE_Erro("protocolo inválido: " protocolo " — só dígitos são aceitos.")
    }

    if !WinExist(TESTE_WIN_MOVDOC_ANY)
        TESTE_Erro("MOV DOC não está aberto. Abra e autentique o MV2000i manualmente antes.")

    if WinExist(TESTE_WIN_IDENT)
        TESTE_Erro("janela de Identificação do MV2000i aberta — autentique manualmente.")

    TESTE_Log("=== início: " protocolos.Length " protocolo(s)"
        (dryRun ? ", --dry-run: só navega até a baixa" : "") " ===")

    total := protocolos.Length

    for indice, protocolo in protocolos {
        TESTE_Log("--- " indice "/" total ": protocolo " protocolo " ---")
        TESTE_BaixarProtocolo(protocolo, dryRun)
    }

    TESTE_Log("=== fim: " (dryRun ? total " navegação(ões) concluída(s)" : total " protocolo(s) baixado(s)") " ===")

    ; Nunca fechar o MV aqui: com popup aberto a mensagem é a evidência do
    ; operador, e fechar a tela jogaria fora. O script encerra e deixa a tela.
}

try {
    TESTE_Rodar()
    ExitApp 0
} catch as err {
    TESTE_Log("ERRO: " err.Message)
    TESTE_Log("O MV2000i foi deixado como está. Leia a tela antes de rodar de novo.")
    TESTE_Log("log: " TESTE_LOG_PATH)
    ExitApp 1
}
