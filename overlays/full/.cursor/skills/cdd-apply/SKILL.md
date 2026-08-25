---
name: cdd-apply
description: "Write client deliverable drafts in docs/draft/. Trigger: orchestrator launches cdd-apply for assigned writing tasks."
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
> the dedicated `cdd-apply` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-apply` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor — execute.

## Language Domain Contract

- **Client deliverable drafts:** formal Spanish per `consulting-draft-client-deliverable`.
- **CDD internal artifacts** (apply-progress): neutral professional Spanish.
- **Chat with user:** match user language.

## Persistencia repo-first (prevalece sobre referencias legacy)

El artefacto completo se escribe en `.cdd/changes/{change-name}/{artifact}.md` y se actualiza `state.json`. Engram recibe sólo un resumen de hasta 250 palabras con decisiones, hallazgos, riesgos, estado, siguiente fase y puntero al archivo. No guardar el cuerpo completo ni recuperar observaciones completas si el puntero del resumen alcanza.

## Purpose

You are a sub-agent responsible for **REDACCIÓN**. You receive specific tasks from the tasks artifact and write client-facing Markdown **only** under `docs/draft/`. You follow spec, design, and `consulting-draft-client-deliverable` strictly.

## Consulting Hard Rules

- **Write ONLY** to `docs/draft/` for deliverable content.
- Canonical updates (ARCHITECTURE.md, gaps, Archi) happen per tasks — port to canonical BEFORE or AS documented in tasks, not inside deliverable text as internal refs.
- Load and follow **`consulting-draft-client-deliverable`** skill when writing.
- Follow **`client-deliverables.mdc`** and **`deliverable-draft-workflow.mdc`** for composition and forbidden references.
- **NO unit tests, NO builds, NO coverage, NO go test, NO strict TDD.**
- **NO PR creation** unless user explicitly requests git workflow.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md` and `../_shared/persistence-contract.md`.

## What You Receive

From the orchestrator:
- Change name
- Specific task(s) to execute (e.g., "Fase 2, tareas 2.1–2.3")
- Persistence mode (`hybrid-repo-first`)

## Repository retrieval

Required before writing:
- `.cdd/changes/{change-name}/tasks.md`
- `.cdd/changes/{change-name}/spec.md`
- `.cdd/changes/{change-name}/design.md`
- `.cdd/changes/{change-name}/apply-progress.md` if it exists

## Execution Steps

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.

**Mandatory loads:**
- `consulting-draft-client-deliverable`
- Read rules: `.cursor/rules/client-deliverables.mdc`, `.cursor/rules/deliverable-draft-workflow.mdc`

### Step 2: Read Context

Before writing ANY deliverable text:
1. Read spec — acceptance criteria are your quality bar
2. Read design — file names, numbering, canonical mapping
3. Read canonical sources cited in design (ARCHITECTURE.md, gaps, diagrams)
4. Read existing draft files in `docs/draft/` if present
5. Read previous apply-progress if orchestrator indicates prior batches

### Step 3: Canonical Port Gate

If assigned tasks include canonical ports (Fase 1):
- Update `ARCHITECTURE.md`, `docs/architecture-gaps-and-questions.md`, or diagrams **first**
- Only then write deliverable text that reflects backed-up content
- Never introduce new facts in deliverable that are not in canonical sources

### Step 4: Write Draft Files

**Allowed edit roots:** `docs/draft/` only for deliverable Markdown.

For each assigned task:
1. Open/create the target `.md` file per design
2. Use hierarchical numbering from `deliverable-draft-workflow.mdc`
3. Write formal Spanish, client-safe — **no internal repo paths**
4. Cite client material using client-facing names only
5. Mark task `[x]` in tasks artifact as you complete it

### Step 5: Mark Tasks Complete

Update `.cdd/changes/{change-name}/tasks.md` — change `- [ ]` to `- [x]` for completed tasks.

### Step 6: Persist Apply Progress

**Mandatory — do NOT skip.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `apply-progress`
- topic_key: `cdd/{change-name}/apply-progress`
- type: `architecture`
- `capture_prompt: false`

**Merge protocol:** If previous apply-progress exists, include ALL prior completions plus new work in one cumulative artifact.

Apply-progress MUST list:
- Completed tasks with checkbox state
- Files changed under `draft/`
- Deviations from design (or "None")
- Remaining tasks

### Step 7: Return Summary

```markdown
## Progreso de redacción

**Change**: {change-name}

### Tareas completadas
- [x] {task}

### Archivos draft modificados
| Archivo | Acción | Qué se hizo |
|---------|--------|-------------|
| `docs/draft/{file}.md` | Created/Modified | {brief} |

### Desviaciones del diseño
{None or list}

### Tareas pendientes
- [ ] {next}

### Estado
{N}/{total} tareas. {Listo para siguiente lote / Listo para cdd-verify}
```

## Result Contract Fields

Return per **Section D** from `../_shared/cdd-phase-common.md`:

| Field | Content |
|-------|---------|
| `status` | `done` \| `blocked` \| `partial` |
| `executive_summary` | Writing progress summary |
| `artifacts` | Draft file paths, Engram `cdd/{change}/apply-progress` ID, updated tasks ID |
| `next_recommended` | `cdd-apply` (next batch) or `cdd-verify` when all tasks complete |
| `risks` | Missing canonical sources, internal refs introduced, numbering breaks |
| `skill_resolution` | `consulting-draft-client-deliverable` loaded |

## Engram Topic Keys

| Artifact | Topic Key |
|----------|-----------|
| Apply progress | `cdd/{change}/apply-progress` |
| Tasks (updated) | `cdd/{change}/tasks` |

## Rules

- NEVER write deliverable content outside `docs/draft/`
- NEVER run tests or builds as validation
- ALWAYS follow `consulting-draft-client-deliverable` tone and structure
- ALWAYS mark completed tasks in persisted tasks artifact before returning
- If canonical source is missing, STOP and report — do not invent client-facing facts
- Do NOT regenerate `.docx` in apply — that follows successful `cdd-verify`
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
