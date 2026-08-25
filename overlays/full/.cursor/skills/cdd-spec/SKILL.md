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
> the ORCHESTRATOR â€” STOP. Do NOT execute these instructions inline. Delegate to
> the dedicated `cdd-spec` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-spec` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor â€” execute.

## Language Domain Contract

- **CDD internal artifacts:** neutral professional Spanish unless the user requests otherwise.
- **Client deliverables:** formal Spanish per `draft-client-deliverable` (spec is internal QA contract).
- **Chat with user:** match user language.

## Purpose

You are a sub-agent responsible for **CRITERIOS DE ACEPTACIÃ“N** del entregable. You take the proposal and define testable acceptance criteria â€” what must be true before the deliverable is client-ready. Cross-check against `SPEC.md` at all times.

## Consulting Hard Rules

- Specs describe **deliverable quality**, not code behavior â€” no unit test scenarios, no API requirements unless the deliverable documents them.
- Do NOT run unit tests, builds, or coverage.
- Do NOT create PRs or dev workflow artifacts.
- Do NOT write to `docs/draft/` in this phase.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md` and `../_shared/persistence-contract.md`.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)

## Engram Retrieval

Required:
- `cdd/{change-name}/proposal` (mandatory)
- Read **SPEC.md** from workspace (mandatory cross-check)

## Execution Steps

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.

### Step 2: Read Proposal and SPEC.md

1. Read full proposal â€” outline, scope, success criteria
2. Read `SPEC.md` â€” objectives, in/out of scope, constraints
3. Build alignment matrix: each acceptance criterion MUST trace to a proposal section AND a SPEC objective (or explicit internal need)

Flag conflicts between proposal and SPEC â€” report as risk, do not silently expand scope.

### Step 3: Write Spec Artifact

Acceptance criteria for **client deliverable**, not software:

```markdown
# EspecificaciÃ³n: {TÃ­tulo del entregable}

## PropÃ³sito
{QuÃ© debe cumplir el entregable antes de exportar al cliente}

## AlineaciÃ³n SPEC.md
| Criterio | Objetivo SPEC | SecciÃ³n propuesta |
|----------|---------------|-------------------|
| {ID} | {objetivo} | {secciÃ³n/anexo} |

## Requisitos de aceptaciÃ³n

### Requisito: {Nombre â€” ej. Cobertura AS-IS}
El entregable DEBE {comportamiento observable en el documento}.

#### Escenario: {Camino feliz}
- DADO {precondiciÃ³n â€” fuente canÃ³nica disponible}
- CUANDO {lector revisa secciÃ³n X}
- ENTONCES {contenido esperado â€” sin referencias internas}

#### Escenario: {Caso lÃ­mite}
- DADO {gap abierto en architecture-gaps-and-questions.md}
- CUANDO {se redacta la secciÃ³n afectada}
- ENTONCES {marcador âš  o formulaciÃ³n neutral, sin paths internos}

## Calidad redaccional
- Tono formal espaÃ±ol segÃºn `draft-client-deliverable`
- Sin paths internos del repo (validable en cdd-verify)
- Diagramas referenciados existen o tienen placeholder explÃ­cito

## Fuera de alcance (recordatorio)
- {Items de SPEC.md explÃ­citamente excluidos}

## Definition of Done (pre-cliente)
- [ ] Todos los requisitos tienen escenario verificable
- [ ] AlineaciÃ³n SPEC verificada
- [ ] Gaps crÃ­ticos tratados o marcados
```

Use RFC 2119 keywords (DEBE / DEBERÃA / PUEDE) for requirement strength.

### Step 4: Persist Artifact

**Mandatory â€” do NOT skip.**

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
| Ãrea | Requisitos | Escenarios |
|------|------------|------------|
| {secciÃ³n} | {N} | {M} |

### AlineaciÃ³n SPEC
{OK / N conflictos â€” listar}

### PrÃ³ximo paso
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

- ALWAYS cross-check `SPEC.md` â€” every requirement traces to SPEC or explicit internal QA need
- Every requirement MUST have at least ONE verifiable scenario (document review, not automated test)
- DO NOT include implementation or test-runner details
- DO NOT describe code behavior unless the deliverable documents architecture for the client
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
