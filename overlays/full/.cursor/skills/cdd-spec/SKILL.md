---
name: cdd-spec
description: "Write CDD acceptance criteria for a client deliverable. Trigger: orchestrator launches cdd-spec for a change."
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
> the dedicated `cdd-spec` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-spec` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor — execute.

## Language Domain Contract

- **CDD internal artifacts:** neutral professional Spanish unless the user requests otherwise.
- **Client deliverables:** formal Spanish per `consulting-draft-client-deliverable` (spec is internal QA contract).
- **Chat with user:** match user language.

## Persistencia repo-first (prevalece sobre referencias legacy)

El artefacto completo se escribe en `.cdd/changes/{change-name}/{artifact}.md` y se actualiza `state.json`. Engram recibe sólo un resumen de hasta 250 palabras con decisiones, hallazgos, riesgos, estado, siguiente fase y puntero al archivo. No guardar el cuerpo completo ni recuperar observaciones completas si el puntero del resumen alcanza.

## Purpose

You are a sub-agent responsible for **CRITERIOS DE ACEPTACIÓN** del entregable. You take the proposal and define testable acceptance criteria — what must be true before the deliverable is client-ready. Cross-check against `SPEC.md` at all times.

## Consulting Hard Rules

- Specs describe **deliverable quality**, not code behavior — no unit test scenarios, no API requirements unless the deliverable documents them.
- Do NOT run unit tests, builds, or coverage.
- Do NOT create PRs or dev workflow artifacts.
- Do NOT write to `docs/draft/` in this phase.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md` and `../_shared/persistence-contract.md`.

## What You Receive

From the orchestrator:
- Change name
- Persistence mode (`hybrid-repo-first`)

## Repository retrieval

Required:
- `.cdd/changes/{change-name}/proposal.md`
- Read **SPEC.md** from workspace (mandatory cross-check)

## Execution Steps

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.

### Step 2: Read Proposal and SPEC.md

1. Read full proposal — outline, scope, success criteria
2. Read `SPEC.md` — objectives, in/out of scope, constraints
3. Build alignment matrix: each acceptance criterion MUST trace to a proposal section AND a SPEC objective (or explicit internal need)

Flag conflicts between proposal and SPEC — report as risk, do not silently expand scope.

### Step 3: Write Spec Artifact

Acceptance criteria for **client deliverable**, not software:

```markdown
# Especificación: {Título del entregable}

## Propósito
{Qué debe cumplir el entregable antes de exportar al cliente}

## Alineación SPEC.md
| Criterio | Objetivo SPEC | Sección propuesta |
|----------|---------------|-------------------|
| {ID} | {objetivo} | {sección/anexo} |

## Requisitos de aceptación

### Requisito: {Nombre — ej. Cobertura AS-IS}
El entregable DEBE {comportamiento observable en el documento}.

#### Escenario: {Camino feliz}
- DADO {precondición — fuente canónica disponible}
- CUANDO {lector revisa sección X}
- ENTONCES {contenido esperado — sin referencias internas}

#### Escenario: {Caso límite}
- DADO {gap abierto en architecture-gaps-and-questions.md}
- CUANDO {se redacta la sección afectada}
- ENTONCES {marcador ⚠ o formulación neutral, sin paths internos}

## Calidad redaccional
- Tono formal español según `consulting-draft-client-deliverable`
- Sin paths internos del repo (validable en cdd-verify)
- Diagramas referenciados existen o tienen placeholder explícito

## Fuera de alcance (recordatorio)
- {Items de SPEC.md explícitamente excluidos}

## Definition of Done (pre-cliente)
- [ ] Todos los requisitos tienen escenario verificable
- [ ] Alineación SPEC verificada
- [ ] Gaps críticos tratados o marcados
```

Use RFC 2119 keywords (DEBE / DEBERÍA / PUEDE) for requirement strength.

### Step 4: Persist Artifact

**Mandatory — do NOT skip.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `spec`
- topic_key: `cdd/{change-name}/spec`
- type: `architecture`
- `capture_prompt: false`

### Step 5: Return Summary

```markdown
## Spec creada

**Change**: {change-name}

### Cobertura
| Área | Requisitos | Escenarios |
|------|------------|------------|
| {sección} | {N} | {M} |

### Alineación SPEC
{OK / N conflictos — listar}

### Próximo paso
Listo para cdd-design (estructura doc + mapa fuentes).
```

## Result Contract Fields

Return per **Section D** from `../_shared/cdd-phase-common.md`:

| Field | Content |
|-------|---------|
| `status` | `done` \| `blocked` \| `partial` |
| `executive_summary` | Acceptance criteria summary and SPEC alignment |
| `artifacts` | Engram `cdd/{change}/spec` ID |
| `next_recommended` | `cdd-design` |
| `risks` | SPEC conflicts, untestable criteria, missing canonical sources |
| `skill_resolution` | Skills loaded |

## Engram Topic Keys

| Artifact | Topic Key |
|----------|-----------|
| Spec | `cdd/{change}/spec` |

## Rules

- ALWAYS cross-check `SPEC.md` — every requirement traces to SPEC or explicit internal QA need
- Every requirement MUST have at least ONE verifiable scenario (document review, not automated test)
- DO NOT include implementation or test-runner details
- DO NOT describe code behavior unless the deliverable documents architecture for the client
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
