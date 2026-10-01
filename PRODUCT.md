# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Existing codebase built around AutoHotkey v2 for desktop automation and a WebView2 interface using HTML/CSS/JS. The app is a Windows desktop utility, not a browser app, but the UI surface is implemented as a webview frontend and therefore the design work should be treated as web-UI execution within the desktop shell.

## Users

Primary users are hospital billing operators and administrative staff who execute repetitive faturamento workflows in the MV2000i system. Their work is time-sensitive, operational, and high-risk if a task is routed incorrectly or a screen is not closed in the right sequence.

Secondary users are developers and support staff validating automation, updating workflow rules, and packaging the desktop app for hospital deployment.

## Product Purpose

Praxis automates recurring financial and movement tasks in the MV2000i hospital management system, reducing manual navigation, repeated data entry, and operational errors. The product exists to keep the operator focused on confirmation and exception handling instead of low-value, repetitive keystroke work.

Success means the workflow executes with predictable Windows automation, preserves the operator’s control over exceptions, and produces correct remessas and XML outputs without introducing silent failures.

## Positioning

Praxis is a specialist automation layer for a specific hospital billing workflow, not a generalized ERP tool. Its differentiator is the combination of desktop automation, OCR-based error handling, WebView2 workflow UI, and validated operational guardrails tailored to Oracle Forms 6i screens.

## Operating Context

- The product runs on Windows desktop machines for hospital staff.
- It automates Oracle Forms 6i screens and MV2000i workflows, notably MOV DOC and FFCV.
- Operators work through a sidebar-driven desktop UI that presents scripted modules and dynamic forms.
- The system depends on real hospital process knowledge, screen titles, keyboard shortcuts, and operational validation against the live MV2000i environment.
- The work happens in an environment where the cost of a wrong automation step is a bad remessa, a wrong document state, or a silent transactional error.

## Capabilities and Constraints

Confirmed capabilities:

- Execute predefined billing and movement scripts for remessa por protocolo, protocolar, and fechar XML.
- Present a module launcher with per-script parameters and runtime progress/logging.
- Communicate between AutoHotkey and the WebView2 UI via postMessage JSON.
- Use keyboard-driven automation, OCR-based error recognition, and spreadsheet/clipboard-based validation patterns.
- Support packaging and installation through the project’s build and installer workflow.

Confirmed constraints:

- The app is a desktop automation tool, not a general-purpose business app.
- Automations must preserve MV2000i state and screen transitions; silent misclassification is a critical failure.
- The project explicitly favors known valid shortcuts and validated patterns over inferred or guessed UI coordinates.
- Files such as config.ini and dist/ output are local runtime artifacts and not part of the source of truth.
- The project places strong emphasis on operator control, exception handling, and explicit validation against the real system before treating a workflow as trusted.

## Brand Commitments

The project name is Praxis. The user-facing language and documented identity are in Brazilian Portuguese. The UI presently follows a legacy Windows desktop aesthetic rather than a modern SaaS style: deep blue header, light gray panel surfaces, classic form controls, and a utility-first operational feel.

No broader brand or marketing identity was identified beyond the product name, hospital context, and this operational design language.

## Evidence on Hand

Real project evidence includes:

- [README.md](README.md) — product overview, workflow catalog, installation notes, and validation status.
- [ui/index.html](ui/index.html) — the actual app shell, module sidebar, form structure, and visual language.
- [scripts/mv_session.ahk](scripts/mv_session.ahk) — shared MV2000i session contracts and automation primitives.
- [scripts/remessa_protocolo.ahk](scripts/remessa_protocolo.ahk) — primary validated workflow.
- [AGENTS.md](AGENTS.md) — repository rules, operational constraints, and failure modes.

No product claims are being added beyond the evidence above. Future work must not fabricate pricing, customer names, deployment claims, or broader product positioning not present in the repo.

## Product Principles

1. Keep the operator in control of exceptions and confirmations.
2. Prefer known-good MV2000i contracts and keyboard flows over guessed automation.
3. Treat silent failure as the highest-risk defect and preserve validation gates.
4. Build operational clarity into the workflow, not just speed.
5. Keep the desktop utility reliable, explicit, and institution-specific rather than generic.

## Accessibility & Inclusion

The product is designed for hospital staff working in controlled operational environments, with emphasis on clarity over aesthetics and on a deterministic workflow for operators. The codebase includes keyboard-first automation assumptions, and the UI is intentionally functional and high-contrast for desktop operation.

No additional product-specific accessibility requirements beyond operational legibility, clear controls, and robust error handling were identified in the repo.
