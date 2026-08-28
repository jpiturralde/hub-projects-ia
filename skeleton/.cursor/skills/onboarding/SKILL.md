---
name: onboarding
description: "Trigger: onboarding, primeros pasos, como continuar, /onboarding, que hago ahora, abrir proyecto, verificar MCP, engram no conecta. Guia post-generacion del proyecto."
---

# Onboarding — primer arranque

## Cuando usar

- Proyecto **recien generado** desde un hub generador.
- Usuario pregunta como continuar, si Engram/MCP estan bien, o que hacer despues de crear el repo.
- Comando explicito: **`/onboarding`**.

## Antes de empezar

1. Leer **`docs/GETTING-STARTED.md`** (checklist canonica generada al crear el proyecto).
2. Leer metadata segun perfil:
   - **Consulting / ConsultingAI:** `.consulting-engagement.json`
   - **GentleAi:** `.project-profile.json`
3. Leer **`.atl/onboarding-pending.json`** si existe (estado pendiente).

## Flujo guiado (Interactive)

Recorre estos pasos **en orden**. Tras cada paso, confirma con el usuario antes de seguir (salvo que pida modo rapido).

### Paso 0 — Workspace raiz (critico)

Explica:

- Los MCP específicos del proyecto viven en `.cursor/mcp.json`; Engram es administrado por Gentle AI y puede ser global.
- Si el workspace activo es el hub padre, no se carga el contexto ni el MCP local del hijo.
- Accion: **File -> Open Folder** -> raiz de **este** repositorio.
- Luego: **Developer: Reload Window** si hace falta.

Pregunta: "¿Ya tenes esta carpeta abierta como workspace raiz?" Si no, detente hasta que confirme.

### Paso 1 — Verificar MCP

Guia al usuario a **Cursor Settings -> MCP**:

- Listar servidores locales esperados según `.cursor/mcp.json`: típicamente `drawio`, opcionalmente `backlog`/`archi`, y **`startia`** si figura en el JSON (default al generar).
- Si **`startia`** está presente: confirmar que existen variables de entorno de usuario `GOVERNOR_PAT` y `GOVERNOR_TENANT_ID`, y que el server está en verde tras reiniciar Cursor. Detalle: `docs/GETTING-STARTED.md` y, si existe, `docs/MCP-PREREQUISITOS.md` § Startia.
- Para ConsultingAI/GentleAi, verificar Engram por separado como integración administrada por Gentle AI. No agregarlo al MCP local.
- Si **archi** o **backlog** tienen rutas placeholder, indicar editar `.cursor/mcp.json` (ver `docs/MCP-PREREQUISITOS.md`).

Si el usuario reporta Engram solo en CLI: explicar diferencia CLI vs MCP y repetir Paso 0 + Reload.

### Paso 2 — Metadata del encargo

Resumir en 3-5 lineas: cliente, iniciativa, `stackProfile`, MCP toggles desde el JSON de metadata.

### Paso 3 — Siguiente accion segun perfil

| Perfil | Proximo paso |
|--------|--------------|
| **Consulting** | Skill **`bootstrap-consulting-engagement`** + copiar plantilla Word a `docs/templates/` |
| **ConsultingAI / Full** | **`/start-task`** -> bootstrap si falta contexto -> **`/cdd-new [entregable]`** si la complejidad lo justifica |
| **GentleAi** | **`/start-task`**; Gentle AI activa SDD cuando corresponde o cuando el usuario lo pide |

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

1. Workspace raiz + MCP en verde (2 frases).
2. Un solo proximo paso segun perfil (tabla del Paso 3).
3. Marcar onboarding completo (Paso 4).

## Prohibido

- No iniciar bootstrap, CDD o SDD automáticamente sin confirmación del usuario.
- No editar `transcripts/` ni entregables al cliente durante onboarding.
