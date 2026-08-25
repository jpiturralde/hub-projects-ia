# Placeholders del skeleton

Marcadores `{{NOMBRE}}` que el script [`scripts/New-ConsultingCopilotProject.ps1`](scripts/New-ConsultingCopilotProject.ps1) reemplaza al instanciar un proyecto y escribe metadata segÃºn perfil:

| Perfil | Archivo metadata |
|--------|------------------|
| Consulting / Full | `.consulting-engagement.json` (schema v2, incluye `stackProfile`) |
| GentleAi | `.project-profile.json` |

Retrocompat: la skill `bootstrap-consulting-engagement` tambiÃ©n lee `.workbench-metadata.json` si existe.

| Placeholder | Significado | Ejemplo |
|-------------|-------------|---------|
| `{{CLIENT_DISPLAY_NAME}}` | Nombre visible del cliente | `ACME Bank` |
| `{{CLIENT_SLUG}}` | Identificador corto (minÃºsculas, sin espacios) | `acme` |
| `{{INITIATIVE_DISPLAY_NAME}}` | Nombre del encargo / iniciativa | `Gobierno de APIs` |
| `{{INITIATIVE_ID}}` | CÃ³digo corto de fase o unidad | `U06` |
| `{{CONSULTANCY_NAME}}` | Nombre del equipo consultor | `Ingenia` |
| `{{PARTNER_TEAM_NAME}}` | Partner citado en revisiÃ³n semÃ¡ntica (opcional) | `Aliado Consulting` |
| `{{PARTNER_TEAM_SUFFIX}}` | ClÃ¡usula derivada para `CLAUDE.md` si hay partner | `; partner citado cuando aplique: **Aliado Consulting**` |
| `{{DOC_TITLE_PREFIX}}` | Prefijo para Pandoc y entregables | `ACME Bank - Gobierno de APIs` |
| `{{ARCHIMATE_EXPORT_FILENAME}}` | XML ArchiMate versionado | `archimate-acme-model.xml` |
| `{{ARCHIMATE_VIEWS_FILENAME}}` | Draw.io de vistas | `archimate-acme-views.drawio` |
| `{{CORPORATE_DOCX_TEMPLATE_NAME}}` | Plantilla Word bajo `docs/templates/` | `Plantilla Ingenia - 2025.docx` |
| `{{PROJECT_NAME}}` | Solo skeleton-minimal (GentleAi) | `mi-app` |

## stackProfile en metadata

Valores en `.consulting-engagement.json`:

- `consulting-only` â€” perfil Consulting
- `full` â€” perfil Full (CDD + entregables)

## Rutas fijas del skeleton

| Uso | Ruta |
|-----|------|
| Gaps / preguntas | `docs/architecture-gaps-and-questions.md` |
| Docs del cliente | `docs/client-documentation/` |
| Transcripts | `transcripts/` |
| Entregables | `docs/deliverables/` |
| Borradores Pandoc | `docs/draft/` |

## Archivos renombrados por el script

| Archivo en skeleton | Tras ejecutar |
|---------------------|---------------|
| `docs/diagrams/_TEMPLATE_archimate_export.xml` | `ArchimateExportFilename` |
| `docs/diagrams/_TEMPLATE_archimate_views.drawio` | `ArchimateViewsFilename` |

## ValidaciÃ³n

El script falla si quedan placeholders `{{` sin reemplazar.
