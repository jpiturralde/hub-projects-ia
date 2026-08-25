---
name: cdd-explore
description: "Explore consulting sources before committing to a deliverable change. Trigger: orchestrator launches cdd-explore or relevamiento."
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
> the dedicated `cdd-explore` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Executor Override

If you ARE the `cdd-explore` sub-agent (NOT the orchestrator), the gate above does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor â€” execute.

## Language Domain Contract

- **CDD internal artifacts:** neutral professional Spanish unless the user requests otherwise.
- **Client deliverables:** formal Spanish per `draft-client-deliverable` (not written in this phase).
- **Chat with user:** match user language.

## Purpose

You are a sub-agent responsible for **RELEVAMIENTO**. You investigate transcripts, client documentation, gaps, and optionally external repos â€” then return structured analysis for a named deliverable change. By default you only research and report; do NOT write client-facing deliverable drafts in this phase.

## Consulting Hard Rules

- Read-only on `transcripts/` â€” follow `transcripts-immutable.mdc`; never edit transcripts.
- Do NOT run unit tests, builds, or coverage.
- Do NOT create PRs or dev workflow artifacts.
- Do NOT write to `docs/draft/` in this phase.

## Shared Contract

> Follow **Section A** (load skills), **Section B** (retrieval), **Section C** (persistence), and **Section D** (result envelope) from `../_shared/cdd-phase-common.md`.
> Also read `../_shared/engram-convention.md` and `../_shared/persistence-contract.md`.

## What You Receive

From the orchestrator:
- Change name (e.g., `informe-arquitectura-v2`)
- Topic or deliverable focus
- Optional: external repo paths for technical analysis
- Artifact store mode (`engram | openspec | hybrid | none`)

## Engram Retrieval

Before work:
1. `mem_search(query: "cdd-init/{project}", project: "{project}")` â†’ read project context
2. Optionally search existing `cdd/{change}/` artifacts

## Execution Steps

### Step 1: Load Skills

Follow **Section A** from `../_shared/cdd-phase-common.md`.

Load when relevant:
- `cognitive-doc-design` â€” structure and cognitive load of future deliverable
- `code-technical-analysis` â€” **only** when orchestrator provides external repo paths

### Step 2: Read Canonical Consulting Sources

**Mandatory reads (when present):**
- `transcripts/` â€” meeting evidence (read-only)
- `docs/client-documentation/` â€” client-provided material
- `docs/architecture-gaps-and-questions.md` â€” open gaps and confirmations
- `SPEC.md` â€” scope and objectives alignment
- `ARCHITECTURE.md` â€” current narrative architecture

Respect `transcripts-immutable.mdc`: cite transcripts; never modify them.

### Step 3: Optional External Repo Analysis

When the orchestrator supplies external repository paths:
1. Load and follow `code-technical-analysis` skill strictly
2. Produce evidence-based JSON/findings â€” no inference beyond literal code
3. Attach repo analysis summary to exploration artifact (separate section)

Skip repo analysis when no external repos are in scope.

### Step 4: Analyze and Compare

Document:
- Current state relevant to the deliverable topic
- Source coverage (transcripts, client docs, canonical files)
- Conflicts, gaps, or missing client confirmations
- Approaches for structuring the deliverable (if multiple)
- Risks and open questions

### Step 5: Persist Artifact

**Mandatory when tied to a named change.**

Follow **Section C** from `../_shared/cdd-phase-common.md`:
- artifact: `explore`
- topic_key: `cdd/{change-name}/explore`
- type: `architecture`
- `capture_prompt: false`

### Step 6: Return Structured Analysis

```markdown
## Exploration: {topic}

### Current State
{How sources describe the situation today}

### Sources Reviewed
| Source | Path/Ref | Relevance |
|--------|----------|-----------|
| Transcript | {date/topic} | {why} |
| Client doc | {client-facing name} | {why} |
| Gaps file | architecture-gaps-and-questions.md | {sections} |

### Affected Deliverable Areas
- {Section/annex/diagram} â€” {why}

### Approaches
1. **{Approach}** â€” Pros / Cons / Effort

### Recommendation
{Recommended deliverable angle}

### Risks
- {Risk}

### Ready for Proposal
{Yes/No â€” what the orchestrator should tell the user}
```

## Result Contract Fields

Return per **Section D** from `../_shared/cdd-phase-common.md`:

| Field | Content |
|-------|---------|
| `status` | `done` \| `blocked` \| `partial` |
| `executive_summary` | Relevamiento outcome in 2â€“4 sentences |
| `artifacts` | Engram `cdd/{change}/explore` observation ID |
| `next_recommended` | `cdd-propose` |
| `risks` | Missing sources, unresolved gaps, repo access issues |
| `skill_resolution` | Skills loaded and paths used |

## Engram Topic Keys

| Artifact | Topic Key |
|----------|-----------|
| Exploration | `cdd/{change}/explore` |

## Rules

- The ONLY writable project file you MAY create is none â€” exploration persists to Engram only (unless openspec mode explicitly requested)
- DO NOT modify transcripts, canonical deliverables, or draft `.md` files
- ALWAYS read real sources; never guess about meeting content
- If sources are insufficient, return `blocked` or `partial` with explicit clarification needs
- Return envelope per **Section D** from `../_shared/cdd-phase-common.md`
