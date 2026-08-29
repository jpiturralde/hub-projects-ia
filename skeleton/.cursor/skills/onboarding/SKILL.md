---
name: onboarding
description: "Trigger: onboarding, primeros pasos, como continuar, /onboarding, que hago ahora, abrir proyecto, verificar MCP, entorno, herramientas faltantes. Guia post-generacion del proyecto."
---

# Onboarding — primer arranque

## Cuando usar

- Proyecto **recien generado** desde un hub generador.
- Usuario pregunta como continuar, si el entorno/MCP estan bien, o que hacer despues de crear el repo.
- Comando explicito: **`/onboarding`**.

## Antes de empezar

1. Leer **`docs/GETTING-STARTED.md`** (checklist canonica generada al crear el proyecto).
2. Leer metadata segun perfil y extraer **`requires`** (si falta, usar toggles MCP / `gentleAiScope`):
   - **Consulting / ConsultingAI / Full:** `.consulting-engagement.json`
   - **GentleAi:** `.project-profile.json`
3. Leer **`.atl/onboarding-pending.json`** si existe (estado pendiente).

## Flujo guiado (Interactive)

Recorre estos pasos **en orden**. Tras cada paso, confirma con el usuario antes de seguir (salvo que pida modo rapido).

### Paso 0 — Workspace raiz (critico)

Explica:

- Las integraciones **locales** viven en `.cursor/mcp.json` de **esta** carpeta.
- La memoria del asistente (si el perfil la usa) se administra fuera del MCP local; no hace falta duplicarla en `.cursor/mcp.json`.
- Si el workspace activo es el hub padre, no se carga el contexto ni el MCP local del hijo.
- Accion: **File -> Open Folder** -> raiz de **este** repositorio.
- Luego: **Developer: Reload Window** si hace falta.

Pregunta: "¿Ya tenes esta carpeta abierta como workspace raiz?" Si no, detente hasta que confirme.

### Paso 1 — Verificar entorno desde `requires` (sin PowerShell)

Lee `requires.tools[]` (ids con `level` required|optional). Si `requires` no existe (schema menor a 4), deriva con los mismos toggles que la metadata:

| Toggle / campo | Efecto tipico |
|---|---|
| `includeDrawioMcp=true` | node, npm, npx obligatorios |
| `includeArchiMcp=true` | archi (+ node/npm) obligatorios |
| `includeBacklogMcp=true` | backlog obligatorio |
| Consulting* | pandoc opcional; backlog opcional si el toggle es false |
| `gentleAiScope` global\|workspace | CLI de asistencia obligatorio |

Para cada herramienta **obligatoria**, guia una verificacion **sin PowerShell**:

- `node` / `npm` / `npx` / `pandoc` / `backlog`: comando `--version` (o equivalente) en la terminal del usuario.
- `archi`: confirmar instalacion / ruta configurada segun `docs/MCP-PREREQUISITOS.md`.
- `gentle-ai`: una sola instalacion nativa usable en PATH (no mezclar con binario Windows en WSL).

Opcionales: informar si faltan; no bloquear el onboarding.

**MCP local** (solo drawio / backlog / archi — nunca entradas de memoria en el MCP del hijo):

- **Aun no materializado** (no hay `.cursor/mcp.json`): falla la verificacion **solo** si el perfil requiere servidores locales; si no, es informativo.
- **Con problemas / roto** (JSON invalido, rutas malas, o entradas prohibidas): **siempre** es un fallo a corregir.

Guia a **Cursor Settings -> MCP** para ver servidores locales en verde. Si hay placeholders en archi/backlog, indicar editar `.cursor/mcp.json`.

### Paso 2 — Metadata del encargo

Resumir en 3-5 lineas: cliente, iniciativa, `stackProfile`, toggles MCP y resumen de `requires` (herramientas obligatorias).

### Paso 3 — Siguiente accion segun perfil

| Perfil | Proximo paso |
|--------|--------------|
| **Consulting** | Skill **`bootstrap-consulting-engagement`** + copiar plantilla Word a `docs/templates/` |
| **ConsultingAI / Full** | **`/start-task`** -> bootstrap si falta contexto -> **`/cdd-new [entregable]`** si la complejidad lo justifica |
| **GentleAi** | **`/start-task`**; la asistencia activa flujos de especificacion cuando corresponde o cuando el usuario lo pide |

Mencionar **`docs/GETTING-STARTED.md`** como referencia permanente.

### Paso 4 — Cierre

1. Crear o actualizar **`.atl/onboarding-complete.json`**:

```json
{
  "completedAt": "<ISO-8601>",
  "stackProfile": "<perfil>",
  "notes": "Onboarding guiado completado"
}
```

2. **Eliminar** `.atl/onboarding-pending.json` si existe.

3. Resumir al usuario los proximos 2-3 pasos concretos (no repetir toda la checklist).

## Modo rapido

Si el usuario dice "rapido" o "solo lo esencial":

1. Workspace raiz + entorno obligatorio OK (2 frases; sin exigir scripts `.ps1`).
2. Un solo proximo paso segun perfil (tabla del Paso 3).
3. Marcar onboarding completo (Paso 4).

## Prohibido

- No iniciar bootstrap, CDD o SDD automáticamente sin confirmación del usuario.
- No editar `transcripts/` ni entregables al cliente durante onboarding.
- No exigir PowerShell ni scripts `.ps1` al cliente para verificar el entorno.
- No escribir servidores de memoria en el MCP local del hijo.
