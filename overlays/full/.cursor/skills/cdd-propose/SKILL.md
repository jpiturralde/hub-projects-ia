---
name: cdd-propose
description: "Create a CDD deliverable proposal with intent, scope, and outline. Trigger: orchestrator launches cdd-propose for a change."
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
> the dedicated `cdd-propose` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-propose` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor â€” execute.

## Language Domain Contract

- **CDD internal artifacts:** neutral professional Spanish unless the user requests otherwise.
- **Client deliverables:** formal Spanish per `draft-client-deliverable` (proposal is internal planning).
- **Chat with user:** match user language.

## Purpose

You are a sub-agent responsible for **PROPUESTA DE ENTREGABLE**. You take exploration analysis (or direct user input) and produce a structured proposal aligned with `SPEC.md` scope and objectives.

## Consulting Hard Rules

- Align every deliverable outline section with `SPEC.md` â€” cite SPEC sections when mapping scope.
- Do NOT run unit tests, builds, or coverage.
- Do NOT create PRs or dev workflow artifacts.
- Do NOT write client-facing draft files in `docs/draft/` â€” proposal is Engram-only planning.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md` and `../_shared/persistence-contract.md`.

## What You Receive

From the orchestrator:
- Change name
- Exploration analysis (from `cdd-explore`) OR direct user description
- Artifact store mode (`engram | openspec | hybrid | none`)

## Engram Retrieval

Required reads:
- `cdd/{change-name}/explore` (optional but preferred)
- `cdd-init/{project}` (project context)
- Read **SPEC.md** from workspace â€” mandatory cross-check

## Execution Steps

### Step 0: Shape the Proposal (Interactive Mode)

When interactive CDD mode is active, offer a brief question round before finalizing:
- Business problem and audience for this deliverable
- What the client should understand or decide after reading
- Scope boundaries vs `SPEC.md` out-of-scope items
- Dependencies on pending gaps from `architecture-gaps-and-questions.md`

Do NOT ask about test commands, PR shape, or dev harness decisions.

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.
Load `cognitive-doc-design` when structuring complex deliverables.

### Step 2: Cross-Check SPEC.md

Read `SPEC.md` and map:
- Initiative objectives â†’ deliverable intent
- In-scope items â†’ proposal in-scope
- Out-of-scope â†’ proposal out-of-scope (explicit deferrals)
- Flag any proposal scope that contradicts SPEC â€” report as risk

### Step 3: Write Proposal Artifact

```markdown
# Propuesta: {TÃ­tulo del entregable}

## Intent
{Problema / necesidad del cliente que resuelve este entregable}

## AlineaciÃ³n con SPEC.md
| Objetivo SPEC | Cobertura en esta propuesta |
|---------------|----------------------------|
| {objetivo} | {cÃ³mo se cubre} |

## Alcance

### Incluido
- {SecciÃ³n / anexo / diagrama concreto}

### Excluido
- {ExplÃ­citamente fuera de este entregable}

## Esquema del entregable (outline)
1. Motivo del trabajo
2. Etapa / contexto
3. Detalle tÃ©cnico
4. Anexos tÃ©cnicos
   - Anexo A â€” {tema}
   - Anexo B â€” {tema}

## Fuentes canÃ³nicas previstas
| InformaciÃ³n | Fuente canÃ³nica |
|-------------|-----------------|
| {tipo} | {ARCHITECTURE.md / Archi / gaps / etc.} |

## Enfoque
{CÃ³mo se construirÃ¡ el entregable â€” narrativa, diagramas, nivel de detalle}

## Riesgos
| Riesgo | MitigaciÃ³n |
|--------|------------|
| {riesgo} | {acciÃ³n} |

## Criterios de Ã©xito
- [ ] {Medible / verificable antes de enviar al cliente}

## Dependencias
- {Gap abierto, confirmaciÃ³n pendiente, material del cliente}
```

### Step 4: Persist Artifact

**Mandatory â€” do NOT skip.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `proposal`
- topic_key: `cdd/{change-name}/proposal`
- type: `architecture`
- `capture_prompt: false`

### Step 5: Return Summary

```markdown
## Propuesta creada

**Change**: {change-name}
**UbicaciÃ³n**: Engram `cdd/{change-name}/proposal`

### Resumen
- **Intent**: {one-line}
- **AlineaciÃ³n SPEC**: {OK / gaps flagged}
- **Outline**: {N secciones, M anexos}
- **Riesgo**: {Low/Medium/High}

### PrÃ³ximo paso
Listo para cdd-spec (criterios de aceptaciÃ³n).
```

## Result Contract Fields

Return per **Section D** from `../_shared/cdd-phase-common.md`:

| Field | Content |
|-------|---------|
| `status` | `done` \| `blocked` \| `partial` |
| `executive_summary` | Proposal intent and SPEC alignment |
| `artifacts` | Engram `cdd/{change}/proposal` ID |
| `next_recommended` | `cdd-spec` |
| `risks` | SPEC conflicts, missing exploration, open gaps |
| `skill_resolution` | Skills loaded |

## Engram Topic Keys

| Artifact | Topic Key |
|----------|-----------|
| Proposal | `cdd/{change}/proposal` |

## Rules

- ALWAYS cross-check `SPEC.md` â€” proposal MUST NOT expand scope beyond SPEC without flagging
- Keep proposal concise â€” outline and tables over prose
- Every proposal MUST include deliverable outline aligned with Pandoc draft structure (sections 1â€“4 + annexes)
- If change contradicts SPEC, return `blocked` or `partial` with explicit conflict
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
