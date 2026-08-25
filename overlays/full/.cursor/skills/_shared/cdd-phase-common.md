# Contrato común de fases CDD

## Carga mínima

1. Leer `PROJECT-CONTEXT.md`.
2. Leer `.cdd/changes/{change}/state.json`.
3. Leer sólo las dependencias directas:

| Fase | Dependencias |
|---|---|
| propose | explore, si existe |
| spec | proposal |
| design | proposal |
| tasks | spec + design |
| apply | tasks + spec + design + apply-progress, si existe |
| verify | spec + tasks + apply-progress |
| archive | state + verify-report; abrir otros artefactos sólo para resolver una inconsistencia |

`SPEC.md` es la referencia canónica de alcance.

## Escritura

Guardar el artefacto completo en `.cdd/changes/{change}/{artifact}.md` y actualizar `state.json`.

Después, guardar en Engram una observación breve con:

- estado y resumen ejecutivo;
- decisiones o hallazgos reutilizables;
- riesgos/bloqueos;
- puntero al archivo del repositorio;
- siguiente fase.

No copiar el artefacto completo. Máximo recomendado: 250 palabras.

## Resultado

Devolver: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks` y `skill_resolution`.

