# {{INITIATIVE_DISPLAY_NAME}} — {{CLIENT_DISPLAY_NAME}}

> **¿Proyecto recién generado?** Seguí la checklist en [docs/GETTING-STARTED.md](docs/GETTING-STARTED.md) — incluye abrir este repo como workspace raíz y verificar MCP (Engram, etc.).

Repositorio de **documentación y planificación** del encargo **{{INITIATIVE_DISPLAY_NAME}}** ({{CONSULTANCY_NAME}} → {{CLIENT_DISPLAY_NAME}}).

## Documentos principales

| Documento | Para qué sirve |
|-----------|----------------|
| [SPEC.md](SPEC.md) | Alcance, objetivos y contexto (fuente de verdad del «qué»). |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Contexto técnico y decisiones de arquitectura. |
| [backlog.md](backlog.md) | Backlog operativo. |
| [docs/architecture-gaps-and-questions.md](docs/architecture-gaps-and-questions.md) | Brechas y preguntas abiertas. |
| [docs/diagrams/](docs/diagrams/) | Diagramas y export ArchiMate (`{{ARCHIMATE_EXPORT_FILENAME}}`). |
| [docs/draft/](docs/draft/) | Borradores al cliente (Pandoc, diagramas en revisión). |
| [docs/deliverables/](docs/deliverables/) | Entregables promovidos al cliente (no canónico). |
| [transcripts/](transcripts/) | Fuentes crudas de reuniones (inmutables por defecto). |

## IDE, agente y MCP (`.cursor/`)

En editores compatibles (p. ej. Cursor), la configuración local del proyecto suele vivir aquí:

- `.cursor/mcp.json` — MCPs del proyecto (local; ver `.gitignore`). Ejemplo versionado: `.cursor/mcp.json.example`.
- `.cursor/skills/` — skills del agente (onboarding, bootstrap, architect-copilot, transcripts → acciones, entregables, análisis de código).
- Prerrequisitos e instalación por SO (Node, Backlog.md, Archi, Draw.io MCP): [docs/MCP-PREREQUISITOS.md](docs/MCP-PREREQUISITOS.md).

## Capa Anthropic (Claude Cowork / Claude Desktop)

- `CLAUDE.md` — instrucciones persistentes del repo (imports con `@` a README, SPEC, ARCHITECTURE y docs MCP). Si generaste el proyecto con `-IncludeClaudeCoworkLayer:$false`, este archivo no estará presente.
- `.claude/rules/` — reglas por ámbito (p. ej. `transcripts/`, entregables y diagramas). Misma condición que arriba.
- [docs/MCP-CLAUDE-DESKTOP.md](docs/MCP-CLAUDE-DESKTOP.md) — cómo registrar manualmente los mismos servidores MCP en Claude Desktop / Cowork (equivalente operativo a `.cursor/mcp.json` en el IDE).

## Próximos pasos

Ver checklist completa: **[docs/GETTING-STARTED.md](docs/GETTING-STARTED.md)**.

1. Copiar la plantilla Word corporativa a `docs/templates/{{CORPORATE_DOCX_TEMPLATE_NAME}}`.
2. Exportar el modelo ArchiMate a `docs/diagrams/{{ARCHIMATE_EXPORT_FILENAME}}` cuando exista modelo en Archi.
3. Skill **bootstrap-consulting-engagement** para completar README / SPEC / ARCHITECTURE con más detalle.
