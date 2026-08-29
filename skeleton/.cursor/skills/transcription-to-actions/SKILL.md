---
name: transcription-to-actions
description: Extrae decisiones, tareas, riesgos, preguntas abiertas y seguimientos de stakeholders desde transcripciones de reuniones. Usar al resumir transcripts, convertir reuniones en ítems de backlog o derivar acciones de proyecto desde notas crudas.
source: startia
canonical_mcp: transcription-to-actions
---

# Transcription To Actions

> Capa hub sobre Startia (`transcription-to-actions`). No copiar a `~/.cursor/skills`. Re-sync manual desde Startia cuando cambie la versión approved.

Usar este skill para transformar material crudo de reuniones en salidas operativas del proyecto.

## Regla no negociable

Los archivos bajo `transcripts/` son registros crudos de reuniones y fuente de verdad. Leerlos como contexto, pero no editarlos, renombrarlos, borrarlos ni reformatearlos salvo que el usuario autorice explícitamente ese cambio exacto en el hilo actual (regla `transcripts-immutable`).

Escribir las salidas derivadas en otro lugar, por ejemplo:

- `backlog/meetings/` para resúmenes o minutas.
- `backlog/tasks/` o el MCP `backlog` para tareas.
- `backlog/decisions/` para decisiones.
- `docs/architecture-gaps-and-questions.md` para brechas, riesgos y preguntas abiertas.
- `docs/` / `ARCHITECTURE.md` / `SPEC.md` para documentación sintetizada del proyecto (solo hechos confirmados).

## Workflow de extracción

1. Identificar fecha de reunión, participantes, contexto cliente/interno y propósito.
2. Extraer decisiones, compromisos explícitos, acciones, riesgos, bloqueos, preguntas abiertas y seguimientos.
3. Separar hechos confirmados de interpretaciones inferidas.
4. Vincular cada ítem derivado con la transcripción fuente por nombre de archivo o referencia de reunión.
5. Proponer actualizaciones al backlog, brechas, decisiones o documentación.

No inventar contexto faltante. Si un ítem es ambiguo, marcarlo como `Pendiente de confirmar`.

## Formato de salida

Devolver una síntesis concisa con:

- Resumen.
- Decisiones.
- Acciones con responsable y fecha límite cuando estén disponibles.
- Riesgos/bloqueos.
- Preguntas abiertas.
- Actualizaciones sugeridas al backlog o documentación.

Cuando se pida crear tareas, usar títulos orientados a la acción e incluir suficiente contexto para que sean útiles sin reabrir la transcripción completa.
