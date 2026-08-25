# Draft — accompaniment documents

**Markdown** sources and Pandoc-generated **`.docx`** drafts for engagement **{{INITIATIVE_ID}} — {{INITIATIVE_DISPLAY_NAME}}**.

## File layout

| File | Role |
|------|------|
| `{{DOC_TITLE_PREFIX}} - [Deliverable-name].md` | Main source (sections 1–4). |
| `{{DOC_TITLE_PREFIX}} - [Deliverable-name] - Notes [Topic].md` | Annex source (section 5+). |
| `{{DOC_TITLE_PREFIX}} - [Deliverable-name] - draft.docx` | Pandoc output (artifact). |
| `remove-bookmarks.lua` | Pandoc filter — strips auto bookmarks for Google Docs. |
| `diagrams/` | Client-facing diagrams under review (not canonical). |

## Promotion flow

Borradores viven aquí hasta cerrar la entrega:

1. **Fuentes canónicas** (`docs/diagrams/`, `ARCHITECTURE.md`, Archi) → portar hechos confirmados a `docs/draft/*.md` o adaptar vistas a `docs/draft/diagrams/`.
2. **CDD `cdd-apply`** escribe **solo** en `docs/draft/` (y `docs/draft/diagrams/` si aplica).
3. **Al cerrar entrega**: promover con `git mv` a `docs/deliverables/` (`.md`, `.docx`) o `docs/deliverables/diagrams/` (diagramas listos para el cliente).
4. Actualizar la tabla "Current files" en [`docs/deliverables/README.md`](../deliverables/README.md).

## Regenerating the draft

See `.cursor/rules/deliverable-draft-workflow.mdc`.

Minimal command (adapt filenames):

```bash
cd "docs/draft" && pandoc \
  "{{DOC_TITLE_PREFIX}} - [Deliverable-name].md" \
  -o "{{DOC_TITLE_PREFIX}} - [Deliverable-name] - draft.docx" \
  --reference-doc="../../templates/{{CORPORATE_DOCX_TEMPLATE_NAME}}" \
  --lua-filter="remove-bookmarks.lua"
```

> Prerequisite: Pandoc installed and `docs/templates/{{CORPORATE_DOCX_TEMPLATE_NAME}}` present.

## Current files

| File | Purpose |
|------|---------|
| *(empty — add each draft when started)* | |
