# Perfiles y alcance Gentle AI

## Perfiles

| Perfil | Metadata | Workflow |
|---|---|---|
| `ConsultingAI` | `stackProfile: consulting-ai` | CDD para entregables; SDD sólo ante desarrollo explícito |
| `Full` | Igual que ConsultingAI; registra el alias solicitado | Retrocompatibilidad |
| `GentleAi` | `.project-profile.json` | Políticas y workflows Gentle AI de desarrollo |
| `Consulting` | `stackProfile: consulting-only` | Skills/reglas de consultoría sin Gentle AI |

`New-IngeniaTemplateProject.ps1` ahora genera ConsultingAI.

## Resolución de alcance

| Estado detectado | Auto | Global | Workspace | Existing |
|---|---|---|---|---|
| Global existe | Reusar global | Reusar global | **Error** | Reusar global |
| Sólo workspace existe | Reusar workspace | **Error** | Reusar workspace | Reusar workspace |
| No existe configuración | Preguntar | Instalar global | Instalar workspace | **Error** |
| Global + workspace | **Error y diagnóstico** | **Error** | **Error** | **Error** |
| Más de un CLI | **Error y rutas** | **Error** | **Error** | **Error** |

La opción local sólo aparece cuando no existe global.

## CDD: Consulting-Driven Delivery

`explore → propose → spec + design → tasks → apply → verify → archive`

- Gentle AI conserva autoridad sobre orquestación, delegación y modelos.
- Los agentes CDD usan `model: inherit`.
- Artefactos completos: `.cdd/changes/{change}/`.
- Engram: resumen ≤250 palabras, decisiones/hallazgos, estado, riesgos y puntero.
- Explore: un dominio, índice + hasta dos archivos; justificar expansión.
- Verify usa contexto fresco y no modifica borradores.
- Archive sincroniza fuentes canónicas.

## Skills locales

Las especializaciones del template usan nombres propios para no sombrear skills globales:

- `consulting-draft-client-deliverable`
- `consulting-code-technical-analysis`

No se incluye `judgment-day` local; ConsultingAI reutiliza la versión instalada por Gentle AI.

## Capa Claude/Cowork

Es opcional y default `false`. Si se incluye, `CLAUDE.md` importa sólo `PROJECT-CONTEXT.md`; no precarga README, SPEC y ARCHITECTURE.

## Engram y MCP

El generador nunca escribe Engram en `.cursor/mcp.json`. Gentle AI administra Engram en el alcance que corresponda; el MCP local contiene sólo Draw.io, Backlog o Archi.

### Backlog.md

Si el perfil/toggle incluye MCP Backlog (`-IncludeBacklogMcp`):

- Requiere **Node.js** y **npm** nativos del SO (en WSL, dentro de la distro; no `/mnt/c`).
- Reutiliza un `backlog` válido en PATH tras `backlog --version`.
- Si falta: interactivo ofrece instalar; no interactivo usa `-BacklogCliChoice I|X` (sin instalar en silencio).
- Comando: `npm install -g backlog.md@latest --include=optional`.
- No escribe la entrada MCP si la validación falla o el usuario cancela.

Después de actualizar el binario Gentle AI, usar `gentle-ai sync`. Para diagnóstico, `gentle-ai doctor` y `scripts/Test-GentleAiProject.ps1`.

