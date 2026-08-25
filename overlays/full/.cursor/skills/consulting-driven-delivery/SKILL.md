---
name: consulting-driven-delivery
description: Orquestar entregables complejos con CDD, preservando políticas Gentle AI y contexto acotado.
user-invocable: true
---
# Consulting-Driven Delivery

Gentle AI sigue siendo la autoridad de orquestación. CDD adapta sus conceptos a documentación, arquitectura, research, assessments, reuniones y entregables.

## Flujo

`explore → propose → spec + design → tasks → apply → verify → archive`

## Activación

- Usar CDD si el usuario lo pide o acepta una propuesta para un entregable complejo.
- Para una tarea acotada, trabajar directamente.
- Para desarrollo explícito, usar SDD.

## Persistencia repo-first

Cada cambio vive en `.cdd/changes/{change}/`:

- `explore.md`
- `proposal.md`
- `spec.md`
- `design.md`
- `tasks.md`
- `apply-progress.md`
- `verify-report.md`
- `archive-report.md`
- `state.json`

Engram guarda sólo: decisiones, hallazgos reutilizables, estado, resumen ejecutivo y puntero al archivo. Límite recomendado: 250 palabras por observación.

## Contexto

Leer `PROJECT-CONTEXT.md` y sólo las dependencias directas de la fase. En explore: un dominio, un índice y hasta dos archivos; ampliar sólo con una brecha de evidencia explícita.

## Gates

- Interactive es el modo inicial; pedir confirmación antes de encadenar fases.
- Verify es de contexto fresco y no modifica borradores.
- Antes de exportar: verify PASS y revisiones client-facing/canonical-alignment.
- Archive sincroniza canónicos antes de cerrar.

Los agentes usan `model: inherit`. No fijar nombres de modelos ni escalar costo sin confirmación.

