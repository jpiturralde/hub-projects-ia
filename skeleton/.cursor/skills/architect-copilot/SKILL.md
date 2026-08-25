---
name: architect-copilot
description: Analiza el estado del encargo de consultoría — backlog, riesgos, brechas, stakeholders y próximas acciones. Usar cuando el usuario pregunte qué hacer, pida revisar el proyecto, priorizar trabajo, identificar bloqueos o actuar como copilot de arquitectura/proyecto.
---

# Architect Copilot

Usar este skill para ayudar a ejecutar de forma ordenada encargos de consultoría con mucha documentación.

## Relación con otros flujos

- **`onboarding`**: primer arranque (workspace + MCP). No sustituye onboarding.
- **`bootstrap-consulting-engagement`**: rellenar README / SPEC / ARCHITECTURE iniciales.
- **Perfil Full (`/cdd-*`)**: si el usuario pregunta por el estado de un **entregable CDD** en curso, preferir el skill/comando CDD correspondiente. Este skill cubre el **encargo completo** (backlog, gaps, prioridades del día), no el ciclo de un entregable.

## Contexto a leer

Partir desde la raíz del proyecto. Priorizar estas fuentes, si existen:

- `README.md` — intención del proyecto y navegación.
- `docs/GETTING-STARTED.md` — checklist post-generación.
- `docs/MCP-PREREQUISITOS.md` — landscape de MCP y prerrequisitos.
- `SPEC.md` — alcance, objetivos, supuestos y exclusiones.
- `ARCHITECTURE.md` — contexto técnico e implicaciones de arquitectura.
- `docs/architecture-gaps-and-questions.md` — preguntas abiertas, riesgos y confirmaciones faltantes.
- `backlog.md`, `backlog/config.yml` y `backlog/tasks/` — estado operativo.
- `backlog/meetings/` — notas de reuniones.
- `backlog/decisions/` — decisiones y registros tipo ADR.
- `.consulting-engagement.json` (o `.workbench-metadata.json`) — metadata del encargo.
- `transcripts/` — solo como material fuente crudo. No editar archivos allí salvo autorización explícita del usuario para el cambio concreto (regla `transcripts-immutable`).

Usar el MCP `backlog` cuando esté disponible para listar, inspeccionar, crear o actualizar tareas. Si el MCP no está disponible, leer y editar los Markdown directamente cuando el usuario esté en Agent mode.

## Workflow de análisis

1. Identificar el alcance actual y el foco de entrega.
2. Comparar backlog, brechas, decisiones y documentos de arquitectura para detectar inconsistencias.
3. Detectar bloqueos, dependencias, stakeholders faltantes, reuniones faltantes y preguntas sin responder.
4. Identificar qué cambió recientemente o qué parece desactualizado.
5. Proponer las acciones mínimas siguientes que hagan avanzar el proyecto.

No inventar features, decisiones, confirmaciones ni compromisos del cliente. Si la evidencia es débil, marcarlo como supuesto o preguntar al usuario.

## Formato de salida

Devolver:

- Acciones priorizadas para hoy.
- Próximos 3 pasos concretos.
- Riesgos y bloqueos.
- Información o stakeholders faltantes.
- Actualizaciones sugeridas al backlog, si corresponde.

Mantener las recomendaciones pragmáticas y atadas a evidencia visible del proyecto.
