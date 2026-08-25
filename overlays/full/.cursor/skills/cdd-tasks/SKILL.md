---
name: cdd-tasks
description: "Break a CDD deliverable into sections, annexes, and diagrams checklist. Trigger: orchestrator launches cdd-tasks for a change."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
  delegate_only: true
---

> **ORCHESTRATOR GATE**: If you loaded this skill via the `skill()` tool, you are
> the ORCHESTRATOR — STOP. Do NOT execute these instructions inline. Delegate to
> the dedicated `cdd-tasks` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-tasks` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor — execute.

## Language Domain Contract

- **CDD internal artifacts:** neutral professional Spanish unless the user requests otherwise.
- **Client deliverables:** formal Spanish per `consulting-draft-client-deliverable`.
- **Chat with user:** match user language.

## Persistencia repo-first (prevalece sobre referencias legacy)

El artefacto completo se escribe en `.cdd/changes/{change-name}/{artifact}.md` y se actualiza `state.json`. Engram recibe sólo un resumen de hasta 250 palabras con decisiones, hallazgos, riesgos, estado, siguiente fase y puntero al archivo. No guardar el cuerpo completo ni recuperar observaciones completas si el puntero del resumen alcanza.

## Purpose

You are a sub-agent responsible for **DESGLOSE DE REDACCIÓN**. You take proposal, spec, and design, then produce a checklist of concrete writing tasks: sections, annexes, diagrams, canonical ports, and cross-references — organized for `cdd-apply` batches.

## Consulting Hard Rules

- Tasks are **writing and porting** tasks — NOT code implementation, NOT unit tests, NOT PR slices.
- Do NOT include Review Workload Forecast / chained PR / 400-line budget — those are dev SDD concepts.
- Do NOT run unit tests, builds, or coverage.
- Do NOT create PRs unless user explicitly requests git workflow.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md` and `../_shared/persistence-contract.md`.

## What You Receive

From the orchestrator:
- Change name
- Persistence mode (`hybrid-repo-first`)

## Repository retrieval

Required:
- `.cdd/changes/{change-name}/spec.md`
- `.cdd/changes/{change-name}/design.md`
- Open `proposal.md` only to resolve an inconsistency

## Execution Steps

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.

### Step 2: Analyze Design

From design document, extract:
- All draft `.md` files to create or update
- Section and annex numbering
- Diagrams to embed or reference (client-safe exports only)
- Canonical ports needed BEFORE writing deliverable text

### Step 3: Write Tasks Artifact

```markdown
# Tareas: {Título del entregable}

## Resumen
| Fase | Tareas | Foco |
|------|--------|------|
| 1 | {N} | Fuentes canónicas |
| 2 | {N} | Cuerpo principal |
| 3 | {N} | Anexos |
| 4 | {N} | Diagramas + QA redacción |

## Fase 1: Preparación canónica
- [ ] 1.1 Portar {información} a `ARCHITECTURE.md` §{X} (si falta)
- [ ] 1.2 Actualizar `docs/architecture-gaps-and-questions.md` — cerrar/marcar gap {ID}
- [ ] 1.3 Confirmar export Archi / diagrama {nombre} actualizado

## Fase 2: Cuerpo principal (`{archivo-main}.md`)
- [ ] 2.1 Redactar §1 Motivo — criterio spec {ID}
- [ ] 2.2 Redactar §2 Etapa
- [ ] 2.3 Redactar §3 Detalle — escenarios spec {IDs}
- [ ] 2.4 Redactar §4 Anexos técnicos (índice + refs)

## Fase 3: Anexos
- [ ] 3.1 Anexo A (#5) — `{archivo-anexo-A}.md` — spec {ID}
- [ ] 3.2 Anexo B (#6) — `{archivo-anexo-B}.md`

## Fase 4: Diagramas y cierre redacción
- [ ] 4.1 Exportar/incrustar diagrama {tipo} — versión cliente
- [ ] 4.2 Verificar numeración continua y refs cruzadas
- [ ] 4.3 Autorevisión: sin paths internos (pre-verify)

## Lotes sugeridos para cdd-apply
| Lote | Tareas | Archivos draft |
|------|--------|----------------|
| 1 | 1.x + 2.1–2.2 | main partial |
| 2 | 2.3–2.4 + 3.x | main + anexos |
| 3 | 4.x | diagramas + polish |
```

### Task Writing Rules

Each task MUST be:

| Criterio | Ejemplo ✅ | Anti-ejemplo ❌ |
|----------|-----------|----------------|
| **Específico** | "Redactar §3.2 Flujos AS-IS en `{main}.md`" | "Escribir detalle" |
| **Verificable** | "Criterio spec REQ-04 escenario happy path" | "Que quede bien" |
| **Acotado** | Un archivo o una sección H2 | "Hacer el entregable" |
| **Consultoría** | "Portar gap #12 a gaps file" | "Implementar auth middleware" |

### Step 4: Persist Artifact

**Mandatory — do NOT skip.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `tasks`
- topic_key: `cdd/{change-name}/tasks`
- type: `architecture`
- `capture_prompt: false`

### Step 5: Return Summary

```markdown
## Tareas creadas

**Change**: {change-name}

### Desglose
| Fase | Tareas |
|------|--------|
| Total | {N} |

### Lotes apply sugeridos
{Brief — 2–3 batches}

### Próximo paso
Listo para cdd-apply (redactar en draft/).
```

## Result Contract Fields

Return per **Section D** from `../_shared/cdd-phase-common.md`:

| Field | Content |
|-------|---------|
| `status` | `done` \| `blocked` \| `partial` |
| `executive_summary` | Task breakdown summary |
| `artifacts` | Engram `cdd/{change}/tasks` ID |
| `next_recommended` | `cdd-apply` |
| `risks` | Missing design/spec, canonical ports blocking writing |
| `skill_resolution` | Skills loaded |

## Engram Topic Keys

| Artifact | Topic Key |
|----------|-----------|
| Tasks | `cdd/{change}/tasks` |

## Rules

- ALWAYS reference concrete draft filenames and section numbers from design
- Tasks MUST trace to spec acceptance criteria where applicable
- NEVER include dev PR/chained-PR/TDD tasks
- Canonical port tasks come BEFORE deliverable writing tasks when information is missing
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
