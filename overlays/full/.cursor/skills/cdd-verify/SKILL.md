---
name: cdd-verify
description: "Trigger: CDD verification phase, verify deliverable before Pandoc. QA pre-cliente â€” grep, revisores, no tests."
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
> the dedicated `cdd-verify` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-verify` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor â€” execute.

## Language Domain Contract

- **Verify report:** neutral professional Spanish unless the user requests otherwise.
- **Client deliverables under review:** formal Spanish per `draft-client-deliverable`.
- **Chat with user:** match user language.

## Purpose

You are a sub-agent responsible for **QA PRE-CLIENTE**. You prove the deliverable draft meets spec acceptance criteria, passes the internal-reference linter, and is ready for Pandoc â€” without running dev tests or builds.

## Consulting Hard Rules

- **NO `go test`, NO unit tests, NO builds, NO coverage** â€” verification is document QA only.
- **Mandatory:** run internal-reference grep from `deliverable-draft-workflow.mdc` on all `draft/*.md` â€” output MUST be empty to PASS.
- **Recommend delegation** (orchestrator executes): `review-client-facing` + `review-canonical-alignment` in parallel when available.
- **Recommend `judgment-day`** on draft files after apply or when issues are subtle.
- Do NOT fix issues â€” report for orchestrator/user or return to `cdd-apply`.
- Do NOT regenerate `.docx` â€” verify source `.md` only.

## Shared Contract

> Follow **Section A**, **Section B**, **Section C**, and **Section D** from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md`, `.cursor/rules/deliverable-draft-workflow.mdc`, and `.cursor/rules/client-deliverables.mdc`.

## What You Receive

From the orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- Optional: results from delegated `review-client-facing` and `review-canonical-alignment`

## Engram Retrieval

Required:
- `cdd/{change-name}/spec`
- `cdd/{change-name}/tasks`
- `cdd/{change-name}/apply-progress`

## Execution Steps

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.

### Step 2: Read Artifacts and Draft Files

1. Read spec â€” acceptance requirements and scenarios
2. Read tasks â€” confirm all writing tasks marked `[x]` (unchecked = CRITICAL)
3. Read apply-progress â€” files changed, known deviations
4. Read all `docs/draft/*.md` implicated by design/tasks

### Step 3: Mandatory Internal-Reference Grep

Run the **exact** linter from `deliverable-draft-workflow.mdc`:

```bash
cd "docs/draft" && grep -niE \
  "docs/|\.cursor|backlog/|architecture-gaps-and-questions|ARCHITECTURE\.md|SPEC\.md|archimate-{{CLIENT_SLUG}}|archi-server|transcripts/|transcripci|\.mdc|\btask-[0-9]|\bCursor\b" \
  *.md
```

On Windows/PowerShell, use equivalent search (e.g., `Select-String` with same pattern) if `grep` unavailable.

**Any hit = CRITICAL** â€” blocks PASS until fixed in `cdd-apply`.

Also perform **semantic review** (not grep-able) per workflow rule:
- Internal-only meetings without client cited? â†’ CRITICAL/WARNING
- "Official list" without **client-provided** context? â†’ WARNING
- Meeting dates without clear **with the client** context? â†’ WARNING

### Step 4: Spec Compliance Matrix

Map each acceptance requirement/scenario to draft evidence:

| Requisito | Escenario | Evidencia en draft | Estado |
|-----------|-----------|-------------------|--------|
| {ID} | {name} | {Â§ / file} | PASS / FAIL / MISSING |

Static reading of draft text is sufficient â€” no runtime tests.

### Step 5: Delegated Reviews (Recommend to Orchestrator)

If not already run, **recommend** orchestrator delegate in parallel:
- `review-client-facing` â€” tone, client-safe wording, no leakage
- `review-canonical-alignment` â€” deliverable reflects canonical sources

Incorporate delegated results into verify report when provided.

### Step 6: Recommend Judgment Day

When draft is substantial or prior reviews found WARNINGs, recommend `judgment-day` dual adversarial review on draft files before Pandoc.

### Step 7: Numbering and Composition Check

Verify per `deliverable-draft-workflow.mdc`:
- Main file sections 1â€“4
- Annexes continuous from 5+
- Cross-references in Â§4 match annex files
- Pandoc file list matches design (informational â€” do not run Pandoc in verify)

### Step 8: Persist Verify Report

**Mandatory â€” do NOT skip.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `verify-report`
- topic_key: `cdd/{change-name}/verify-report`
- type: `architecture`
- `capture_prompt: false`

### Step 9: Return Verification Report

```markdown
## Verification Report

**Change**: {change-name}
**Mode**: CDD document QA (no dev tests)

### Completeness
| DimensiÃ³n | Estado |
|-----------|--------|
| Tasks completadas | {N}/{total} |
| Archivos draft | {list} |

### Internal-Reference Grep
- Command: {shown}
- Hits: {0 or list with line numbers}
- Semantic review: {PASS / issues}

### Spec Compliance
{matrix}

### Delegated Reviews
| Review | Status | Summary |
|--------|--------|---------|
| review-client-facing | {done/pending} | {brief} |
| review-canonical-alignment | {done/pending} | {brief} |

### Issues
**CRITICAL**
- {issue}

**WARNING**
- {issue}

**SUGGESTION**
- {issue}

### Judgment Day
Recommended: {Yes/No} â€” {reason}

### Verdict
{PASS | PASS WITH WARNINGS | FAIL}

### Next Step
{PASS â†’ cdd-archive or Pandoc (user) | FAIL â†’ cdd-apply}
```

## Result Contract Fields

Return per **Section D** from `../_shared/cdd-phase-common.md`:

| Field | Content |
|-------|---------|
| `status` | `done` \| `blocked` \| `partial` |
| `executive_summary` | Verdict and critical blockers |
| `artifacts` | Engram `cdd/{change}/verify-report` ID |
| `next_recommended` | `cdd-apply` (FAIL), `judgment-day` (recommended), or `cdd-archive` (PASS) |
| `risks` | Grep hits, unchecked tasks, canonical drift |
| `skill_resolution` | Reviews delegated/recommended |

## Engram Topic Keys

| Artifact | Topic Key |
|----------|-----------|
| Verify report | `cdd/{change}/verify-report` |

## Decision Gates

| Condition | Action |
|-----------|--------|
| Grep hits > 0 | FAIL â€” return to cdd-apply |
| Unchecked writing task | CRITICAL â€” FAIL or PASS WITH WARNINGS if explicitly waived |
| Spec scenario MISSING | CRITICAL |
| CRITICAL issues | Verdict FAIL â€” blocks archive |
| WARNING only | PASS WITH WARNINGS |
| All checks pass | PASS |

## Rules

- NEVER use `go test`, builds, or coverage as verification evidence
- ALWAYS run internal-reference grep â€” skipping is FAIL
- Do NOT fix draft content â€” report only
- CRITICAL issues in verify report block `cdd-archive`
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
