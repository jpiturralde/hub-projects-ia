---
paths:
  - "docs/draft/**"
  - "docs/deliverables/**"
  - "docs/diagrams/**/*.drawio"
  - "docs/diagrams/**/*.xml"
---

# Entregables y diagramas

- **`docs/draft/`**: borradores Pandoc/Markdown hacia DOCX; seguí el flujo descrito en `.cursor/rules/deliverable-draft-workflow.mdc` (referencia para humanos y el agente en el IDE). Diagramas en revisión: `docs/draft/diagrams/`.
- **`docs/deliverables/`**: working copy orientada al cliente promovida desde draft; puede divergir del modelo canónico. No tratar como única fuente de arquitectura sin contrastar con `ARCHITECTURE.md`, `SPEC.md` y el export ArchiMate bajo `docs/diagrams/`. Diagramas listos: `docs/deliverables/diagrams/`.
- **Draw.io / ArchiMate**: respetá nombres de archivo del encargo (export XML y vistas `.drawio` definidos en el README del repo).
