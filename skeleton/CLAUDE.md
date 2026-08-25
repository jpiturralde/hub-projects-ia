# Proyecto Ingenia (desde template) — {{DOC_TITLE_PREFIX}}

Repositorio de **documentación y arquitectura** del encargo (consultoría **{{CONSULTANCY_NAME}}**{{PARTNER_TEAM_SUFFIX}}). No es código de producto: el valor está en `docs/`, diagramas, backlog y entregables.

## Contexto inicial

@PROJECT-CONTEXT.md

No cargar README, SPEC, ARCHITECTURE, transcripts ni documentación cliente completa al inicio. Abrir sólo el índice y hasta dos archivos necesarios para el objetivo actual.

## Instalación y MCP

- Prerrequisitos (Node, Backlog.md, Archi, Draw.io): abrir `docs/MCP-PREREQUISITOS.md` sólo cuando se configure una integración.
- **Claude Desktop / Cowork:** abrir `docs/MCP-CLAUDE-DESKTOP.md` sólo si se usa esa capa.

## Convenciones que no negociar

- **`transcripts/`**: registro fiel de reuniones; **no** editar, borrar ni renombrar salvo instrucción explícita del usuario para ese archivo. Derivados van en `docs/` o `backlog/meetings/`. Detalle: reglas bajo `.claude/rules/` cuando trabajes en esa rama del árbol.
- **`docs/draft/`** y **`docs/deliverables/`**: flujo de borradores y entregables según reglas del proyecto en `.cursor/rules/` (referencia humana y agente en el IDE); en Cowork, pedí confirmación antes de promover a `docs/deliverables/` si hay duda.
- **ArchiMate / Draw.io**: export canónico `docs/diagrams/{{ARCHIMATE_EXPORT_FILENAME}}`; vistas `{{ARCHIMATE_VIEWS_FILENAME}}` donde aplique.

## Claude Cowork (VM) vs herramientas en el host

Cowork ejecuta parte del trabajo en una **VM aislada**. Comandos que en el IDE del host asumís en el PATH del sistema (Pandoc, `npx`, `backlog`, pipelines DOCX) **pueden no estar disponibles** allí. Para regenerar `.docx` o scripts PowerShell documentados, usá **terminal local** o el **IDE en el host** salvo que hayáis validado lo contrario en vuestra versión de Claude Desktop.

## Cumplimiento

Si el encargo es regulado o exige trazabilidad tipo audit log, revisá la política interna: la documentación pública de Cowork advierte limitaciones frente a cargas con requisitos formales de auditoría.
