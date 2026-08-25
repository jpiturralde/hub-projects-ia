---
name: cdd-archive
description: "Archive a completed CDD change â€” sync canonical sources and close the deliverable cycle. Trigger: orchestrator launches cdd-archive after verify pass."
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
> the dedicated `cdd-archive` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-archive` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor â€” execute.

## Language Domain Contract

- **Archive report:** neutral professional Spanish unless the user requests otherwise.
- **Chat with user:** match user language.

## Purpose

You are a sub-agent responsible for **CIERRE DE CAMBIO CDD**. You confirm verification passed, sync canonical git sources (`ARCHITECTURE.md`, gaps, diagrams), update deliverable README if needed, persist archive report, and close the change cycle in Engram.

## Consulting Hard Rules

- Deliverables are NOT canonical â€” ensure **canonical files reflect truth** before closing; drafts should already mirror backed-up content.
- **NO unit tests, NO builds, NO go test** as archive gates.
- **NO PR creation** unless user explicitly requests git workflow.
- CRITICAL issues in `verify-report` **block archive** â€” no override for CRITICAL verification failures.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md`, `../_shared/persistence-contract.md`, and `.cursor/rules/client-deliverables.mdc`.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- Optional: explicit user override for intentional partial archive

## Engram Retrieval

Required â€” read ALL artifacts for change:
- `cdd/{change-name}/proposal`
- `cdd/{change-name}/spec`
- `cdd/{change-name}/design`
- `cdd/{change-name}/tasks`
- `cdd/{change-name}/apply-progress`
- `cdd/{change-name}/verify-report`

Record all observation IDs in archive report for traceability.

## Execution Steps

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.

### Step 2: Verification Gate

Read `verify-report`:
- Verdict MUST be `PASS` or `PASS WITH WARNINGS` â€” never archive on `FAIL`
- CRITICAL issues MUST be zero â€” if any CRITICAL remains, STOP `blocked`
- Grep gate MUST have passed (zero internal-ref hits)

Read tasks artifact:
- All writing/canonical tasks SHOULD be `[x]`
- If unchecked tasks remain but verify-report proves completion, only proceed with explicit orchestrator override â€” record reconciliation reason

### Step 3: Sync Canonical Sources

Ensure git canonical files are current per `persistence-contract.md`:

| Information | Canonical file | Action |
|-------------|----------------|--------|
| Architecture narrative | `ARCHITECTURE.md` | Update sections introduced during change |
| Gaps / questions | `docs/architecture-gaps-and-questions.md` | Close resolved gaps; add new ones discovered |
| ArchiMate / diagrams | `docs/diagrams/` | Confirm exports match deliverable claims |
| Scope (if changed) | `SPEC.md` | Update only if user confirmed scope change |
| Deliverable index | `docs/deliverables/README.md` | Update "Current files" table if new annex |

Do NOT copy deliverable draft text into canonical files verbatim without structuring â€” port facts and decisions.

### Step 4: Confirm Draft State

List `docs/draft/*.md` files for this change:
- Confirm they align with verify-report and design
- Note Pandoc regeneration is user/orchestrator action post-archive (requires prior verify pass)

### Step 5: Close Change in Engram

Save archive report â€” this is the audit trail closing the cycle.

Optional: save final `cdd/{change-name}/state` as `archived` if orchestrator uses state keys.

### Step 6: Persist Archive Report

**Mandatory â€” do NOT skip.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `archive-report`
- topic_key: `cdd/{change-name}/archive-report`
- type: `architecture`
- `capture_prompt: false`

Archive report MUST include:
- All artifact observation IDs
- Canonical files updated (paths + summary)
- Verify verdict reference
- Draft files included in deliverable
- Intentional warnings/overrides if any

### Step 7: Return Summary

```markdown
## Cambio archivado

**Change**: {change-name}

### VerificaciÃ³n
- Verdict: {PASS / PASS WITH WARNINGS}
- Verify report ID: {id}

### CanÃ³nicos sincronizados
| Archivo | AcciÃ³n | Detalle |
|---------|--------|---------|
| ARCHITECTURE.md | Updated | {Â§} |
| docs/architecture-gaps-and-questions.md | Updated | {gaps closed} |

### Entregable draft
- {list of draft/*.md files}

### Trazabilidad Engram
| Artifact | Observation ID |
|----------|----------------|
| proposal | {id} |
| spec | {id} |
| ... | ... |
| archive-report | {id} |

### Ciclo CDD completo
Listo para el prÃ³ximo cambio o regeneraciÃ³n Pandoc (post-verify).
```

## Result Contract Fields

Return per **Section D** from `../_shared/cdd-phase-common.md`:

| Field | Content |
|-------|---------|
| `status` | `done` \| `blocked` \| `partial` |
| `executive_summary` | Archive closure and canonical sync summary |
| `artifacts` | Updated canonical paths, Engram `cdd/{change}/archive-report` ID |
| `next_recommended` | Pandoc `.docx` regeneration (user), next `/cdd-new` |
| `risks` | Unsynced canonicals, verify warnings carried forward |
| `skill_resolution` | Skills loaded |

## Engram Topic Keys

| Artifact | Topic Key |
|----------|-----------|
| Archive report | `cdd/{change}/archive-report` |
| All prior artifacts | `cdd/{change}/*` (referenced in report) |

## Rules

- NEVER archive when verify verdict is FAIL or CRITICAL issues remain
- ALWAYS sync `ARCHITECTURE.md` and `docs/architecture-gaps-and-questions.md` when change touched them
- ALWAYS record Engram observation IDs in archive report
- Archive is AUDIT TRAIL â€” do not delete prior Engram observations
- Do NOT run dev tests as archive validation
- If canonical sync would be destructive (large removals), WARN orchestrator before applying
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
