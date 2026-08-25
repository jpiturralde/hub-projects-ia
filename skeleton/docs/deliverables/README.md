# Client deliverables — working copy (NOT canonical)

This folder holds material **presented and iterated with the client** in meetings and partial deliveries for **{{INITIATIVE_ID}} — {{INITIATIVE_DISPLAY_NAME}}**: diagrams, notes, documents, and other supporting artifacts.

> **Not canonical.**  
> Working copy for delivery. Every new or confirmed fact here must be **ported** to the appropriate canonical file before continuing.

## Promotion flow

Material arrives here **promoted from** [`docs/draft/`](../draft/README.md) when the deliverable is ready for client handoff:

- `.md` / `.docx` → `docs/deliverables/`
- Diagramas listos para el cliente → `docs/deliverables/diagrams/`

Use `git mv` to preserve history. CDD `cdd-archive` puede registrar la promoción y sincronizar canónicos en `docs/diagrams/`.

## Current files

| File | Purpose |
|------|---------|
| *(add when starting each deliverable)* | |

## Canonical locations — where each type lands

| If you confirm or discover… | Canonical location |
|-----------------------------|---------------------|
| AS-IS ArchiMate model | **Archi** + export `docs/diagrams/{{ARCHIMATE_EXPORT_FILENAME}}` |
| Narrative architecture | `ARCHITECTURE.md` |
| Technical C4 diagrams | `docs/diagrams/puml/`, `docs/diagrams/drawio/` |
| Open gaps and questions | [`docs/architecture-gaps-and-questions.md`](../architecture-gaps-and-questions.md) |
| Scope | `SPEC.md` |
| Operational backlog | `backlog.md` + `backlog/tasks/` |
| Minutes | `backlog/meetings/AAAA-MM-DD-*.md` |
| Raw transcripts | `transcripts/` (immutable by default) |
| Formal client material | [`docs/client-documentation/`](../client-documentation/) |

## Critical rule · Deliverables must not expose this internal repository

Anything here **leaves the repo for the client**. Do not include internal repo paths, internal tool names, or references to how this documentation was produced.

Project rules: `.cursor/rules/client-deliverables.mdc`.

## Naming

- **Suggested pattern:** `{{DOC_TITLE_PREFIX}} - <deliverable-name>.<ext>`
- **Notes that do not fit the canvas:** sibling `.md` next to the main artifact.
