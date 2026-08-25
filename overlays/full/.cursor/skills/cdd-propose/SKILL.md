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
> the ORCHESTRATOR — STOP. Do NOT execute these instructions inline. Delegate to
> the dedicated `cdd-propose` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-propose` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor — execute.

## Language Domain Contract

- **CDD internal artifacts:** neutral professional Spanish unless the user requests otherwise.
- **Client deliverables:** formal Spanish per `consulting-draft-client-deliverable` (proposal is internal planning).
- **Chat with user:** match user language.

## Persistencia repo-first (prevalece sobre referencias legacy)

El artefacto completo se escribe en `.cdd/changes/{change-name}/{artifact}.md` y se actualiza `state.json`. Engram recibe sólo un resumen de hasta 250 palabras con decisiones, hallazgos, riesgos, estado, siguiente fase y puntero al archivo. No guardar el cuerpo completo ni recuperar observaciones completas si el puntero del resumen alcanza.

## Purpose

You are a sub-agent responsible for **PROPUESTA DE ENTREGABLE**. You take exploration analysis (or direct user input) and produce a structured proposal aligned with `SPEC.md` scope and objectives.

## Consulting Hard Rules

- Align every deliverable outline section with `SPEC.md` — cite SPEC sections when mapping scope.
- Do NOT run unit tests, builds, or coverage.
- Do NOT create PRs or dev workflow artifacts.
- Do NOT write client-facing draft files in `docs/draft/` — proposal is internal planning under `.cdd/`.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md` and `../_shared/persistence-contract.md`.

## What You Receive

From the orchestrator:
- Change name
- Exploration analysis (from `cdd-explore`) OR direct user description
- Persistence mode (`hybrid-repo-first`)

## Repository retrieval

Required reads:
- `.cdd/changes/{change-name}/explore.md` (optional)
- `.cdd/project-context.md`
- Read **SPEC.md** from workspace — mandatory cross-check

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
- Initiative objectives → deliverable intent
- In-scope items → proposal in-scope
- Out-of-scope → proposal out-of-scope (explicit deferrals)
- Flag any proposal scope that contradicts SPEC — report as risk

### Step 3: Write Proposal Artifact

```markdown
# Propuesta: {Título del entregable}

## Intent
{Problema / necesidad del cliente que resuelve este entregable}

## Alineación con SPEC.md
| Objetivo SPEC | Cobertura en esta propuesta |
|---------------|----------------------------|
| {objetivo} | {cómo se cubre} |

## Alcance

### Incluido
- {Sección / anexo / diagrama concreto}

### Excluido
- {Explícitamente fuera de este entregable}

## Esquema del entregable (outline)
1. Motivo del trabajo
2. Etapa / contexto
3. Detalle técnico
4. Anexos técnicos
   - Anexo A — {tema}
   - Anexo B — {tema}

## Fuentes canónicas previstas
| Información | Fuente canónica |
|-------------|-----------------|
| {tipo} | {ARCHITECTURE.md / Archi / gaps / etc.} |

## Enfoque
{Cómo se construirá el entregable — narrativa, diagramas, nivel de detalle}

## Riesgos
| Riesgo | Mitigación |
|--------|------------|
| {riesgo} | {acción} |

## Criterios de éxito
- [ ] {Medible / verificable antes de enviar al cliente}

## Dependencias
- {Gap abierto, confirmación pendiente, material del cliente}
```

### Step 4: Persist Artifact

**Mandatory — do NOT skip.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `proposal`
- topic_key: `cdd/{change-name}/proposal`
- type: `architecture`
- `capture_prompt: false`

### Step 5: Return Summary

```markdown
## Propuesta creada

**Change**: {change-name}
**Ubicación**: Engram `cdd/{change-name}/proposal`

### Resumen
- **Intent**: {one-line}
- **Alineación SPEC**: {OK / gaps flagged}
- **Outline**: {N secciones, M anexos}
- **Riesgo**: {Low/Medium/High}

### Próximo paso
Listo para cdd-spec (criterios de aceptación).
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

- ALWAYS cross-check `SPEC.md` — proposal MUST NOT expand scope beyond SPEC without flagging
- Keep proposal concise — outline and tables over prose
- Every proposal MUST include deliverable outline aligned with Pandoc draft structure (sections 1–4 + annexes)
- If change contradicts SPEC, return `blocked` or `partial` with explicit conflict
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
